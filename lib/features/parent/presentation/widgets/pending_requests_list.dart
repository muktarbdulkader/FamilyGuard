import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/request_provider.dart';
import '../../../../core/providers/family_provider.dart';
import '../../../../core/providers/auth_provider.dart';
import 'request_notification_card.dart';

/// Widget displaying list of pending app requests for parents
class PendingRequestsList extends ConsumerWidget {
  const PendingRequestsList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    if (user == null) return const SizedBox.shrink();

    // Get families where user is parent
    final familiesAsync = ref.watch(userFamiliesProvider);
    
    return familiesAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(),
      ),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.red[400],
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'Error loading requests',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
      data: (families) {
        if (families.isEmpty) {
          return _buildEmptyState(context, 'No families found');
        }

        final familyIds = families.map((f) => f.id).toList();
        
        // Watch pending requests for all families
        final requestsAsync = ref.watch(parentPendingRequestsProvider(familyIds));
        
        return requestsAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(),
          ),
          error: (error, stack) => _buildErrorState(context, error.toString()),
          data: (requestsWithChildren) {
            if (requestsWithChildren.isEmpty) {
              return _buildEmptyState(context, 'No pending requests');
            }

            return _buildRequestsList(context, ref, requestsWithChildren);
          },
        );
      },
    );
  }

  Widget _buildRequestsList(
    BuildContext context,
    WidgetRef ref,
    List<AppRequestWithChild> requestsWithChildren,
  ) {
    return RefreshIndicator(
      onRefresh: () async {
        // Refresh the requests
        ref.invalidate(parentPendingRequestsProvider);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(
                  Icons.notifications_active,
                  color: Colors.orange[600],
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'Pending Requests',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${requestsWithChildren.length}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.red[700],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Requests list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: requestsWithChildren.length,
              itemBuilder: (context, index) {
                final item = requestsWithChildren[index];
                
                if (item.child == null) {
                  return _buildUnknownChildRequest(context, item.request);
                }
                
                return RequestNotificationCard(
                  request: item.request,
                  child: item.child!,
                  onApproved: () {
                    // Refresh the list after approval
                    ref.invalidate(parentPendingRequestsProvider);
                    _showSuccessMessage(context, 'Request approved successfully');
                  },
                  onDenied: () {
                    // Refresh the list after denial
                    ref.invalidate(parentPendingRequestsProvider);
                    _showSuccessMessage(context, 'Request denied');
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnknownChildRequest(BuildContext context, request) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Request from Unknown Child',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'App: ${request.appName}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            Text(
              'Child ID: ${request.childId}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'When children request app access, you\'ll see them here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Error Loading Requests',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                // Retry loading
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSuccessMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

/// Compact widget showing request count for dashboard
class RequestCountIndicator extends ConsumerWidget {
  const RequestCountIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    if (user == null) return const SizedBox.shrink();

    final familiesAsync = ref.watch(userFamiliesProvider);
    
    return familiesAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (error, stack) => const SizedBox.shrink(),
      data: (families) {
        if (families.isEmpty) return const SizedBox.shrink();

        final familyIds = families.map((f) => f.id).toList();
        final requestsAsync = ref.watch(parentPendingRequestsProvider(familyIds));
        
        return requestsAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (error, stack) => const SizedBox.shrink(),
          data: (requestsWithChildren) {
            if (requestsWithChildren.isEmpty) return const SizedBox.shrink();

            return Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${requestsWithChildren.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            );
          },
        );
      },
    );
  }
}