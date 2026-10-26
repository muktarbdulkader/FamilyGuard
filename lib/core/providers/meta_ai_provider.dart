import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/meta_ai_service.dart';
import '../models/app_info.dart';
import 'family_provider.dart';

/// Represents a message in the AI Guardian interactive session
class AiGuardianMessage {
  final String id;
  final String sender; // 'user' or 'ai'
  final String text;
  final DateTime timestamp;
  final AgentReasoningResult? reasoningResult;

  AiGuardianMessage({
    required this.id,
    required this.sender,
    required this.text,
    required this.timestamp,
    this.reasoningResult,
  });
}

/// State of the Meta AI Guardian Agent
class MetaAiGuardianState {
  final bool isLoading;
  final MetaModelChoice selectedModel;
  final AgentReasoningResult? lastAgentResult;
  final VisualSafetyAuditResult? lastSamVisualResult;
  final String? voiceTranscription;
  final String? generatedBadgeMessage;
  final String? errorMessage;
  final bool isListeningVoice;
  final List<AgentToolAction> pendingApprovals;
  final List<AiGuardianMessage> messages;

  MetaAiGuardianState({
    this.isLoading = false,
    this.selectedModel = MetaModelChoice.museSpark,
    this.lastAgentResult,
    this.lastSamVisualResult,
    this.voiceTranscription,
    this.generatedBadgeMessage,
    this.errorMessage,
    this.isListeningVoice = false,
    this.pendingApprovals = const [],
    this.messages = const [],
  });

  MetaAiGuardianState copyWith({
    bool? isLoading,
    MetaModelChoice? selectedModel,
    AgentReasoningResult? lastAgentResult,
    VisualSafetyAuditResult? lastSamVisualResult,
    String? voiceTranscription,
    String? generatedBadgeMessage,
    String? errorMessage,
    bool? isListeningVoice,
    List<AgentToolAction>? pendingApprovals,
    List<AiGuardianMessage>? messages,
  }) {
    return MetaAiGuardianState(
      isLoading: isLoading ?? this.isLoading,
      selectedModel: selectedModel ?? this.selectedModel,
      lastAgentResult: lastAgentResult ?? this.lastAgentResult,
      lastSamVisualResult: lastSamVisualResult ?? this.lastSamVisualResult,
      voiceTranscription: voiceTranscription ?? this.voiceTranscription,
      generatedBadgeMessage: generatedBadgeMessage ?? this.generatedBadgeMessage,
      errorMessage: errorMessage,
      isListeningVoice: isListeningVoice ?? this.isListeningVoice,
      pendingApprovals: pendingApprovals ?? this.pendingApprovals,
      messages: messages ?? this.messages,
    );
  }
}

class MetaAiGuardianNotifier extends StateNotifier<MetaAiGuardianState> {
  final MetaAiService _service = MetaAiService.instance;

  MetaAiGuardianNotifier() : super(MetaAiGuardianState()) {
    _init();
  }

  Future<void> _init() async {
    await _service.init();
    state = state.copyWith(selectedModel: _service.activeModel);
  }

  Future<void> selectModel(MetaModelChoice model) async {
    await _service.setActiveModel(model);
    state = state.copyWith(selectedModel: model);
  }

  Future<void> saveApiKey(String key) async {
    await _service.setApiKey(key);
  }

  int _currentExecutionId = 0;

  /// Stop currently running agent evaluation
  void stopAgent() {
    _currentExecutionId++;
    if (state.isLoading) {
      final stoppedMsg = AiGuardianMessage(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        sender: 'ai',
        text: '⏹️ Agent evaluation stopped by parent.',
        timestamp: DateTime.now(),
      );
      state = state.copyWith(
        isLoading: false,
        messages: [...state.messages, stoppedMsg],
      );
    }
  }

  /// Run Autonomous Agent with Child Context
  Future<void> triggerAgent({
    required String childName,
    int childAge = 12,
    String contextInfo = 'Active on device for 3h 15m. Homework due tonight.',
    required String prompt,
  }) async {
    final executionId = ++_currentExecutionId;
    final userMsg = AiGuardianMessage(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      sender: 'user',
      text: prompt,
      timestamp: DateTime.now(),
    );
    final updatedMessages = List<AiGuardianMessage>.from(state.messages)..add(userMsg);
    state = state.copyWith(isLoading: true, errorMessage: null, messages: updatedMessages);

    try {
      final result = await _service.runFamilyGuardianAgent(
        childName: childName,
        childAge: childAge,
        recentActivityContext: contextInfo,
        promptOrTrigger: prompt,
      );

      // Discard result if user stopped this evaluation
      if (executionId != _currentExecutionId) return;

      final newPending = result.toolActions
          .where((action) => action.requiresParentConfirmation && !action.isExecuted)
          .toList();

      final aiMsg = AiGuardianMessage(
        id: (DateTime.now().microsecondsSinceEpoch + 1).toString(),
        sender: 'ai',
        text: result.parentSummary,
        timestamp: DateTime.now(),
        reasoningResult: result,
      );
      final finalMessages = List<AiGuardianMessage>.from(state.messages)..add(aiMsg);

      state = state.copyWith(
        isLoading: false,
        lastAgentResult: result,
        pendingApprovals: newPending,
        messages: finalMessages,
      );
    } catch (e) {
      if (executionId != _currentExecutionId) return;
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  /// Run SAM 3.1 Visual Risk Audit
  Future<void> triggerSamVisualAudit() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final visualResult = await _service.runSam31VisualAudit();
      state = state.copyWith(
        isLoading: false,
        lastSamVisualResult: visualResult,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  /// Approve and execute pending parent tool action
  Future<void> approveToolAction(
    AgentToolAction action, {
    String? familyId,
    String? childId,
  }) async {
    action.isExecuted = true;
    final updatedList = List<AgentToolAction>.from(state.pendingApprovals)
      ..removeWhere((a) => a.toolName == action.toolName);
    state = state.copyWith(pendingApprovals: updatedList);

    // If familyId and childId are provided, execute the real action in Firestore
    if (familyId != null && familyId.isNotEmpty && childId != null && childId.isNotEmpty) {
      try {
        final toolName = action.toolName.toLowerCase();
        final params = action.parameters;
        final appTarget = (params['app'] ?? params['packageName'] ?? '').toString().toLowerCase();

        if (toolName.contains('lock') || toolName.contains('limit') || toolName.contains('guard') || toolName.contains('shield')) {
          final packageName = appTarget.contains('tiktok')
              ? 'com.zhiliaoapp.musically'
              : appTarget.contains('youtube')
                  ? 'com.google.android.youtube'
                  : appTarget.contains('roblox')
                      ? 'com.roblox.client'
                      : (appTarget.isNotEmpty ? appTarget : 'com.entertainment.general');

          final limitMinutes = params['limitMinutes'] ?? params['maxDailyMinutes'] ?? 0;

          await AppRuleService().updateAppRule(
            familyId: familyId,
            childId: childId,
            packageName: packageName,
            rule: limitMinutes > 0 ? AppControlRule.timeLimited : AppControlRule.block,
            dailyLimitMinutes: limitMinutes > 0 ? (limitMinutes as num).toInt() : null,
          );
        }
      } catch (e) {
        // Safe execution
      }
    }
  }

  /// Transcribe voice command via Muse Voice
  Future<void> simulateVoiceCommand(String langCode) async {
    state = state.copyWith(isListeningVoice: true);
    await Future.delayed(const Duration(milliseconds: 1200));
    final transcript = await _service.transcribeVoice(
      audioPath: 'virtual_audio_buffer',
      language: langCode,
    );
    state = state.copyWith(
      isListeningVoice: false,
      voiceTranscription: transcript,
    );
  }

  /// Generate Muse Image positive reinforcement badge
  Future<void> generateRewardBadge(String title) async {
    state = state.copyWith(isLoading: true);
    final badgeMsg = await _service.generatePositiveReinforcementBadge(
      achievementTitle: title,
      childInterest: 'Science & Gaming',
    );
    state = state.copyWith(isLoading: false, generatedBadgeMessage: badgeMsg);
  }
}

final metaAiGuardianProvider =
    StateNotifierProvider<MetaAiGuardianNotifier, MetaAiGuardianState>((ref) {
  return MetaAiGuardianNotifier();
});
