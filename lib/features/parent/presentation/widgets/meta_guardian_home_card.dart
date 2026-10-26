import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/providers/meta_ai_provider.dart';
import '../../../../core/providers/family_provider.dart';

class MetaGuardianHomeCard extends ConsumerWidget {
  const MetaGuardianHomeCard({super.key});

  static const Color _tealAccent = Color(0xFF14B8A6);
  static const Color _aiPurple = Color(0xFF8B5CF6);
  static const Color _darkSurface = Color(0xFF111E33);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aiState = ref.watch(metaAiGuardianProvider);
    final selectedChild = ref.watch(selectedChildProvider);
    final childName = selectedChild?.displayName ?? 'Leo';

    final lastThought = aiState.lastAgentResult?.thought ??
        'Meta Muse Spark actively supervising device usage & study balance.';
    final score = aiState.lastAgentResult?.safetyScore.toInt() ?? 95;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _darkSurface,
            const Color(0xFF0F172A),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _tealAccent.withValues(alpha: 0.35), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: _tealAccent.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => context.push(AppRoutes.metaAiGuardian),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: Hackathon Tag & Model Indicator
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [_tealAccent, _aiPurple],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.auto_awesome,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'META AI GUARDIAN',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _tealAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _tealAccent.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: _tealAccent,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            '$score% Safe',
                            style: const TextStyle(
                              color: _tealAccent,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Real-time summary for child
                Text(
                  'Autonomous Copilot for $childName',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  lastThought,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 14),

                // Features chip row
                Row(
                  children: [
                    _buildChip(Icons.psychology_rounded, 'Muse Spark'),
                    const SizedBox(width: 6),
                    _buildChip(Icons.center_focus_strong, 'SAM 3.1 Shield'),
                    const SizedBox(width: 6),
                    _buildChip(Icons.mic, 'Muse Voice'),
                    const Spacer(),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      color: _tealAccent,
                      size: 20,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _tealAccent, size: 12),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 10, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
