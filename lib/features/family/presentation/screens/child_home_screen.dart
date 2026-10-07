import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/user_provider.dart';

/// Child home screen - Modern, friendly status interface for protected devices
class ChildHomeScreen extends ConsumerWidget {
  const ChildHomeScreen({super.key});

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
                ? [const Color(0xFF0F172A), const Color(0xFF064E3B)]
                : [const Color(0xFFECFDF5), const Color(0xFFF8FAFC)],
          ),
        ),
        child: SafeArea(
          child: userData.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: Color(0xFF10B981)),
            ),
            error: (error, stack) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 56, color: Color(0xFFEF4444)),
                    const SizedBox(height: 16),
                    Text('Failed to load status', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(error.toString(), textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => ref.refresh(currentUserDataProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
            data: (user) => CustomScrollView(
              slivers: [
                // Top Custom Header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
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
                                  colors: [Color(0xFF059669), Color(0xFF10B981)],
                                ),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF10B981).withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.child_care_rounded, color: Colors.white, size: 26),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Child Companion',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                                Text(
                                  'Hi, ${user?.displayName ?? 'Friend'}!',
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
                              color: isDark ? const Color(0xFF334155) : Colors.white,
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
                            PopupMenuItem(
                              value: 'info',
                              child: const ListTile(
                                leading: Icon(Icons.info_outline_rounded, color: Color(0xFF059669)),
                                title: Text('Safety Info'),
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                            PopupMenuItem(
                              value: 'role',
                              child: const ListTile(
                                leading: Icon(Icons.swap_horiz_rounded, color: Color(0xFF4F46E5)),
                                title: Text('Switch Role'),
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                            PopupMenuItem(
                              value: 'logout',
                              child: const ListTile(
                                leading: Icon(Icons.logout_rounded, color: Color(0xFFEF4444)),
                                title: Text('Sign Out'),
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ],
                          onSelected: (value) async {
                            if (value == 'info') {
                              _showMonitoringInfo(context);
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

                // Shield Status Banner
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF059669), Color(0xFF10B981), Color(0xFF14B8A6)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF10B981).withOpacity(0.35),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
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
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.shield_rounded, size: 14, color: Colors.white),
                                    SizedBox(width: 6),
                                    Text(
                                      'Smart Guard Protected',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.favorite_rounded, color: Colors.white70, size: 26),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            user?.hasFamily == true
                                ? 'Connected to Family Group'
                                : 'Pair With Your Parent',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            user?.hasFamily == true
                                ? 'Your device is safeguarded with healthy limits set by your family.'
                                : 'Scan your family QR code to link this phone to your parent\'s dashboard.',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.92),
                              fontSize: 13,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Status List Header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Text(
                      'Protection & Setup Status',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                ),

                // Protection Status Cards
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _StatusCard(
                        icon: Icons.admin_panel_settings_rounded,
                        title: 'Device Permissions',
                        subtitle: 'Required for background protection & overlay',
                        status: 'Verify Status',
                        statusColor: const Color(0xFF4F46E5),
                        onTap: () => context.push(AppRoutes.childPermissions),
                      ),
                      const SizedBox(height: 10),
                      _StatusCard(
                        icon: Icons.apps_rounded,
                        title: 'Apps & Limits',
                        subtitle: 'View scanned apps and current rules',
                        status: 'Explore Apps',
                        statusColor: const Color(0xFF059669),
                        onTap: () => context.push(AppRoutes.childApps),
                      ),
                      const SizedBox(height: 10),
                      _StatusCard(
                        icon: Icons.qr_code_scanner_rounded,
                        title: 'Join Family Group',
                        subtitle: user?.hasFamily == true ? 'Paired and Connected' : 'Scan Parent QR Code',
                        status: user?.hasFamily == true ? 'Connected' : 'Scan QR',
                        statusColor: const Color(0xFFD97706),
                        onTap: () => context.push(AppRoutes.familyJoin),
                      ),
                      const SizedBox(height: 10),
                      _StatusCard(
                        icon: Icons.health_and_safety_rounded,
                        title: 'Monitoring Health',
                        subtitle: 'Check background service & diagnostic state',
                        status: 'Diagnostic',
                        statusColor: const Color(0xFF7C3AED),
                        onTap: () => context.push(AppRoutes.childStatus),
                      ),
                      const SizedBox(height: 24),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showMonitoringInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.shield_rounded, color: Color(0xFF059669)),
            SizedBox(width: 10),
            Text('About Smart Guard', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Family Guardian helps you build healthy digital habits:',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            SizedBox(height: 12),
            Text('• Keeps screen time balanced and productive'),
            SizedBox(height: 6),
            Text('• Allows you to request extra time or unlock apps from parents'),
            SizedBox(height: 6),
            Text('• Shares device status transparently so you stay safe'),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it!'),
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String status;
  final Color statusColor;
  final VoidCallback onTap;

  const _StatusCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.statusColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: statusColor, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}