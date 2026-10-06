# Authentication System Testing Guide

This guide provides comprehensive testing instructions for the production Firebase Authentication system in the Family Guardian app.

## Prerequisites

Before testing, ensure you have:

1. **Firebase Project Setup**
   - Firebase project created and configured
   - Authentication enabled with Email/Password provider
   - Firestore database created
   - `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) properly configured

2. **Development Environment**
   - Flutter SDK installed
   - Firebase CLI installed and authenticated
   - Android/iOS development environment set up

3. **Deploy Firestore Security Rules**
   ```bash
   # Deploy the security rules
   firebase deploy --only firestore:rules
   ```

## Test Scenarios

### 1. Initial App Launch (Unauthenticated State)

**Expected Behavior:**
- App should open to the login screen
- No authentication state should be present
- Clean UI with Family Guardian branding

**Test Steps:**
1. Fresh install the app or clear app data
2. Launch the app
3. Verify login screen is displayed
4. Check that no navigation to other screens occurs

### 2. User Registration Flow

**Test Case 2.1: Successful Registration**
1. On login screen, tap "Sign Up"
2. Enter valid email: `test.parent@example.com`
3. Enter strong password: `SecurePass123!`
4. Tap "Create Account"
5. Enter display name when prompted: `Test Parent`
6. Tap "Continue"

**Expected Results:**
- Registration succeeds without errors
- Display name dialog appears and accepts input
- User is redirected to role selection screen
- Success message is displayed
- Firestore user document is created

**Test Case 2.2: Registration Validation**

Test invalid inputs:
- Empty email: Should show "Please enter your email"
- Invalid email format: Should show "Please enter a valid email address"
- Empty password: Should show "Please enter your password" 
- Short password (< 6 chars): Should show "Password must be at least 6 characters"
- Empty display name: Should prevent registration
- Short display name (< 2 chars): Should show validation error

**Test Case 2.3: Registration Error Handling**
- Try registering with existing email: Should show appropriate error message
- Test with network disabled: Should show network error
- Test with invalid Firebase configuration: Should show configuration error

### 3. User Sign-In Flow

**Test Case 3.1: Successful Sign-In**
1. On login screen, ensure "Sign In" mode is selected
2. Enter registered email: `test.parent@example.com`
3. Enter correct password: `SecurePass123!`
4. Tap "Sign In"

**Expected Results:**
- Sign-in succeeds without errors
- User is redirected based on role:
  - No role → Role Selection screen
  - Parent role → Parent Home screen
  - Child role → Child Home screen

**Test Case 3.2: Sign-In Validation**
Test with invalid credentials:
- Wrong password: Should show authentication error
- Non-existent email: Should show user not found error
- Malformed email: Should show validation error

### 4. Role Selection Flow

**Test Case 4.1: Parent Role Selection**
1. Complete registration or sign in without role
2. On role selection screen, tap "Parent" card
3. Verify role is saved to Firestore
4. Check redirection to Parent Home screen

**Test Case 4.2: Child Role Selection**
1. On role selection screen, tap "Child" card  
2. Verify role is saved to Firestore
3. Check redirection to Child Home screen

**Test Case 4.3: Role Persistence**
1. Select a role
2. Force close the app
3. Reopen the app
4. Verify user is taken directly to appropriate home screen (not role selection)

### 5. Password Reset Flow

**Test Case 5.1: Successful Password Reset**
1. On login screen, tap "Forgot Password?"
2. Ensure email field has valid email
3. Tap reset button
4. Check for success message
5. Verify password reset email is received

**Test Case 5.2: Password Reset Validation**
1. Clear email field
2. Tap "Forgot Password?"
3. Should show "Please enter your email address first"

### 6. Authentication State Management

**Test Case 6.1: App Restart with Authenticated User**
1. Sign in successfully
2. Force close app
3. Reopen app
4. Verify user goes directly to appropriate home screen
5. Check that auth state is properly restored

**Test Case 6.2: Sign Out Flow**
1. From any authenticated screen, trigger sign out
2. Verify user is redirected to login screen
3. Verify auth state is cleared
4. Try navigating back - should not be possible

### 7. Role-Based Access Control

**Test Case 7.1: Parent Route Protection**
1. Sign in as child user
2. Try to access parent routes (manually via deep links if possible)
3. Should be redirected to child home screen

**Test Case 7.2: Child Route Protection**
1. Sign in as parent user
2. Try to access child-specific routes
3. Should be redirected to parent home screen

### 8. Error Handling and Loading States

**Test Case 8.1: Network Connectivity**
1. Disable network connection
2. Try to sign in/register
3. Enable network
4. Retry operation
5. Verify appropriate error messages and recovery

**Test Case 8.2: Loading States**
1. Observe loading indicators during:
   - Sign in process
   - Registration process  
   - Role selection
   - Auth state restoration
2. Verify UI is disabled during loading
3. Check loading indicators are shown/hidden appropriately

### 9. Form Validation and UX

**Test Case 9.1: Password Visibility Toggle**
1. Enter password
2. Tap visibility icon
3. Verify password becomes visible
4. Tap again to hide

**Test Case 9.2: Error Message Display**
1. Trigger various validation errors
2. Verify error messages are displayed inline
3. Check that errors clear when user starts typing
4. Verify error styling and positioning

**Test Case 9.3: Form Submission**
1. Test "Enter" key on password field triggers sign-in
2. Verify form validation runs before submission
3. Check that multiple rapid taps don't cause issues

### 10. Firestore Integration

**Test Case 10.1: User Document Creation**
1. Register new user
2. Check Firestore console for user document
3. Verify document structure matches UserModel:
   ```json
   {
     "uid": "user-uid",
     "email": "user@example.com", 
     "displayName": "User Name",
     "role": "none",
     "createdAt": "timestamp",
     "updatedAt": "timestamp"
   }
   ```

**Test Case 10.2: Role Update**
1. Select role in app
2. Check Firestore document is updated
3. Verify `updatedAt` timestamp changes
4. Verify role field has correct enum value

**Test Case 10.3: Security Rules**
1. Try to access another user's document (using Firebase console)
2. Should be denied by security rules
3. Verify only authenticated user can read/write own document

## Performance Testing

### Memory and Performance
1. Monitor app memory usage during auth flows
2. Check for memory leaks after sign out
3. Verify smooth animations and transitions
4. Test on low-end devices for performance

### Network Optimization
1. Test with slow network connection
2. Verify reasonable timeout handling
3. Check offline behavior and recovery

## Security Testing

### Authentication Security
1. Verify passwords are not logged
2. Check that tokens are securely stored
3. Test session timeout behavior
4. Verify secure communication with Firebase

### Authorization Testing  
1. Test Firestore security rules manually
2. Verify role-based access controls
3. Check that client-side role checks are backed by server rules

## Automated Testing Setup

### Unit Tests
```bash
# Run unit tests
flutter test test/unit/
```

### Integration Tests  
```bash
# Run integration tests
flutter test integration_test/
```

### Widget Tests
```bash
# Test authentication widgets
flutter test test/widget/auth/
```

## Common Issues and Troubleshooting

### Firebase Configuration Issues
- **Problem**: Firebase not initialized
- **Solution**: Check `firebase_options.dart` and platform configuration files

### Authentication Errors
- **Problem**: Sign-in fails with unclear error
- **Solution**: Enable Firebase Auth debug logging and check console

### Navigation Issues  
- **Problem**: Wrong screen after auth
- **Solution**: Check router redirect logic and auth state providers

### Firestore Permission Errors
- **Problem**: User document access denied
- **Solution**: Verify security rules are deployed and user is authenticated

## Test Data Management

### Test Users
Create test accounts for different scenarios:
```
Parent User: parent@test.com / TestPass123
Child User: child@test.com / TestPass123  
No Role User: norole@test.com / TestPass123
```

### Cleanup
After testing:
1. Delete test user accounts from Firebase Auth
2. Remove test user documents from Firestore
3. Clear app data on test devices

## Reporting Issues

When reporting authentication issues, include:
1. Device type and OS version
2. Flutter version and dependencies
3. Firebase project configuration
4. Console logs and error messages
5. Steps to reproduce
6. Expected vs actual behavior

## Success Criteria

The authentication system passes testing when:
- ✅ All registration flows work correctly
- ✅ All sign-in flows work correctly  
- ✅ Role selection and persistence works
- ✅ Auth state restoration works after app restart
- ✅ Role-based routing works correctly
- ✅ Error handling is comprehensive and user-friendly
- ✅ Loading states are smooth and informative
- ✅ Firestore integration works securely
- ✅ Security rules protect user data
- ✅ Performance is acceptable on target devices