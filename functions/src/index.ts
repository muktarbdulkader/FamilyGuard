import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { FieldValue } from 'firebase-admin/firestore';

admin.initializeApp();
const db = admin.firestore();
const messaging = admin.messaging();

interface ApprovalRequest {
  requestId: string;
  familyId: string;
  childId: string;
  parentId: string;
  grantedMinutes: number;
  timestamp: number;
}

interface DenialRequest {
  requestId: string;
  familyId: string;
  childId: string;
  parentId: string;
  timestamp: number;
}

/**
 * Securely approve an app request with server-side validation
 */
export const approveAppRequest = functions.https.onCall(
  async (data: ApprovalRequest, context) => {
    // Verify authentication
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }

    const { requestId, familyId, childId, parentId, grantedMinutes, timestamp } = data;
    
    // Validate input
    if (!requestId || !familyId || !childId || !parentId || !grantedMinutes) {
      throw new functions.https.HttpsError('invalid-argument', 'Missing required parameters');
    }

    if (context.auth.uid !== parentId) {
      throw new functions.https.HttpsError('permission-denied', 'Parent ID mismatch');
    }

    if (grantedMinutes < 1 || grantedMinutes > 480) { // Max 8 hours
      throw new functions.https.HttpsError('invalid-argument', 'Invalid granted minutes');
    }

    // Prevent replay attacks
    const requestAge = Date.now() - timestamp;
    if (requestAge > 300000) { // 5 minutes
      throw new functions.https.HttpsError('invalid-argument', 'Request timestamp too old');
    }

    try {
      // Verify parent has permission for this family
      const familyRef = db.collection('families').doc(familyId);
      const familyDoc = await familyRef.get();
      
      if (!familyDoc.exists) {
        throw new functions.https.HttpsError('not-found', 'Family not found');
      }

      const familyData = familyDoc.data();
      const parentIds = familyData?.parentIds || [];
      
      if (!parentIds.includes(parentId)) {
        throw new functions.https.HttpsError('permission-denied', 'User is not a parent in this family');
      }

      // Get the request document
      const requestRef = familyRef
        .collection('children')
        .doc(childId)
        .collection('requests')
        .doc(requestId);
      
      const requestDoc = await requestRef.get();
      
      if (!requestDoc.exists) {
        throw new functions.https.HttpsError('not-found', 'Request not found');
      }

      const requestData = requestDoc.data();
      
      // Verify request is still pending
      if (requestData?.status !== 'pending') {
        throw new functions.https.HttpsError('failed-precondition', 'Request is no longer pending');
      }

      // Check if request hasn't expired
      const expiresAt = requestData?.expiresAt?.toDate();
      if (!expiresAt || expiresAt < new Date()) {
        throw new functions.https.HttpsError('failed-precondition', 'Request has expired');
      }

      // Generate authorization token
      const authToken = generateAuthToken(requestId, parentId, grantedMinutes, timestamp);

      // Update request with approval
      await requestRef.update({
        status: 'approved',
        grantedMinutes,
        decidedBy: parentId,
        decidedAt: FieldValue.serverTimestamp(),
        authToken, // For verification by child device
      });

      // Send FCM notification to child
      await sendApprovalNotificationToChild(
        familyId,
        childId,
        requestId,
        grantedMinutes,
        authToken
      );

      // Log approval for audit
      await db.collection('auditLogs').add({
        type: 'request_approved',
        requestId,
        familyId,
        childId,
        parentId,
        grantedMinutes,
        timestamp: FieldValue.serverTimestamp(),
      });

      return { 
        success: true, 
        authToken,
        message: 'Request approved successfully' 
      };

    } catch (error) {
      console.error('Error approving request:', error);
      
      if (error instanceof functions.https.HttpsError) {
        throw error;
      }
      
      throw new functions.https.HttpsError('internal', 'Failed to approve request');
    }
  }
);

/**
 * Securely deny an app request with server-side validation
 */
export const denyAppRequest = functions.https.onCall(
  async (data: DenialRequest, context) => {
    // Verify authentication
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }

    const { requestId, familyId, childId, parentId, timestamp } = data;
    
    // Validate input
    if (!requestId || !familyId || !childId || !parentId) {
      throw new functions.https.HttpsError('invalid-argument', 'Missing required parameters');
    }

    if (context.auth.uid !== parentId) {
      throw new functions.https.HttpsError('permission-denied', 'Parent ID mismatch');
    }

    // Prevent replay attacks
    const requestAge = Date.now() - timestamp;
    if (requestAge > 300000) { // 5 minutes
      throw new functions.https.HttpsError('invalid-argument', 'Request timestamp too old');
    }

    try {
      // Verify parent has permission for this family
      const familyRef = db.collection('families').doc(familyId);
      const familyDoc = await familyRef.get();
      
      if (!familyDoc.exists) {
        throw new functions.https.HttpsError('not-found', 'Family not found');
      }

      const familyData = familyDoc.data();
      const parentIds = familyData?.parentIds || [];
      
      if (!parentIds.includes(parentId)) {
        throw new functions.https.HttpsError('permission-denied', 'User is not a parent in this family');
      }

      // Get the request document
      const requestRef = familyRef
        .collection('children')
        .doc(childId)
        .collection('requests')
        .doc(requestId);
      
      const requestDoc = await requestRef.get();
      
      if (!requestDoc.exists) {
        throw new functions.https.HttpsError('not-found', 'Request not found');
      }

      const requestData = requestDoc.data();
      
      // Verify request is still pending
      if (requestData?.status !== 'pending') {
        throw new functions.https.HttpsError('failed-precondition', 'Request is no longer pending');
      }

      // Update request with denial
      await requestRef.update({
        status: 'denied',
        decidedBy: parentId,
        decidedAt: FieldValue.serverTimestamp(),
      });

      // Send FCM notification to child
      await sendDenialNotificationToChild(familyId, childId, requestId);

      // Log denial for audit
      await db.collection('auditLogs').add({
        type: 'request_denied',
        requestId,
        familyId,
        childId,
        parentId,
        timestamp: FieldValue.serverTimestamp(),
      });

      return { 
        success: true,
        message: 'Request denied successfully' 
      };

    } catch (error) {
      console.error('Error denying request:', error);
      
      if (error instanceof functions.https.HttpsError) {
        throw error;
      }
      
      throw new functions.https.HttpsError('internal', 'Failed to deny request');
    }
  }
);

/**
 * Send FCM notification to parents when child makes a request
 */
export const notifyParentsOfRequest = functions.firestore
  .document('families/{familyId}/children/{childId}/requests/{requestId}')
  .onCreate(async (snapshot, context) => {
    const requestData = snapshot.data();
    const { familyId, childId, requestId } = context.params;

    try {
      // Get family data to find parent FCM tokens
      const familyDoc = await db.collection('families').doc(familyId).get();
      const familyData = familyDoc.data();
      
      if (!familyData) return;

      const parentIds = familyData.parentIds || [];
      
      // Get parent FCM tokens
      const parentTokens: string[] = [];
      for (const parentId of parentIds) {
        const parentDoc = await db.collection('users').doc(parentId).get();
        const parentData = parentDoc.data();
        if (parentData?.fcmToken) {
          parentTokens.push(parentData.fcmToken);
        }
      }

      if (parentTokens.length === 0) {
        console.log('No parent FCM tokens found');
        return;
      }

      // Get child name
      const childDoc = await db.collection('users').doc(childId).get();
      const childData = childDoc.data();
      const childName = childData?.displayName || 'Your child';

      // Send notification
      const message = {
        notification: {
          title: 'App Permission Request',
          body: `${childName} wants to use ${requestData.appName}`,
        },
        data: {
          type: 'app_request',
          requestId,
          familyId,
          childId,
          packageName: requestData.packageName,
          appName: requestData.appName,
        },
        tokens: parentTokens,
      };

      const response = await messaging.sendMulticast(message);
      console.log(`Sent ${response.successCount} notifications to parents`);

    } catch (error) {
      console.error('Error sending parent notification:', error);
    }
  });

/**
 * Clean up expired requests
 */
export const cleanupExpiredRequests = functions.pubsub
  .schedule('every 15 minutes')
  .onRun(async () => {
    const now = admin.firestore.Timestamp.now();
    
    try {
      // Query expired pending requests across all families and children
      // Note: This is a simplified approach. In production, you'd want to
      // optimize this query structure for better performance
      
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
          
          const batch = db.batch();
          
          expiredRequestsSnapshot.docs.forEach((requestDoc) => {
            batch.update(requestDoc.ref, {
              status: 'expired',
              expiredAt: FieldValue.serverTimestamp(),
            });
          });
          
          if (!batch.isEmpty) {
            await batch.commit();
            console.log(`Expired ${expiredRequestsSnapshot.docs.length} requests for child ${childId}`);
          }
        }
      }
    } catch (error) {
      console.error('Error cleaning up expired requests:', error);
    }
  });

// Helper functions

async function sendApprovalNotificationToChild(
  familyId: string,
  childId: string,
  requestId: string,
  grantedMinutes: number,
  authToken: string
) {
  try {
    // Get child's FCM token
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
    // Get child's FCM token
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
      },
      token: childData.fcmToken,
    };

    await messaging.send(message);
    console.log('Sent denial notification to child');

  } catch (error) {
    console.error('Error sending denial notification to child:', error);
  }
}

function generateAuthToken(
  requestId: string,
  parentId: string,
  grantedMinutes: number,
  timestamp: number
): string {
  const crypto = require('crypto');
  const data = `${requestId}:${parentId}:${grantedMinutes}:${timestamp}`;
  return crypto.createHash('sha256').update(data).digest('hex');
}