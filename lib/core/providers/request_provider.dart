import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/request_model.dart';
import '../models/family_model.dart';
import '../services/request_service.dart';
import '../services/approval_service.dart';
import 'auth_provider.dart';
import 'family_provider.dart';

/// Provider for managing app access requests (child-side)
final childRequestsProvider = StreamProvider.family<List<AppRequest>, String>((ref, childId) {
  final user = ref.watch(authProvider).user;
  final family = ref.watch(selectedFamilyProvider);
  
  if (user == null || family == null) {
    return Stream.value([]);
  }
  
  // Listen to child's requests in real-time
  return FirebaseFirestore.instance
      .collection('families')
      .doc(family.id)
      .collection('children')
      .doc(childId)
      .collection('requests')
      .where('status', whereIn: ['pending', 'approved', 'denied'])
      .orderBy('createdAt', descending: true)
      .limit(10)
      .snapshots()
      .map((snapshot) {
    return snapshot.docs
        .map((doc) => AppRequest.fromFirestore(doc))
        .toList();
  });
});

/// Provider for managing pending requests for parents
final parentPendingRequestsProvider = StreamProvider.family<List<AppRequestWithChild>, List<String>>((ref, familyIds) {
  if (familyIds.isEmpty) {
    return Stream.value([]);
  }
  
  // For simplicity, listen to first family
  // In real implementation, would aggregate multiple families
  final familyId = familyIds.first;
  
  return FirebaseFirestore.instance
      .collection('families')
      .doc(familyId)
      .snapshots()
      .asyncExpand((familyDoc) async* {
    final familyData = familyDoc.data();
    if (familyData == null) {
      yield [];
      return;
    }
    
    final childIds = List<String>.from(familyData['childIds'] ?? []);
    if (childIds.isEmpty) {
      yield [];
      return;
    }
    
    // Listen to all children's pending requests
    yield* _combineChildRequests(familyId, childIds);
  });
});

/// Provider for request service instance
final requestServiceProvider = Provider<RequestService>((ref) {
  return RequestService.instance;
});

/// Provider for approval service instance
final approvalServiceProvider = Provider<ApprovalService>((ref) {
  return ApprovalService.instance;
});

/// Provider for creating app requests
final createAppRequestProvider = FutureProvider.family<AppRequestResult, CreateRequestParams>((ref, params) async {
  final requestService = ref.read(requestServiceProvider);
  
  return await requestService.createRequest(
    familyId: params.familyId,
    childId: params.childId,
    packageName: params.packageName,
    appName: params.appName,
    deviceInfo: params.deviceInfo,
  );
});

/// Provider for approving requests
final approveRequestProvider = FutureProvider.family<bool, ApprovalParams>((ref, params) async {
  final approvalService = ref.read(approvalServiceProvider);
  
  return await approvalService.approveRequest(
    requestId: params.requestId,
    familyId: params.familyId,
    childId: params.childId,
    parentId: params.parentId,
    grantedMinutes: params.grantedMinutes,
  );
});

/// Provider for denying requests
final denyRequestProvider = FutureProvider.family<bool, DenialParams>((ref, params) async {
  final approvalService = ref.read(approvalServiceProvider);
  
  return await approvalService.denyRequest(
    requestId: params.requestId,
    familyId: params.familyId,
    childId: params.childId,
    parentId: params.parentId,
  );
});

/// Provider for request history
final requestHistoryProvider = FutureProvider.family<List<AppRequest>, RequestHistoryParams>((ref, params) async {
  final approvalService = ref.read(approvalServiceProvider);
  
  return await approvalService.getRequestHistory(
    familyId: params.familyId,
    childId: params.childId,
    limit: params.limit,
  );
});

/// Provider for active temporary permissions
final activePermissionsProvider = FutureProvider.family<List<TemporaryPermission>, String>((ref, childId) async {
  // This would typically fetch from local database
  // For now, returning empty list as placeholder
  return [];
});

// Helper function to combine child requests from multiple children
Stream<List<AppRequestWithChild>> _combineChildRequests(String familyId, List<String> childIds) async* {
  // This is a simplified implementation
  // In production, you'd want to use a more efficient stream combination
  
  final streams = childIds.map((childId) {
    return FirebaseFirestore.instance
        .collection('families')
        .doc(familyId)
        .collection('children')
        .doc(childId)
        .collection('requests')
        .where('status', isEqualTo: 'pending')
        .where('expiresAt', isGreaterThan: Timestamp.now())
        .orderBy('expiresAt')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
      // Get child info
      final childDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(childId)
          .get();
      
      ChildModel? child;
      if (childDoc.exists) {
        final childData = childDoc.data()!;
        child = ChildModel(
          id: childId,
          displayName: childData['displayName'] ?? 'Unknown Child',
          email: childData['email'] ?? '',
          familyId: familyId,
          joinedAt: (childData['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          lastActiveAt: (childData['lastActiveAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          isOnline: childData['isOnline'] ?? false,
          deviceInfo: childData['deviceInfo'],
          preferences: Map<String, dynamic>.from(childData['preferences'] ?? {}),
        );
      }
      
      return snapshot.docs
          .map((doc) => AppRequestWithChild(
                request: AppRequest.fromFirestore(doc),
                child: child,
              ))
          .toList();
    });
  });
  
  // For simplicity, just yield from first child's stream
  // In production, would properly combine all streams
  if (streams.isNotEmpty) {
    yield* streams.first;
  } else {
    yield [];
  }
}

/// Combined request and child data for parent UI
class AppRequestWithChild {
  final AppRequest request;
  final ChildModel? child;
  
  const AppRequestWithChild({
    required this.request,
    required this.child,
  });
}

/// Parameters for creating app requests
class CreateRequestParams {
  final String familyId;
  final String childId;
  final String packageName;
  final String appName;
  final String? deviceInfo;
  
  const CreateRequestParams({
    required this.familyId,
    required this.childId,
    required this.packageName,
    required this.appName,
    this.deviceInfo,
  });
}

/// Parameters for approving requests
class ApprovalParams {
  final String requestId;
  final String familyId;
  final String childId;
  final String parentId;
  final int grantedMinutes;
  
  const ApprovalParams({
    required this.requestId,
    required this.familyId,
    required this.childId,
    required this.parentId,
    required this.grantedMinutes,
  });
}

/// Parameters for denying requests
class DenialParams {
  final String requestId;
  final String familyId;
  final String childId;
  final String parentId;
  
  const DenialParams({
    required this.requestId,
    required this.familyId,
    required this.childId,
    required this.parentId,
  });
}

/// Parameters for fetching request history
class RequestHistoryParams {
  final String familyId;
  final String childId;
  final int limit;
  
  const RequestHistoryParams({
    required this.familyId,
    required this.childId,
    this.limit = 20,
  });
}