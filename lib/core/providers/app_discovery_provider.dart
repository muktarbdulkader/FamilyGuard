import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/app_discovery_service.dart';
import '../models/app_info.dart';
import 'auth_provider.dart';

/// Provider for app discovery service instance
final appDiscoveryServiceProvider = Provider<AppDiscoveryService>((ref) {
  final service = AppDiscoveryService();
  ref.onDispose(() {
    service.dispose();
  });
  return service;
});

/// State notifier for managing discovered apps
class AppDiscoveryNotifier extends StateNotifier<AsyncValue<List<AppInfo>>> {
  AppDiscoveryNotifier(this.ref) : super(const AsyncValue.loading()) {
    _initialize();
  }

  final Ref ref;
  AppDiscoveryService? _service;
  
  /// Initialize the app discovery system
  Future<void> _initialize() async {
    try {
      _service = ref.read(appDiscoveryServiceProvider);
      await _service!.initialize();
      
      // Listen to app discovery events
      _service!.eventStream.listen((event) {
        _handleAppEvent(event);
      });
      
      // Perform initial scan
      await scanApps();
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  /// Scan for installed applications
  Future<void> scanApps() async {
    if (_service == null) return;
    
    try {
      state = const AsyncValue.loading();
      final apps = await _service!.scanInstalledApps();
      state = AsyncValue.data(apps);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  /// Detect changes in installed applications
  Future<List<AppDiscoveryEventInfo>> detectChanges() async {
    if (_service == null) return [];
    
    try {
      return await _service!.detectAppChanges();
    } catch (e) {
      return [];
    }
  }

  /// Synchronize apps with Firestore
  Future<void> synchronizeWithFirestore() async {
    if (_service == null) return;
    
    final user = ref.read(currentUserDataProvider).value;
    if (user == null || user.role.name != 'child') {
      return; // Only sync for child users
    }
    
    try {
      // Get family ID from user data or family provider
      final familyId = await _getFamilyId(user.uid);
      if (familyId != null) {
        await _service!.synchronizeWithFirestore(familyId, user.uid);
        
        // Refresh local state after sync
        await scanApps();
      }
    } catch (e) {
      // Log error but don't throw to avoid breaking UI
      print('Error synchronizing apps with Firestore: $e');
    }
  }

  /// Handle app discovery events
  void _handleAppEvent(AppDiscoveryEventInfo event) {
    state.whenData((apps) {
      final updatedApps = List<AppInfo>.from(apps);
      final existingIndex = updatedApps.indexWhere(
        (app) => app.packageName == event.appInfo.packageName,
      );
      
      switch (event.event) {
        case AppDiscoveryEvent.appInstalled:
        case AppDiscoveryEvent.appReinstalled:
          if (existingIndex == -1) {
            updatedApps.add(event.appInfo);
          } else {
            updatedApps[existingIndex] = event.appInfo;
          }
          break;
          
        case AppDiscoveryEvent.appUninstalled:
          if (existingIndex != -1) {
            updatedApps[existingIndex] = event.appInfo; // Mark as unavailable
          }
          break;
          
        case AppDiscoveryEvent.appUpdated:
          if (existingIndex != -1) {
            updatedApps[existingIndex] = event.appInfo;
          }
          break;
      }
      
      state = AsyncValue.data(updatedApps);
    });
  }

  /// Get family ID for current user
  Future<String?> _getFamilyId(String userId) async {
    try {
      // Query families collection to find family containing this user
      final familiesQuery = await FirebaseFirestore.instance
          .collection('families')
          .where('memberIds', arrayContains: userId)
          .limit(1)
          .get();
      
      if (familiesQuery.docs.isNotEmpty) {
        return familiesQuery.docs.first.id;
      }
      
      return null;
    } catch (e) {
      print('Error getting family ID: $e');
      return null;
    }
  }
}

/// Provider for app discovery state management
final appDiscoveryProvider = StateNotifierProvider<AppDiscoveryNotifier, AsyncValue<List<AppInfo>>>((ref) {
  return AppDiscoveryNotifier(ref);
});

/// Provider for getting app by package name
final appByPackageProvider = Provider.family<AppInfo?, String>((ref, packageName) {
  final appsAsync = ref.watch(appDiscoveryProvider);
  return appsAsync.whenOrNull(
    data: (apps) => apps.cast<AppInfo?>().firstWhere(
      (app) => app?.packageName == packageName,
      orElse: () => null,
    ),
  );
});

/// Provider for filtering apps by availability
final availableAppsProvider = Provider<AsyncValue<List<AppInfo>>>((ref) {
  final appsAsync = ref.watch(appDiscoveryProvider);
  return appsAsync.when(
    data: (apps) => AsyncValue.data(
      apps.where((app) => app.isAvailable).toList(),
    ),
    loading: () => const AsyncValue.loading(),
    error: (error, stack) => AsyncValue.error(error, stack),
  );
});

/// Provider for filtering apps by control rule
final appsByRuleProvider = Provider.family<AsyncValue<List<AppInfo>>, AppControlRule>((ref, rule) {
  final appsAsync = ref.watch(appDiscoveryProvider);
  return appsAsync.when(
    data: (apps) => AsyncValue.data(
      apps.where((app) => app.rule == rule && app.isAvailable).toList(),
    ),
    loading: () => const AsyncValue.loading(),
    error: (error, stack) => AsyncValue.error(error, stack),
  );
});

/// Provider for apps requiring parent approval
final appsRequiringApprovalProvider = Provider<AsyncValue<List<AppInfo>>>((ref) {
  return ref.watch(appsByRuleProvider(AppControlRule.ask));
});

/// Provider for blocked apps
final blockedAppsProvider = Provider<AsyncValue<List<AppInfo>>>((ref) {
  return ref.watch(appsByRuleProvider(AppControlRule.block));
});

/// Provider for apps with time restrictions
final timeRestrictedAppsProvider = Provider<AsyncValue<List<AppInfo>>>((ref) {
  final appsAsync = ref.watch(appDiscoveryProvider);
  return appsAsync.when(
    data: (apps) => AsyncValue.data(
      apps.where((app) => 
        app.isAvailable && 
        (app.rule == AppControlRule.timeRestricted || app.hasTimeRestrictions)
      ).toList(),
    ),
    loading: () => const AsyncValue.loading(),
    error: (error, stack) => AsyncValue.error(error, stack),
  );
});

/// Provider for apps with daily limits
final dailyLimitAppsProvider = Provider<AsyncValue<List<AppInfo>>>((ref) {
  final appsAsync = ref.watch(appDiscoveryProvider);
  return appsAsync.when(
    data: (apps) => AsyncValue.data(
      apps.where((app) => 
        app.isAvailable && 
        (app.rule == AppControlRule.timeLimited || app.hasDailyLimit)
      ).toList(),
    ),
    loading: () => const AsyncValue.loading(),
    error: (error, stack) => AsyncValue.error(error, stack),
  );
});

/// Provider for app discovery events stream
final appDiscoveryEventsProvider = StreamProvider<AppDiscoveryEventInfo>((ref) {
  final service = ref.watch(appDiscoveryServiceProvider);
  return service.eventStream;
});

/// Provider for syncing apps with Firestore
final appSyncProvider = FutureProvider<void>((ref) async {
  final notifier = ref.read(appDiscoveryProvider.notifier);
  await notifier.synchronizeWithFirestore();
});

/// Extension methods for app discovery provider
extension AppDiscoveryProviderExtension on WidgetRef {
  /// Trigger app scan
  Future<void> scanApps() async {
    await read(appDiscoveryProvider.notifier).scanApps();
  }
  
  /// Sync apps with Firestore
  Future<void> syncApps() async {
    await read(appDiscoveryProvider.notifier).synchronizeWithFirestore();
  }
  
  /// Detect app changes
  Future<List<AppDiscoveryEventInfo>> detectAppChanges() async {
    return await read(appDiscoveryProvider.notifier).detectChanges();
  }
}