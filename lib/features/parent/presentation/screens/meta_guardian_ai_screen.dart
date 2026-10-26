import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/meta_ai_provider.dart';
import '../../../../core/providers/family_provider.dart';
import '../../../../core/services/meta_ai_service.dart';

class MetaGuardianAiScreen extends ConsumerStatefulWidget {
  const MetaGuardianAiScreen({super.key});

  @override
  ConsumerState<MetaGuardianAiScreen> createState() => _MetaGuardianAiScreenState();
}

class _MetaGuardianAiScreenState extends ConsumerState<MetaGuardianAiScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _promptController = TextEditingController();

  static const Color _tealAccent = Color(0xFF14B8A6);
  static const Color _aiPurple = Color(0xFF8B5CF6);
  static const Color _darkSurface = Color(0xFF111E33);
  static const Color _darkBg = Color(0xFF0A1220);
  static const Color _cardBorder = Color(0xFF1E2D4A);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    // Trigger initial agent analysis automatically on load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final selectedChild = ref.read(selectedChildProvider);
      final childName = selectedChild?.displayName ?? 'Leo';
      ref.read(metaAiGuardianProvider.notifier).triggerAgent(
            childName: childName,
            prompt: 'Nighttime schedule check and safety audit',
          );
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _promptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final aiState = ref.watch(metaAiGuardianProvider);
    final selectedChild = ref.watch(selectedChildProvider);
    final childName = selectedChild?.displayName ?? 'Leo';

    return Scaffold(
      backgroundColor: _darkBg,
      appBar: AppBar(
        backgroundColor: _darkSurface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
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
                  const Text(
                    'FamilyGuard AI Guardian',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
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
                      Text(
                        aiState.selectedModel.displayName,
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
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
            tooltip: 'Model & Hackathon API Settings',
            icon: const Icon(Icons.tune_rounded, color: _tealAccent),
            onPressed: () => _showModelSettingsDialog(context, aiState),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: _tealAccent,
          indicatorWeight: 3,
          labelColor: _tealAccent,
          unselectedLabelColor: const Color(0xFF94A3B8),
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
          // 1. Autonomous Agent Hub
          _buildAgentView(aiState, childName),
          // 2. SAM 3.1 Visual Risk Shield
          _buildSamVisualView(aiState),
          // 3. Muse Voice Transcribe Co-Pilot
          _buildVoiceView(aiState),
          // 4. Muse Image Generative Rewards
          _buildRewardsView(aiState, childName),
        ],
      ),
    );
  }

  // ── Tab 1: Autonomous Agent View ──────────────────────────────────────────
  Widget _buildAgentView(MetaAiGuardianState state, String childName) {
    final result = state.lastAgentResult;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hackathon Banner
          _buildHackathonBadge(),
          const SizedBox(height: 16),

          // Child Status Overview Card
          _buildChildOverviewCard(childName, result?.safetyScore ?? 92.0),
          const SizedBox(height: 18),

          // Quick Action Triggers
          const Text(
            'Autonomous Guardian Triggers',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildQuickActionChip(
                  icon: Icons.nightlight_round,
                  label: 'Bedtime Wind-Down',
                  color: Colors.indigo,
                  onTap: () => ref.read(metaAiGuardianProvider.notifier).triggerAgent(
                        childName: childName,
                        prompt: 'Bedtime audit: late night gaming on TikTok',
                      ),
                ),
                const SizedBox(width: 8),
                _buildQuickActionChip(
                  icon: Icons.school_rounded,
                  label: 'Study Focus Mode',
                  color: Colors.teal,
                  onTap: () => ref.read(metaAiGuardianProvider.notifier).triggerAgent(
                        childName: childName,
                        prompt: 'Study session math homework distraction check',
                      ),
                ),
                const SizedBox(width: 8),
                _buildQuickActionChip(
                  icon: Icons.shield_rounded,
                  label: 'Social Risk Scan',
                  color: Colors.deepOrange,
                  onTap: () => ref.read(metaAiGuardianProvider.notifier).triggerAgent(
                        childName: childName,
                        prompt: 'Social chat external link safety audit',
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Custom Prompt Input
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: _darkSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _cardBorder),
            ),
            child: Row(
              children: [
                const Icon(Icons.bolt_rounded, color: _tealAccent, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _promptController,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: const InputDecoration(
                      hintText: 'Ask Meta Muse Spark to balance, lock, or reward...',
                      hintStyle: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                      border: InputBorder.none,
                    ),
                    onSubmitted: (val) {
                      if (val.trim().isNotEmpty) {
                        ref.read(metaAiGuardianProvider.notifier).triggerAgent(
                              childName: childName,
                              prompt: val.trim(),
                            );
                        _promptController.clear();
                      }
                    },
                  ),
                ),
                IconButton(
                  icon: state.isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _tealAccent,
                          ),
                        )
                      : const Icon(Icons.send_rounded, color: _tealAccent),
                  onPressed: state.isLoading
                      ? null
                      : () {
                          if (_promptController.text.trim().isNotEmpty) {
                            ref.read(metaAiGuardianProvider.notifier).triggerAgent(
                                  childName: childName,
                                  prompt: _promptController.text.trim(),
                                );
                            _promptController.clear();
                          }
                        },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ReAct / Chain-of-Thought Agent Trace (Targeting "Best Agentic Use-Case")
          if (result != null) ...[
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _aiPurple.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _aiPurple.withValues(alpha: 0.5)),
                  ),
                  child: const Text(
                    'RE-ACT TRACE',
                    style: TextStyle(
                      color: _aiPurple,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Multi-Step Agent Reasoning',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Step 1: Observation & Thought
            _buildReasoningStepCard(
              stepNumber: '1',
              title: 'Context Observation & Thought',
              content: result.thought,
              icon: Icons.psychology_alt_rounded,
              accentColor: _aiPurple,
            ),
            const SizedBox(height: 10),

            // Step 2: Formulated Strategic Plan
            _buildReasoningStepCard(
              stepNumber: '2',
              title: 'Formulated Strategic Plan',
              content: result.plan,
              icon: Icons.checklist_rounded,
              accentColor: _tealAccent,
            ),
            const SizedBox(height: 10),

            // Step 3: Autonomous Tool Actions Execution
            _buildToolActionsCard(result.toolActions),
            const SizedBox(height: 14),

            // Step 4: Parent Executive Summary
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _tealAccent.withValues(alpha: 0.12),
                    _darkSurface,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _tealAccent.withValues(alpha: 0.4)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.verified_user_rounded, color: _tealAccent, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Executive Parent Summary',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          result.parentSummary,
                          style: const TextStyle(
                            color: Color(0xFFCBD5E1),
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ],
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

  // ── Tab 2: SAM 3.1 Visual Risk Shield ─────────────────────────────────────
  Widget _buildSamVisualView(MetaAiGuardianState state) {
    final visualResult = state.lastSamVisualResult;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _darkSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _cardBorder),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.cyan.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.center_focus_strong, color: Colors.cyan, size: 26),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Meta SAM 3.1 Screen Shield',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Segment Anything 3.1 real-time UI element segmentation to detect predatory dark patterns & risky feeds.',
                        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Scan Trigger Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: state.isLoading
                  ? null
                  : () => ref.read(metaAiGuardianProvider.notifier).triggerSamVisualAudit(),
              icon: state.isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                    )
                  : const Icon(Icons.document_scanner_rounded, size: 20),
              label: Text(
                state.isLoading ? 'SAM 3.1 Analyzing Screen...' : 'Run SAM 3.1 Visual Safety Audit',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.cyanAccent.shade700,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Simulated Device Screen with SAM 3.1 Segmentation Overlay
          Container(
            height: 260,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF070D17),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.cyan.withValues(alpha: 0.4), width: 1.5),
            ),
            child: Stack(
              children: [
                // Background simulated screen content
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.phone_android_rounded, size: 64, color: Colors.white.withValues(alpha: 0.15)),
                      const SizedBox(height: 8),
                      Text(
                        'Child Active Screen Canvas',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 13),
                      ),
                    ],
                  ),
                ),
                // SAM 3.1 Interactive Bounding Boxes
                Positioned(
                  top: 24,
                  right: 20,
                  width: 90,
                  height: 40,
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
                  bottom: 24,
                  left: 30,
                  right: 30,
                  height: 52,
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
                        style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (visualResult != null) ...[
            const Text(
              'Segmented Region Insights',
              style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            ...visualResult.segments.map((seg) => _buildSegmentItem(seg)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _darkSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _cardBorder),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lightbulb_outline_rounded, color: _tealAccent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      visualResult.recommendation,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
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
  Widget _buildVoiceView(MetaAiGuardianState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _darkSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _cardBorder),
            ),
            child: const Row(
              children: [
                Icon(Icons.record_voice_over_rounded, color: _tealAccent, size: 28),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Meta Muse Voice Transcribe',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Zero-latency multilingual voice interpretation for Ethiopian & Global families (English, Amharic, Oromo, Arabic).',
                        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Voice Interactive Visualizer
          Center(
            child: Column(
              children: [
                GestureDetector(
                  onTap: () => ref.read(metaAiGuardianProvider.notifier).simulateVoiceCommand('en'),
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [_tealAccent, _aiPurple],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _tealAccent.withValues(alpha: 0.35),
                          blurRadius: 24,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: state.isListeningVoice
                        ? const Center(
                            child: SizedBox(
                              width: 32,
                              height: 32,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                            ),
                          )
                        : const Icon(Icons.mic, color: Colors.white, size: 40),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  state.isListeningVoice ? 'Listening & Transcribing via Meta Muse Voice...' : 'Tap to speak voice guardian command',
                  style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Multi-language Test Buttons
          const Text(
            'Test Multilingual Voice Samples',
            style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildLangChip('English', 'en'),
              _buildLangChip('አማርኛ (Amharic)', 'am'),
              _buildLangChip('Afaan Oromoo', 'om'),
              _buildLangChip('العربية (Arabic)', 'ar'),
            ],
          ),
          const SizedBox(height: 20),

          // Transcription Result Display
          if (state.voiceTranscription != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _darkSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _tealAccent.withValues(alpha: 0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.transcribe_rounded, color: _tealAccent, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Muse Voice Transcribe Output',
                        style: TextStyle(color: _tealAccent, fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    state.voiceTranscription!,
                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 14),
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
                    icon: const Icon(Icons.play_arrow_rounded, size: 18),
                    label: const Text('Execute through Muse Spark Agent'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _tealAccent,
                      foregroundColor: const Color(0xFF0C1829),
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
  Widget _buildRewardsView(MetaAiGuardianState state, String childName) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _darkSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _cardBorder),
            ),
            child: const Row(
              children: [
                Icon(Icons.palette_rounded, color: Colors.amber, size: 28),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Meta Muse Image Reward Studio',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Positive reinforcement over punishment. Generates tailored 3D achievement badges for completed lessons.',
                        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Generator Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: state.isLoading
                  ? null
                  : () => ref
                      .read(metaAiGuardianProvider.notifier)
                      .generateRewardBadge('Math Geometry Master'),
              icon: const Icon(Icons.star_rounded, color: Colors.white),
              label: const Text(
                'Generate Custom Achievement Crest',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEAB308),
                foregroundColor: const Color(0xFF0C1829),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Display Generated Badge Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFEAB308).withValues(alpha: 0.15),
                  _darkSurface,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFEAB308).withValues(alpha: 0.4)),
            ),
            child: Column(
              children: [
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(
                      colors: [Color(0xFFFDE047), Color(0xFFCA8A04)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFEAB308).withValues(alpha: 0.4),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.military_tech_rounded, size: 54, color: Color(0xFF422006)),
                ),
                const SizedBox(height: 14),
                Text(
                  '$childName\'s Gold Math Crest',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Rendered via Meta Muse Image Generator',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                ),
                const SizedBox(height: 12),
                Text(
                  state.generatedBadgeMessage ??
                      'Awarded for completing 3 modules in Algebra without screen-time distraction penalties!',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 13, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Supporting Widget Builders ────────────────────────────────────────────

  Widget _buildHackathonBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _tealAccent.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _tealAccent.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.emoji_events_rounded, color: _tealAccent, size: 18),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Meta Global AI Hackathon Edition',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Build for Your World · Multi-Model Autonomous Guardian',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChildOverviewCard(String childName, double safetyScore) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _darkSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _cardBorder),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: _tealAccent.withValues(alpha: 0.2),
            child: Text(
              childName.isNotEmpty ? childName[0].toUpperCase() : 'C',
              style: const TextStyle(color: _tealAccent, fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$childName · Active Protection',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Supervised by Meta Muse Spark Autonomous Agent',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _tealAccent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _tealAccent.withValues(alpha: 0.4)),
            ),
            child: Column(
              children: [
                Text(
                  '${safetyScore.toInt()}%',
                  style: const TextStyle(color: _tealAccent, fontSize: 16, fontWeight: FontWeight.w900),
                ),
                const Text('Safety', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10)),
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
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _darkSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
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
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _darkSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    stepNumber,
                    style: TextStyle(color: accentColor, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(icon, color: accentColor, size: 18),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildToolActionsCard(List<AgentToolAction> actions) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _darkSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.bolt_rounded, color: Colors.amber, size: 20),
              SizedBox(width: 6),
              Text(
                'Autonomous Tool Executions',
                style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...actions.map((act) => _buildToolActionRow(act)),
        ],
      ),
    );
  }

  Widget _buildToolActionRow(AgentToolAction action) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            action.isExecuted ? Icons.check_circle_rounded : Icons.pending_rounded,
            color: action.isExecuted ? _tealAccent : Colors.amber,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  action.actionDescription,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                ),
                Text(
                  'Tool: ${action.toolName}',
                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                ),
              ],
            ),
          ),
          if (action.requiresParentConfirmation && !action.isExecuted)
            ElevatedButton(
              onPressed: () {
                ref.read(metaAiGuardianProvider.notifier).approveToolAction(action);
                setState(() {});
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _tealAccent,
                foregroundColor: const Color(0xFF0C1829),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Approve', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }

  Widget _buildSegmentItem(SamSegment segment) {
    final Color badgeColor = segment.riskLevel == 'critical'
        ? Colors.redAccent
        : segment.riskLevel == 'warning'
            ? Colors.amber
            : _tealAccent;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _darkSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _cardBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              segment.riskLevel.toUpperCase(),
              style: TextStyle(color: badgeColor, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  segment.label,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  segment.explanation,
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                ),
              ],
            ),
          ),
          Text(
            '${(segment.confidence * 100).toInt()}%',
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildLangChip(String label, String code) {
    return ActionChip(
      backgroundColor: _darkSurface,
      side: const BorderSide(color: _cardBorder),
      label: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
      onPressed: () => ref.read(metaAiGuardianProvider.notifier).simulateVoiceCommand(code),
    );
  }

  void _showModelSettingsDialog(BuildContext context, MetaAiGuardianState state) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.tune_rounded, color: _tealAccent),
                  SizedBox(width: 8),
                  Text(
                    'Meta Model API & Inference Config',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Text(
                'Select Active Meta Model for Hackathon Evaluation:',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
              ),
              const SizedBox(height: 10),
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
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  subtitle: Text(
                    model.description,
                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
