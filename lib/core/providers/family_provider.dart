import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/family_model.dart';
import '../models/app_info.dart';
import 'auth_provider.dart';

/// Provider for user's families
final userFamiliesProvider = StreamProvider<List<FamilyModel>>((ref) {
  final user = ref.watch(currentUserDataProvider).value;
  if (user == null) {
    return Stream.value([]);
  }

  return FirebaseFirestore.instance
      .collection('families')
      .where('parentIds', arrayContains: user.uid)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => FamilyModel.fromFirestore(doc))
          .toList());
});

/// Provider for selected family
final selectedFamilyProvider = StateProvider<FamilyModel?>((ref) => null);

/// Provider for children in selected family
final familyChildrenProvider = StreamProvider<List<ChildModel>>((ref) {
  final family = ref.watch(selectedFamilyProvider);
  if (family == null) {
    return Stream.value([]);
  }

  return FirebaseFirestore.instance
      .collection('users')
      .where(FieldPath.documentId, whereIn: family.childIds.isEmpty ? [''] : family.childIds)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => ChildModel.fromFirestore(doc))
          .toList());
});

/// Provider for selected child
final selectedChildProvider = StateProvider<ChildModel?>((ref) => null);

/// Provider for child's apps with real-time updates
final childAppsProvider = StreamProvider.family<List<AppInfo>, String>((ref, childId) {
  final family = ref.watch(selectedFamilyProvider);
  if (family == null) {
    return Stream.value([]);
  }

  return FirebaseFirestore.instance
      .collection('families')
      .doc(family.id)
      .collection('children')
      .doc(childId)
      .collection('apps')
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => AppInfo.fromFirestore(doc))
          .where((app) => app.isAvailable) // Only show available apps
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name))); // Sort alphabetically
});

/// Provider for child's app usage data
final childAppUsageProvider = StreamProvider.family<Map<String, AppUsageModel>, String>((ref, childId) {
  final family = ref.watch(selectedFamilyProvider);
  if (family == null) {
    return Stream.value({});
  }

  return FirebaseFirestore.instance
      .collection('families')
      .doc(family.id)
      .collection('children')
      .doc(childId)
      .collection('usage')
      .snapshots()
      .map((snapshot) {
    final usageMap = <String, AppUsageModel>{};
    for (final doc in snapshot.docs) {
      final usage = AppUsageModel.fromFirestore(doc.data());
      usageMap[usage.packageName] = usage;
    }
    return usageMap;
  });
});

/// Provider for specific app with usage data
final appWithUsageProvider = Provider.family<AsyncValue<AppWithUsage?>, AppWithUsageParams>((ref, params) {
  final appsAsync = ref.watch(childAppsProvider(params.childId));
  final usageAsync = ref.watch(childAppUsageProvider(params.childId));

  return appsAsync.when(
    data: (apps) => usageAsync.when(
      data: (usageMap) {
        final app = apps.cast<AppInfo?>().firstWhere(
          (a) => a?.packageName == params.packageName,
          orElse: () => null,
        );
        
        if (app == null) return const AsyncValue.data(null);
        
        final usage = usageMap[params.packageName];
        return AsyncValue.data(AppWithUsage(app: app, usage: usage));
      },
      loading: () => const AsyncValue.loading(),
      error: (error, stack) => AsyncValue.error(error, stack),
    ),
    loading: () => const AsyncValue.loading(),
    error: (error, stack) => AsyncValue.error(error, stack),
  );
});

/// Service for managing app rules
class AppRuleService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Update app rule with optimistic UI updates
  Future<void> updateAppRule({
    required String familyId,
    required String childId,
    required String packageName,
    required AppControlRule rule,
    int? dailyLimitMinutes,
    String? allowedFrom,
    String? allowedUntil,
  }) async {
    final appRef = _firestore
        .collection('families')
        .doc(familyId)
        .collection('children')
        .doc(childId)
        .collection('apps')
        .doc(packageName);

    final updates = <String, dynamic>{
      'rule': rule.name,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    // Add rule-specific fields
    switch (rule) {
      case AppControlRule.timeLimited:
        updates['dailyLimitMinutes'] = dailyLimitMinutes;
        break;
      case AppControlRule.timeRestricted:
        updates['allowedFrom'] = allowedFrom;
        updates['allowedUntil'] = allowedUntil;
        break;
      default:
        // Clear time-related fields for other rules
        updates['dailyLimitMinutes'] = null;
        updates['allowedFrom'] = null;
        updates['allowedUntil'] = null;
        break;
    }

    await appRef.update(updates);
  }

  /// Batch update multiple app rules
  Future<void> batchUpdateAppRules({
    required String familyId,
    required String childId,
    required List<BatchAppRuleUpdate> updates,
  }) async {
    final batch = _firestore.batch();

    for (final update in updates) {
      final appRef = _firestore
          .collection('families')
          .doc(familyId)
          .collection('children')
          .doc(childId)
          .collection('apps')
          .doc(update.packageName);

      final data = <String, dynamic>{
        'rule': update.rule.name,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (update.dailyLimitMinutes != null) {
        data['dailyLimitMinutes'] = update.dailyLimitMinutes;
      }
      if (update.allowedFrom != null) {
        data['allowedFrom'] = update.allowedFrom;
      }
      if (update.allowedUntil != null) {
        data['allowedUntil'] = update.allowedUntil;
      }

      batch.update(appRef, data);
    }

    await batch.commit();
  }
}

/// Provider for app rule service
final appRuleServiceProvider = Provider<AppRuleService>((ref) => AppRuleService());

/// Combined app and usage data
class AppWithUsage {
  final AppInfo app;
  final AppUsageModel? usage;

  AppWithUsage({
    required this.app,
    this.usage,
  });

  /// Get today's usage in minutes
  int get todayMinutes => usage?.todayMinutes ?? 0;

  /// Get usage status for display
  String get usageStatusText => usage?.usageStatusText ?? 'Not used today';

  /// Get usage percentage for daily limit
  double get usagePercentage => usage?.getUsagePercentage(app.dailyLimitMinutes) ?? 0.0;

  /// Check if app is over daily limit
  bool get isOverLimit {
    if (app.dailyLimitMinutes == null) return false;
    return todayMinutes >= app.dailyLimitMinutes!;
  }

  /// Get status color based on usage and rules
  Color get statusColor {
    switch (app.rule) {
      case AppControlRule.allow:
        return const Color(0xFF4CAF50); // Green
      case AppControlRule.block:
        return const Color(0xFFF44336); // Red
      case AppControlRule.ask:
        return const Color(0xFF2196F3); // Blue
      case AppControlRule.timeLimited:
        return isOverLimit ? const Color(0xFFF44336) : const Color(0xFFFF9800); // Red if over limit, orange otherwise
      case AppControlRule.timeRestricted:
        return const Color(0xFF9C27B0); // Purple
    }
  }

  /// Get status text
  String get statusText {
    switch (app.rule) {
      case AppControlRule.allow:
        return 'Allowed';
      case AppControlRule.block:
        return 'Blocked';
      case AppControlRule.ask:
        return 'Ask Parent';
      case AppControlRule.timeLimited:
        if (app.dailyLimitMinutes != null) {
          return isOverLimit ? 'Limit Exceeded' : 'Limited (${app.dailyLimitMinutes}m)';
        }
        return 'Time Limited';
      case AppControlRule.timeRestricted:
        if (app.allowedFrom != null && app.allowedUntil != null) {
          return 'Allowed ${app.allowedFrom}–${app.allowedUntil}';
        }
        return 'Time Restricted';
    }
  }
}

/// Parameters for app with usage provider
class AppWithUsageParams {
  final String childId;
  final String packageName;

  AppWithUsageParams({
    required this.childId,
    required this.packageName,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppWithUsageParams &&
          runtimeType == other.runtimeType &&
          childId == other.childId &&
          packageName == other.packageName;

  @override
  int get hashCode => childId.hashCode ^ packageName.hashCode;
}

/// Batch app rule update data
class BatchAppRuleUpdate {
  final String packageName;
  final AppControlRule rule;
  final int? dailyLimitMinutes;
  final String? allowedFrom;
  final String? allowedUntil;

  BatchAppRuleUpdate({
    required this.packageName,
    required this.rule,
    this.dailyLimitMinutes,
    this.allowedFrom,
    this.allowedUntil,
  });
}