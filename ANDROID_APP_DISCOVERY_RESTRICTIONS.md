# Android App Discovery Restrictions & Implementation Strategy

## Android System Limitations

### Package Visibility Changes (Android 11+)
**Scoped Storage and Package Visibility:**
- Android 11 (API 30+) introduced package visibility restrictions
- Apps can only see a limited set of installed packages by default
- Family Guardian needs `<queries>` declarations in AndroidManifest.xml
- Cannot enumerate all packages without proper queries configuration

### App Installation/Removal Detection Limitations

**Real-time Detection Challenges:**
1. **PACKAGE_ADDED/PACKAGE_REMOVED Broadcasts:**
   - Only received when your app is running (foreground/background service)
   - Not received when app is completely stopped
   - May be delayed or batched by system

2. **No Reliable Background Detection:**
   - Cannot run continuous background scanning (battery/performance restrictions)
   - System may kill background processes
   - Doze mode and App Standby can prevent background operations

3. **Permission Requirements:**
   - No special permissions required for reading installed packages (with proper queries)
   - QUERY_ALL_PACKAGES permission exists but not available for most apps on Play Store
   - Must rely on periodic scanning rather than real-time detection

### Android Version Differences

**Android 6.0-10 (API 23-29):**
- `PackageManager.getInstalledPackages()` returns most user apps
- Fewer restrictions on package visibility
- More reliable background detection

**Android 11+ (API 30+):**
- Package visibility restrictions enforced
- Need `<queries>` declarations for specific packages/intents
- `<package android:name="*" />` query allows seeing user-installed apps

**Android 13+ (API 33+):**
- Additional privacy restrictions
- Improved notification permissions
- More aggressive background task limitations

## Implementation Strategy

### Efficient App Discovery Approach

**1. Periodic Scanning (Primary Method):**
```kotlin
// Scan every 30 minutes when app is active
// Scan on app startup
// Scan when returning from background
```

**2. Broadcast Receiver (Secondary):**
```kotlin
// Listen for PACKAGE_ADDED/PACKAGE_REMOVED
// Only works when service/app is running
// Provides immediate detection when possible
```

**3. Smart Caching:**
```kotlin
// Cache last known app list locally
// Compare with current scan to detect changes
// Minimize Firestore writes
```

### App Filtering Strategy

**Include User Apps:**
- Apps installed from Google Play Store
- Sideloaded APKs (user-installed)
- Apps that can be launched by user
- Apps with LAUNCHER intent

**Exclude System Apps:**
- Pre-installed system applications
- System services and hidden packages
- Apps without user-facing interfaces
- Testing/debugging applications

**Filtering Criteria:**
```kotlin
private fun isUserApp(packageInfo: PackageInfo): Boolean {
    // Check if app has launcher activity
    val hasLauncherActivity = hasLauncherActivity(packageInfo.packageName)
    
    // Check if it's a system app
    val isSystemApp = (packageInfo.applicationInfo.flags and ApplicationInfo.FLAG_SYSTEM) != 0
    
    // Include if: has launcher AND (not system OR user-installed system app)
    return hasLauncherActivity && (!isSystemApp || isUserInstalledSystemApp(packageInfo))
}
```

## Privacy and Security Considerations

### Data Collection Limits
**What We Collect:**
- Package name (e.g., "com.whatsapp")
- App display name (e.g., "WhatsApp")
- Icon (if available and appropriate)
- Installation/detection timestamps
- Enabled/disabled state

**What We DON'T Collect:**
- App data or content
- User activity within apps (separate feature)
- Private app information
- App permissions or configurations
- Internal app state

### Compliance Requirements
- **COPPA Compliance:** No private data collection from child apps
- **GDPR Compliance:** Minimal data collection, clear purpose
- **Google Play Policies:** Only parental control appropriate data
- **Transparency:** Clear to users what is being monitored

## Technical Implementation Plan

### Phase 1: Basic App Discovery
1. Native Kotlin app scanner service
2. PackageManager integration with proper filtering
3. Local SQLite caching for performance
4. Basic Firestore synchronization

### Phase 2: Change Detection
1. Broadcast receiver for real-time detection (when possible)
2. Periodic background scanning (respecting battery optimization)
3. Smart diffing algorithm to detect changes
4. Event generation for new/removed apps

### Phase 3: Parent Notification System
1. Firebase Cloud Messaging for new app alerts
2. Configurable notification preferences
3. Batch notifications to avoid spam
4. Historical app installation tracking

### Phase 4: Advanced Features
1. App categorization (social, games, education, etc.)
2. Age-appropriate app suggestions
3. Bulk app management for parents
4. Usage correlation with installed apps

## Performance Optimization

### Minimize Battery Impact
- Use JobScheduler for periodic scans
- Respect doze mode and app standby
- Cache results to avoid repeated expensive operations
- Batch network operations

### Minimize Storage Impact  
- Compress app icons appropriately
- Use efficient data structures
- Clean up old/unused data periodically
- Implement proper database indexing

### Minimize Network Impact
- Batch Firestore updates
- Use Firestore offline capabilities
- Implement retry logic with exponential backoff
- Compress data where possible

## Testing Strategy

### Real Device Testing Requirements
1. **Multiple Android Versions:** Test on Android 8, 10, 11, 12, 13, 14
2. **Different Manufacturers:** Samsung, Google Pixel, OnePlus, etc.
3. **Various Apps:** Install/uninstall popular apps during testing
4. **Battery Scenarios:** Test during doze mode, low battery, etc.
5. **Network Scenarios:** Test offline/online sync behavior

### Test Scenarios
1. **Initial App Discovery:** Fresh device setup
2. **App Installation:** Install new app, verify detection
3. **App Removal:** Uninstall app, verify marking as unavailable
4. **System Updates:** Android system updates affecting package list
5. **App Updates:** App version updates (should not create duplicates)
6. **Permissions Revoked:** Package visibility permission issues

## Expected Limitations

### What Will Work Well
- Detection of newly installed user apps (within 30 minutes)
- Accurate list of currently installed user applications
- App metadata collection (name, icon, package)
- Parent notifications for significant app changes

### What Has Limitations
- **Instant Detection:** May have 5-30 minute delay depending on system state
- **Background Detection:** Limited when app is force-stopped or in deep sleep
- **System Apps:** May miss some system app changes (acceptable for parental control)
- **Network Dependency:** Firestore sync requires internet connectivity

### Acceptable Trade-offs
- Periodic scanning vs real-time detection (battery life)
- Some detection delay vs system resource usage
- User app focus vs complete package enumeration
- Privacy protection vs comprehensive monitoring

This implementation strategy balances Android system limitations with parental control requirements while maintaining compliance with privacy regulations and platform policies.