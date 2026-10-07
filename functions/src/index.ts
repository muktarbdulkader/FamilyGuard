import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { FieldValue } from 'firebase-admin/firestore';
import * as crypto from 'crypto';

admin.initializeApp();
const db = admin.firestore();
const messaging = admin.messaging();

// Security configuration
const SECURITY_CONFIG = {
  MAX_REQUEST_AGE_SECONDS: 300, // 5 minutes
  MAX_GRANTED_MINUTES: 480, // 8 hours maximum
  MIN_GRANTED_MINUTES: 1,
  TOKEN_VALIDITY_SECONDS: 86400, // 24 hours
  MAX_REQUESTS_PER_CHILD_PER_HOUR: 10,
  NONCE_LENGTH: 32,
};

interface ApprovalRequest {
  requestId: string;
  familyId: string;
  childId: string;
  parentId: string;
  grantedMinutes: number;
  timestamp: number;
  authNonce: string;
}

interface DenialRequest {
  requestId: string;
  familyId: string;
  childId: string;
  parentId: string;
  timestamp: number;
  authNonce: string;
}

interface NotificationData {
  familyId: string;
  childId: string;
  childName: string;
  type: string;
  priority: string;
  title: string;
  body: string;
  data: any;
  createdAt: FirebaseFirestore.Timestamp;
}

interface FCMToken {
  userId: string;
  token: string;
  platform: string;
  deviceId?: string;
  isActive: boolean;
  lastUsed: FirebaseFirestore.Timestamp;
}

/**
 * CRITICAL: Enhanced security validation for all requests
 */
async function validateSecureRequest(
  context: functions.https.CallableContext,
  data: any,
  requiredFields: string[]
): Promise<{userId: string, familyId: string}> {
  // CRITICAL: Verify authentication
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
  }

  // CRITICAL: Validate input structure
  for (const field of requiredFields) {
    if (!data[field]) {
      throw new functions.https.HttpsError('invalid-argument', `Missing required field: ${field}`);
    }
  }

  // CRITICAL: Prevent timestamp manipulation and replay attacks
  if (data.timestamp) {
    const now = Date.now();
    const requestAge = now - data.timestamp;
    
    if (requestAge > SECURITY_CONFIG.MAX_REQUEST_AGE_SECONDS * 1000) {
      throw new functions.https.HttpsError('invalid-argument', 'Request timestamp too old');
    }
    
    if (requestAge < -30000) { // Allow 30 seconds of clock skew
      throw new functions.https.HttpsError('invalid-argument', 'Request timestamp in future');
    }
  }

  // CRITICAL: Verify user ID matches authenticated user
  const userId = context.auth.uid;
  const familyId = data.familyId;

  // CRITICAL: Verify family membership and permissions
  await validateFamilyMembership(userId, familyId);

  return { userId, familyId };
}

/**
 * CRITICAL: Validate family membership and prevent cross-family attacks
 */
async function validateFamilyMembership(userId: string, familyId: string): Promise<void> {
  try {
    const familyDoc = await db.collection('families').doc(familyId).get();
    
    if (!familyDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Family not found');
    }

    const familyData = familyDoc.data();
    const parentIds = familyData?.parentIds || [];
    const childIds = familyData?.childIds || [];
    
    if (!parentIds.includes(userId) && !childIds.includes(userId)) {
      // CRITICAL: Log security violation
      await logSecurityEvent('unauthorized_family_access', {
        userId,
        familyId,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });
      
      throw new functions.https.HttpsError('permission-denied', 'Not a member of this family');
    }
  } catch (error) {
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    throw new functions.https.HttpsError('internal', 'Error validating family membership');
  }
}

/**
 * CRITICAL: Validate parent authorization for family operations
 */
async function validateParentAuthorization(userId: string, familyId: string): Promise<void> {
  try {
    const familyDoc = await db.collection('families').doc(familyId).get();
    
    if (!familyDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Family not found');
    }

    const familyData = familyDoc.data();
    const parentIds = familyData?.parentIds || [];
    
    if (!parentIds.includes(userId)) {
      // CRITICAL: Log unauthorized parent action attempt
      await logSecurityEvent('unauthorized_parent_action', {
        userId,
        familyId,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });
      
      throw new functions.https.HttpsError('permission-denied', 'Parent authorization required');
    }
  } catch (error) {
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    throw new functions.https.HttpsError('internal', 'Error validating parent authorization');
  }
}

/**
 * CRITICAL: Rate limiting to prevent abuse
 */
async function checkRateLimit(userId: string, operation: string): Promise<void> {
  const now = Date.now();
  const hourAgo = now - 3600000; // 1 hour ago
  
  try {
    const recentRequests = await db
      .collection('rate_limits')
      .where('userId', '==', userId)
      .where('operation', '==', operation)
      .where('timestamp', '>=', new Date(hourAgo))
      .get();

    if (recentRequests.size >= SECURITY_CONFIG.MAX_REQUESTS_PER_CHILD_PER_HOUR) {
      // CRITICAL: Log rate limit violation
      await logSecurityEvent('rate_limit_exceeded', {
        userId,
        operation,
        requestCount: recentRequests.size,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });
      
      throw new functions.https.HttpsError('resource-exhausted', 'Rate limit exceeded');
    }

    // Record this request
    await db.collection('rate_limits').add({
      userId,
      operation,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

  } catch (error) {
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    // Don't fail on rate limit check errors, but log them
    console.error('Rate limit check failed:', error);
  }
}

/**
 * CRITICAL: Enhanced approval function with security validation
 */
export const approveAppRequest = functions.https.onCall(
  async (data: ApprovalRequest, context) => {
    try {
      // CRITICAL: Validate request security
      const { userId, familyId } = await validateSecureRequest(
        context, 
        data, 
        ['requestId', 'familyId', 'childId', 'parentId', 'grantedMinutes', 'timestamp', 'authNonce']
      );

      // CRITICAL: Verify parent authorization
      await validateParentAuthorization(userId, familyId);

      // CRITICAL: Verify user ID matches parentId
      if (userId !== data.parentId) {
        await logSecurityEvent('parent_id_mismatch', { userId, claimedParentId: data.parentId, familyId });
        throw new functions.https.HttpsError('permission-denied', 'Parent ID mismatch');
      }

      // CRITICAL: Validate granted minutes bounds
      if (data.grantedMinutes < SECURITY_CONFIG.MIN_GRANTED_MINUTES || 
          data.grantedMinutes > SECURITY_CONFIG.MAX_GRANTED_MINUTES) {
        throw new functions.https.HttpsError('invalid-argument', 'Invalid granted minutes');
      }

      // CRITICAL: Rate limiting
      await checkRateLimit(userId, 'approve_request');

      // CRITICAL: Verify request exists and is still pending
      const requestRef = db
        .collection('families')
        .doc(familyId)
        .collection('children')
        .doc(data.childId)
        .collection('requests')
        .doc(data.requestId);

      const requestDoc = await requestRef.get();
      
      if (!requestDoc.exists) {
        throw new functions.https.HttpsError('not-found', 'Request not found');
      }

      const requestData = requestDoc.data();
      
      // CRITICAL: Verify request is still pending
      if (requestData?.status !== 'pending') {
        throw new functions.https.HttpsError('failed-precondition', 'Request no longer pending');
      }

      // CRITICAL: Check request hasn't expired
      const expiresAt = requestData?.expiresAt?.toDate();
      if (!expiresAt || expiresAt < new Date()) {
        throw new functions.https.HttpsError('failed-precondition', 'Request expired');
      }

      // CRITICAL: Generate secure authorization token
      const authToken = generateSecureAuthToken(data.requestId, data.parentId, data.grantedMinutes, data.timestamp);

      // CRITICAL: Atomic update with security validation
      await db.runTransaction(async (transaction) => {
        // Re-read request in transaction
        const currentRequest = await transaction.get(requestRef);
        
        if (!currentRequest.exists || currentRequest.data()?.status !== 'pending') {
          throw new functions.https.HttpsError('failed-precondition', 'Request state changed');
        }

        // Update request with approval
        transaction.update(requestRef, {
          status: 'approved',
          grantedMinutes: data.grantedMinutes,
          decidedBy: data.parentId,
          decidedAt: FieldValue.serverTimestamp(),
          authToken,
          authNonce: data.authNonce, // Store nonce for verification
        });

        // Create temporary approval record
        const approvalRef = db
          .collection('families')
          .doc(familyId)
          .collection('children')
          .doc(data.childId)
          .collection('approvals')
          .doc();

        transaction.set(approvalRef, {
          requestId: data.requestId,
          packageName: requestData.packageName,
          grantedMinutes: data.grantedMinutes,
          startTime: FieldValue.serverTimestamp(),
          expiresAt: admin.firestore.Timestamp.fromDate(
            new Date(Date.now() + data.grantedMinutes * 60000)
          ),
          authToken,
          decidedBy: data.parentId,
        });
      });

      // CRITICAL: Send secure notification to child
      await sendApprovalNotificationToChild(familyId, data.childId, data.requestId, data.grantedMinutes, authToken);

      // CRITICAL: Log approval for audit trail
      await logSecurityEvent('request_approved', {
        requestId: data.requestId,
        familyId,
        childId: data.childId,
        parentId: data.parentId,
        grantedMinutes: data.grantedMinutes,
        timestamp: FieldValue.serverTimestamp(),
      });

      return { 
        success: true, 
        authToken,
        expiresAt: new Date(Date.now() + data.grantedMinutes * 60000).toISOString(),
        message: 'Request approved successfully' 
      };

    } catch (error) {
      console.error('Error in approveAppRequest:', error);
      
      if (error instanceof functions.https.HttpsError) {
        throw error;
      }
      
      throw new functions.https.HttpsError('internal', 'Failed to approve request');
    }
  }
);

/**
 * CRITICAL: Enhanced denial function with security validation
 */
export const denyAppRequest = functions.https.onCall(
  async (data: DenialRequest, context) => {
    try {
      // CRITICAL: Validate request security
      const { userId, familyId } = await validateSecureRequest(
        context, 
        data, 
        ['requestId', 'familyId', 'childId', 'parentId', 'timestamp', 'authNonce']
      );

      // CRITICAL: Verify parent authorization
      await validateParentAuthorization(userId, familyId);

      // CRITICAL: Verify user ID matches parentId
      if (userId !== data.parentId) {
        await logSecurityEvent('parent_id_mismatch', { userId, claimedParentId: data.parentId, familyId });
        throw new functions.https.HttpsError('permission-denied', 'Parent ID mismatch');
      }

      // CRITICAL: Rate limiting
      await checkRateLimit(userId, 'deny_request');

      // CRITICAL: Verify and update request
      const requestRef = db
        .collection('families')
        .doc(familyId)
        .collection('children')
        .doc(data.childId)
        .collection('requests')
        .doc(data.requestId);

      await db.runTransaction(async (transaction) => {
        const requestDoc = await transaction.get(requestRef);
        
        if (!requestDoc.exists) {
          throw new functions.https.HttpsError('not-found', 'Request not found');
        }

        const requestData = requestDoc.data();
        
        if (requestData?.status !== 'pending') {
          throw new functions.https.HttpsError('failed-precondition', 'Request no longer pending');
        }

        // Update request with denial
        transaction.update(requestRef, {
          status: 'denied',
          decidedBy: data.parentId,
          decidedAt: FieldValue.serverTimestamp(),
          authNonce: data.authNonce,
        });
      });

      // Send notification to child
      await sendDenialNotificationToChild(familyId, data.childId, data.requestId);

      // CRITICAL: Log denial for audit trail
      await logSecurityEvent('request_denied', {
        requestId: data.requestId,
        familyId,
        childId: data.childId,
        parentId: data.parentId,
        timestamp: FieldValue.serverTimestamp(),
      });

      return { 
        success: true,
        message: 'Request denied successfully' 
      };

    } catch (error) {
      console.error('Error in denyAppRequest:', error);
      
      if (error instanceof functions.https.HttpsError) {
        throw error;
      }
      
      throw new functions.https.HttpsError('internal', 'Failed to deny request');
    }
  }
);

/**
 * CRITICAL: Secure token generation with cryptographic strength
 */
function generateSecureAuthToken(
  requestId: string,
  parentId: string,
  grantedMinutes: number,
  timestamp: number
): string {
  const secret = process.env.AUTH_SECRET || 'default_secret_change_in_production';
  const data = `${requestId}:${parentId}:${grantedMinutes}:${timestamp}:${Date.now()}`;
  
  return crypto
    .createHmac('sha256', secret)
    .update(data)
    .digest('hex');
}

/**
 * CRITICAL: Token verification for client requests
 */
export const verifyAuthToken = functions.https.onCall(
  async (data: { requestId: string; authToken: string; familyId: string; childId: string }, context) => {
    try {
      // CRITICAL: Validate request security
      const { userId } = await validateSecureRequest(
        context, 
        data, 
        ['requestId', 'authToken', 'familyId', 'childId']
      );

      // CRITICAL: Verify child authorization
      if (userId !== data.childId) {
        throw new functions.https.HttpsError('permission-denied', 'Child ID mismatch');
      }

      // CRITICAL: Check approval exists and is valid
      const approvalQuery = await db
        .collection('families')
        .doc(data.familyId)
        .collection('children')
        .doc(data.childId)
        .collection('approvals')
        .where('requestId', '==', data.requestId)
        .where('authToken', '==', data.authToken)
        .limit(1)
        .get();

      if (approvalQuery.empty) {
        throw new functions.https.HttpsError('not-found', 'Valid approval not found');
      }

      const approval = approvalQuery.docs[0].data();
      const expiresAt = approval.expiresAt?.toDate();

      if (!expiresAt || expiresAt < new Date()) {
        throw new functions.https.HttpsError('failed-precondition', 'Approval expired');
      }

      return {
        valid: true,
        expiresAt: expiresAt.toISOString(),
        packageName: approval.packageName,
        grantedMinutes: approval.grantedMinutes,
      };

    } catch (error) {
      console.error('Error verifying auth token:', error);
      
      if (error instanceof functions.https.HttpsError) {
        throw error;
      }
      
      throw new functions.https.HttpsError('internal', 'Token verification failed');
    }
  }
);

/**
 * CRITICAL: Secure audit logging
 */
async function logSecurityEvent(event: string, data: any): Promise<void> {
  try {
    await db.collection('auditLogs').add({
      event,
      data,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      source: 'cloud_functions',
    });
  } catch (error) {
    console.error('Failed to log security event:', error);
    // Don't throw - logging failure shouldn't break operations
  }
}

/**
 * CRITICAL: Enhanced device status notification with security validation
 */
export const sendDeviceStatusNotification = functions.https.onCall(
  async (data: {
    familyId: string;
    childId: string;
    isOnline: boolean;
    deviceSignature: string;
    timestamp: number;
  }, context) => {
    try {
      // CRITICAL: Validate request security
      const { userId } = await validateSecureRequest(
        context, 
        data, 
        ['familyId', 'childId', 'isOnline', 'deviceSignature', 'timestamp']
      );

      // CRITICAL: Verify child ID matches authenticated user
      if (userId !== data.childId) {
        await logSecurityEvent('child_id_mismatch', { 
          userId, 
          claimedChildId: data.childId, 
          familyId: data.familyId 
        });
        throw new functions.https.HttpsError('permission-denied', 'Child ID mismatch');
      }

      // CRITICAL: Rate limiting for device status updates
      await checkRateLimit(userId, 'device_status_update');

      // CRITICAL: Verify device signature to prevent spoofing
      const expectedSignature = crypto
        .createHmac('sha256', process.env.DEVICE_SECRET || 'device_secret_change_in_production')
        .update(`${data.childId}:${data.isOnline}:${data.timestamp}`)
        .digest('hex');
      
      if (data.deviceSignature !== expectedSignature) {
        await logSecurityEvent('invalid_device_signature', {
          childId: data.childId,
          familyId: data.familyId,
          provided: data.deviceSignature,
          timestamp: FieldValue.serverTimestamp(),
        });
        throw new functions.https.HttpsError('permission-denied', 'Invalid device signature');
      }

      // Get child information with validation
      const childDoc = await db.collection('users').doc(data.childId).get();
      const childData = childDoc.data();
      
      if (!childData) {
        throw new functions.https.HttpsError('not-found', 'Child not found');
      }

      // Check for duplicate status updates (avoid spam)
      const lastStatusKey = `lastStatus_${data.childId}`;
      const lastStatusDoc = await db.collection('device_status').doc(lastStatusKey).get();
      const lastStatus = lastStatusDoc.data();
      
      if (lastStatus && lastStatus.isOnline === data.isOnline) {
        const timeDiff = Date.now() - lastStatus.timestamp;
        if (timeDiff < 300000) { // 5 minutes
          return { skipped: true, reason: 'duplicate' };
        }
      }

      // CRITICAL: Atomic update to prevent race conditions
      await db.runTransaction(async (transaction) => {
        const statusRef = db.collection('device_status').doc(lastStatusKey);
        
        transaction.set(statusRef, {
          childId: data.childId,
          isOnline: data.isOnline,
          timestamp: data.timestamp,
          updatedAt: FieldValue.serverTimestamp(),
          verified: true,
        });

        // Create secure notification
        const notificationRef = db.collection('notifications').doc();
        transaction.set(notificationRef, {
          familyId: data.familyId,
          childId: data.childId,
          childName: childData.displayName || 'Child',
          type: data.isOnline ? 'device_online' : 'device_offline',
          priority: 'normal',
          title: data.isOnline ? 'Device Online' : 'Device Offline',
          body: `${childData.displayName || 'Your child'}'s device ${data.isOnline ? 'is back online' : 'went offline'}.`,
          data: {
            type: data.isOnline ? 'device_online' : 'device_offline',
            familyId: data.familyId,
            childId: data.childId,
            isOnline: data.isOnline,
            timestamp: data.timestamp,
            verified: true,
          },
          createdAt: FieldValue.serverTimestamp(),
          expiresAt: data.isOnline ? 
            admin.firestore.Timestamp.fromDate(new Date(Date.now() + 3600000)) : // 1 hour for online
            null, // No expiration for offline
        });
      });

      // CRITICAL: Log device status change for audit
      await logSecurityEvent('device_status_change', {
        childId: data.childId,
        familyId: data.familyId,
        isOnline: data.isOnline,
        timestamp: FieldValue.serverTimestamp(),
      });

      return { success: true };

    } catch (error) {
      console.error('Error in sendDeviceStatusNotification:', error);
      
      if (error instanceof functions.https.HttpsError) {
        throw error;
      }
      
      throw new functions.https.HttpsError('internal', 'Failed to send device status notification');
    }
  }
);

/**
 * CRITICAL: Enhanced system status notification with security validation
 */
export const sendSystemStatusNotification = functions.https.onCall(
  async (data: {
    familyId: string;
    childId: string;
    type: 'permission_disabled' | 'service_unavailable';
    details: string;
    timestamp: number;
    deviceSignature: string;
  }, context) => {
    try {
      // CRITICAL: Validate request security
      const { userId } = await validateSecureRequest(
        context, 
        data, 
        ['familyId', 'childId', 'type', 'details', 'timestamp', 'deviceSignature']
      );

      // CRITICAL: Verify child ID matches authenticated user
      if (userId !== data.childId) {
        await logSecurityEvent('child_id_mismatch', { 
          userId, 
          claimedChildId: data.childId, 
          familyId: data.familyId 
        });
        throw new functions.https.HttpsError('permission-denied', 'Child ID mismatch');
      }

      // CRITICAL: Validate notification type
      const validTypes = ['permission_disabled', 'service_unavailable'];
      if (!validTypes.includes(data.type)) {
        throw new functions.https.HttpsError('invalid-argument', 'Invalid notification type');
      }

      // CRITICAL: Rate limiting for system notifications
      await checkRateLimit(userId, 'system_notification');

      // CRITICAL: Verify device signature
      const expectedSignature = crypto
        .createHmac('sha256', process.env.DEVICE_SECRET || 'device_secret_change_in_production')
        .update(`${data.childId}:${data.type}:${data.details}:${data.timestamp}`)
        .digest('hex');
      
      if (data.deviceSignature !== expectedSignature) {
        await logSecurityEvent('invalid_device_signature', {
          childId: data.childId,
          familyId: data.familyId,
          type: data.type,
          timestamp: FieldValue.serverTimestamp(),
        });
        throw new functions.https.HttpsError('permission-denied', 'Invalid device signature');
      }

      // Get child information
      const childDoc = await db.collection('users').doc(data.childId).get();
      const childData = childDoc.data();
      
      if (!childData) {
        throw new functions.https.HttpsError('not-found', 'Child not found');
      }

      // Create critical security notification
      const isPermission = data.type === 'permission_disabled';
      const notificationRef = db.collection('notifications').doc();
      
      await notificationRef.set({
        familyId: data.familyId,
        childId: data.childId,
        childName: childData.displayName || 'Child',
        type: data.type,
        priority: 'urgent',
        title: isPermission ? 'SECURITY ALERT: Permission Disabled' : 'SECURITY ALERT: Monitoring Unavailable',
        body: isPermission ? 
          `CRITICAL: ${data.details} was disabled on ${childData.displayName || 'your child'}'s device.` :
          `CRITICAL: Monitoring service stopped on ${childData.displayName || 'your child'}'s device.`,
        data: {
          type: data.type,
          familyId: data.familyId,
          childId: data.childId,
          details: data.details,
          timestamp: data.timestamp,
          securityAlert: true,
          verified: true,
        },
        createdAt: FieldValue.serverTimestamp(),
        expiresAt: null, // Critical security notifications never expire
      });

      // CRITICAL: Log security event
      await logSecurityEvent('security_alert', {
        type: data.type,
        childId: data.childId,
        familyId: data.familyId,
        details: data.details,
        timestamp: FieldValue.serverTimestamp(),
      });

      return { success: true, notificationId: notificationRef.id };

    } catch (error) {
      console.error('Error in sendSystemStatusNotification:', error);
      
      if (error instanceof functions.https.HttpsError) {
        throw error;
      }
      
      throw new functions.https.HttpsError('internal', 'Failed to send system status notification');
    }
  }
);

/**
 * CRITICAL: Send FCM notifications to parents with enhanced security
 */
export const sendParentNotification = functions.firestore
  .document('notifications/{notificationId}')
  .onCreate(async (snapshot, context) => {
    const notificationData = snapshot.data() as NotificationData;
    const { notificationId } = context.params;

    try {
      console.log(`Processing notification: ${notificationId} for family: ${notificationData.familyId}`);
      
      // CRITICAL: Validate notification data structure
      if (!notificationData.familyId || !notificationData.childId) {
        await logSecurityEvent('invalid_notification_data', {
          notificationId,
          data: notificationData,
          timestamp: FieldValue.serverTimestamp(),
        });
        return;
      }

      // Get all parent FCM tokens for this family
      const parentTokens = await getParentFCMTokens(notificationData.familyId);
      
      if (parentTokens.length === 0) {
        console.log('No parent FCM tokens found for family:', notificationData.familyId);
        return;
      }

      // Prepare the FCM message with security considerations
      const message = {
        notification: {
          title: notificationData.title,
          body: notificationData.body,
        },
        data: {
          notificationId,
          ...notificationData.data,
          priority: notificationData.priority,
          verified: 'true', // Mark as server-verified
        },
        android: {
          priority: getAndroidPriority(notificationData.priority),
          notification: {
            channelId: getChannelId(notificationData.priority),
            sound: notificationData.priority !== 'low' ? 'default' : undefined,
            priority: getAndroidNotificationPriority(notificationData.priority),
          },
        },
        apns: {
          payload: {
            aps: {
              alert: {
                title: notificationData.title,
                body: notificationData.body,
              },
              sound: notificationData.priority !== 'low' ? 'default' : undefined,
              'content-available': 1,
            },
          },
        },
      };

      // Send to all parent tokens
      const results = await sendToTokensWithRetry(parentTokens, message);
      
      // Update notification with delivery status
      await snapshot.ref.update({
        deliveryAttempts: FieldValue.increment(1),
        deliveredTo: results.successCount,
        failedDeliveries: results.failureCount,
        lastDeliveryAttempt: FieldValue.serverTimestamp(),
        serverProcessed: true,
      });

      console.log(`Notification sent: ${results.successCount} success, ${results.failureCount} failed`);

    } catch (error) {
      console.error('Error sending parent notification:', error);
      
      // Mark notification as failed
      await snapshot.ref.update({
        deliveryFailed: true,
        deliveryError: error instanceof Error ? error.message : String(error),
        lastDeliveryAttempt: FieldValue.serverTimestamp(),
      });
    }
  });
/**
 * CRITICAL: Enhanced cleanup for expired requests with audit logging
 */
export const cleanupExpiredRequests = functions.pubsub
  .schedule('every 15 minutes')
  .onRun(async () => {
    const now = admin.firestore.Timestamp.now();
    let totalCleaned = 0;
    
    try {
      const familiesSnapshot = await db.collection('families').get();
      
      for (const familyDoc of familiesSnapshot.docs) {
        const familyData = familyDoc.data();
        const childIds = familyData.childIds || [];
        
        for (const childId of childIds) {
          const requestsRef = familyDoc.ref
            .collection('children')
            .doc(childId)
            .collection('requests');
          
          const expiredRequestsSnapshot = await requestsRef
            .where('status', '==', 'pending')
            .where('expiresAt', '<', now)
            .get();
          
          if (expiredRequestsSnapshot.docs.length > 0) {
            const batch = db.batch();
            
            expiredRequestsSnapshot.docs.forEach((requestDoc) => {
              batch.update(requestDoc.ref, {
                status: 'expired',
                expiredAt: FieldValue.serverTimestamp(),
              });
              totalCleaned++;
            });
            
            await batch.commit();
            console.log(`Expired ${expiredRequestsSnapshot.docs.length} requests for child ${childId}`);
          }
        }
      }

      // CRITICAL: Log cleanup operation for audit
      await logSecurityEvent('cleanup_expired_requests', {
        totalCleaned,
        timestamp: FieldValue.serverTimestamp(),
      });

    } catch (error) {
      console.error('Error cleaning up expired requests:', error);
      
      await logSecurityEvent('cleanup_error', {
        operation: 'expired_requests',
        error: error instanceof Error ? error.message : String(error),
        timestamp: FieldValue.serverTimestamp(),
      });
    }
  });

/**
 * CRITICAL: Enhanced FCM token cleanup with security validation
 */
export const cleanupInvalidTokens = functions.pubsub
  .schedule('every 24 hours')
  .onRun(async () => {
    console.log('Starting FCM token cleanup...');
    
    try {
      const tokensSnapshot = await db.collection('fcm_tokens').get();
      const batch = db.batch();
      let cleanupCount = 0;
      
      for (const tokenDoc of tokensSnapshot.docs) {
        const tokenData = tokenDoc.data() as FCMToken;
        const token = tokenData.token;
        
        try {
          // Test if token is still valid by sending a dry-run message
          await messaging.send({
            token,
            data: { test: 'true' },
          }, true); // dry-run = true
          
          // Update last validated timestamp if token is valid
          batch.update(tokenDoc.ref, {
            lastValidated: FieldValue.serverTimestamp(),
            isActive: true,
          });
          
        } catch (error: any) {
          console.log(`Invalid token found: ${token.substring(0, 10)}...`);
          
          // Remove invalid tokens
          if (error.code === 'messaging/invalid-registration-token' ||
              error.code === 'messaging/registration-token-not-registered') {
            batch.delete(tokenDoc.ref);
            cleanupCount++;
          } else {
            // Mark as inactive for other errors
            batch.update(tokenDoc.ref, {
              isActive: false,
              lastError: error.message,
              lastValidated: FieldValue.serverTimestamp(),
            });
          }
        }
      }
      
      await batch.commit();
      console.log(`FCM token cleanup completed. Removed ${cleanupCount} invalid tokens.`);

      // CRITICAL: Log cleanup operation
      await logSecurityEvent('cleanup_fcm_tokens', {
        totalProcessed: tokensSnapshot.size,
        cleanupCount,
        timestamp: FieldValue.serverTimestamp(),
      });
      
    } catch (error) {
      console.error('Error during FCM token cleanup:', error);
      
      await logSecurityEvent('cleanup_error', {
        operation: 'fcm_tokens',
        error: error instanceof Error ? error.message : String(error),
        timestamp: FieldValue.serverTimestamp(),
      });
    }
  });
// CRITICAL: Helper functions with enhanced security

async function getParentFCMTokens(familyId: string): Promise<string[]> {
  try {
    const familyDoc = await db.collection('families').doc(familyId).get();
    const familyData = familyDoc.data();
    
    if (!familyData) {
      console.log('Family not found:', familyId);
      return [];
    }

    const parentIds = familyData.parentIds || [familyData.parentId];
    const tokens: string[] = [];
    
    for (const parentId of parentIds) {
      const parentTokensSnapshot = await db
        .collection('fcm_tokens')
        .where('userId', '==', parentId)
        .where('isActive', '==', true)
        .get();
      
      parentTokensSnapshot.docs.forEach(doc => {
        const tokenData = doc.data() as FCMToken;
        tokens.push(tokenData.token);
      });
    }

    return [...new Set(tokens)];
    
  } catch (error) {
    console.error('Error getting parent FCM tokens:', error);
    return [];
  }
}

async function sendToTokensWithRetry(
  tokens: string[], 
  message: any
): Promise<{ successCount: number; failureCount: number }> {
  if (tokens.length === 0) {
    return { successCount: 0, failureCount: 0 };
  }

  let successCount = 0;
  let failureCount = 0;

  const batchSize = 500;
  for (let i = 0; i < tokens.length; i += batchSize) {
    const batch = tokens.slice(i, i + batchSize);
    
    try {
      const response = await messaging.sendMulticast({
        ...message,
        tokens: batch,
      });
      
      successCount += response.successCount;
      failureCount += response.failureCount;
      
      if (response.responses && response.responses.length > 0) {
        const failedTokens: string[] = [];
        
        response.responses.forEach((resp, index) => {
          if (!resp.success && resp.error) {
            const errorCode = resp.error.code;
            if (errorCode === 'messaging/invalid-registration-token' ||
                errorCode === 'messaging/registration-token-not-registered') {
              failedTokens.push(batch[index]);
            }
          }
        });
        
        if (failedTokens.length > 0) {
          await cleanupFailedTokens(failedTokens);
        }
      }
      
    } catch (error) {
      console.error('Error sending batch:', error);
      failureCount += batch.length;
    }
  }

  return { successCount, failureCount };
}

async function cleanupFailedTokens(failedTokens: string[]): Promise<void> {
  try {
    const batch = db.batch();
    
    for (const token of failedTokens) {
      const tokenQuery = await db.collection('fcm_tokens').where('token', '==', token).limit(1).get();
      tokenQuery.docs.forEach(doc => {
        batch.delete(doc.ref);
      });
    }
    
    await batch.commit();
    console.log(`Cleaned up ${failedTokens.length} failed tokens`);
    
  } catch (error) {
    console.error('Error cleaning up failed tokens:', error);
  }
}

function getChannelId(priority: string): string {
  switch (priority) {
    case 'urgent': return 'urgent_notifications';
    case 'high': return 'high_notifications';
    case 'normal': return 'normal_notifications';
    case 'low': return 'low_notifications';
    default: return 'normal_notifications';
  }
}

function getAndroidPriority(priority: string): 'normal' | 'high' {
  return priority === 'urgent' || priority === 'high' ? 'high' : 'normal';
}

function getAndroidNotificationPriority(priority: string): 'min' | 'low' | 'default' | 'high' | 'max' {
  switch (priority) {
    case 'urgent': return 'max';
    case 'high': return 'high';
    case 'normal': return 'default';
    case 'low': return 'low';
    default: return 'default';
  }
}
async function sendApprovalNotificationToChild(
  familyId: string,
  childId: string,
  requestId: string,
  grantedMinutes: number,
  authToken: string
) {
  try {
    const childDoc = await db.collection('users').doc(childId).get();
    const childData = childDoc.data();
    
    if (!childData?.fcmToken) {
      console.log('No FCM token for child');
      return;
    }

    const message = {
      notification: {
        title: 'Request Approved!',
        body: `You can now use the app for ${grantedMinutes} minutes`,
      },
      data: {
        type: 'request_approved',
        requestId,
        familyId,
        childId,
        grantedMinutes: grantedMinutes.toString(),
        authToken,
        verified: 'true',
      },
      token: childData.fcmToken,
    };

    await messaging.send(message);
    console.log('Sent approval notification to child');

  } catch (error) {
    console.error('Error sending approval notification to child:', error);
  }
}

async function sendDenialNotificationToChild(
  familyId: string,
  childId: string,
  requestId: string
) {
  try {
    const childDoc = await db.collection('users').doc(childId).get();
    const childData = childDoc.data();
    
    if (!childData?.fcmToken) {
      console.log('No FCM token for child');
      return;
    }

    const message = {
      notification: {
        title: 'Request Denied',
        body: 'Your app request was not approved',
      },
      data: {
        type: 'request_denied',
        requestId,
        familyId,
        childId,
        verified: 'true',
      },
      token: childData.fcmToken,
    };

    await messaging.send(message);
    console.log('Sent denial notification to child');

  } catch (error) {
    console.error('Error sending denial notification to child:', error);
  }
}

// ============================================================================
// RULES MANAGEMENT FUNCTIONS
// ============================================================================

/**
 * Validate and process new rule creation
 */
exports.onRuleCreated = functions.firestore
  .document('rules/{ruleId}')
  .onCreate(async (snapshot, context) => {
    try {
      const ruleData = snapshot.data();
      const ruleId = context.params.ruleId;
      
      console.log(`New rule created: ${ruleId}`, ruleData);

      // Validate rule data integrity
      await validateRuleData(ruleId, ruleData);

      // Log rule creation for audit
      await logRuleActivity('created', ruleId, ruleData);

      // Notify child device about new rule
      await notifyChildDevice(ruleData.childId, 'rule_created', {
        ruleId,
        ruleName: ruleData.ruleName,
        type: ruleData.type,
        status: ruleData.status
      });

    } catch (error) {
      console.error('Error processing rule creation:', error);
    }
  });

/**
 * Handle rule updates and enforce changes
 */
exports.onRuleUpdated = functions.firestore
  .document('rules/{ruleId}')
  .onUpdate(async (change, context) => {
    try {
      const beforeData = change.before.data();
      const afterData = change.after.data();
      const ruleId = context.params.ruleId;

      console.log(`Rule updated: ${ruleId}`);

      // Check if status changed
      if (beforeData.status !== afterData.status) {
        await handleRuleStatusChange(ruleId, beforeData.status, afterData.status, afterData);
      }

      // Check if rule parameters changed
      const parameterChanges = checkParameterChanges(beforeData, afterData);
      if (parameterChanges.length > 0) {
        await handleRuleParameterChanges(ruleId, parameterChanges, afterData);
      }

      // Log rule update for audit
      await logRuleActivity('updated', ruleId, afterData, beforeData);

      // Notify child device about rule changes
      await notifyChildDevice(afterData.childId, 'rule_updated', {
        ruleId,
        ruleName: afterData.ruleName,
        type: afterData.type,
        status: afterData.status,
        changes: parameterChanges
      });

    } catch (error) {
      console.error('Error processing rule update:', error);
    }
  });

/**
 * Handle rule deletion
 */
exports.onRuleDeleted = functions.firestore
  .document('rules/{ruleId}')
  .onDelete(async (snapshot, context) => {
    try {
      const deletedData = snapshot.data();
      const ruleId = context.params.ruleId;

      console.log(`Rule deleted: ${ruleId}`);

      // Log rule deletion for audit
      await logRuleActivity('deleted', ruleId, deletedData);

      // Notify child device about rule removal
      await notifyChildDevice(deletedData.childId, 'rule_deleted', {
        ruleId,
        ruleName: deletedData.ruleName,
        type: deletedData.type
      });

    } catch (error) {
      console.error('Error processing rule deletion:', error);
    }
  });

/**
 * Callable function to check if an app is allowed
 */
exports.checkAppAllowed = functions.https.onCall(async (data, context) => {
  try {
    const { childId, packageName, currentUsage = 0 } = data;
    
    // Verify authentication
    if (!context.auth?.uid) {
      throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
    }

    // Verify the caller is authorized (child or parent)
    const isAuthorized = await verifyChildAccess(context.auth.uid, childId);
    if (!isAuthorized) {
      throw new functions.https.HttpsError('permission-denied', 'Unauthorized access');
    }

    // Get active rules for the child
    const rulesSnapshot = await db.collection('rules')
      .where('childId', '==', childId)
      .where('status', '==', 'active')
      .get();

    const result = {
      allowed: true,
      remainingTime: null as number | null,
      reason: '',
      blockedUntil: null as Date | null
    };

    // Check each rule
    for (const doc of rulesSnapshot.docs) {
      const rule = doc.data();
      
      // Check app-specific rules
      if (rule.appPackageName === packageName) {
        const ruleResult = await evaluateAppRule(rule, currentUsage);
        if (!ruleResult.allowed) {
          result.allowed = false;
          result.reason = ruleResult.reason;
          result.remainingTime = ruleResult.remainingTime;
          result.blockedUntil = ruleResult.blockedUntil;
          break;
        }
        if (ruleResult.remainingTime !== null) {
          result.remainingTime = ruleResult.remainingTime;
        }
      }

      // Check bedtime rules
      if (rule.type === 'bedtime' && rule.bedtimeEnabled) {
        const bedtimeResult = evaluateBedtimeRule(rule);
        if (!bedtimeResult.allowed) {
          result.allowed = false;
          result.reason = bedtimeResult.reason;
          result.blockedUntil = bedtimeResult.blockedUntil;
          break;
        }
      }
    }

    return result;

  } catch (error) {
    console.error('Error checking app allowance:', error);
    throw new functions.https.HttpsError('internal', 'Failed to check app allowance');
  }
});

/**
 * Callable function to log rule enforcement
 */
exports.logRuleEnforcement = functions.https.onCall(async (data, context) => {
  try {
    const { ruleId, childId, action, details = {} } = data;
    
    // Verify authentication
    if (!context.auth?.uid) {
      throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
    }

    // Verify the caller is the child or authorized parent
    const isAuthorized = await verifyChildAccess(context.auth.uid, childId);
    if (!isAuthorized) {
      throw new functions.https.HttpsError('permission-denied', 'Unauthorized access');
    }

    // Create enforcement log
    const logData = {
      ruleId,
      childId,
      action,
      details,
      timestamp: FieldValue.serverTimestamp(),
      reportedBy: context.auth.uid
    };

    await db.collection('rule_enforcement_logs').add(logData);

    // Notify parent if enforcement action occurred
    if (['blocked', 'limited', 'violated'].includes(action)) {
      await notifyParentOfEnforcement(childId, action, details);
    }

    return { success: true };

  } catch (error) {
    console.error('Error logging rule enforcement:', error);
    throw new functions.https.HttpsError('internal', 'Failed to log enforcement');
  }
});

// ============================================================================
// RULES HELPER FUNCTIONS
// ============================================================================

async function validateRuleData(ruleId: string, ruleData: any) {
  // Validate required fields
  const requiredFields = ['familyId', 'childId', 'ruleName', 'type', 'status'];
  for (const field of requiredFields) {
    if (!ruleData[field]) {
      throw new Error(`Missing required field: ${field}`);
    }
  }

  // Validate rule type
  const validTypes = ['appLimit', 'appBlock', 'appSchedule', 'screenTime', 'bedtime', 'appRequest', 'category'];
  if (!validTypes.includes(ruleData.type)) {
    throw new Error(`Invalid rule type: ${ruleData.type}`);
  }

  // Validate status
  const validStatuses = ['active', 'paused', 'expired', 'disabled'];
  if (!validStatuses.includes(ruleData.status)) {
    throw new Error(`Invalid rule status: ${ruleData.status}`);
  }

  // Type-specific validation
  if (ruleData.type === 'appLimit' || ruleData.type === 'screenTime') {
    if (ruleData.dailyLimitMinutes && (ruleData.dailyLimitMinutes < 1 || ruleData.dailyLimitMinutes > 1440)) {
      throw new Error('Daily limit must be between 1 and 1440 minutes');
    }
  }

  console.log(`Rule validation passed for: ${ruleId}`);
}

async function logRuleActivity(action: string, ruleId: string, ruleData: any, previousData?: any) {
  try {
    await db.collection('audit_logs').add({
      type: 'rule_activity',
      action,
      ruleId,
      ruleData,
      previousData: previousData || null,
      timestamp: FieldValue.serverTimestamp()
    });
  } catch (error) {
    console.error('Error logging rule activity:', error);
  }
}

async function handleRuleStatusChange(
  ruleId: string, 
  oldStatus: string, 
  newStatus: string, 
  ruleData: any
) {
  console.log(`Rule ${ruleId} status changed: ${oldStatus} -> ${newStatus}`);

  // If rule was activated, send immediate sync to child device
  if (newStatus === 'active') {
    await notifyChildDevice(ruleData.childId, 'rule_activated', {
      ruleId,
      ruleName: ruleData.ruleName,
      type: ruleData.type,
      settings: extractRuleSettings(ruleData)
    });
  }

  // If rule was paused/disabled, notify child device
  if (['paused', 'disabled'].includes(newStatus)) {
    await notifyChildDevice(ruleData.childId, 'rule_deactivated', {
      ruleId,
      type: ruleData.type
    });
  }
}

function checkParameterChanges(beforeData: any, afterData: any): string[] {
  const changes: string[] = [];
  const importantFields = [
    'dailyLimitMinutes', 'weeklyLimitMinutes', 'allowedStartTime', 'allowedEndTime',
    'bedtimeStart', 'bedtimeEnd', 'totalScreenTimeMinutes', 'requireApproval'
  ];

  for (const field of importantFields) {
    if (beforeData[field] !== afterData[field]) {
      changes.push(field);
    }
  }

  return changes;
}

async function handleRuleParameterChanges(
  ruleId: string, 
  changes: string[], 
  ruleData: any
) {
  console.log(`Rule ${ruleId} parameters changed:`, changes);

  // Force immediate sync for time-sensitive changes
  const timeSensitiveChanges = [
    'dailyLimitMinutes', 'allowedStartTime', 'allowedEndTime', 
    'bedtimeStart', 'bedtimeEnd', 'totalScreenTimeMinutes'
  ];

  if (changes.some(change => timeSensitiveChanges.includes(change))) {
    await notifyChildDevice(ruleData.childId, 'rule_sync_required', {
      ruleId,
      priority: 'high',
      changes
    });
  }
}

async function notifyChildDevice(childId: string, type: string, data: any) {
  try {
    // Get child's FCM tokens
    const tokensSnapshot = await db.collection('fcm_tokens')
      .where('userId', '==', childId)
      .get();

    if (tokensSnapshot.empty) {
      console.warn(`No FCM tokens found for child: ${childId}`);
      return;
    }

    const tokens = tokensSnapshot.docs.map(doc => doc.data().token);
    
    const message = {
      data: {
        type,
        childId,
        payload: JSON.stringify(data)
      },
      tokens
    };

    const response = await messaging.sendMulticast(message);
    console.log(`Sent ${type} notification to child ${childId}:`, response);

  } catch (error) {
    console.error('Error sending notification to child device:', error);
  }
}

async function verifyChildAccess(authUid: string, childId: string): Promise<boolean> {
  // Child can access their own data
  if (authUid === childId) {
    return true;
  }

  // Check if auth user is parent of this child
  return await verifyParentRole(authUid, childId);
}

async function verifyParentRole(authUid: string, childId: string): Promise<boolean> {
  try {
    // Get child's family ID
    const childDoc = await db.collection('users').doc(childId).get();
    if (!childDoc.exists) {
      return false;
    }

    const familyId = childDoc.data()?.familyId;
    if (!familyId) {
      return false;
    }

    // Check if auth user is parent in this family
    const familyDoc = await db.collection('families').doc(familyId).get();
    if (!familyDoc.exists) {
      return false;
    }

    const familyData = familyDoc.data();
    return familyData?.parentIds?.includes(authUid) || false;

  } catch (error) {
    console.error('Error verifying parent role:', error);
    return false;
  }
}

async function evaluateAppRule(rule: any, currentUsage: number) {
  const result = {
    allowed: true,
    reason: '',
    remainingTime: null as number | null,
    blockedUntil: null as Date | null
  };

  // Check if app is blocked
  if (rule.type === 'appBlock') {
    result.allowed = false;
    result.reason = 'App is blocked by parent';
    return result;
  }

  // Check daily time limit
  if (rule.type === 'appLimit' && rule.dailyLimitMinutes) {
    if (currentUsage >= rule.dailyLimitMinutes) {
      result.allowed = false;
      result.reason = 'Daily time limit exceeded';
      // Next day at midnight
      const tomorrow = new Date();
      tomorrow.setDate(tomorrow.getDate() + 1);
      tomorrow.setHours(0, 0, 0, 0);
      result.blockedUntil = tomorrow;
    } else {
      result.remainingTime = rule.dailyLimitMinutes - currentUsage;
    }
    return result;
  }

  // Check time window
  if (rule.type === 'appSchedule' && rule.allowedStartTime && rule.allowedEndTime) {
    const now = new Date();
    const currentTime = now.getHours() * 60 + now.getMinutes();
    const startTime = parseTimeString(rule.allowedStartTime);
    const endTime = parseTimeString(rule.allowedEndTime);

    let isInWindow = false;
    if (startTime <= endTime) {
      // Same day window
      isInWindow = currentTime >= startTime && currentTime <= endTime;
    } else {
      // Overnight window
      isInWindow = currentTime >= startTime || currentTime <= endTime;
    }

    if (!isInWindow) {
      result.allowed = false;
      result.reason = 'App is not available at this time';
      
      // Calculate when it will be available next
      const nextAvailable = new Date();
      if (startTime <= endTime) {
        // Next availability is today or tomorrow at start time
        if (currentTime < startTime) {
          nextAvailable.setHours(Math.floor(startTime / 60), startTime % 60, 0, 0);
        } else {
          nextAvailable.setDate(nextAvailable.getDate() + 1);
          nextAvailable.setHours(Math.floor(startTime / 60), startTime % 60, 0, 0);
        }
      } else {
        // Overnight schedule
        if (currentTime > endTime && currentTime < startTime) {
          nextAvailable.setHours(Math.floor(startTime / 60), startTime % 60, 0, 0);
        } else {
          nextAvailable.setHours(Math.floor(startTime / 60), startTime % 60, 0, 0);
          if (currentTime >= startTime) {
            nextAvailable.setDate(nextAvailable.getDate() + 1);
          }
        }
      }
      
      result.blockedUntil = nextAvailable;
    }
  }

  return result;
}

function evaluateBedtimeRule(rule: any) {
  const result = {
    allowed: true,
    reason: '',
    blockedUntil: null as Date | null
  };

  if (!rule.bedtimeStart || !rule.bedtimeEnd) {
    return result;
  }

  const now = new Date();
  const currentTime = now.getHours() * 60 + now.getMinutes();
  const bedtimeStart = parseTimeString(rule.bedtimeStart);
  const bedtimeEnd = parseTimeString(rule.bedtimeEnd);

  let isInBedtime = false;
  if (bedtimeStart <= bedtimeEnd) {
    // Same day bedtime (unusual)
    isInBedtime = currentTime >= bedtimeStart && currentTime <= bedtimeEnd;
  } else {
    // Overnight bedtime (normal)
    isInBedtime = currentTime >= bedtimeStart || currentTime <= bedtimeEnd;
  }

  if (isInBedtime) {
    result.allowed = false;
    result.reason = 'Device is locked during bedtime';
    
    // Calculate when bedtime ends
    const bedtimeEnds = new Date();
    if (bedtimeStart <= bedtimeEnd) {
      // Same day - ends today
      bedtimeEnds.setHours(Math.floor(bedtimeEnd / 60), bedtimeEnd % 60, 0, 0);
    } else {
      // Overnight - ends today or tomorrow
      if (currentTime >= bedtimeStart) {
        // Currently after bedtime start, ends tomorrow
        bedtimeEnds.setDate(bedtimeEnds.getDate() + 1);
      }
      bedtimeEnds.setHours(Math.floor(bedtimeEnd / 60), bedtimeEnd % 60, 0, 0);
    }
    
    result.blockedUntil = bedtimeEnds;
  }

  return result;
}

async function notifyParentOfEnforcement(childId: string, action: string, details: any) {
  try {
    // Get child's family
    const childDoc = await db.collection('users').doc(childId).get();
    const familyId = childDoc.data()?.familyId;
    
    if (!familyId) return;

    // Get family parents
    const familyDoc = await db.collection('families').doc(familyId).get();
    const parentIds = familyDoc.data()?.parentIds || [];

    // Create notification for parents
    for (const parentId of parentIds) {
      await db.collection('notifications').add({
        familyId,
        parentId,
        childId,
        type: 'rule_enforcement',
        title: `Rule ${action}`,
        body: `${action} action taken on child's device`,
        data: { action, ...details },
        createdAt: FieldValue.serverTimestamp(),
        isRead: false
      });
    }

  } catch (error) {
    console.error('Error notifying parent of enforcement:', error);
  }
}

function parseTimeString(timeString: string): number {
  const [hours, minutes] = timeString.split(':').map(Number);
  return hours * 60 + minutes;
}

function extractRuleSettings(ruleData: any) {
  const settings: any = {
    type: ruleData.type,
    status: ruleData.status
  };

  // Include relevant settings based on rule type
  if (ruleData.dailyLimitMinutes) settings.dailyLimitMinutes = ruleData.dailyLimitMinutes;
  if (ruleData.allowedStartTime) settings.allowedStartTime = ruleData.allowedStartTime;
  if (ruleData.allowedEndTime) settings.allowedEndTime = ruleData.allowedEndTime;
  if (ruleData.bedtimeStart) settings.bedtimeStart = ruleData.bedtimeStart;
  if (ruleData.bedtimeEnd) settings.bedtimeEnd = ruleData.bedtimeEnd;
  if (ruleData.requireApproval !== undefined) settings.requireApproval = ruleData.requireApproval;

  return settings;
}