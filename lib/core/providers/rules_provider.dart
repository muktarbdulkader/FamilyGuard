import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/rule_model.dart';
import '../services/rules_service.dart';

/// Provider for rules service
final rulesServiceProvider = Provider<RulesService>((ref) {
  return RulesService();
});

/// Provider for all rules in a family
final familyRulesProvider = StreamProvider.family<List<RuleModel>, String>((ref, familyId) {
  final rulesService = ref.watch(rulesServiceProvider);
  return rulesService.getRulesForFamily(familyId);
});

/// Provider for rules of a specific child
final childRulesProvider = StreamProvider.family<List<RuleModel>, String>((ref, childId) {
  final rulesService = ref.watch(rulesServiceProvider);
  return rulesService.getRulesForChild(childId);
});

/// Provider for active rules of a specific child
final activeChildRulesProvider = StreamProvider.family<List<RuleModel>, String>((ref, childId) {
  final rulesService = ref.watch(rulesServiceProvider);
  return rulesService.getActiveRulesForChild(childId);
});

/// Provider for rules by type for a child
final rulesByTypeProvider = StreamProvider.family<List<RuleModel>, RuleTypeQuery>((ref, query) {
  final rulesService = ref.watch(rulesServiceProvider);
  return rulesService.getRulesByType(query.childId, query.ruleType);
});

/// Provider for enforcement logs of a child
final enforcementLogsProvider = StreamProvider.family<List<RuleEnforcementLog>, String>((ref, childId) {
  final rulesService = ref.watch(rulesServiceProvider);
  return rulesService.getEnforcementLogs(childId);
});

/// Provider for a single rule
final singleRuleProvider = FutureProvider.family<RuleModel?, String>((ref, ruleId) {
  final rulesService = ref.watch(rulesServiceProvider);
  return rulesService.getRule(ruleId);
});

/// Provider for checking if an app is allowed for a child
final appAllowanceProvider = FutureProvider.family<bool, AppAllowanceQuery>((ref, query) {
  final rulesService = ref.watch(rulesServiceProvider);
  return rulesService.isAppAllowed(query.childId, query.packageName);
});

/// Provider for remaining app time for a child
final remainingAppTimeProvider = FutureProvider.family<int?, AppTimeQuery>((ref, query) {
  final rulesService = ref.watch(rulesServiceProvider);
  return rulesService.getRemainingAppTime(query.childId, query.packageName, query.todayUsage);
});

/// Provider for enforcement statistics
final enforcementStatsProvider = FutureProvider.family<Map<String, int>, StatsQuery>((ref, query) {
  final rulesService = ref.watch(rulesServiceProvider);
  return rulesService.getEnforcementStats(query.childId, query.startDate, query.endDate);
});

/// Query classes for providers
class RuleTypeQuery {
  final String childId;
  final RuleType ruleType;

  const RuleTypeQuery({
    required this.childId,
    required this.ruleType,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RuleTypeQuery &&
        other.childId == childId &&
        other.ruleType == ruleType;
  }

  @override
  int get hashCode => childId.hashCode ^ ruleType.hashCode;
}

class AppAllowanceQuery {
  final String childId;
  final String packageName;

  const AppAllowanceQuery({
    required this.childId,
    required this.packageName,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppAllowanceQuery &&
        other.childId == childId &&
        other.packageName == packageName;
  }

  @override
  int get hashCode => childId.hashCode ^ packageName.hashCode;
}

class AppTimeQuery {
  final String childId;
  final String packageName;
  final int todayUsage;

  const AppTimeQuery({
    required this.childId,
    required this.packageName,
    required this.todayUsage,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppTimeQuery &&
        other.childId == childId &&
        other.packageName == packageName &&
        other.todayUsage == todayUsage;
  }

  @override
  int get hashCode => childId.hashCode ^ packageName.hashCode ^ todayUsage.hashCode;
}

class StatsQuery {
  final String childId;
  final DateTime startDate;
  final DateTime endDate;

  const StatsQuery({
    required this.childId,
    required this.startDate,
    required this.endDate,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is StatsQuery &&
        other.childId == childId &&
        other.startDate == startDate &&
        other.endDate == endDate;
  }

  @override
  int get hashCode => childId.hashCode ^ startDate.hashCode ^ endDate.hashCode;
}

/// Notifier for managing rules state
class RulesNotifier extends StateNotifier<AsyncValue<List<RuleModel>>> {
  RulesNotifier(this._rulesService) : super(const AsyncValue.loading());

  final RulesService _rulesService;

  /// Create a new rule
  Future<void> createRule(RuleModel rule) async {
    try {
      await _rulesService.createRule(rule);
      // The stream providers will automatically update
    } catch (e) {
      // Handle error - could emit to a separate error state if needed
      rethrow;
    }
  }

  /// Update an existing rule
  Future<void> updateRule(String ruleId, RuleModel rule) async {
    try {
      await _rulesService.updateRule(ruleId, rule);
      // The stream providers will automatically update
    } catch (e) {
      rethrow;
    }
  }

  /// Delete a rule
  Future<void> deleteRule(String ruleId) async {
    try {
      await _rulesService.deleteRule(ruleId);
      // The stream providers will automatically update
    } catch (e) {
      rethrow;
    }
  }

  /// Toggle rule status
  Future<void> toggleRuleStatus(String ruleId, RuleStatus status) async {
    try {
      await _rulesService.toggleRuleStatus(ruleId, status);
      // The stream providers will automatically update
    } catch (e) {
      rethrow;
    }
  }

  /// Log rule enforcement
  Future<void> logEnforcement(RuleEnforcementLog log) async {
    try {
      await _rulesService.logRuleEnforcement(log);
      // Enforcement logs are handled separately by stream providers
    } catch (e) {
      rethrow;
    }
  }

  /// Bulk update rules
  Future<void> bulkUpdateRules(Map<String, Map<String, dynamic>> updates) async {
    try {
      await _rulesService.bulkUpdateRules(updates);
    } catch (e) {
      rethrow;
    }
  }
}

/// Provider for rules notifier
final rulesNotifierProvider = StateNotifierProvider<RulesNotifier, AsyncValue<List<RuleModel>>>((ref) {
  final rulesService = ref.watch(rulesServiceProvider);
  return RulesNotifier(rulesService);
});

/// Helper providers for common rule filtering
final screenTimeRulesProvider = StreamProvider.family<List<RuleModel>, String>((ref, childId) {
  final rulesService = ref.watch(rulesServiceProvider);
  return rulesService.getRulesByType(childId, RuleType.screenTime);
});

final bedtimeRulesProvider = StreamProvider.family<List<RuleModel>, String>((ref, childId) {
  final rulesService = ref.watch(rulesServiceProvider);
  return rulesService.getRulesByType(childId, RuleType.bedtime);
});

final appLimitRulesProvider = StreamProvider.family<List<RuleModel>, String>((ref, childId) {
  final rulesService = ref.watch(rulesServiceProvider);
  return rulesService.getRulesByType(childId, RuleType.appLimit);
});

final appBlockRulesProvider = StreamProvider.family<List<RuleModel>, String>((ref, childId) {
  final rulesService = ref.watch(rulesServiceProvider);
  return rulesService.getRulesByType(childId, RuleType.appBlock);
});

final appScheduleRulesProvider = StreamProvider.family<List<RuleModel>, String>((ref, childId) {
  final rulesService = ref.watch(rulesServiceProvider);
  return rulesService.getRulesByType(childId, RuleType.appSchedule);
});

final appRequestRulesProvider = StreamProvider.family<List<RuleModel>, String>((ref, childId) {
  final rulesService = ref.watch(rulesServiceProvider);
  return rulesService.getRulesByType(childId, RuleType.appRequest);
});

/// Helper provider to get active rules count for a child
final activeRulesCountProvider = Provider.family<int, String>((ref, childId) {
  final rulesAsync = ref.watch(activeChildRulesProvider(childId));
  return rulesAsync.when(
    data: (rules) => rules.length,
    loading: () => 0,
    error: (_, __) => 0,
  );
});

/// Helper provider to check if child has any active rules
final hasActiveRulesProvider = Provider.family<bool, String>((ref, childId) {
  final count = ref.watch(activeRulesCountProvider(childId));
  return count > 0;
});

/// Provider to get rules that are about to expire (within 24 hours)
final expiringSoonRulesProvider = Provider.family<List<RuleModel>, String>((ref, childId) {
  final rulesAsync = ref.watch(activeChildRulesProvider(childId));
  return rulesAsync.when(
    data: (rules) {
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      return rules.where((rule) => 
        rule.expiresAt != null && 
        rule.expiresAt!.isBefore(tomorrow)
      ).toList();
    },
    loading: () => [],
    error: (_, __) => [],
  );
});