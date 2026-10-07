import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/user_provider.dart';

/// Premium Parent Home Dashboard with modern UI, live children status, and quick tools
class ParentHomeScreen extends ConsumerWidget {
  const ParentHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userData = ref.watch(currentUserDataProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [const Color(0xFF0F172A), const Color(0xFF1E1B4B), const Color(0xFF0F172A)]
                : [const Color(0xFFEEF2FF), const Color(0xFFF8FAFC), const Color(0xFFEDE9FE)],
          ),
        ),
        child: SafeArea(
          child: userData.when(
            loading: () => const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF4F46E5),
                strokeWidth: 3,
              ),
            ),
            error: (error, stack) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.error_outline_rounded,
                        size: 48,
                        color: Color(0xFFEF4444),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Connection Error',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Unable to load your family dashboard. Please retry.',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: () => ref.refresh(currentUserDataProvider),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try Again'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            data: (user) => CustomScrollView(
              slivers: [
                // Top Custom App Bar
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
                                ),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF4F46E5).withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.shield_rounded, color: Colors.white, size: 24),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Parent Portal',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                                Text(
                                  user?.displayName != null && user!.displayName.isNotEmpty
                                      ? 'Hello, ${user.displayName}'
                                      : 'Family Guardian',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        PopupMenuButton<String>(
                          icon: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(Icons.more_vert_rounded, size: 20),
                          ),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'notifications',
                              child: ListTile(
                                leading: Icon(Icons.notifications_rounded, color: Color(0xFF4F46E5)),
                                title: Text('Notifications'),
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'role',
                              child: ListTile(
                                leading: Icon(Icons.swap_horiz_rounded, color: Color(0xFF10B981)),
                                title: Text('Switch Role'),
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'logout',
                              child: ListTile(
                                leading: Icon(Icons.logout_rounded, color: Color(0xFFEF4444)),
                                title: Text('Sign Out'),
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ],
                          onSelected: (value) async {
                            if (value == 'notifications') {
                              context.push('/notifications');
                            } else if (value == 'role') {
                              context.push(AppRoutes.roleSelection);
                            } else if (value == 'logout') {
                              await ref.read(authNotifierProvider.notifier).signOut();
                              if (context.mounted) {
                                context.go(AppRoutes.login);
                              }
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                // Hero Status Card
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF4F46E5), Color(0xFF6366F1), Color(0xFF818CF8)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF4F46E5).withOpacity(0.35),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.security_rounded, size: 14, color: Colors.white),
                                    SizedBox(width: 6),
                                    Text(
                                      'Active Guarding',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.family_restroom_rounded, color: Colors.white70, size: 28),
                            ],
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'Family Protection Active',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            user?.hasFamily == true
                                ? 'All child device rules, limits, and location sync are active.'
                                : 'Pair your children\'s devices to monitor screen time and keep them safe.',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 13,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Connected Children Header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Connected Children',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => context.push(AppRoutes.familySetup),
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('Add Child', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                ),

                // Connected Children List
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _buildChildrenSection(context, user?.familyId, isDark),
                  ),
                ),

                // Management Tools Header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                    child: Text(
                      'Management Tools',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                ),

                // Quick Actions Grid
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  sliver: SliverGrid.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: 1.25,
                    children: [
                      _QuickActionTile(
                        icon: Icons.qr_code_scanner_rounded,
                        title: 'Pair Devices',
                        subtitle: 'Generate pairing QR',
                        gradientColors: const [Color(0xFF2563EB), Color(0xFF4F46E5)],
                        onTap: () => context.push(AppRoutes.familySetup),
                      ),
                      _QuickActionTile(
                        icon: Icons.apps_rounded,
                        title: 'App Rules',
                        subtitle: 'Block & set limits',
                        gradientColors: const [Color(0xFF059669), Color(0xFF10B981)],
                        onTap: () => context.push(AppRoutes.parentApps),
                      ),
                      _QuickActionTile(
                        icon: Icons.pin_drop_rounded,
                        title: 'Live Location',
                        subtitle: 'Family GPS map',
                        gradientColors: const [Color(0xFFD97706), Color(0xFFF59E0B)],
                        onTap: () => context.push(AppRoutes.parentLocation),
                      ),
                      _QuickActionTile(
                        icon: Icons.pending_actions_rounded,
                        title: 'App Requests',
                        subtitle: 'Approve child access',
                        gradientColors: const [Color(0xFF7C3AED), Color(0xFF8B5CF6)],
                        onTap: () => context.push(AppRoutes.parentRequests),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChildrenSection(BuildContext context, String? familyId, bool isDark) {
    if (familyId == null || familyId.isEmpty) {
      return _buildEmptyFamilyCard(context, isDark);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(AppConstants.usersCollection)
          .where('familyId', isEqualTo: familyId)
          .where('role', isEqualTo: AppConstants.childRole)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }

        if (snapshot.hasError) {
          return _buildEmptyFamilyCard(context, isDark);
        }

        final children = snapshot.data?.docs ?? [];
        if (children.isEmpty) {
          return _buildEmptyFamilyCard(context, isDark);
        }

        return Column(
          children: children.map((doc) {
            final childData = doc.data() as Map<String, dynamic>;
            final childName = childData['displayName'] ?? 'Child';
            final childEmail = childData['email'] ?? '';
            final lastSeen = childData['lastSeen'] as Timestamp?;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF3B82F6), Color(0xFF6366F1)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      childName.isNotEmpty ? childName[0].toUpperCase() : 'C',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                title: Text(
                  childName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(childEmail, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFF10B981),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          lastSeen != null
                              ? 'Last active: ${_formatLastSeen(lastSeen.toDate())}'
                              : 'Online & Protected',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF059669)),
                        ),
                      ],
                    ),
                  ],
                ),
                trailing: ElevatedButton.icon(
                  onPressed: () {
                    context.push('/parent-apps/${doc.id}/$childName');
                  },
                  icon: const Icon(Icons.tune_rounded, size: 16),
                  label: const Text('Rules', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    minimumSize: Size.zero,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                onTap: () {
                  context.push('/parent-apps/${doc.id}/$childName');
                },
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildEmptyFamilyCard(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF4F46E5).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.family_restroom_rounded, size: 40, color: Color(0xFF4F46E5)),
          ),
          const SizedBox(height: 14),
          const Text(
            'No Children Connected Yet',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 6),
          const Text(
            'Scan your family pairing code on your child\'s phone to start monitoring.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => context.push(AppRoutes.familySetup),
            icon: const Icon(Icons.qr_code_rounded, size: 18),
            label: const Text('Pair Child Device'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ],
      ),
    );
  }

  String _formatLastSeen(DateTime lastSeen) {
    final difference = DateTime.now().difference(lastSeen);
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}

/// Quick action grid tile widget
class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> gradientColors;
  final VoidCallback onTap;

  const _QuickActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradientColors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: gradientColors),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: gradientColors.first.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}