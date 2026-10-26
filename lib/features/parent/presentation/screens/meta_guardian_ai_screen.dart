import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/meta_ai_provider.dart';
import '../../../../core/providers/family_provider.dart';
import '../../../../core/services/meta_ai_service.dart';
import '../widgets/ai_telemetry_chart_card.dart';

class MetaGuardianAiScreen extends ConsumerStatefulWidget {
  const MetaGuardianAiScreen({super.key});

  @override
  ConsumerState<MetaGuardianAiScreen> createState() => _MetaGuardianAiScreenState();
}

class _MetaGuardianAiScreenState extends ConsumerState<MetaGuardianAiScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _promptController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  static const Color _tealAccent = Color(0xFF14B8A6);
  static const Color _aiPurple = Color(0xFF8B5CF6);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);

    // Trigger initial agent analysis on load if messages are empty
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = ref.read(metaAiGuardianProvider);
      final selectedChild = ref.read(selectedChildProvider);
      final childName = selectedChild?.displayName ?? 'Leo';

      if (state.messages.isEmpty) {
        ref.read(metaAiGuardianProvider.notifier).triggerAgent(
              childName: childName,
              prompt: 'Nighttime schedule check and safety audit',
            );
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _promptController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final aiState = ref.watch(metaAiGuardianProvider);
    final selectedChild = ref.watch(selectedChildProvider);
    final childName = selectedChild?.displayName ?? 'Leo';

    final bgColor = isDark ? const Color(0xFF0A1220) : const Color(0xFFF8FAFC);
    final surfaceColor = isDark ? const Color(0xFF111E33) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: surfaceColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textPrimary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_tealAccent, _aiPurple],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'FamilyGuard AI Guardian',
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: _tealAccent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          aiState.selectedModel.displayName,
                          style: TextStyle(
                            color: textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Model & API Config',
            icon: const Icon(Icons.tune_rounded, color: _tealAccent),
            onPressed: () => _showModelSettingsDialog(context, aiState, isDark),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: _tealAccent,
          indicatorWeight: 3,
          labelColor: _tealAccent,
          unselectedLabelColor: textSecondary,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.psychology_rounded, size: 20), text: 'Agent'),
            Tab(icon: Icon(Icons.center_focus_strong_rounded, size: 20), text: 'SAM 3.1'),
            Tab(icon: Icon(Icons.mic_rounded, size: 20), text: 'Voice'),
            Tab(icon: Icon(Icons.palette_rounded, size: 20), text: 'Rewards'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 1. Interactive Autonomous Agent Hub
          _buildAgentView(aiState, childName, isDark),
          // 2. SAM 3.1 Visual Risk Shield
          _buildSamVisualView(aiState, isDark),
          // 3. Muse Voice Transcribe Co-Pilot
          _buildVoiceView(aiState, isDark),
          // 4. Muse Image Generative Rewards
          _buildRewardsView(aiState, childName, isDark),
        ],
      ),
    );
  }

  // ── Tab 1: Autonomous Agent & Interactive Chat View ───────────────────────
  Widget _buildAgentView(MetaAiGuardianState state, String childName, bool isDark) {
    final selectedChild = ref.watch(selectedChildProvider);
    final surfaceColor = isDark ? const Color(0xFF111E33) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF1E2D4A) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final inputBg = isDark ? const Color(0xFF132238) : const Color(0xFFF1F5F9);

    return Column(
      children: [
        // Scrollable content area
        Expanded(
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Hackathon Banner
                _buildHackathonBadge(isDark),
                const SizedBox(height: 14),

                // Child Status Overview Card
                _buildChildOverviewCard(
                  childName,
                  state.lastAgentResult?.safetyScore ?? 92.0,
                  isDark,
                ),
                const SizedBox(height: 14),

                // Visual AI Telemetry Chart & Graphs
                AiTelemetryChartCard(
                  childName: childName,
                  isDark: isDark,
                ),
                const SizedBox(height: 16),

                // Quick Action Triggers
                Text(
                  'Autonomous Guardian Triggers',
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      _buildQuickActionChip(
                        icon: Icons.nightlight_round,
                        label: 'Bedtime Wind-Down',
                        color: Colors.indigoAccent,
                        isDark: isDark,
                        onTap: () {
                          ref.read(metaAiGuardianProvider.notifier).triggerAgent(
                                childName: childName,
                                prompt: 'Check bedtime compliance and lock entertainment apps for night wind-down',
                              );
                          _scrollToBottom();
                        },
                      ),
                      const SizedBox(width: 8),
                      _buildQuickActionChip(
                        icon: Icons.school_rounded,
                        label: 'Study Focus Mode',
                        color: Colors.teal,
                        isDark: isDark,
                        onTap: () {
                          ref.read(metaAiGuardianProvider.notifier).triggerAgent(
                                childName: childName,
                                prompt: 'Activate Study Focus Shield for homework and mute gaming distractions',
                              );
                          _scrollToBottom();
                        },
                      ),
                      const SizedBox(width: 8),
                      _buildQuickActionChip(
                        icon: Icons.shield_rounded,
                        label: 'Social Risk Scan',
                        color: Colors.deepOrangeAccent,
                        isDark: isDark,
                        onTap: () {
                          ref.read(metaAiGuardianProvider.notifier).triggerAgent(
                                childName: childName,
                                prompt: 'Scan social chat interactions and external link risks via Llama Guard',
                              );
                          _scrollToBottom();
                        },
                      ),
                      const SizedBox(width: 8),
                      _buildQuickActionChip(
                        icon: Icons.timer_rounded,
                        label: 'Screen Time Audit',
                        color: Colors.purpleAccent,
                        isDark: isDark,
                        onTap: () {
                          ref.read(metaAiGuardianProvider.notifier).triggerAgent(
                                childName: childName,
                                prompt: 'Audit screen time and daily quota usage across apps',
                              );
                          _scrollToBottom();
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Conversation / Multi-Turn Feed Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _tealAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: _tealAccent.withValues(alpha: 0.4)),
                      ),
                      child: const Text(
                        'LIVE AGENT STREAM',
                        style: TextStyle(
                          color: _tealAccent,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Parent & Copilot Dialogue',
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Message Thread
                if (state.messages.isEmpty && !state.isLoading)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: cardBorder),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.chat_bubble_outline_rounded, color: textSecondary, size: 36),
                        const SizedBox(height: 8),
                        Text(
                          'No messages yet',
                          style: TextStyle(color: textPrimary, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Type a message or tap one of the triggers above to consult Meta AI Guardian.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  )
                else
                  ...state.messages.map((msg) => _buildMessageBubble(msg, childName, isDark)),

                // Loading Indicator
                if (state.isLoading)
                  Container(
                    margin: const EdgeInsets.only(top: 8, bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _tealAccent.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: _tealAccent),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Meta AI is evaluating child telemetry & formulating safety response...',
                            style: TextStyle(color: textSecondary, fontSize: 11.5),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            ref.read(metaAiGuardianProvider.notifier).stopAgent();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.redAccent.withValues(alpha: 0.45)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.stop_rounded, color: Colors.redAccent, size: 14),
                                SizedBox(width: 3),
                                Text(
                                  'Stop',
                                  style: TextStyle(
                                    color: Colors.redAccent,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 12),
              ],
            ),
          ),
        ),

        // Bottom Input Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: surfaceColor,
            border: Border(top: BorderSide(color: cardBorder)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                blurRadius: 10,
                offset: const Offset(0, -3),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                    decoration: BoxDecoration(
                      color: inputBg,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: cardBorder),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.bolt_rounded, color: _tealAccent, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _promptController,
                            style: TextStyle(color: textPrimary, fontSize: 14),
                            decoration: InputDecoration(
                              hintText: 'Ask Meta AI to balance, lock, or check...',
                              hintStyle: TextStyle(color: textSecondary, fontSize: 13),
                              border: InputBorder.none,
                            ),
                            onSubmitted: (val) {
                              if (val.trim().isNotEmpty && !state.isLoading) {
                                final usageMap = ref.read(childAppUsageProvider(selectedChild?.id ?? '')).asData?.value ?? {};
                                final usageSummary = usageMap.isNotEmpty
                                    ? usageMap.values.map((u) => '${u.appName}: ${u.todayMinutes}m (${u.openCount} opens)').join(', ')
                                    : 'Active on device today';

                                ref.read(metaAiGuardianProvider.notifier).triggerAgent(
                                      childName: childName,
                                      contextInfo: 'Live Firestore Telemetry: $usageSummary',
                                      prompt: val.trim(),
                                    );
                                _promptController.clear();
                                _scrollToBottom();
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: state.isLoading
                          ? [Colors.redAccent, Colors.deepOrangeAccent]
                          : [_tealAccent, _aiPurple],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    tooltip: state.isLoading ? 'Stop' : 'Send',
                    icon: Icon(
                      state.isLoading ? Icons.stop_rounded : Icons.send_rounded,
                      color: Colors.white,
                      size: 19,
                    ),
                    onPressed: () {
                      if (state.isLoading) {
                        ref.read(metaAiGuardianProvider.notifier).stopAgent();
                        return;
                      }
                      final text = _promptController.text.trim();
                      if (text.isNotEmpty) {
                        final usageMap = ref.read(childAppUsageProvider(selectedChild?.id ?? '')).asData?.value ?? {};
                        final usageSummary = usageMap.isNotEmpty
                            ? usageMap.values.map((u) => '${u.appName}: ${u.todayMinutes}m (${u.openCount} opens)').join(', ')
                            : 'Active on device today';

                        ref.read(metaAiGuardianProvider.notifier).triggerAgent(
                              childName: childName,
                              contextInfo: 'Live Firestore Telemetry: $usageSummary',
                              prompt: text,
                            );
                        _promptController.clear();
                        _scrollToBottom();
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMessageBubble(AiGuardianMessage msg, String childName, bool isDark) {
    final surfaceColor = isDark ? const Color(0xFF111E33) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF1E2D4A) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    if (msg.sender == 'user') {
      // Parent's sent message card
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12, left: 40),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0D9488), Color(0xFF0F766E)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(4),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.teal.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.person_rounded, size: 13, color: Colors.white70),
                  const SizedBox(width: 4),
                  const Text(
                    'You',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${msg.timestamp.hour.toString().padLeft(2, '0')}:${msg.timestamp.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(color: Colors.white54, fontSize: 10),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                msg.text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // AI's response message card
    final reasoning = msg.reasoningResult;
    final safetyScore = reasoning?.safetyScore ?? 94.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16, right: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with AI Icon, Model & Safety Score
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: _tealAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.auto_awesome, color: _tealAccent, size: 15),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Meta AI Copilot',
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _tealAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _tealAccent.withValues(alpha: 0.3)),
                ),
                child: Text(
                  '${safetyScore.toInt()}% Safe',
                  style: const TextStyle(
                    color: _tealAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Main answer
          Text(
            msg.text,
            style: TextStyle(
              color: textPrimary,
              fontSize: 13.5,
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),

          // Detected Risks if any (Responsive Column with Expanded text)
          if (reasoning != null && reasoning.detectedRisks.isNotEmpty) ...[
            const SizedBox(height: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: reasoning.detectedRisks.map((risk) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 14),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          risk,
                          style: TextStyle(
                            color: isDark ? Colors.amber.shade200 : Colors.amber.shade900,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],

          // Expandable Re-Act Agent Trace
          if (reasoning != null) ...[
            const SizedBox(height: 12),
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(top: 8),
                title: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _aiPurple.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'RE-ACT TRACE',
                        style: TextStyle(
                          color: _aiPurple,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Multi-Step Agent Reasoning',
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                children: [
                  _buildReasoningStepCard(
                    stepNumber: '1',
                    title: 'Context Observation & Thought',
                    content: reasoning.thought,
                    icon: Icons.psychology_alt_rounded,
                    accentColor: _aiPurple,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 8),
                  _buildReasoningStepCard(
                    stepNumber: '2',
                    title: 'Formulated Strategic Plan',
                    content: reasoning.plan,
                    icon: Icons.checklist_rounded,
                    accentColor: _tealAccent,
                    isDark: isDark,
                  ),
                  if (reasoning.toolActions.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _buildToolActionsCard(reasoning.toolActions, isDark),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Tab 2: SAM 3.1 Visual Risk Shield ─────────────────────────────────────
  Widget _buildSamVisualView(MetaAiGuardianState state, bool isDark) {
    final visualResult = state.lastSamVisualResult;
    final surfaceColor = isDark ? const Color(0xFF111E33) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF1E2D4A) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cardBorder),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.cyan.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.center_focus_strong, color: Colors.cyan, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Meta SAM 3.1 Screen Shield',
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Segment Anything 3.1 visual risk audit detects predatory dark patterns and risky feeds.',
                        style: TextStyle(color: textSecondary, fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              onPressed: state.isLoading
                  ? null
                  : () => ref.read(metaAiGuardianProvider.notifier).triggerSamVisualAudit(),
              icon: state.isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.document_scanner_rounded, size: 18),
              label: Text(
                state.isLoading ? 'SAM 3.1 Analyzing Screen...' : 'Run SAM 3.1 Visual Safety Audit',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0891B2),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Simulated Device Screen with SAM 3.1 Overlay
          Container(
            height: 240,
            width: double.infinity,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF070D17) : const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.cyan.withValues(alpha: 0.4), width: 1.5),
            ),
            child: Stack(
              children: [
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.phone_android_rounded, size: 56, color: Colors.white.withValues(alpha: 0.2)),
                      const SizedBox(height: 8),
                      Text(
                        'Child Active Screen Canvas',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 20,
                  right: 18,
                  width: 90,
                  height: 38,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.amber, width: 2),
                      color: Colors.amber.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Text(
                        'SAM: Chat Icon\n[Warning 91%]',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.amber, fontSize: 8, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 20,
                  left: 20,
                  right: 20,
                  height: 48,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.redAccent, width: 2),
                      color: Colors.redAccent.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Text(
                        'SAM 3.1 Segmented: Microtransaction Dark Pattern [Critical 96%]',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (visualResult != null) ...[
            Text(
              'Segmented Region Insights',
              style: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            ...visualResult.segments.map((seg) => _buildSegmentItem(seg, isDark)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cardBorder),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lightbulb_outline_rounded, color: _tealAccent, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      visualResult.recommendation,
                      style: TextStyle(color: textPrimary, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Tab 3: Muse Voice Transcribe ──────────────────────────────────────────
  Widget _buildVoiceView(MetaAiGuardianState state, bool isDark) {
    final surfaceColor = isDark ? const Color(0xFF111E33) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF1E2D4A) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cardBorder),
            ),
            child: Row(
              children: [
                const Icon(Icons.record_voice_over_rounded, color: _tealAccent, size: 26),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Meta Muse Voice Transcribe',
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Zero-latency multilingual voice interpretation (English, Amharic, Oromo, Arabic).',
                        style: TextStyle(color: textSecondary, fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          Center(
            child: Column(
              children: [
                GestureDetector(
                  onTap: () => ref.read(metaAiGuardianProvider.notifier).simulateVoiceCommand('en'),
                  child: Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [_tealAccent, _aiPurple],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _tealAccent.withValues(alpha: 0.35),
                          blurRadius: 20,
                          spreadRadius: 3,
                        ),
                      ],
                    ),
                    child: state.isListeningVoice
                        ? const Center(
                            child: SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                            ),
                          )
                        : const Icon(Icons.mic, color: Colors.white, size: 36),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  state.isListeningVoice ? 'Listening via Meta Muse Voice...' : 'Tap to speak voice command',
                  style: TextStyle(color: textSecondary, fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          Text(
            'Test Multilingual Voice Samples',
            style: TextStyle(color: textPrimary, fontSize: 13.5, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildLangChip('English', 'en', isDark),
              _buildLangChip('አማርኛ (Amharic)', 'am', isDark),
              _buildLangChip('Afaan Oromoo', 'om', isDark),
              _buildLangChip('العربية (Arabic)', 'ar', isDark),
            ],
          ),
          const SizedBox(height: 18),

          if (state.voiceTranscription != null) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _tealAccent.withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.transcribe_rounded, color: _tealAccent, size: 18),
                      SizedBox(width: 6),
                      Text(
                        'Muse Voice Transcribe Output',
                        style: TextStyle(color: _tealAccent, fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    state.voiceTranscription!,
                    style: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      final selectedChild = ref.read(selectedChildProvider);
                      final childName = selectedChild?.displayName ?? 'Leo';
                      ref.read(metaAiGuardianProvider.notifier).triggerAgent(
                            childName: childName,
                            prompt: state.voiceTranscription!,
                          );
                      _tabController.animateTo(0);
                    },
                    icon: const Icon(Icons.play_arrow_rounded, size: 16),
                    label: const Text('Execute through Copilot Agent'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _tealAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Tab 4: Muse Image Positive Reinforcement ─────────────────────────────
  Widget _buildRewardsView(MetaAiGuardianState state, String childName, bool isDark) {
    final surfaceColor = isDark ? const Color(0xFF111E33) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF1E2D4A) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cardBorder),
            ),
            child: Row(
              children: [
                const Icon(Icons.palette_rounded, color: Colors.amber, size: 26),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Meta Muse Image Reward Studio',
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Generates tailored 3D achievement badges to celebrate completed study milestones.',
                        style: TextStyle(color: textSecondary, fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              onPressed: state.isLoading
                  ? null
                  : () => ref
                      .read(metaAiGuardianProvider.notifier)
                      .generateRewardBadge('Math Geometry Master'),
              icon: const Icon(Icons.star_rounded, color: Colors.white, size: 18),
              label: const Text(
                'Generate Custom Achievement Crest',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD97706),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFEAB308).withValues(alpha: isDark ? 0.15 : 0.08),
                  surfaceColor,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFEAB308).withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(
                      colors: [Color(0xFFFDE047), Color(0xFFCA8A04)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFEAB308).withValues(alpha: 0.35),
                        blurRadius: 18,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.military_tech_rounded, size: 48, color: Color(0xFF422006)),
                ),
                const SizedBox(height: 12),
                Text(
                  '$childName\'s Gold Math Crest',
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Rendered via Meta Muse Image Generator',
                  style: TextStyle(color: textSecondary, fontSize: 11),
                ),
                const SizedBox(height: 10),
                Text(
                  state.generatedBadgeMessage ??
                      'Awarded for completing 3 modules in Algebra without screen-time distraction penalties!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: textSecondary, fontSize: 12.5, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Supporting Widget Builders ────────────────────────────────────────────

  Widget _buildHackathonBadge(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _tealAccent.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: _tealAccent.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.emoji_events_rounded, color: _tealAccent, size: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Meta Global AI Hackathon Edition',
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Build for Your World · Multi-Model Autonomous Guardian',
                  style: TextStyle(
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChildOverviewCard(String childName, double safetyScore, bool isDark) {
    final surfaceColor = isDark ? const Color(0xFF111E33) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF1E2D4A) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: _tealAccent.withValues(alpha: 0.2),
            child: Text(
              childName.isNotEmpty ? childName[0].toUpperCase() : 'C',
              style: const TextStyle(color: _tealAccent, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$childName · Active Protection',
                  style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  'Supervised by Meta Llama Autonomous Agent',
                  style: TextStyle(color: textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _tealAccent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _tealAccent.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                Text(
                  '${safetyScore.toInt()}%',
                  style: const TextStyle(color: _tealAccent, fontSize: 15, fontWeight: FontWeight.w900),
                ),
                Text('Safety', style: TextStyle(color: textSecondary, fontSize: 9)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionChip({
    required IconData icon,
    required String label,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final surfaceColor = isDark ? const Color(0xFF111E33) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(color: textPrimary, fontSize: 11.5, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReasoningStepCard({
    required String stepNumber,
    required String title,
    required String content,
    required IconData icon,
    required Color accentColor,
    required bool isDark,
  }) {
    final cardBg = isDark ? const Color(0xFF0D1726) : const Color(0xFFF8FAFC);
    final cardBorder = isDark ? const Color(0xFF1E2D4A) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    stepNumber,
                    style: TextStyle(color: accentColor, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Icon(icon, color: accentColor, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(color: textPrimary, fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            content,
            style: TextStyle(color: textSecondary, fontSize: 12, height: 1.35),
          ),
        ],
      ),
    );
  }

  Widget _buildToolActionsCard(List<AgentToolAction> actions, bool isDark) {
    final cardBg = isDark ? const Color(0xFF0D1726) : const Color(0xFFF8FAFC);
    final cardBorder = isDark ? const Color(0xFF1E2D4A) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bolt_rounded, color: Colors.amber, size: 18),
              const SizedBox(width: 6),
              Text(
                'Autonomous Tool Executions',
                style: TextStyle(color: textPrimary, fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...actions.map((act) => _buildToolActionRow(act, isDark)),
        ],
      ),
    );
  }

  Widget _buildToolActionRow(AgentToolAction action, bool isDark) {
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            action.isExecuted ? Icons.check_circle_rounded : Icons.pending_rounded,
            color: action.isExecuted ? _tealAccent : Colors.amber,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  action.actionDescription,
                  style: TextStyle(color: textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
                ),
                Text(
                  'Tool: ${action.toolName}',
                  style: TextStyle(color: textSecondary, fontSize: 10.5),
                ),
              ],
            ),
          ),
          if (action.requiresParentConfirmation && !action.isExecuted)
            ElevatedButton(
              onPressed: () async {
                final family = ref.read(selectedFamilyProvider);
                final selectedChild = ref.read(selectedChildProvider);
                final familyId = family?.id ?? '';
                final childId = selectedChild?.id ?? '';
                final messenger = ScaffoldMessenger.of(context);

                await ref.read(metaAiGuardianProvider.notifier).approveToolAction(
                      action,
                      familyId: familyId,
                      childId: childId,
                    );

                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Action executed: ${action.actionDescription}',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      backgroundColor: _tealAccent,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      duration: const Duration(seconds: 3),
                    ),
                  );
                  setState(() {});
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _tealAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Approve', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }

  Widget _buildSegmentItem(SamSegment segment, bool isDark) {
    final surfaceColor = isDark ? const Color(0xFF111E33) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF1E2D4A) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final Color badgeColor = segment.riskLevel == 'critical'
        ? Colors.redAccent
        : segment.riskLevel == 'warning'
            ? Colors.amber
            : _tealAccent;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cardBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              segment.riskLevel.toUpperCase(),
              style: TextStyle(color: badgeColor, fontSize: 9, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  segment.label,
                  style: TextStyle(color: textPrimary, fontSize: 12, fontWeight: FontWeight.w700),
                ),
                Text(
                  segment.explanation,
                  style: TextStyle(color: textSecondary, fontSize: 10.5),
                ),
              ],
            ),
          ),
          Text(
            '${(segment.confidence * 100).toInt()}%',
            style: TextStyle(color: textPrimary, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildLangChip(String label, String code, bool isDark) {
    final surfaceColor = isDark ? const Color(0xFF111E33) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF1E2D4A) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);

    return ActionChip(
      backgroundColor: surfaceColor,
      side: BorderSide(color: cardBorder),
      label: Text(label, style: TextStyle(color: textPrimary, fontSize: 11.5)),
      onPressed: () => ref.read(metaAiGuardianProvider.notifier).simulateVoiceCommand(code),
    );
  }

  void _showModelSettingsDialog(BuildContext context, MetaAiGuardianState state, bool isDark) {
    final surfaceColor = isDark ? const Color(0xFF111E33) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final inputBg = isDark ? const Color(0xFF132238) : const Color(0xFFF1F5F9);
    final cardBorder = isDark ? const Color(0xFF1E2D4A) : const Color(0xFFCBD5E1);

    final keyController = TextEditingController(text: MetaAiService.instance.apiKey ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.tune_rounded, color: _tealAccent),
                    const SizedBox(width: 8),
                    Text(
                      'Meta Model API & Inference Config',
                      style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Select Active Meta Model for Evaluation:',
                  style: TextStyle(color: textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 8),
                ...MetaModelChoice.values.map(
                  (model) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Radio<MetaModelChoice>(
                      value: model,
                      groupValue: state.selectedModel,
                      activeColor: _tealAccent,
                      onChanged: (val) {
                        if (val != null) {
                          ref.read(metaAiGuardianProvider.notifier).selectModel(val);
                          Navigator.pop(ctx);
                        }
                      },
                    ),
                    title: Text(
                      model.displayName,
                      style: TextStyle(color: textPrimary, fontWeight: FontWeight.w700, fontSize: 12.5),
                    ),
                    subtitle: Text(
                      model.description,
                      style: TextStyle(color: textSecondary, fontSize: 10.5),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Live API Key (Groq / Fireworks / Meta / Partner):',
                  style: TextStyle(color: textPrimary, fontSize: 12, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: inputBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: cardBorder),
                  ),
                  child: TextField(
                    controller: keyController,
                    style: TextStyle(color: textPrimary, fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'Enter API key for live inference (optional)',
                      hintStyle: TextStyle(color: textSecondary, fontSize: 11),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 42,
                  child: ElevatedButton(
                    onPressed: () {
                      ref.read(metaAiGuardianProvider.notifier).saveApiKey(keyController.text.trim());
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('API configuration saved successfully')),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _tealAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Save Settings', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
