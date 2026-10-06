# Stage 5: Real Device App Discovery Testing Guide

## Testing Overview

This guide provides comprehensive testing procedures for the Android app discovery system in Family Guardian. The system discovers, tracks, and synchronizes installed applications while respecting Android security restrictions.

## Prerequisites

### Test Environment Setup
```bash
# Build and install on test device
flutter run --release

# Enable USB debugging and development options
# Install ADB tools for debugging
adb devices
```

### Test Device Requirements
- **Primary**: Android 11+ device (package visibility restrictions)
- **Secondary**: Android 8-10 device (legacy behavior)
- **Minimum**: Android 6.0+ device (basic functionality)
- Real device required (emulators may not accurately simulate package management)

### Pre-Test Preparation
1. **Fresh App Installation**: Uninstall and reinstall Family Guardian
2. **Clear Data**: Settings > Apps > Family Guardian > Storage > Clear Data
3. **Test Apps Ready**: Have 3-5 apps ready to install/uninstall during testing
   - Popular apps: WhatsApp, Instagram, TikTok, YouTube
   - Small utility apps for quick install/uninstall
4. **Authentication**: Complete authentication as a **Child** user
5. **Permissions**: Complete all permission onboarding steps

## Test Scenarios

### Test 1: Initial App Discovery

#### Setup Phase
```
1. Complete Fresh installation of Family Guardian
2. Complete authentication as child user
3. Complete permission onboarding (especially Usage Access)
4. Ensure several user apps are already installed on device
```

#### Test Steps
**1.1 Trigger Initial Scan**
```
Expected Flow:
1. Navigate to child home screen
2. App discovery should trigger automatically
3. Loading indicator shows during scan
4. List of installed apps appears
5. Each app shows: name, package name, "Ask Parent" rule (default)
```

**1.2 Verify App Filtering**
```
Check app list includes:
✅ User-installed apps (WhatsApp, Instagram, games, etc.)
✅ Updated system apps (Chrome, Gmail if user-updated)

Check app list excludes:
❌ System services (Android System, SystemUI)
❌ Hidden packages (com.android.internal.*)
❌ Family Guardian itself
❌ Apps without launcher activities
❌ OEM system apps (Samsung Knox, etc.)
```

**1.3 App Metadata Verification**
```
For each discovered app verify:
✅ App name is human-readable (not package name)
✅ Package name is correct (com.whatsapp, com.instagram.android)
✅ Version information present
✅ Installation timestamps reasonable
✅ No system apps marked as user apps
```

**Expected Results:**
- 10-50 apps discovered (typical range for user devices)
- All apps have proper metadata
- Scan completes within 10 seconds
- No crashes or errors during discovery

### Test 2: Firestore Synchronization

#### Test Steps
**2.1 Initial Sync**
```
Test Flow:
1. Complete initial app discovery
2. Sync should trigger automatically for child users
3. Check Firebase Console > Firestore Database
4. Navigate to: families/{familyId}/children/{childId}/apps/
5. Verify documents created for each discovered app
```

**2.2 Document Structure Verification**
```
Each app document should contain:
{
  "packageName": "com.whatsapp",
  "name": "WhatsApp",
  "rule": "ask",
  "dailyLimitMinutes": null,
  "allowedFrom": null,
  "allowedUntil": null,
  "detectedAt": Timestamp,
  "updatedAt": Timestamp,
  "isAvailable": true,
  "iconBase64": null, // May be null initially
  "version": "2.23.24.1",
  "isSystemApp": false
}
```

**2.3 Sync Performance**
```
Measure and verify:
✅ Sync completes within 30 seconds for 50 apps
✅ No timeout errors
✅ No duplicate documents created
✅ All apps successfully written to Firestore
✅ Network usage reasonable (batch operations)
```

**Expected Results:**
- All discovered apps synced to Firestore
- Document structure matches specification
- No duplicate or corrupted data
- Sync completes without errors

### Test 3: Real-Time App Installation Detection

#### Test Steps
**3.1 Install New App (Immediate Detection)**
```
Test Sequence:
1. Family Guardian app is open and running
2. Install a new app from Play Store (e.g., Twitter)
3. Complete installation
4. Return to Family Guardian immediately
5. Check if new app appears in list automatically

Expected Timeline:
- Real-time detection: Within 10-30 seconds
- UI update: Immediate after detection
- Firestore sync: Within 60 seconds
```

**3.2 Install New App (Background Detection)**
```
Test Sequence:
1. Close Family Guardian app completely (swipe away)
2. Install new app from Play Store
3. Wait 1 minute
4. Reopen Family Guardian
5. Check if new app is detected

Expected Timeline:
- Detection on app restart: Immediate
- Full sync: Within 30 seconds
```

**3.3 App Installation Events**
```
Monitor for events:
1. Install app while Family Guardian running
2. Check app discovery event stream
3. Verify AppDiscoveryEvent.appInstalled event fired
4. Check event contains correct app metadata
5. Verify parent notification would be triggered
```

**Expected Results:**
- New apps detected within 30 seconds when app is running
- New apps detected on next app launch when not running
- Events properly generated for real-time notifications
- No missed installations during testing

### Test 4: App Removal Detection

#### Test Steps
**4.1 Uninstall App (Real-time)**
```
Test Sequence:
1. Family Guardian running in background
2. Uninstall existing app from device settings
3. Return to Family Guardian
4. Verify app marked as "unavailable" (not deleted)
5. Check app still visible but marked unavailable
```

**4.2 Historical Data Preservation**
```
Verification Steps:
1. Uninstall app that had usage rules/limits set
2. Check Firestore document still exists
3. Verify isAvailable = false
4. Verify usage history preserved
5. Check parent can still see app in dashboard
```

**4.3 Reinstallation Detection**
```
Test Sequence:
1. Uninstall app (should be marked unavailable)
2. Reinstall same app from Play Store
3. Verify app marked as available again
4. Check previous settings preserved
5. Verify AppDiscoveryEvent.appReinstalled fired
```

**Expected Results:**
- Uninstalled apps marked unavailable, not deleted
- Historical data preserved across uninstall/reinstall
- Reinstallation properly detected and updated
- Events generated for parent notification

### Test 5: App Update Detection

#### Test Steps
**5.1 App Update via Play Store**
```
Test Sequence:
1. Find app with available update in Play Store
2. Update the app
3. Return to Family Guardian
4. Verify app version updated in list
5. Check AppDiscoveryEvent.appUpdated event
```

**5.2 System App Updates**
```
Test Sequence:
1. Update system app (like Chrome or Gmail)
2. Check if app appears in user app list
3. Verify proper categorization
4. Check metadata correctness
```

**Expected Results:**
- App updates detected and version information updated
- No duplicate entries created for updated apps
- System app updates handled correctly
- Update events generated for notifications

### Test 6: Android Version Compatibility

#### Test on Android 11+ (Package Visibility)
```
Verification Points:
1. App discovery works with package visibility restrictions
2. Proper <queries> declaration allows app enumeration
3. No security warnings or permission issues
4. Performance acceptable despite restrictions
```

#### Test on Android 8-10 (Legacy API)
```
Verification Points:
1. Legacy getInstalledPackages() API works
2. Proper filtering of system vs user apps
3. No deprecated API warnings in production
4. Consistent behavior across versions
```

#### Test on Android 14+ (Latest)
```
Verification Points:
1. New API calls work correctly
2. Foreground service integration works
3. No new permission requirements
4. Performance optimized for latest version
```

**Expected Results:**
- Consistent functionality across Android versions
- No crashes or compatibility issues
- Proper API usage for each Android version
- No security violations or warnings

### Test 7: Performance and Battery Impact

#### Battery Usage Test
```
Test Procedure:
1. Install Family Guardian and complete setup
2. Use device normally for 24 hours
3. Check battery usage in Settings > Battery
4. Verify Family Guardian usage is reasonable

Acceptable Thresholds:
- Background battery usage: < 5% of total battery
- No high battery usage warnings
- No thermal throttling due to app
```

#### Memory Usage Test
```
Test Procedure:
1. Monitor app memory usage during scanning
2. Check for memory leaks after multiple scans
3. Verify clean up after app closure

Acceptable Thresholds:
- Peak memory usage during scan: < 100MB
- Steady state memory usage: < 50MB  
- No memory leaks over time
```

#### Network Usage Test
```
Test Procedure:
1. Monitor network usage during Firestore sync
2. Check data usage for app discovery
3. Verify efficient batch operations

Acceptable Thresholds:
- Initial sync of 50 apps: < 1MB data
- Periodic sync updates: < 100KB
- No excessive network polling
```

**Expected Results:**
- Minimal battery impact during normal operation
- Reasonable memory usage with proper cleanup
- Efficient network usage with batch operations
- No performance degradation over time

### Test 8: Error Handling and Edge Cases

#### Network Connectivity
```
Test Scenarios:
1. Start app with no internet connection
2. Discover apps locally (should work)
3. Enable internet and verify sync
4. Lose internet during sync (should gracefully fail)
5. Restore internet and retry sync
```

#### Storage Constraints
```
Test Scenarios:
1. Device with very low storage space
2. Install/uninstall apps with low storage
3. Verify app discovery still works
4. Check error handling for storage issues
```

#### App Permission Revocation
```
Test Scenarios:
1. Revoke Usage Access permission during operation
2. Verify app discovery gracefully handles
3. Re-grant permission and verify recovery
4. Test with partial permissions (location disabled)
```

#### Large App Inventory
```
Test Scenarios:
1. Device with 100+ apps installed
2. Verify scan performance remains acceptable
3. Check memory usage with large app lists
4. Verify Firestore batch operations handle large datasets
```

**Expected Results:**
- Graceful handling of network issues
- Appropriate error messages for user
- Recovery after permission/network restoration
- Acceptable performance with large app inventories

## Debug Tools and Commands

### ADB Commands for Testing
```bash
# List installed packages
adb shell pm list packages -3  # User packages only
adb shell pm list packages -s  # System packages only

# Install test APK
adb install app.apk

# Uninstall app
adb shell pm uninstall com.example.testapp

# Check app info
adb shell dumpsys package com.whatsapp

# Monitor package broadcasts
adb shell am monitor
```

### Firebase Console Verification
```bash
# Check Firestore structure
Navigate to: https://console.firebase.google.com/
Project > Firestore Database > Data tab
Path: families/{familyId}/children/{childId}/apps/

# Monitor real-time updates
Enable real-time listeners in console
Watch documents update during testing
```

### Flutter Debug Commands
```bash
# Run with debug logging
flutter run --debug --verbose

# Check method channel calls
flutter logs | grep AppDiscovery

# Monitor memory usage
flutter run --trace-systrace
```

## Common Issues and Solutions

### Issue: Apps Not Discovered
```
Possible Causes:
- Package visibility restrictions (Android 11+)
- Missing <queries> declarations in manifest
- Apps without launcher activities
- Permission denied errors

Solutions:
1. Check AndroidManifest.xml for proper <queries>
2. Verify apps have MAIN/LAUNCHER intents
3. Check device logs for permission errors
4. Test with different Android versions
```

### Issue: Sync Failures
```
Possible Causes:
- Network connectivity issues
- Firebase authentication problems
- Firestore security rules blocking writes
- Batch size too large

Solutions:
1. Check network connection stability
2. Verify user authentication state
3. Review Firestore security rules
4. Implement smaller batch sizes
```

### Issue: Real-time Detection Not Working
```
Possible Causes:
- App not running in background
- Broadcast receiver not registered
- Android system batching broadcasts
- Battery optimization killing service

Solutions:
1. Verify foreground service running
2. Check broadcast receiver registration
3. Test with battery optimization disabled
4. Add fallback periodic scanning
```

## Success Criteria

Stage 5 is successfully implemented when:

1. ✅ **App Discovery**: Accurately discovers 90%+ of user-installed apps
2. ✅ **Firestore Sync**: Successfully syncs app inventory to cloud storage
3. ✅ **Change Detection**: Detects app install/uninstall within 30 seconds when app is active
4. ✅ **Data Preservation**: Historical data preserved across app uninstall/reinstall
5. ✅ **Performance**: Minimal battery/memory impact during normal operation
6. ✅ **Compatibility**: Works correctly on Android 8.0 through latest version
7. ✅ **Error Handling**: Graceful handling of network, permission, and system errors
8. ✅ **Security Compliance**: No privacy violations or security bypasses

The implementation should provide reliable app inventory management for parental control while respecting Android system limitations and maintaining good performance characteristics.