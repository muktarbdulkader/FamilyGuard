# Stage 8: Child Request → Parent Approval Testing Guide

## Overview

This guide covers testing the complete child request → parent approval workflow with FCM notifications, Cloud Functions, and secure authorization.

## Architecture Overview

```
Child Device                 Cloud Functions              Parent Device
     ↓                            ↓                           ↓
1. Child opens ASK_PARENT app     
2. Request screen shown           
3. "Ask Parent" button pressed    
4. Create request in Firestore    
     ↓                            ↓
5. Cloud Function triggered  →    
6. Validate request               
7. Send FCM to parents      →     
     ↓                            ↓                           ↓
8. Parent receives notification   
9. Parent opens approval screen   
10. Parent selects duration       
11. Parent approves/denies   →    
     ↓                            ↓
12. Cloud Function validates      
13. Update request status         
14. Send FCM to child       →     
     ↓                            ↓
15. Child receives approval       
16. Create local permission       
17. App access granted            
```

## Test Scenarios

### 1. Child Request Creation

#### Test 1.1: Basic Request Flow
```
Setup: Child device with ASK_PARENT rule for Instagram

Steps:
1. Child opens Instagram
2. App is blocked by enforcement engine
3. Enforcement overlay shows "Ask Parent" button
4. Child taps "Ask Parent"
5. Request screen opens with app info
6. Child taps "Ask Parent" button

Expected Results:
✅ Request created in Firestore with correct structure
✅ Request has pending status and 5-minute expiry
✅ Request includes nonce for replay prevention
✅ Parent receives FCM notification immediately
✅ Child sees "Request Sent" confirmation
```

#### Test 1.2: Duplicate Request Prevention
```
Setup: Child already has pending request for Instagram

Steps:
1. Child tries to open Instagram again
2. Enforcement overlay shows
3. Child taps "Ask Parent"

Expected Results:
✅ Shows existing request instead of creating new one
✅ Displays current request status and time remaining
✅ No duplicate request created in Firestore
```

#### Test 1.3: Rate Limiting
```
Setup: Child has 3 pending requests already

Steps:
1. Child tries to create 4th request
2. Taps "Ask Parent" on different app

Expected Results:
✅ Request creation fails with rate limit message
✅ Shows "Too many pending requests" error
✅ No new request created in Firestore
```

#### Test 1.4: Request Expiry
```
Setup: Child creates request and waits 5+ minutes

Steps:
1. Wait for request to expire (5 minutes)
2. Check request status
3. Try to create new request for same app

Expected Results:
✅ Expired request status updated to "expired"
✅ Child can create new request for same app
✅ Parent no longer sees expired request in pending list
```

### 2. Parent Notification and Approval

#### Test 2.1: FCM Notification Delivery
```
Setup: Parent device with FCM token registered

Steps:
1. Child creates request
2. Check parent device for notification

Expected Results:
✅ Parent receives push notification within 5 seconds
✅ Notification shows child name and app name
✅ Notification includes request data in payload
✅ Tapping notification opens approval screen
```

#### Test 2.2: Parent Approval Flow
```
Setup: Parent receives request notification

Steps:
1. Parent opens notification
2. Approval screen shows request details
3. Parent selects 30-minute duration
4. Parent taps "Approve" button

Expected Results:
✅ Cloud Function validates parent authorization
✅ Request status updated to "approved" with granted minutes
✅ Child receives approval notification immediately
✅ Child can activate permission and use app
✅ Temporary permission expires after 30 minutes
```

#### Test 2.3: Parent Denial Flow
```
Setup: Parent receives request notification

Steps:
1. Parent opens notification
2. Reviews request details
3. Parent taps "Deny" button
4. Confirms denial

Expected Results:
✅ Cloud Function validates parent authorization
✅ Request status updated to "denied"
✅ Child receives denial notification
✅ Child sees "Request Denied" message
✅ Child cannot use the app
```

#### Test 2.4: Quick Approval Options
```
Setup: Parent sees request in notification list

Steps:
1. Parent taps "15 min" quick approval button
2. Confirms quick approval

Expected Results:
✅ Request approved for exactly 15 minutes
✅ Child receives approval notification
✅ Permission expires after 15 minutes precisely
```

### 3. Security and Authorization Testing

#### Test 3.1: Parent Authorization Verification
```
Setup: Malicious user tries to approve request for different family

Steps:
1. Get valid request ID from another family
2. Call approval Cloud Function with unauthorized parent ID
3. Attempt to approve request

Expected Results:
✅ Cloud Function rejects with "permission denied"
✅ Request status remains "pending"
✅ No unauthorized approval occurs
✅ Audit log records failed attempt
```

#### Test 3.2: Child Self-Approval Prevention
```
Setup: Child device with request ID and parent credentials

Steps:
1. Child attempts to call approval Cloud Function
2. Uses parent's UID in request
3. Tries to approve own request

Expected Results:
✅ Cloud Function validates authentication token
✅ Request rejected if child tries to impersonate parent
✅ Firestore security rules prevent direct rule modification
✅ No self-approval possible
```

#### Test 3.3: Replay Attack Prevention
```
Setup: Valid approval request captured

Steps:
1. Parent approves request normally
2. Replay same approval request 10 minutes later
3. Try to extend or reapprove same request

Expected Results:
✅ Cloud Function rejects replayed request (too old timestamp)
✅ Already-approved request cannot be re-approved
✅ Auth token validation prevents replay
✅ No duplicate permission created
```

#### Test 3.4: Firestore Security Rules
```
Setup: Child device with direct Firestore access

Steps:
1. Child tries to directly modify request status in Firestore
2. Child attempts to change granted minutes
3. Child tries to create fake approved request

Expected Results:
✅ All direct modifications rejected by security rules
✅ Children can only create/cancel own requests
✅ Only Cloud Functions can approve/deny requests
✅ Request structure validation prevents malformed data
```

### 4. Offline and Network Error Scenarios

#### Test 4.1: Parent Offline During Request
```
Setup: Child creates request, parent device offline

Steps:
1. Child creates request
2. Parent device has no internet connection
3. Parent comes back online after 2 minutes

Expected Results:
✅ Request persists in Firestore while parent offline
✅ Parent receives notification when back online
✅ Request still valid if within 5-minute window
✅ Parent can approve/deny normally
```

#### Test 4.2: Child Offline During Approval
```
Setup: Parent approves request, child device offline

Steps:
1. Parent approves 30-minute request
2. Child device has no internet connection
3. Child comes back online after 5 minutes

Expected Results:
✅ Approval persists in Firestore
✅ Child receives approval notification when online
✅ Permission created with remaining time (25 minutes)
✅ Child can use app for remaining duration
```

#### Test 4.3: Network Error During Approval
```
Setup: Parent tries to approve during network issues

Steps:
1. Parent selects approval duration
2. Network fails during Cloud Function call
3. Parent retries approval

Expected Results:
✅ First approval attempt fails gracefully
✅ Retry mechanism prevents duplicate approvals
✅ Error message shown to parent
✅ Request remains in pending state until successful approval
```

### 5. Permission Management and Enforcement

#### Test 5.1: Permission Activation
```
Setup: Child receives approval for 1-hour access

Steps:
1. Child taps "Use App Now" button
2. App request screen closes
3. Child tries to open the app
4. Monitor permission status

Expected Results:
✅ Local permission created with exact expiry time
✅ Native enforcement engine allows app access
✅ Permission stored securely with auth token
✅ App opens normally without blocking overlay
```

#### Test 5.2: Permission Expiry Enforcement
```
Setup: Child has 15-minute permission that's about to expire

Steps:
1. Wait until 1 minute before expiry
2. Continue using app
3. Wait until exact expiry time
4. Try to continue using app

Expected Results:
✅ Warning notification at 2 minutes remaining
✅ App continues working until exact expiry
✅ App immediately blocked after expiry
✅ Normal ASK_PARENT rule applies again
```

#### Test 5.3: Permission Validation
```
Setup: Child has active permission

Steps:
1. Check permission auth token validity
2. Verify permission matches approved request
3. Attempt to modify permission locally

Expected Results:
✅ Auth token validates against server-generated token
✅ Permission data matches approved request exactly
✅ Local modification attempts fail/are ignored
✅ Only server-authorized permissions work
```

### 6. Cross-Device and Multi-Parent Testing

#### Test 6.1: Multiple Parents
```
Setup: Family with 2 parents, 1 child

Steps:
1. Child creates request
2. Both parents receive notification
3. First parent approves for 30 minutes
4. Second parent tries to modify approval

Expected Results:
✅ Both parents receive notification simultaneously
✅ First parent's approval succeeds
✅ Second parent sees request already approved
✅ Cannot override existing approval
```

#### Test 6.2: Parent Device Switching
```
Setup: Parent starts approval on phone, switches to tablet

Steps:
1. Parent opens request on phone
2. Switches to tablet device
3. Continues approval process on tablet

Expected Results:
✅ Request state synchronized across devices
✅ Approval can be completed on either device
✅ Real-time updates show on both devices
✅ No conflicts between devices
```

### 7. Edge Cases and Error Handling

#### Test 7.1: Invalid App Request
```
Setup: Malformed or corrupted request data

Steps:
1. Attempt to create request with invalid package name
2. Try request with future timestamp
3. Create request with excessive app name length

Expected Results:
✅ Invalid requests rejected by Firestore rules
✅ Appropriate error messages shown
✅ No malformed data stored
✅ App continues working normally
```

#### Test 7.2: Cloud Function Failures
```
Setup: Cloud Functions temporarily unavailable

Steps:
1. Parent attempts approval during outage
2. Check fallback mechanisms
3. Retry when functions restored

Expected Results:
✅ Graceful error handling shown to parent
✅ Fallback to direct Firestore update (if implemented)
✅ Retry mechanism available
✅ Eventual consistency when service restored
```

#### Test 7.3: FCM Token Issues
```
Setup: Device with expired or invalid FCM token

Steps:
1. Create request with invalid parent token
2. Check notification delivery
3. Update token and retry

Expected Results:
✅ Failed notifications logged but don't block request
✅ Parent can still find request in app
✅ Token refresh mechanism works
✅ Subsequent notifications delivered
```

## Performance Testing

### Load Testing
1. **Concurrent Requests**: 10 children creating requests simultaneously
2. **High-Volume Approvals**: Parent approving 50 requests in 5 minutes
3. **FCM Scalability**: 100 parents receiving notifications simultaneously

### Response Time Testing
1. **Request Creation**: < 2 seconds from button tap to Firestore
2. **Notification Delivery**: < 5 seconds from request to parent notification
3. **Approval Processing**: < 3 seconds from approval to child notification
4. **Permission Activation**: < 1 second from approval to local permission

## Monitoring and Audit

### Audit Trail Verification
1. **Request Logs**: All request creation/modification logged
2. **Approval Logs**: Parent approvals/denials with timestamps
3. **Permission Logs**: Permission creation and expiry tracked
4. **Security Logs**: Failed authorization attempts recorded

### Analytics Verification
1. **Request Patterns**: Track most requested apps and times
2. **Approval Rates**: Percentage of approved vs denied requests
3. **Usage Patterns**: How children use granted permissions
4. **Parent Response Times**: How quickly parents respond to requests

## Cleanup and Maintenance Testing

### Data Cleanup
1. **Expired Requests**: Automatic cleanup after 24 hours
2. **Old Permissions**: Remove expired permissions from local storage
3. **Audit Log Rotation**: Archive old logs after 30 days

### System Health
1. **Firestore Quota**: Monitor read/write operations
2. **Cloud Function Costs**: Track function invocations and duration
3. **FCM Quotas**: Monitor message delivery rates and limits

## Success Criteria

### Functional Requirements ✅
- [x] Child can request app access with professional UI
- [x] Parents receive real-time FCM notifications
- [x] Server-side approval/denial with security validation
- [x] Temporary permissions work offline
- [x] Request expiry and cleanup handled automatically

### Security Requirements ✅
- [x] Children cannot approve their own requests
- [x] Parents must be authenticated for approvals
- [x] Replay attacks prevented
- [x] Request tampering impossible
- [x] All actions audited and logged

### Performance Requirements ✅
- [x] Request creation under 2 seconds
- [x] Notification delivery under 5 seconds
- [x] System handles concurrent requests
- [x] Graceful error handling and recovery
- [x] Efficient data cleanup and maintenance

### User Experience Requirements ✅
- [x] Professional, child-friendly request UI
- [x] Parent approval process is intuitive
- [x] Clear status indicators throughout flow
- [x] Appropriate error messages and guidance
- [x] Offline functionality where possible

This testing framework ensures the request-approval system is secure, reliable, and user-friendly while maintaining strict parental control boundaries.