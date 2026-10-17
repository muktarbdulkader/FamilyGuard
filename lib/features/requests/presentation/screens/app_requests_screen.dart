import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/models/request_model.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/user_provider.dart';
import '../../../../core/providers/family_provider.dart';

/// Parent screen for reviewing and acting on child app access requests
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
    final userAsync = ref.watch(currentUserDataProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('App Requests',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            Text('Approve or deny child access',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF4F46E5),
          unselectedLabelColor: const Color(0xFF94A3B8),
          indicatorColor: const Color(0xFF4F46E5),
          indicatorWeight: 3,
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'Approved'),
            Tab(text: 'Denied'),
          ],
        ),
      ),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5))),
        error: (e, _) => _buildError(e.toString()),
        data: (user) {
          final familyId = user?.familyId ??
              ref.watch(selectedFamilyProvider)?.id ??
              ref.watch(userFamiliesProvider).value?.firstOrNull?.id;
          if (familyId == null) {
            return _buildNoFamily();
          }
          return _RequestTabsView(
            familyId: familyId,
            tabController: _tabController,
          );
        },
      ),
    );
  }

  Widget _buildError(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 56, color: Color(0xFFEF4444)),
            const SizedBox(height: 16),
            const Text('Error loading requests', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Text(error, style: const TextStyle(color: Color(0xFF64748B), fontSize: 13), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildNoFamily() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF7C3AED).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.pending_actions_rounded, size: 52, color: Color(0xFF7C3AED)),
            ),
            const SizedBox(height: 20),
            const Text('No Family Linked', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
              'Link a family first to see app access requests from your children.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF64748B), fontSize: 13, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tabs body ─────────────────────────────────────────────────────────────────

class _RequestTabsView extends StatelessWidget {
  final String familyId;
  final TabController tabController;

  const _RequestTabsView({required this.familyId, required this.tabController});

  @override
  Widget build(BuildContext context) {
    return TabBarView(
      controller: tabController,
      children: [
        _RequestList(familyId: familyId, filter: RequestStatus.pending),
        _RequestList(familyId: familyId, filter: RequestStatus.approved),
        _RequestList(familyId: familyId, filter: RequestStatus.denied),
      ],
    );
  }
}

// ── Request list (one per tab) ────────────────────────────────────────────────

class _RequestList extends StatelessWidget {
  final String familyId;
  final RequestStatus filter;

  const _RequestList({required this.familyId, required this.filter});

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
          return const Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5)));
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading requests: ${snapshot.error}',
              style: const TextStyle(color: Color(0xFFEF4444), fontSize: 13),
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return _buildEmpty();
        }

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

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: requests.length,
          itemBuilder: (context, index) => _RequestCard(
            request: requests[index],
            familyId: familyId,
          ),
        );
      },
    );
  }

  Widget _buildEmpty() {
    final (icon, label, color) = switch (filter) {
      RequestStatus.pending => (Icons.hourglass_empty_rounded, 'No Pending Requests', const Color(0xFFF59E0B)),
      RequestStatus.approved => (Icons.check_circle_outline_rounded, 'No Approved Requests', const Color(0xFF10B981)),
      RequestStatus.denied => (Icons.cancel_outlined, 'No Denied Requests', const Color(0xFFEF4444)),
      _ => (Icons.inbox_rounded, 'No Requests', const Color(0xFF94A3B8)),
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
            Text(label, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              filter == RequestStatus.pending
                  ? 'When your children request access to blocked apps, they\'ll appear here.'
                  : 'No ${ filter.name} requests yet.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 13, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Request Card ──────────────────────────────────────────────────────────────

class _RequestCard extends ConsumerWidget {
  final AppRequest request;
  final String familyId;

  const _RequestCard({required this.request, required this.familyId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPending = request.status == RequestStatus.pending && !request.isExpired;
    final statusColor = switch (request.status) {
      RequestStatus.pending => const Color(0xFFF59E0B),
      RequestStatus.approved => const Color(0xFF10B981),
      RequestStatus.denied => const Color(0xFFEF4444),
      _ => const Color(0xFF94A3B8),
    };

    final statusLabel = request.isExpired && request.status == RequestStatus.pending
        ? 'Expired'
        : request.status.name[0].toUpperCase() + request.status.name.substring(1);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: statusColor.withOpacity(0.25), width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: app icon placeholder + name + badge
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.apps_rounded, color: Colors.white, size: 26),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.appName.isNotEmpty ? request.appName : request.packageName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (request.childName != null && request.childName!.isNotEmpty)
                        Text(
                          'Requested by: ${request.childName}',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF4F46E5), fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      Text(
                        request.packageName,
                        style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
            const Divider(height: 1),
            const SizedBox(height: 10),

            // Info row
            Row(
              children: [
                _InfoChip(
                  icon: Icons.access_time_rounded,
                  label: _timeAgo(request.createdAt),
                  color: const Color(0xFF94A3B8),
                ),
                const SizedBox(width: 8),
                _InfoChip(
                  icon: Icons.person_outline_rounded,
                  label: 'Child: ${request.childId.substring(0, 6)}…',
                  color: const Color(0xFF64748B),
                ),
                if (request.isApproved && request.grantedMinutes != null) ...[
                  const SizedBox(width: 8),
                  _InfoChip(
                    icon: Icons.timer_outlined,
                    label: '${request.grantedMinutes}m granted',
                    color: const Color(0xFF10B981),
                  ),
                ],
              ],
            ),

            // Action buttons (only for pending)
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
                        foregroundColor: const Color(0xFFEF4444),
                        side: const BorderSide(color: Color(0xFFEF4444)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () => _showApproveDialog(context, ref),
                      icon: const Icon(Icons.check_rounded, size: 16),
                      label: const Text('Approve'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ],

            // If approved — show access validity
            if (request.isApproved && request.accessExpiresAt != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.access_time_filled_rounded, size: 14, color: Color(0xFF10B981)),
                    const SizedBox(width: 6),
                    Text(
                      request.timeRemainingText,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF10B981)),
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

  Future<void> _deny(BuildContext context, WidgetRef ref) async {
    try {
      final updateData = {
        'status': RequestStatus.denied.name,
        'decidedAt': Timestamp.now(),
        'decidedBy': ref.read(authProvider).user?.uid ?? '',
      };

      await FirebaseFirestore.instance
          .collection('families')
          .doc(familyId)
          .collection('requests')
          .doc(request.id)
          .set(updateData, SetOptions(merge: true));

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

        // Notify child that request was denied
        try {
          await FirebaseFirestore.instance.collection('notifications').add({
            'familyId': familyId,
            'childId': request.childId,
            'type': 'appDenied',
            'priority': 'normal',
            'title': '❌ Access Denied: ${request.appName}',
            'body': 'Your request for access to ${request.appName} was denied by your parent.',
            'data': {
              'type': 'app_denied',
              'packageName': request.packageName,
              'appName': request.appName,
              'requestId': request.id,
            },
            'createdAt': Timestamp.now(),
            'isRead': false,
          });
        } catch (_) {}
      }

      // Sync root notifications and family notifications
      final notifDenyData = {
        'status': 'denied',
        'isDenied': true,
        'isRead': true,
      };
      try {
        final rootSnap = await FirebaseFirestore.instance
            .collection('notifications')
            .where('data.requestId', isEqualTo: request.id)
            .get();
        for (final doc in rootSnap.docs) {
          await doc.reference.set(notifDenyData, SetOptions(merge: true));
        }
      } catch (_) {}
      try {
        final famSnap = await FirebaseFirestore.instance
            .collection('families')
            .doc(familyId)
            .collection('notifications')
            .where('data.requestId', isEqualTo: request.id)
            .get();
        for (final doc in famSnap.docs) {
          await doc.reference.set(notifDenyData, SetOptions(merge: true));
        }
      } catch (_) {}

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Denied access to ${request.appName}'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  void _showApproveDialog(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _ApproveSheet(
        request: request,
        familyId: familyId,
        parentId: ref.read(authProvider).user?.uid ?? '',
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

// ── Info chip ─────────────────────────────────────────────────────────────────

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

// ── Approve duration sheet ────────────────────────────────────────────────────

class _ApproveSheet extends StatefulWidget {
  final AppRequest request;
  final String familyId;
  final String parentId;

  const _ApproveSheet({required this.request, required this.familyId, required this.parentId});

  @override
  State<_ApproveSheet> createState() => _ApproveSheetState();
}

class _ApproveSheetState extends State<_ApproveSheet> {
  ApprovalDuration _selected = ApprovalDuration.thirtyMinutes;
  bool _loading = false;

  Future<void> _approve() async {
    setState(() => _loading = true);
    try {
      final now = DateTime.now();
      final approveData = {
        'status': RequestStatus.approved.name,
        'grantedMinutes': _selected.minutes,
        'decidedAt': Timestamp.fromDate(now),
        'decidedBy': widget.parentId,
        'accessExpiresAt': Timestamp.fromDate(now.add(Duration(minutes: _selected.minutes))),
      };

      await FirebaseFirestore.instance
          .collection('families')
          .doc(widget.familyId)
          .collection('requests')
          .doc(widget.request.id)
          .set(approveData, SetOptions(merge: true));

      if (widget.request.childId.isNotEmpty) {
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

        // Write temporary approval doc for native enforcement engine
        if (widget.request.packageName.isNotEmpty) {
          try {
            final pkgClean = widget.request.packageName.replaceAll('.', '_');
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
                  'durationMinutes': _selected.minutes,
                  'approvedBy': widget.parentId,
                  'accessExpiresAt': Timestamp.fromDate(now.add(Duration(minutes: _selected.minutes))),
                }, SetOptions(merge: true));
          } catch (e) {
            debugPrint('Error writing temporaryApproval doc: $e');
          }
        }

        // Notify child that request was approved
        try {
          await FirebaseFirestore.instance.collection('notifications').add({
            'familyId': widget.familyId,
            'childId': widget.request.childId,
            'type': 'appApproved',
            'priority': 'normal',
            'title': '🎉 Access Approved: ${widget.request.appName}',
            'body': 'Your parent approved ${_selected.displayText} of access to ${widget.request.appName}.',
            'data': {
              'type': 'app_approved',
              'packageName': widget.request.packageName,
              'appName': widget.request.appName,
              'grantedMinutes': _selected.minutes,
              'requestId': widget.request.id,
            },
            'createdAt': Timestamp.fromDate(now),
            'isRead': false,
          });
        } catch (_) {}
      }

      // Sync root notifications and family notifications so UI immediately displays approved
      final notifApproveData = {
        'status': 'approved',
        'isApproved': true,
        'grantedMinutes': _selected.minutes,
        'isRead': true,
      };
      try {
        final rootSnap = await FirebaseFirestore.instance
            .collection('notifications')
            .where('data.requestId', isEqualTo: widget.request.id)
            .get();
        for (final doc in rootSnap.docs) {
          await doc.reference.set(notifApproveData, SetOptions(merge: true));
        }
      } catch (_) {}
      try {
        final famSnap = await FirebaseFirestore.instance
            .collection('families')
            .doc(widget.familyId)
            .collection('notifications')
            .where('data.requestId', isEqualTo: widget.request.id)
            .get();
        for (final doc in famSnap.docs) {
          await doc.reference.set(notifApproveData, SetOptions(merge: true));
        }
      } catch (_) {}

      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Approved ${widget.request.appName} for ${_selected.displayText}'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Approve Access', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      Text(
                        widget.request.appName,
                        style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text('Grant access for:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ApprovalDuration.values.map((dur) {
                final selected = _selected == dur;
                return ChoiceChip(
                  label: Text(dur.displayText),
                  selected: selected,
                  onSelected: (_) => setState(() => _selected = dur),
                  selectedColor: const Color(0xFF4F46E5),
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : const Color(0xFF0F172A),
                    fontWeight: FontWeight.w600,
                  ),
                  backgroundColor: const Color(0xFFF1F5F9),
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _approve,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _loading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(
                        'Approve for ${_selected.displayText}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
