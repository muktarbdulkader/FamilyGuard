import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/meta_ai_service.dart';

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

  /// Run Autonomous Agent with Child Context
  Future<void> triggerAgent({
    required String childName,
    int childAge = 12,
    String contextInfo = 'Active on device for 3h 15m. Homework due tonight.',
    required String prompt,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final result = await _service.runFamilyGuardianAgent(
        childName: childName,
        childAge: childAge,
        recentActivityContext: contextInfo,
        promptOrTrigger: prompt,
      );

      final newPending = result.toolActions
          .where((action) => action.requiresParentConfirmation && !action.isExecuted)
          .toList();

      state = state.copyWith(
        isLoading: false,
        lastAgentResult: result,
        pendingApprovals: newPending,
      );
    } catch (e) {
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
  void approveToolAction(AgentToolAction action) {
    action.isExecuted = true;
    final updatedList = List<AgentToolAction>.from(state.pendingApprovals)
      ..removeWhere((a) => a.toolName == action.toolName);
    state = state.copyWith(pendingApprovals: updatedList);
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
