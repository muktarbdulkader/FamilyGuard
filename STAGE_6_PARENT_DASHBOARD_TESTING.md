# Stage 6: Parent Dashboard Testing Guide

## Overview

This testing guide covers the comprehensive parent dashboard implementation for Family Guardian, including family/child selection, app management, real-time rule updates, and offline synchronization.

## Prerequisites

### Test Environment Setup
1. **Firebase Project**: Properly configured with Firestore and Authentication
2. **Test Devices**: 
   - Parent device (Android/iOS) with Family Guardian installed
   - Child device (Android) with Family Guardian installed and apps discovered (Stage 5)
3. **Test Data**: Family created with parent and child accounts linked

### Sample Test Data Structure
```
Firestore Structure:
families/{familyId}/
├── name: "Test Family"
├── parentIds: [parentUserId]
├── childIds: [childUserId]
└── children/{childId}/
    └── apps/{packageName}/
        ├── packageName: "com.whatsapp"
        ├── name: "WhatsApp"
        ├── rule: "ask"
        ├── dailyLimitMinutes: null
        ├── allowedFrom: null
        ├── allowedUntil: null
        ├── detectedAt: Timestamp
        └── updatedAt: Timestamp
```

## Test Scenarios

### Test 1: Dashboard Navigation and Family Selection

#### Test 1.1: Initial Parent Login
```
Steps:
1. Fresh install Family Guardian on parent device
2. Complete authentication as Parent user
3. Navigate to parent dashboard

Expected Results:
✅ Professional parent dashboard loads
✅ Family Guardian branding and header visible
✅ Family selection section appears
✅ Welcome state shows feature cards
✅ Clean, professional UI design
```

#### Test 1.2: Family Selection - Single Family
```
Setup: Parent belongs to one family

Steps:
1. Dashboard loads with single family
2. Family should auto-select and show as card
3. Child selector should appear automatically

Expected Results:
✅ Family auto-selected and displayed as card
✅ Family card shows name, child count, creation date
✅ Child selector appears with family children
✅ No dropdown needed for single family
```

#### Test 1.3: Family Selection - Multiple Families
```
Setup: Parent belongs to multiple families

Steps:
1. Dashboard loads with multiple families
2. Family selector shows dropdown
3. Select different families

Expected Results:
✅ Dropdown shows all parent's families
✅ Each family shows name and child count
✅ Selecting family updates child list
✅ Previous child selection cleared on family change
```

### Test 2: Child Selection and Status

#### Test 2.1: Child Selection UI
```
Setup: Family with 2-3 children

Steps:
1. Select family with multiple children
2. Observe child selector layout
3. Select different children

Expected Results:
✅ Children displayed as cards (≤2 children) or dropdown (>2)
✅ Each child shows name, online status, device info
✅ Status colors: Green (online), Orange (recent), Grey (offline)
✅ Status text shows "Online", "5m ago", "2h ago", etc.
```

#### Test 2.2: Child Status Accuracy
```
Setup: Child device online/offline scenarios

Steps:
1. Child device online and active
2. Child device goes offline
3. Child device comes back online

Expected Results:
✅ Online status updates within 30 seconds
✅ Offline status shows accurate "last seen" time
✅ Status colors match online/offline state
✅ Device information displayed if available
```

### Test 3: App List and Search Functionality

#### Test 3.1: App List Display
```
Setup: Child with 10+ discovered apps

Steps:
1. Select family and child
2. Navigate to Apps tab
3. Scroll through app list

Expected Results:
✅ All child's available apps displayed
✅ Apps sorted alphabetically (blocked apps first)
✅ Each app shows: icon, name, package name, rule, usage
✅ App icons load properly (with fallback for missing icons)
✅ Professional card-based design
```

#### Test 3.2: Search Functionality
```
Steps:
1. Enter app name in search bar (e.g., "WhatsApp")
2. Clear search and try package name (e.g., "com.whatsapp")
3. Search for partial matches
4. Clear search completely

Expected Results:
✅ Apps filter immediately as typing
✅ Search works for app names and package names
✅ Partial matches work correctly
✅ Clear button appears and works
✅ Empty search shows all apps
```

#### Test 3.3: Filter Functionality
```
Steps:
1. Apply "All Apps" filter (default)
2. Apply "Blocked" filter
3. Apply "Time Limited" filter
4. Apply specific rule filters (Allow, Ask Parent, etc.)
5. Combine search with filters

Expected Results:
✅ Filters show only matching apps
✅ Filter chips show selection state
✅ Only one filter active at a time
✅ Search works within filtered results
✅ Filter counts match actual app rules
```

### Test 4: App Rule Editor

#### Test 4.1: Rule Editor Access
```
Steps:
1. Tap any app in the list
2. App rule editor sheet should open
3. Verify current rule is pre-selected

Expected Results:
✅ Modal bottom sheet opens smoothly
✅ App icon, name, and current usage displayed
✅ Current rule pre-selected in radio buttons
✅ Professional sheet design with proper spacing
```

#### Test 4.2: Rule Changes - Basic Rules
```
Test each rule type:

Allow Rule:
1. Select "Always Allow" radio button
2. Tap "Save"
3. Verify app list updates immediately

Block Rule:
1. Select "Always Block" radio button
2. Tap "Save"
3. Verify app shows red blocked status

Ask Parent Rule:
1. Select "Ask Parent" radio button
2. Tap "Save"  
3. Verify app shows blue "Ask Parent" status

Expected Results:
✅ Rule changes save successfully
✅ UI updates immediately (optimistic updates)
✅ Success snackbar shows confirmation
✅ App list reflects new rule and colors
✅ Changes persist after app restart
```

#### Test 4.3: Time Limited Rule
```
Steps:
1. Select "Daily Time Limit" radio button
2. Time limit slider appears
3. Adjust slider to 60 minutes
4. Save rule
5. Verify time limit settings

Expected Results:
✅ Time limit slider appears with correct range (15-480 min)
✅ Slider shows current value label
✅ Saved time limit displays in app list
✅ Usage indicator appears for time-limited apps
✅ Rule persists and syncs to child device
```

#### Test 4.4: Time Restricted Rule
```
Steps:
1. Select "Allowed Time Window" radio button
2. Time picker controls appear
3. Set start time to 18:00
4. Set end time to 21:00
5. Save rule

Expected Results:
✅ Start and end time pickers work correctly
✅ Time window displays in 24-hour or 12-hour format
✅ Saved time window shows in app list
✅ Rule syncs to child device for enforcement
```

### Test 5: Real-time Updates and Synchronization

#### Test 5.1: Firestore Real-time Updates
```
Setup: Two parent devices with same family/child selected

Steps:
1. Parent Device A changes app rule
2. Observer Parent Device B immediately
3. Verify rule change appears without refresh

Expected Results:
✅ Rule changes appear on all parent devices instantly
✅ No manual refresh required
✅ UI updates smoothly without flicker
✅ Consistent state across all parent devices
```

#### Test 5.2: Child Device Synchronization
```
Setup: Parent changes rules, child device monitoring

Steps:
1. Parent blocks an app (e.g., TikTok)
2. Child device should receive rule update
3. Child tries to open blocked app
4. Verify enforcement works offline

Expected Results:
✅ Rule changes sync to child device within 30 seconds
✅ Child device enforces new rules immediately
✅ Enforcement works even when child device offline
✅ Rules cached locally for offline enforcement
```

### Test 6: Usage Data Display

#### Test 6.1: Today's Usage Display
```
Setup: Child has used various apps today

Steps:
1. View app list with usage data
2. Check usage display for different apps
3. Verify usage accuracy

Expected Results:
✅ Today's usage shown for each app
✅ Usage formatted properly (30m, 1h 15m, etc.)
✅ "Not used today" for unused apps
✅ Usage data updates periodically
```

#### Test 6.2: Time Limit Progress Indicators
```
Setup: Apps with daily time limits set

Steps:
1. Set 60-minute limit on YouTube
2. Child uses YouTube for 30 minutes
3. Check progress indicator on parent dashboard
4. Child continues using until limit exceeded

Expected Results:
✅ Progress bar shows 50% (30/60 minutes)
✅ Progress bar color: Green < 50%, Amber 50-80%, Orange 80-100%
✅ "30m left" text displayed
✅ Red color and "Limit exceeded" when over limit
```

### Test 7: Error Handling and Edge Cases

#### Test 7.1: Network Connectivity Issues
```
Steps:
1. Disable internet on parent device
2. Try to change app rules
3. Enable internet and retry

Expected Results:
✅ Appropriate error messages for network issues
✅ Rules queue for sync when connection restored
✅ UI shows loading/error states appropriately
✅ Retry mechanism works correctly
```

#### Test 7.2: Child Device Offline
```
Steps:
1. Child device offline
2. Parent changes app rules
3. Child device comes back online

Expected Results:
✅ Parent can still change rules (queued for sync)
✅ Rules sync when child device reconnects
✅ Child device enforces cached rules while offline
✅ No data loss or inconsistency
```

#### Test 7.3: Empty States
```
Test Scenarios:
- Family with no children
- Child with no apps discovered
- Search with no results
- All apps filtered out

Expected Results:
✅ Appropriate empty state messages
✅ Helpful actions provided (invite child, scan apps)
✅ Professional empty state design
✅ No crashes or blank screens
```

### Test 8: Performance and User Experience

#### Test 8.1: Loading Performance
```
Metrics to measure:
- Dashboard load time: < 3 seconds
- App list rendering: < 2 seconds for 50 apps
- Rule editor opening: < 500ms
- Search typing response: < 100ms
- Rule save response: < 1 second

Expected Results:
✅ All interactions feel responsive
✅ Loading indicators shown for > 500ms operations
✅ Smooth scrolling and animations
✅ No UI freezing during operations
```

#### Test 8.2: Memory Usage
```
Steps:
1. Monitor memory usage during normal operation
2. Navigate between families/children
3. Open/close rule editor multiple times
4. Leave dashboard open for 30 minutes

Expected Results:
✅ Memory usage stable over time
✅ No memory leaks from navigation
✅ App switcher shows reasonable memory usage
✅ No crash due to memory pressure
```

### Test 9: Cross-Platform Consistency

#### Test 9.1: Android vs iOS Parent Devices
```
If iOS version available:

Steps:
1. Test same operations on Android and iOS
2. Compare UI layout and behavior
3. Verify feature parity

Expected Results:
✅ Consistent functionality across platforms
✅ Platform-appropriate UI patterns
✅ Same data visible on both platforms
✅ Rule changes work identically
```

### Test 10: Security and Privacy

#### Test 10.1: Access Control
```
Steps:
1. Try to access another family's data
2. Verify parent can't see unrelated children
3. Check Firestore security rules enforcement

Expected Results:
✅ Parents can only access their own families
✅ No access to other families' app data
✅ Firestore security rules properly enforced
✅ No data leakage between families
```

#### Test 10.2: Data Privacy
```
Steps:
1. Review what data is collected and displayed
2. Verify only necessary app metadata shown
3. Check no sensitive app content exposed

Expected Results:
✅ Only app names, package names, and usage times shown
✅ No app content, messages, or private data
✅ Appropriate data collection for parental control
✅ Privacy-compliant implementation
```

## Automation and Testing Tools

### Unit Tests
```dart
// Example test for app filtering
testWidgets('App list filters work correctly', (tester) async {
  // Setup test apps with different rules
  final apps = [
    AppInfo.newDetection(packageName: 'com.blocked', name: 'Blocked App')
      .copyWith(rule: AppControlRule.block),
    AppInfo.newDetection(packageName: 'com.allowed', name: 'Allowed App')
      .copyWith(rule: AppControlRule.allow),
  ];
  
  // Build widget with test data
  await tester.pumpWidget(testWidget(apps: apps));
  
  // Test filter functionality
  await tester.tap(find.text('Blocked'));
  await tester.pumpAndSettle();
  
  expect(find.text('Blocked App'), findsOneWidget);
  expect(find.text('Allowed App'), findsNothing);
});
```

### Integration Tests
```dart
// Example test for rule saving
testWidgets('App rule changes persist', (tester) async {
  // Setup test environment with real Firestore
  await tester.pumpWidget(testApp());
  
  // Navigate to app and change rule
  await tester.tap(find.text('WhatsApp'));
  await tester.pumpAndSettle();
  
  await tester.tap(find.text('Always Block'));
  await tester.tap(find.text('Save'));
  await tester.pumpAndSettle();
  
  // Verify rule persisted
  expect(find.text('Blocked'), findsOneWidget);
  
  // Restart app and verify persistence
  await tester.pumpWidget(testApp());
  expect(find.text('Blocked'), findsOneWidget);
});
```

## Success Criteria

Stage 6 implementation passes when:

1. ✅ **Professional UI**: Clean, modern parent dashboard design
2. ✅ **Family Management**: Easy family and child selection
3. ✅ **App Discovery**: All child apps displayed with metadata
4. ✅ **Search/Filter**: Fast, accurate app filtering
5. ✅ **Rule Management**: Complete rule editor with all rule types
6. ✅ **Real-time Sync**: Instant updates across parent devices
7. ✅ **Child Enforcement**: Rules sync to child for offline enforcement
8. ✅ **Usage Display**: Accurate usage data and progress indicators
9. ✅ **Error Handling**: Graceful handling of network and error conditions
10. ✅ **Performance**: Responsive UI with good performance characteristics

The parent dashboard should provide a comprehensive, professional interface for managing all aspects of parental controls while maintaining excellent user experience and reliable synchronization with child devices.
## Testing the App Rule Editor

### Opening the Rule Editor
1. **From App Management Screen**:
   - Select a family → Select a child → Go to Apps tab
   - Tap on any app card
   - Verify the rule editor sheet slides up from bottom
   - Verify the current app icon, name, and package name display correctly

2. **Editor UI Elements**:
   - Verify all 5 rule types are displayed with proper icons and descriptions
   - Check that current rule is pre-selected
   - Verify rule-specific settings appear/disappear based on selection

### Testing Each Rule Type

#### 1. Always Allowed Rule
- Select "Always Allowed" rule type
- Tap "Save Rule"
- Verify rule saves successfully
- Verify snackbar shows success message
- Check that app card shows "Allowed" status

#### 2. Always Blocked Rule
- Select "Always Blocked" rule type
- Tap "Save Rule"
- Verify rule saves and app shows "Blocked" status

#### 3. Ask Parent Rule
- Select "Ask Parent" rule type
- Tap "Save Rule"
- Verify rule saves and app shows "Ask Parent" status

#### 4. Daily Time Limit Rule
- Select "Daily Time Limit" rule type
- Verify time limit slider appears
- Test slider functionality (5 minutes to 8 hours range)
- Set a specific time limit (e.g., 2 hours)
- Tap "Save Rule"
- Verify rule saves with correct time limit

#### 5. Time Window Rule
- Select "Allowed Time Window" rule type
- Verify start/end time pickers appear
- Tap on "Start Time" field
- Select a start time (e.g., 9:00 AM)
- Tap on "End Time" field  
- Select an end time (e.g., 5:00 PM)
- Tap "Save Rule"
- Verify rule saves with correct time window

### Error Handling
1. **Network Errors**:
   - Disconnect internet during rule save
   - Verify error snackbar appears with retry option
   - Verify loading state shows during save attempt

2. **Invalid Rules**:
   - Test time window with end time before start time
   - Verify appropriate validation (if implemented)

3. **Sheet Dismissal**:
   - Tap "Cancel" button - verify sheet closes without saving
   - Tap outside sheet area - verify sheet closes
   - Swipe down on sheet - verify sheet closes

### Real-time Updates
1. **Multi-Device Testing**:
   - Open app management on two parent devices
   - Update a rule on device 1
   - Verify rule update appears on device 2 immediately
   - Test with different rule types

2. **Child Device Sync**:
   - Update rule on parent device
   - Check child device receives rule update
   - Verify rule enforcement begins immediately (if child enforcement is implemented)

### Performance Testing
1. **Large App Lists**:
   - Test rule editor with 100+ installed apps
   - Verify sheet opens quickly for any app
   - Test multiple rapid rule changes

2. **Concurrent Updates**:
   - Have multiple parents update different app rules simultaneously
   - Verify no conflicts or data loss occurs