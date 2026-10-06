# Stage 4: Real Device Testing Instructions
## Android Permission Management & Foreground Service

This document provides step-by-step instructions for testing the Android permission management system and monitoring service on real devices.

## Prerequisites

### Development Environment
```bash
# Ensure Flutter is properly configured
flutter doctor

# Build and install on Android device
flutter run --release
# OR
flutter build apk --release
adb install build/app/outputs/flutter-apk/app-release.apk
```

### Test Devices Required
- **Primary Test Device**: Android 8.0+ (API 26+) for basic functionality
- **Secondary Test Device**: Android 14+ (API 34+) for latest features
- **Minimum Requirements**: Android 6.0+ (API 23+) for app compatibility

### Pre-Test Device Setup
1. Enable **Developer Options** and **USB Debugging**
2. Install the Family Guardian APK
3. Ensure device is connected to internet
4. Clear any previous app data: `Settings > Apps > Family Guardian > Storage > Clear Data`

## Test Scenarios

### Test 1: Initial Permission Onboarding (Child User)

#### Setup
1. Launch app fresh install
2. Complete authentication as **Child** user
3. Navigate to permission onboarding screen

#### Test Steps
**Step 1.1: Notifications Permission**
```
Expected Flow:
1. User sees "Notifications" permission page
2. Explanation shows: "Family Guardian needs to send you notifications about..."
3. Permission status shows "Not Granted" 
4. Tap "Grant Permission" button
5. Android permission dialog appears (Android 13+)
6. Grant permission
7. Status changes to "Granted" with green checkmark
8. "Next" button becomes active
```

**Step 1.2: Location Permission**
```
Expected Flow:
1. User sees "Location Sharing" permission page
2. Clear explanation of safety benefits
3. Tap "Grant Permission"
4. Android location permission dialog appears
5. Select "While using the app" or "Allow all the time"
6. Status updates to "Granted"
```

**Step 1.3: Usage Access Permission (Manual Setup)**
```
Expected Flow:
1. User sees "App Usage Monitoring" page
2. Shows "This permission requires manual approval" warning
3. Status shows "Not Granted"
4. Tap "Open Settings" button
5. Android Settings > Usage Access screen opens
6. Find "Family Guardian" in the list
7. Toggle ON the permission
8. Return to app using back button
9. Status automatically updates to "Granted" (within 2 seconds)
```

**Step 1.4: Overlay Permission (Manual Setup)**
```
Expected Flow:
1. User sees "App Blocking" permission page
2. Shows manual setup warning
3. Tap "Open Settings"
4. Android Settings > Display over other apps screen opens
5. Find "Family Guardian" and tap
6. Toggle "Allow display over other apps" ON
7. Return to app
8. Status automatically updates to "Granted"
```

**Step 1.5: Battery Optimization (Optional)**
```
Expected Flow:
1. User sees "Battery Optimization" page
2. Shows "Optional but recommended" badge
3. Tap "Open Settings" 
4. Android battery optimization screen opens
5. Select "Don't optimize" or "Allow"
6. Return to app
7. Status updates accordingly
8. User can continue even if not granted (optional permission)
```

**Step 1.6: Completion**
```
Expected Flow:
1. Final "Setup Complete!" page shows
2. Lists all granted permissions
3. Tap "Complete Setup"
4. Persistent notification appears: "Family Guardian Active - Parental controls are monitoring this device"
5. Navigate to child home screen
6. Notification remains visible in status bar
```

#### Expected Results
- ✅ All required permissions granted through proper Android APIs
- ✅ No bypassing of Android security mechanisms  
- ✅ Clear explanations for each permission
- ✅ Real-time status updates during setup
- ✅ Persistent monitoring notification created
- ✅ Service survives app closure

### Test 2: Permission Status Detection

#### Test Steps
**Real-Time Status Monitoring**
```
Test Sequence:
1. Complete onboarding with all permissions granted
2. Open Android Settings > Apps > Family Guardian > Permissions
3. Revoke notification permission
4. Return to Family Guardian app
5. Navigate to monitoring status screen
6. Verify status shows "Partially Active" within 5 seconds
7. Permission details show notifications as "Not Granted"
8. Tap "Fix Permissions" to return to onboarding
```

**Usage Access Status Check**
```
Test Sequence:
1. Go to Settings > Apps > Special access > Usage access
2. Turn OFF Family Guardian permission
3. Return to Family Guardian app
4. Status should automatically update to show Usage Access as denied
5. Tap settings button to re-enable
```

**Overlay Permission Check**
```
Test Sequence:
1. Go to Settings > Apps > Special access > Display over other apps
2. Find Family Guardian and disable
3. Return to app
4. Status updates automatically
5. Test re-enabling process
```

#### Expected Results
- ✅ Status updates within 2-5 seconds of permission changes
- ✅ No app restart required for status detection
- ✅ Accurate detection of all permission types
- ✅ Proper handling of permission revocation

### Test 3: Foreground Service & Notification

#### Test Steps
**Service Persistence**
```
Test Sequence:
1. Complete onboarding (monitoring service should start)
2. Verify persistent notification appears:
   - Title: "Family Guardian Active"
   - Text: "Parental controls are monitoring this device"
   - Cannot be dismissed by swiping
   - Low priority (no sound/vibration)
3. Force close Family Guardian app
4. Verify notification remains visible
5. Restart device
6. Verify notification reappears after boot (may take 30-60 seconds)
```

**Notification Actions**
```
Test Sequence:
1. Long press on monitoring notification
2. Should show notification details
3. Tap notification
4. Should open Family Guardian app
5. Tap "View Status" action (if visible)
6. Should navigate to monitoring status screen
```

**Service Management**
```
Test Sequence:
1. Open Family Guardian as child user
2. Navigate to settings/status screen
3. Look for "Stop Monitoring" option (should NOT be easily accessible)
4. Verify monitoring cannot be easily disabled by child
5. Test that service restarts after device reboot
```

#### Expected Results
- ✅ Notification is persistent and cannot be dismissed
- ✅ Service survives app termination
- ✅ Service restarts automatically after device reboot
- ✅ Notification clearly identifies monitoring is active
- ✅ No way for child to easily disable monitoring

### Test 4: Android Version Compatibility

#### Android 14+ Specific Tests (API 34+)
```
Additional Requirements:
- Foreground service uses "specialUse" type
- Special use case declared in manifest
- Should not trigger additional restrictions

Test Steps:
1. Install on Android 14+ device
2. Complete permission setup
3. Verify foreground service starts successfully
4. Check no additional system warnings about service
5. Verify service survives 24+ hours of running
```

#### Android 8.0-13 Tests (API 26-33)
```
Test Steps:
1. Install on various Android versions
2. Verify notification channel creation works
3. Test foreground service behavior
4. Ensure no compatibility issues
```

#### Android 6.0-7.1 Tests (API 23-25)
```
Test Steps:
1. Install on older device
2. Verify permissions that don't require user action work correctly
3. Test overlay permission (should be auto-granted)
4. Verify app doesn't crash on unsupported APIs
```

#### Expected Results
- ✅ App works on Android 6.0+ without crashes
- ✅ Appropriate permission handling for each Android version
- ✅ No deprecated API usage warnings
- ✅ Proper fallbacks for unsupported features

### Test 5: Security & Compliance

#### Permission Legitimacy Check
```
Verification Points:
1. ✅ No accessibility service requested or used
2. ✅ All permissions have clear justifications
3. ✅ No hidden functionality or data collection
4. ✅ Transparent monitoring notification always visible
5. ✅ Settings pages are genuine Android settings (not fake overlays)
```

#### Data Protection
```
Test Points:
1. Verify app doesn't request excessive permissions
2. Check no sensitive data is collected without disclosure
3. Ensure monitoring is transparent to user
4. Verify no background data transmission without user knowledge
```

#### Expected Results
- ✅ Only legitimate parental control permissions requested
- ✅ No accessibility service used
- ✅ All data collection is transparent
- ✅ Complies with Google Play policies for parental control apps

### Test 6: Error Handling & Edge Cases

#### Network Connectivity
```
Test Scenarios:
1. Start onboarding with no internet connection
2. Lose internet during permission setup
3. Regain internet and continue
4. Verify Firebase authentication still works
```

#### Battery Optimization
```
Test Cases:
1. Device enters battery saver mode
2. App is force-stopped by system
3. Service should restart when app is reopened
4. Notification should reappear
```

#### Storage & Memory
```
Test Cases:
1. Low storage space during installation
2. Low memory during service operation
3. App data clearing while service is running
4. Service behavior during memory pressure
```

#### Expected Results
- ✅ Graceful handling of network issues
- ✅ Service recovers from system interruptions
- ✅ No crashes or data corruption
- ✅ User-friendly error messages

## Debugging & Troubleshooting

### ADB Commands for Testing
```bash
# Check if service is running
adb shell dumpsys activity services | grep -i family

# Check notification channels
adb shell dumpsys notification | grep -i family

# Check app permissions
adb shell dumpsys package com.example.flutter_study_app | grep -i permission

# Simulate device reboot
adb shell reboot

# Check logs for service startup
adb logcat | grep -i FamilyGuardian
```

### Common Issues and Solutions

**Issue: Notification doesn't appear**
```
Diagnosis:
1. Check notification permission is granted
2. Verify notification channel is created
3. Check foreground service is starting
4. Review Android logs for errors

Solution:
- Ensure targetSdkVersion is appropriate
- Check notification channel creation code
- Verify foreground service is properly declared in manifest
```

**Issue: Permission status not updating**
```
Diagnosis:
1. Check if status check timer is running
2. Verify platform channel methods work
3. Test manual refresh functionality

Solution:
- Check Timer.periodic is not cancelled
- Test platform channel connectivity
- Add manual refresh button for testing
```

**Issue: Service doesn't restart after reboot**
```
Diagnosis:
1. Check BOOT_COMPLETED receiver is registered
2. Verify receiver has proper permissions
3. Check if conditions for service start are met

Solution:
- Ensure boot receiver is in manifest
- Check shared preferences state
- Test with different Android versions
```

## Test Report Template

### Device Information
```
Device Model: ____________________
Android Version: _________________
API Level: ______________________
Security Patch Level: ____________
RAM: ____________________________
Storage: ________________________
```

### Test Results Checklist
```
Permission Onboarding:
□ Notifications permission flow works
□ Location permission flow works  
□ Usage Access settings opens correctly
□ Overlay permission settings opens correctly
□ Battery optimization settings opens correctly
□ Real-time status updates work
□ All explanations are clear and helpful

Monitoring Service:
□ Foreground service starts after onboarding
□ Persistent notification appears
□ Notification cannot be dismissed
□ Service survives app closure
□ Service restarts after device reboot
□ Notification actions work correctly

Permission Detection:
□ Status updates automatically when permissions change
□ Manual permission revocation detected quickly
□ Re-granting permissions updates status
□ All permission types detected accurately

Error Handling:
□ Network issues handled gracefully
□ Low battery/memory scenarios work
□ Service recovery after interruption
□ User-friendly error messages

Compliance:
□ No accessibility service used
□ All permissions justified
□ Monitoring is transparent
□ No security bypasses attempted
```

### Issues Found
```
Issue: _________________________________
Steps to Reproduce: ____________________
Expected: ______________________________
Actual: ________________________________
Workaround: ____________________________
Priority: ______________________________
```

## Success Criteria

Stage 4 is successfully implemented when:

1. ✅ **Permission Onboarding**: All required permissions can be granted through standard Android flows
2. ✅ **Real-time Detection**: Permission status changes are detected within 5 seconds
3. ✅ **Foreground Service**: Monitoring service runs persistently with transparent notification
4. ✅ **Boot Recovery**: Service automatically restarts after device reboot
5. ✅ **Multi-version Support**: Works correctly on Android 6.0 through 14+
6. ✅ **Security Compliance**: No security bypasses, accessibility service avoided
7. ✅ **User Experience**: Clear explanations, no confusing UI, transparent operation
8. ✅ **Error Handling**: Graceful handling of edge cases and system interruptions

The implementation should be ready for Google Play Store submission and comply with all parental control app policies.