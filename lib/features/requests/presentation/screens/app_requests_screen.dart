import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/models/request_model.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/user_provider.dart';
import '../../../../core/providers/family_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/family_bottom_navigation.dart';
import '../../../../l10n/app_localizations.dart';

/// Parent screen for reviewing and acting on child app access requests.
/// All colours driven by [AppColors] / [appColorsProvider].
class AppRequestsScreen extends ConsumerStatefulWidget {
  const AppRequestsScreen({super.key});

  @override
  ConsumerState<AppRequestsScreen> createState() => _AppRequestsScreenState();
}

class _AppRequestsScreenState extends ConsumerState<AppRequestsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final userAsync = ref.watch(currentUserDataProvider);
    final colors = ref.watch(appColorsProvider);

    return Scaffold(
      extendBody: true,
      backgroundColor: colors.background,
      appBar: _buildAppBar(l10n, colors),
      body: userAsync.when(
        loading: () => Center(
          child: CircularProgressIndicator(color: colors.primary),
        ),
        error: (e, _) => _buildError(e.toString(), colors),
        data: (user) {
          final familyId =
              user?.familyId ??
              ref.watch(selectedFamilyProvider)?.id ??
              ref.watch(userFamiliesProvider).value?.firstOrNull?.id;
          if (familyId == null) return _buildNoFamily(colors);
          return _RequestTabsView(
            familyId: familyId,
            tabController: _tabController,
            colors: colors,
          );
        },
      ),
      bottomNavigationBar: const FamilyBottomNavigation(
        isParent: true,
        selected: FamilyNavDestination.requests,
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(AppLocalizations l10n, AppColors colors) {
    return AppBar(
      elevation: 0,
      backgroundColor: colors.surface,
      foregroundColor: colors.textPrimary,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.appRequests,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: colors.textPrimary,
            ),
          ),
          Text(
            l10n.approveOrDenyRequests,
            style: TextStyle(fontSize: 12, color: colors.textSecondary),
          ),
        ],
      ),
      bottom: TabBar(
        controller: _tabController,
        labelColor: colors.primary,
        unselectedLabelColor: colors.textSecondary,
        indicatorColor: colors.primary,
        indicatorWeight: 3,
        tabs: [
          Tab(text: l10n.pending),
          Tab(text: l10n.approved),
          Tab(text: l10n.denied),
        ],
      ),
    );
  }

  Widget _buildError(String error, AppColors colors) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded, size: 56, color: colors.error),
            const SizedBox(height: 16),
            Text(
              'Error loading requests',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: TextStyle(color: colors.textSecondary, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoFamily(AppColors colors) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.pending_actions_rounded,
                size: 52,
                color: colors.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No Family Linked',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Link a family first to see app access requests from your children.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tabs body ──────────────────────────────────────────────────────────────────

class _RequestTabsView extends StatelessWidget {
  final String familyId;
  final TabController tabController;
  final AppColors colors;

  const _RequestTabsView({
    required this.familyId,
    required this.tabController,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return TabBarView(
      controller: tabController,
      children: [
        _RequestList(familyId: familyId, filter: RequestStatus.pending, colors: colors),
        _RequestList(familyId: familyId, filter: RequestStatus.approved, colors: colors),
        _RequestList(familyId: familyId, filter: RequestStatus.denied, colors: colors),
      ],
    );
  }
}

// ── Request list (one per tab) ─────────────────────────────────────────────────

class _RequestList extends StatelessWidget {
  final String familyId;
  final RequestStatus filter;
  final AppColors colors;

  const _RequestList({
    required this.familyId,
    required this.filter,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('families')
          .doc(familyId)
          .collection('requests')
          .where('status', isEqualTo: filter.name)
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(color: colors.primary),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error: ${snapshot.error}',
              style: TextStyle(color: colors.error, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) return _buildEmpty(colors);

        final requests = docs
            .map((doc) {
              try {
                return AppRequest.fromFirestore(doc);
              } catch (_) {
                return null;
              }
            })
            .whereType<AppRequest>()
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .where('familyId', isEqualTo: familyId)
              .where('role', isEqualTo: 'child')
              .snapshots(),
          builder: (context, childrenSnap) {
            final childNames = <String, String>{};
            for (final childDoc in childrenSnap.data?.docs ?? []) {
              final data = childDoc.data();
              final name = (data['displayName'] ?? data['name'] ?? '')
                  .toString()
                  .trim();
              if (name.isNotEmpty) childNames[childDoc.id] = name;
            }

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 112),
              itemCount:
                  requests.length + (childrenSnap.hasError ? 1 : 0),
              itemBuilder: (ctx, index) {
                if (childrenSnap.hasError && index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      'Could not load child names.',
                      style: TextStyle(color: colors.error, fontSize: 12),
                    ),
                  );
                }
                final i = index - (childrenSnap.hasError ? 1 : 0);
                final req = requests[i];
                final saved = req.childName?.trim();
                final name = (saved != null && saved.isNotEmpty)
                    ? saved
                    : childNames[req.childId] ?? 'Child';

                return _RequestCard(
                  request: req,
                  familyId: familyId,
                  childName: name,
                  colors: colors,
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildEmpty(AppColors colors) {
    final (icon, label) = switch (filter) {
      RequestStatus.pending => (
        Icons.hourglass_empty_rounded,
        'No Pending Requests',
      ),
      RequestStatus.approved => (
        Icons.check_circle_outline_rounded,
        'No Approved Requests',
      ),
      RequestStatus.denied => (
        Icons.cancel_outlined,
        'No Denied Requests',
      ),
      _ => (Icons.inbox_rounded, 'No Requests'),
    };
    final color = switch (filter) {
      RequestStatus.pending  => colors.warning,
      RequestStatus.approved => colors.success,
      RequestStatus.denied   => colors.error,
      _                      => colors.textSecondary,
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 52, color: color),
            ),
            const SizedBox(height: 20),
            Text(
              label,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              filter == RequestStatus.pending
                  ? 'When your children request access to blocked apps,\nthey\'ll appear here.'
                  : 'No ${filter.name} requests yet.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Request Card ───────────────────────────────────────────────────────────────

class _RequestCard extends ConsumerWidget {
  final AppRequest request;
  final String familyId;
  final String childName;
  final AppColors colors;

  const _RequestCard({
    required this.request,
    required this.familyId,
    required this.childName,
    required this.colors,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPending =
        request.status == RequestStatus.pending && !request.isExpired;

    final statusColor = switch (request.status) {
      RequestStatus.pending  => colors.warning,
      RequestStatus.approved => colors.success,
      RequestStatus.denied   => colors.error,
      _                      => colors.textSecondary,
    };

    final statusLabel =
        request.isExpired && request.status == RequestStatus.pending
        ? 'Expired'
        : request.status.name[0].toUpperCase() +
              request.status.name.substring(1);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isPending
              ? statusColor.withOpacity(0.35)
              : colors.border,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header: icon + name + status badge ───────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        colors.primary,
                        colors.accent,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.apps_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.appName.isNotEmpty
                            ? request.appName
                            : request.packageName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: colors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Requested by: $childName',
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        request.packageName,
                        style: TextStyle(
                          fontSize: 11,
                          color: colors.textMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            Divider(height: 1, color: colors.border),
            const SizedBox(height: 10),

            // ── Meta chips ────────────────────────────────────────────────
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InfoChip(
                  icon: Icons.access_time_rounded,
                  label: _timeAgo(request.createdAt),
                  color: colors.textSecondary,
                ),
                _InfoChip(
                  icon: Icons.person_outline_rounded,
                  label: childName,
                  color: colors.textSecondary,
                ),
                if (request.isApproved && request.grantedMinutes != null)
                  _InfoChip(
                    icon: Icons.timer_outlined,
                    label: '${request.grantedMinutes}m granted',
                    color: colors.success,
                  ),
              ],
            ),

            // ── Action buttons (pending only) ─────────────────────────────
            if (isPending) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _deny(context, ref),
                      icon: const Icon(Icons.close_rounded, size: 16),
                      label: const Text('Deny'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.error,
                        side: BorderSide(color: colors.error),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () => _showApproveSheet(context, ref),
                      icon: const Icon(Icons.check_rounded, size: 16),
                      label: const Text('Approve'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.success,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],

            // ── Access validity (approved) ────────────────────────────────
            if (request.isApproved && request.accessExpiresAt != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: colors.success.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.access_time_filled_rounded,
                      size: 14,
                      color: colors.success,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      request.timeRemainingText,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colors.success,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Deny ────────────────────────────────────────────────────────────────────

  Future<void> _deny(BuildContext context, WidgetRef ref) async {
    try {
      final updateData = {
        'status': RequestStatus.denied.name,
        'decidedAt': Timestamp.now(),
        'decidedBy': ref.read(authProvider).user?.uid ?? '',
      };

      // Update family-level request
      await FirebaseFirestore.instance
          .collection('families')
          .doc(familyId)
          .collection('requests')
          .doc(request.id)
          .set(updateData, SetOptions(merge: true));

      // Mirror to child subcollection
      if (request.childId.isNotEmpty) {
        try {
          await FirebaseFirestore.instance
              .collection('families')
              .doc(familyId)
              .collection('children')
              .doc(request.childId)
              .collection('requests')
              .doc(request.id)
              .set(updateData, SetOptions(merge: true));
        } catch (_) {}

        // Notify child
        try {
          await FirebaseFirestore.instance.collection('notifications').add({
            'familyId': familyId,
            'childId': request.childId,
            'type': 'appDenied',
            'priority': 'normal',
            'title': '❌ Access Denied: ${request.appName}',
            'body':
                'Your request for ${request.appName} was denied by your parent.',
            'data': {
              'type': 'app_denied',
              'packageName': request.packageName,
              'appName': request.appName,
              'requestId': request.id,
            },
            'createdAt': Timestamp.now(),
            'isRead': false,
          });
        } catch (e) {
          debugPrint('Notify child deny error: $e');
        }
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Denied access to ${request.appName}'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: colors.error,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error denying: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // ── Approve sheet ────────────────────────────────────────────────────────────

  void _showApproveSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ApproveSheet(
        request: request,
        familyId: familyId,
        parentId: ref.read(authProvider).user?.uid ?? '',
        colors: colors,
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'just now';
  }
}

// ── Info chip ──────────────────────────────────────────────────────────────────

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Approve duration bottom sheet ──────────────────────────────────────────────

class _ApproveSheet extends StatefulWidget {
  final AppRequest request;
  final String familyId;
  final String parentId;
  final AppColors colors;

  const _ApproveSheet({
    required this.request,
    required this.familyId,
    required this.parentId,
    required this.colors,
  });

  @override
  State<_ApproveSheet> createState() => _ApproveSheetState();
}

class _ApproveSheetState extends State<_ApproveSheet> {
  // null = custom mode, otherwise a preset
  ApprovalDuration? _selectedPreset = ApprovalDuration.thirtyMinutes;
  final _customCtrl = TextEditingController();
  bool _customMode = false;
  bool _loading = false;

  @override
  void dispose() {
    _customCtrl.dispose();
    super.dispose();
  }

  int get _effectiveMinutes {
    if (_customMode) {
      final v = int.tryParse(_customCtrl.text.trim()) ?? 0;
      return v.clamp(1, 1440); // 1 min – 24 h
    }
    return _selectedPreset?.minutes ?? 30;
  }

  String get _effectiveLabel {
    if (_customMode) {
      final m = _effectiveMinutes;
      if (m >= 60) {
        final h = m ~/ 60;
        final rem = m % 60;
        return rem == 0 ? '${h}h' : '${h}h ${rem}m';
      }
      return '${m}m';
    }
    return _selectedPreset?.displayText ?? '30m';
  }

  bool get _isValid {
    if (_customMode) {
      final v = int.tryParse(_customCtrl.text.trim());
      return v != null && v >= 1 && v <= 1440;
    }
    return _selectedPreset != null;
  }

  Future<void> _approve() async {
    if (!_isValid) return;
    setState(() => _loading = true);

    try {
      final now = DateTime.now();
      final minutes = _effectiveMinutes;
      final approveData = {
        'status': RequestStatus.approved.name,
        'grantedMinutes': minutes,
        'decidedAt': Timestamp.fromDate(now),
        'decidedBy': widget.parentId,
        'accessExpiresAt': Timestamp.fromDate(now.add(Duration(minutes: minutes))),
      };

      // Update family-level request
      await FirebaseFirestore.instance
          .collection('families')
          .doc(widget.familyId)
          .collection('requests')
          .doc(widget.request.id)
          .set(approveData, SetOptions(merge: true));

      if (widget.request.childId.isNotEmpty) {
        // Mirror to child subcollection
        try {
          await FirebaseFirestore.instance
              .collection('families')
              .doc(widget.familyId)
              .collection('children')
              .doc(widget.request.childId)
              .collection('requests')
              .doc(widget.request.id)
              .set(approveData, SetOptions(merge: true));
        } catch (_) {}

        // Write temporaryApproval doc for native enforcement
        if (widget.request.packageName.isNotEmpty) {
          try {
            final pkgClean =
                widget.request.packageName.replaceAll('.', '_');
            await FirebaseFirestore.instance
                .collection('families')
                .doc(widget.familyId)
                .collection('children')
                .doc(widget.request.childId)
                .collection('temporaryApprovals')
                .doc(pkgClean)
                .set({
              'packageName': widget.request.packageName,
              'approvedAt': Timestamp.fromDate(now),
              'durationMinutes': minutes,
              'approvedBy': widget.parentId,
              'accessExpiresAt':
                  Timestamp.fromDate(now.add(Duration(minutes: minutes))),
            }, SetOptions(merge: true));
          } catch (e) {
            debugPrint('temporaryApproval write error: $e');
          }
        }

        // Notify child
        try {
          await FirebaseFirestore.instance.collection('notifications').add({
            'familyId': widget.familyId,
            'childId': widget.request.childId,
            'type': 'appApproved',
            'priority': 'normal',
            'title': '🎉 Access Approved: ${widget.request.appName}',
            'body':
                'Your parent approved $_effectiveLabel of access to ${widget.request.appName}.',
            'data': {
              'type': 'app_approved',
              'packageName': widget.request.packageName,
              'appName': widget.request.appName,
              'grantedMinutes': minutes,
              'requestId': widget.request.id,
            },
            'createdAt': Timestamp.fromDate(now),
            'isRead': false,
          });
        } catch (e) {
          debugPrint('Notify child approve error: $e');
        }
      }

      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Approved ${widget.request.appName} for $_effectiveLabel',
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: widget.colors.success,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: widget.colors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        20,
        24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: c.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: c.success.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.check_circle_rounded, color: c.success),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Approve Access',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: c.textPrimary,
                        ),
                      ),
                      Text(
                        widget.request.appName,
                        style: TextStyle(
                          color: c.textSecondary,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            Text(
              'Grant access for:',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: c.textPrimary,
              ),
            ),
            const SizedBox(height: 12),

            // Preset chips
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...ApprovalDuration.values.map((dur) {
                  final sel = !_customMode && _selectedPreset == dur;
                  return _DurationChip(
                    label: dur.displayText,
                    selected: sel,
                    colors: c,
                    onTap: () => setState(() {
                      _selectedPreset = dur;
                      _customMode = false;
                    }),
                  );
                }),
                // Custom chip
                _DurationChip(
                  label: 'Custom…',
                  selected: _customMode,
                  colors: c,
                  icon: Icons.edit_rounded,
                  onTap: () => setState(() {
                    _customMode = true;
                    _selectedPreset = null;
                  }),
                ),
              ],
            ),

            // Custom input (shown only when customMode is active)
            if (_customMode) ...[
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: c.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: c.primary),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                child: Row(
                  children: [
                    Icon(Icons.timer_outlined, color: c.primary, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _customCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(4),
                        ],
                        onChanged: (_) => setState(() {}),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: c.textPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Enter minutes (1–1440)',
                          hintStyle: TextStyle(
                            fontSize: 13,
                            color: c.textMuted,
                            fontWeight: FontWeight.normal,
                          ),
                          border: InputBorder.none,
                          suffixText: 'min',
                          suffixStyle: TextStyle(
                            color: c.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        autofocus: true,
                      ),
                    ),
                  ],
                ),
              ),
              if (_customCtrl.text.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  '= $_effectiveLabel',
                  style: TextStyle(
                    fontSize: 12,
                    color: c.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],

            const SizedBox(height: 24),

            // Confirm button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_loading || !_isValid) ? null : _approve,
                style: ElevatedButton.styleFrom(
                  backgroundColor: c.success,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: c.border,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        _isValid
                            ? 'Approve for $_effectiveLabel'
                            : 'Enter a valid duration',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Duration chip helper ───────────────────────────────────────────────────────

class _DurationChip extends StatelessWidget {
  final String label;
  final bool selected;
  final AppColors colors;
  final VoidCallback onTap;
  final IconData? icon;

  const _DurationChip({
    required this.label,
    required this.selected,
    required this.colors,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? colors.primary : colors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? colors.primary : colors.border,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 13,
                color: selected ? Colors.white : colors.textSecondary,
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
