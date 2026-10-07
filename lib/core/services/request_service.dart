import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import '../models/request_model.dart';

/// Service for managing app access requests on the child device
class RequestService {
  static const String _collectionFamilies = 'families';
  static const String _collectionChildren = 'children';
  static const String _collectionRequests = 'requests';
  static const Duration _requestTimeout = Duration(minutes: 5);
  static const int _maxPendingRequests = 3;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  StreamController<AppRequest>? _requestUpdatesController;
  StreamSubscription<QuerySnapshot>? _requestListener;
  
  static RequestService? _instance;
  static RequestService get instance => _instance ??= RequestService._();
  RequestService._();

  /// Stream of request updates for this child
  Stream<AppRequest> get requestUpdates {
    _requestUpdatesController ??= StreamController<AppRequest>.broadcast();
    return _requestUpdatesController!.stream;
  }

  /// Start listening for request updates
  void startListening(String familyId, String childId) {
    stopListening();
    
    _requestUpdatesController = StreamController<AppRequest>.broadcast();
    
    final requestsRef = _firestore
        .collection(_collectionFamilies)
        .doc(familyId)
        .collection(_collectionChildren)
        .doc(childId)
        .collection(_collectionRequests);

    _requestListener = requestsRef
        .where('status', whereIn: ['pending', 'approved', 'denied'])
        .limit(10)
        .snapshots()
        .listen(
          (snapshot) {
            for (final change in snapshot.docChanges) {
              if (change.type == DocumentChangeType.modified ||
                  change.type == DocumentChangeType.added) {
                try {
                  final request = AppRequest.fromFirestore(change.doc);
                  _requestUpdatesController?.add(request);
                } catch (e) {
                  print('Error parsing request update: $e');
                }
              }
            }
          },
          onError: (error) {
            print('Error listening to request updates: $error');
          },
        );
  }

  /// Stop listening for request updates
  void stopListening() {
    _requestListener?.cancel();
    _requestListener = null;
    _requestUpdatesController?.close();
    _requestUpdatesController = null;
  }

  /// Create a new app access request
  Future<AppRequestResult> createRequest({
    required String familyId,
    required String childId,
    required String packageName,
    required String appName,
    String? deviceInfo,
  }) async {
    try {
      // Check for existing pending request
      final existingRequest = await _getExistingPendingRequest(
        familyId, childId, packageName
      );
      
      if (existingRequest != null) {
        return AppRequestResult.duplicate(existingRequest);
      }

      // Check request limits
      final pendingCount = await _getPendingRequestCount(familyId, childId);
      if (pendingCount >= _maxPendingRequests) {
        return AppRequestResult.rateLimited();
      }

      // Generate secure nonce
      final nonce = _generateNonce();
      
      // Create request
      final request = AppRequest(
        id: '', // Will be set by Firestore
        familyId: familyId,
        childId: childId,
        packageName: packageName,
        appName: appName,
        status: RequestStatus.pending,
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(_requestTimeout),
        requestNonce: nonce,
        deviceInfo: deviceInfo,
      );

      // Store in Firestore
      final docRef = await _firestore
          .collection(_collectionFamilies)
          .doc(familyId)
          .collection(_collectionChildren)
          .doc(childId)
          .collection(_collectionRequests)
          .add(request.toFirestore());

      final createdRequest = request.copyWith(id: docRef.id);
      
      // Send FCM notification to parents
      await _notifyParents(familyId, createdRequest);

      return AppRequestResult.success(createdRequest);
      
    } catch (e) {
      print('Error creating request: $e');
      return AppRequestResult.error('Failed to create request: ${e.toString()}');
    }
  }

  /// Get pending requests for child
  Future<List<AppRequest>> getPendingRequests(String familyId, String childId) async {
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

      return snapshot.docs
          .map((doc) => AppRequest.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error getting pending requests: $e');
      return [];
    }
  }

  /// Get active temporary permission for package
  Future<TemporaryPermission?> getActivePermission(String packageName) async {
    try {
      // This would typically be stored locally for performance
      // For now, we'll simulate getting it from a local cache
      
      // In a real implementation, this would check the local database
      // that was synchronized from the approved request
      
      return null; // Placeholder - implement with local storage
    } catch (e) {
      print('Error getting active permission: $e');
      return null;
    }
  }

  /// Cancel a pending request
  Future<bool> cancelRequest(String familyId, String childId, String requestId) async {
    try {
      await _firestore
          .collection(_collectionFamilies)
          .doc(familyId)
          .collection(_collectionChildren)
          .doc(childId)
          .collection(_collectionRequests)
          .doc(requestId)
          .update({
        'status': 'cancelled',
        'decidedAt': Timestamp.now(),
      });

      return true;
    } catch (e) {
      print('Error cancelling request: $e');
      return false;
    }
  }

  /// Handle approved request and create local permission
  Future<void> handleApprovedRequest(AppRequest request) async {
    if (!request.isApproved || request.grantedMinutes == null || request.decidedAt == null) {
      return;
    }

    try {
      // Create temporary permission
      final permission = TemporaryPermission(
        packageName: request.packageName,
        grantedAt: request.decidedAt!,
        expiresAt: request.decidedAt!.add(Duration(minutes: request.grantedMinutes!)),
        grantedBy: request.decidedBy!,
        requestId: request.id,
        authToken: _generateAuthToken(request),
      );

      // Store locally for enforcement
      await _storeLocalPermission(permission);
      
      print('Created temporary permission for ${request.packageName}: ${permission.expiresAt}');
      
    } catch (e) {
      print('Error handling approved request: $e');
    }
  }

  /// Clean up expired requests and permissions
  Future<void> cleanupExpired() async {
    try {
      // This would clean up local permissions and old requests
      // Implementation depends on local storage solution
      print('Cleaning up expired requests and permissions');
    } catch (e) {
      print('Error during cleanup: $e');
    }
  }

  // Private helper methods

  Future<AppRequest?> _getExistingPendingRequest(
    String familyId,
    String childId,
    String packageName,
  ) async {
    try {
      final snapshot = await _firestore
          .collection(_collectionFamilies)
          .doc(familyId)
          .collection(_collectionChildren)
          .doc(childId)
          .collection(_collectionRequests)
          .where('packageName', isEqualTo: packageName)
          .where('status', isEqualTo: 'pending')
          .where('expiresAt', isGreaterThan: Timestamp.now())
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return AppRequest.fromFirestore(snapshot.docs.first);
      }
      return null;
    } catch (e) {
      print('Error checking existing request: $e');
      return null;
    }
  }

  Future<int> _getPendingRequestCount(String familyId, String childId) async {
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

      return snapshot.docs.length;
    } catch (e) {
      print('Error getting pending count: $e');
      return 0;
    }
  }

  String _generateNonce() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (i) => random.nextInt(256));
    return base64Url.encode(bytes);
  }

  String _generateAuthToken(AppRequest request) {
    final data = '${request.id}:${request.decidedAt?.millisecondsSinceEpoch}:${request.grantedMinutes}';
    final bytes = utf8.encode(data);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<void> _notifyParents(String familyId, AppRequest request) async {
    try {
      // Get parent FCM tokens
      final familyDoc = await _firestore
          .collection(_collectionFamilies)
          .doc(familyId)
          .get();

      final familyData = familyDoc.data();
      if (familyData == null) return;

      final parentIds = List<String>.from(familyData['parentIds'] ?? []);
      
      // Send notification via Cloud Function (implemented later)
      await _firestore.collection('notifications').add({
        'type': 'app_request',
        'familyId': familyId,
        'childId': request.childId,
        'requestId': request.id,
        'parentIds': parentIds,
        'packageName': request.packageName,
        'appName': request.appName,
        'createdAt': Timestamp.now(),
      });

    } catch (e) {
      print('Error notifying parents: $e');
    }
  }

  Future<void> _storeLocalPermission(TemporaryPermission permission) async {
    // This would store the permission locally for the native enforcement engine
    // Implementation depends on the chosen local storage solution
    print('Storing local permission: ${permission.toMap()}');
  }

  void dispose() {
    stopListening();
  }
}

/// Result of creating an app request
class AppRequestResult {
  final bool success;
  final AppRequest? request;
  final String? error;
  final RequestResultType type;

  const AppRequestResult._({
    required this.success,
    this.request,
    this.error,
    required this.type,
  });

  factory AppRequestResult.success(AppRequest request) {
    return AppRequestResult._(
      success: true,
      request: request,
      type: RequestResultType.success,
    );
  }

  factory AppRequestResult.duplicate(AppRequest existingRequest) {
    return AppRequestResult._(
      success: false,
      request: existingRequest,
      error: 'Request already pending for this app',
      type: RequestResultType.duplicate,
    );
  }

  factory AppRequestResult.rateLimited() {
    return AppRequestResult._(
      success: false,
      error: 'Too many pending requests. Please wait.',
      type: RequestResultType.rateLimited,
    );
  }

  factory AppRequestResult.error(String message) {
    return AppRequestResult._(
      success: false,
      error: message,
      type: RequestResultType.error,
    );
  }
}

enum RequestResultType {
  success,
  duplicate,
  rateLimited,
  error,
}