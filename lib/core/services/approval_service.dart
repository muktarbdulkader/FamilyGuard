import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/request_model.dart';

/// Service for handling parent approval/denial of child app requests
class ApprovalService {
  static const String _collectionFamilies = 'families';
  static const String _collectionChildren = 'children';
  static const String _collectionRequests = 'requests';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  
  StreamController<List<AppRequest>>? _pendingRequestsController;
  StreamSubscription<QuerySnapshot>? _pendingRequestsListener;
  
  static ApprovalService? _instance;
  static ApprovalService get instance => _instance ??= ApprovalService._();
  ApprovalService._();

  /// Stream of pending requests for parent families
  Stream<List<AppRequest>> get pendingRequests {
    _pendingRequestsController ??= StreamController<List<AppRequest>>.broadcast();
    return _pendingRequestsController!.stream;
  }

  /// Start listening for pending requests across all families where user is parent
  void startListening(List<String> familyIds) {
    stopListening();
    
    if (familyIds.isEmpty) return;
    
    _pendingRequestsController = StreamController<List<AppRequest>>.broadcast();
    
    // Create a composite query for all families
    // Note: Firestore doesn't support OR queries across different collections,
    // so we'll need to listen to each family separately and merge results
    _listenToFamilyRequests(familyIds);
  }

  /// Stop listening for pending requests
  void stopListening() {
    _pendingRequestsListener?.cancel();
    _pendingRequestsListener = null;
    _pendingRequestsController?.close();
    _pendingRequestsController = null;
  }

  /// Get all pending requests for families where user is parent
  Future<List<AppRequest>> getPendingRequestsForFamilies(List<String> familyIds) async {
    final allRequests = <AppRequest>[];
    
    for (final familyId in familyIds) {
      try {
        final requests = await _getPendingRequestsForFamily(familyId);
        allRequests.addAll(requests);
      } catch (e) {
        print('Error getting requests for family $familyId: $e');
      }
    }
    
    // Sort by creation time (most recent first)
    allRequests.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    
    return allRequests;
  }

  /// Approve a child's app request
  Future<bool> approveRequest({
    required String requestId,
    required String familyId,
    required String childId,
    required String parentId,
    required int grantedMinutes,
  }) async {
    try {
      // Call Cloud Function for secure server-side approval
      final result = await _functions.httpsCallable('approveAppRequest').call({
        'requestId': requestId,
        'familyId': familyId,
        'childId': childId,
        'parentId': parentId,
        'grantedMinutes': grantedMinutes,
        'timestamp': Timestamp.now().millisecondsSinceEpoch,
      });

      final data = result.data as Map<String, dynamic>;
      return data['success'] == true;
      
    } catch (e) {
      print('Error approving request: $e');
      
      // Fallback to direct Firestore update (less secure)
      return await _fallbackApproveRequest(
        requestId: requestId,
        familyId: familyId,
        childId: childId,
        parentId: parentId,
        grantedMinutes: grantedMinutes,
      );
    }
  }

  /// Deny a child's app request
  Future<bool> denyRequest({
    required String requestId,
    required String familyId,
    required String childId,
    required String parentId,
  }) async {
    try {
      // Call Cloud Function for secure server-side denial
      final result = await _functions.httpsCallable('denyAppRequest').call({
        'requestId': requestId,
        'familyId': familyId,
        'childId': childId,
        'parentId': parentId,
        'timestamp': Timestamp.now().millisecondsSinceEpoch,
      });

      final data = result.data as Map<String, dynamic>;
      return data['success'] == true;
      
    } catch (e) {
      print('Error denying request: $e');
      
      // Fallback to direct Firestore update
      return await _fallbackDenyRequest(
        requestId: requestId,
        familyId: familyId,
        childId: childId,
        parentId: parentId,
      );
    }
  }

  /// Get request by ID
  Future<AppRequest?> getRequest(String familyId, String childId, String requestId) async {
    try {
      final doc = await _firestore
          .collection(_collectionFamilies)
          .doc(familyId)
          .collection(_collectionChildren)
          .doc(childId)
          .collection(_collectionRequests)
          .doc(requestId)
          .get();

      if (doc.exists) {
        return AppRequest.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error getting request: $e');
      return null;
    }
  }

  /// Get request history for a child
  Future<List<AppRequest>> getRequestHistory({
    required String familyId,
    required String childId,
    int limit = 20,
  }) async {
    try {
      final snapshot = await _firestore
          .collection(_collectionFamilies)
          .doc(familyId)
          .collection(_collectionChildren)
          .doc(childId)
          .collection(_collectionRequests)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => AppRequest.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error getting request history: $e');
      return [];
    }
  }

  // Private helper methods

  void _listenToFamilyRequests(List<String> familyIds) {
    // For simplicity, we'll listen to the first family
    // In a real implementation, you'd aggregate streams from all families
    if (familyIds.isNotEmpty) {
      final familyId = familyIds.first;
      
      // Get all children in this family first
      _firestore
          .collection(_collectionFamilies)
          .doc(familyId)
          .get()
          .then((familyDoc) {
        final familyData = familyDoc.data();
        if (familyData == null) return;
        
        final childIds = List<String>.from(familyData['childIds'] ?? []);
        
        // Listen to requests from all children in the family
        _listenToChildrenRequests(familyId, childIds);
      });
    }
  }

  void _listenToChildrenRequests(String familyId, List<String> childIds) {
    // For demonstration, listening to first child
    // Real implementation would aggregate streams from all children
    if (childIds.isNotEmpty) {
      final childId = childIds.first;
      
      _pendingRequestsListener = _firestore
          .collection(_collectionFamilies)
          .doc(familyId)
          .collection(_collectionChildren)
          .doc(childId)
          .collection(_collectionRequests)
          .where('status', isEqualTo: 'pending')
          .snapshots()
          .listen(
            (snapshot) {
              final requests = snapshot.docs
                  .map((doc) => AppRequest.fromFirestore(doc))
                  .where((r) => r.expiresAt.isAfter(DateTime.now()))
                  .toList();
              requests.sort((a, b) => b.createdAt.compareTo(a.createdAt));
              _pendingRequestsController?.add(requests);
            },
            onError: (error) {
              print('Error listening to pending requests: $error');
            },
          );
    }
  }

  Future<List<AppRequest>> _getPendingRequestsForFamily(String familyId) async {
    // Get family data to find child IDs
    final familyDoc = await _firestore
        .collection(_collectionFamilies)
        .doc(familyId)
        .get();

    final familyData = familyDoc.data();
    if (familyData == null) return [];

    final childIds = List<String>.from(familyData['childIds'] ?? []);
    final allRequests = <AppRequest>[];

    // Get pending requests from all children
    for (final childId in childIds) {
      try {
        final snapshot = await _firestore
            .collection(_collectionFamilies)
            .doc(familyId)
            .collection(_collectionChildren)
            .doc(childId)
            .collection(_collectionRequests)
            .where('status', isEqualTo: 'pending')
            .where('expiresAt', isGreaterThan: Timestamp.now())
            .get();

        final childRequests = snapshot.docs
            .map((doc) => AppRequest.fromFirestore(doc))
            .toList();

        allRequests.addAll(childRequests);
      } catch (e) {
        print('Error getting requests for child $childId: $e');
      }
    }

    return allRequests;
  }

  Future<bool> _fallbackApproveRequest({
    required String requestId,
    required String familyId,
    required String childId,
    required String parentId,
    required int grantedMinutes,
  }) async {
    try {
      await _firestore
          .collection(_collectionFamilies)
          .doc(familyId)
          .collection(_collectionChildren)
          .doc(childId)
          .collection(_collectionRequests)
          .doc(requestId)
          .update({
        'status': 'approved',
        'grantedMinutes': grantedMinutes,
        'decidedBy': parentId,
        'decidedAt': Timestamp.now(),
      });

      // Send notification to child (in real implementation)
      await _sendApprovalNotificationToChild(familyId, childId, requestId, grantedMinutes);

      return true;
    } catch (e) {
      print('Error in fallback approve: $e');
      return false;
    }
  }

  Future<bool> _fallbackDenyRequest({
    required String requestId,
    required String familyId,
    required String childId,
    required String parentId,
  }) async {
    try {
      await _firestore
          .collection(_collectionFamilies)
          .doc(familyId)
          .collection(_collectionChildren)
          .doc(childId)
          .collection(_collectionRequests)
          .doc(requestId)
          .update({
        'status': 'denied',
        'decidedBy': parentId,
        'decidedAt': Timestamp.now(),
      });

      // Send notification to child (in real implementation)
      await _sendDenialNotificationToChild(familyId, childId, requestId);

      return true;
    } catch (e) {
      print('Error in fallback deny: $e');
      return false;
    }
  }

  Future<void> _sendApprovalNotificationToChild(
    String familyId,
    String childId,
    String requestId,
    int grantedMinutes,
  ) async {
    try {
      // In real implementation, send FCM notification to child device
      await _firestore.collection('notifications').add({
        'type': 'request_approved',
        'familyId': familyId,
        'childId': childId,
        'requestId': requestId,
        'grantedMinutes': grantedMinutes,
        'createdAt': Timestamp.now(),
      });
    } catch (e) {
      print('Error sending approval notification: $e');
    }
  }

  Future<void> _sendDenialNotificationToChild(
    String familyId,
    String childId,
    String requestId,
  ) async {
    try {
      // In real implementation, send FCM notification to child device
      await _firestore.collection('notifications').add({
        'type': 'request_denied',
        'familyId': familyId,
        'childId': childId,
        'requestId': requestId,
        'createdAt': Timestamp.now(),
      });
    } catch (e) {
      print('Error sending denial notification: $e');
    }
  }

  void dispose() {
    stopListening();
  }
}