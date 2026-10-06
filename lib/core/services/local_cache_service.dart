import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_model.dart';

/// Local cache service for offline app rule enforcement
/// Stores app rules locally for when child device is offline
class LocalCacheService {
  static const String _appRulesKey = 'cached_app_rules';
  static const String _lastSyncKey = 'last_rules_sync';
  static const String _childIdKey = 'cached_child_id';
  
  late final SharedPreferences _prefs;
  bool _initialized = false;

  /// Initialize the local cache
  Future<void> initialize() async {
    if (_initialized) return;
    _prefs = await SharedPreferences.getInstance();
    _initialized = true;
  }

  /// Cache app rules locally for offline enforcement
  Future<void> cacheAppRules({
    required String childId,
    required List<AppModel> apps,
  }) async {
    await initialize();
    
    final appRulesMap = {
      for (final app in apps) app.packageName: app.toJson()
    };
    
    await _prefs.setString(_appRulesKey, jsonEncode(appRulesMap));
    await _prefs.setString(_childIdKey, childId);
    await _prefs.setInt(_lastSyncKey, DateTime.now().millisecondsSinceEpoch);
  }

  /// Get cached app rules for offline enforcement
  Future<List<AppModel>> getCachedAppRules() async {
    await initialize();
    
    final cachedData = _prefs.getString(_appRulesKey);
    if (cachedData == null) return [];
    
    try {
      final Map<String, dynamic> rulesMap = jsonDecode(cachedData);
      return rulesMap.values
          .map((appData) => AppModel.fromJson(appData))
          .toList();
    } catch (e) {
      // Clear corrupted cache
      await clearCache();
      return [];
    }
  }

  /// Get specific app rule from cache
  Future<AppModel?> getCachedAppRule(String packageName) async {
    await initialize();
    
    final cachedData = _prefs.getString(_appRulesKey);
    if (cachedData == null) return null;
    
    try {
      final Map<String, dynamic> rulesMap = jsonDecode(cachedData);
      final appData = rulesMap[packageName];
      return appData != null ? AppModel.fromJson(appData) : null;
    } catch (e) {
      return null;
    }
  }

  /// Update specific app rule in cache
  Future<void> updateCachedAppRule(AppModel app) async {
    await initialize();
    
    final cachedData = _prefs.getString(_appRulesKey);
    if (cachedData == null) return;
    
    try {
      final Map<String, dynamic> rulesMap = jsonDecode(cachedData);
      rulesMap[app.packageName] = app.toJson();
      
      await _prefs.setString(_appRulesKey, jsonEncode(rulesMap));
    } catch (e) {
      // Ignore cache update errors
    }
  }

  /// Get last sync timestamp
  Future<DateTime?> getLastSyncTime() async {
    await initialize();
    
    final timestamp = _prefs.getInt(_lastSyncKey);
    return timestamp != null 
        ? DateTime.fromMillisecondsSinceEpoch(timestamp)
        : null;
  }

  /// Get cached child ID
  Future<String?> getCachedChildId() async {
    await initialize();
    return _prefs.getString(_childIdKey);
  }

  /// Check if cache is stale (older than 1 hour)
  Future<bool> isCacheStale() async {
    final lastSync = await getLastSyncTime();
    if (lastSync == null) return true;
    
    final hoursSinceSync = DateTime.now().difference(lastSync).inHours;
    return hoursSinceSync > 1;
  }

  /// Store app usage locally for sync when online
  Future<void> cacheAppUsage(String packageName, int usageMinutes) async {
    await initialize();
    
    const usageKey = 'pending_usage';
    final existingData = _prefs.getString(usageKey) ?? '{}';
    
    try {
      final Map<String, dynamic> usageMap = jsonDecode(existingData);
      usageMap[packageName] = {
        'usageMinutes': usageMinutes,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      
      await _prefs.setString(usageKey, jsonEncode(usageMap));
    } catch (e) {
      // Create new usage cache if corrupted
      final newUsage = {
        packageName: {
          'usageMinutes': usageMinutes,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        }
      };
      await _prefs.setString(usageKey, jsonEncode(newUsage));
    }
  }

  /// Get pending usage data for sync
  Future<Map<String, int>> getPendingUsage() async {
    await initialize();
    
    const usageKey = 'pending_usage';
    final usageData = _prefs.getString(usageKey);
    if (usageData == null) return {};
    
    try {
      final Map<String, dynamic> usageMap = jsonDecode(usageData);
      final result = <String, int>{};
      
      for (final entry in usageMap.entries) {
        final data = entry.value as Map<String, dynamic>;
        result[entry.key] = data['usageMinutes'] ?? 0;
      }
      
      return result;
    } catch (e) {
      return {};
    }
  }

  /// Clear pending usage after successful sync
  Future<void> clearPendingUsage() async {
    await initialize();
    await _prefs.remove('pending_usage');
  }

  /// Clear all cache data
  Future<void> clearCache() async {
    await initialize();
    await _prefs.remove(_appRulesKey);
    await _prefs.remove(_lastSyncKey);
    await _prefs.remove(_childIdKey);
    await _prefs.remove('pending_usage');
  }

  /// Get cache status information
  Future<Map<String, dynamic>> getCacheStatus() async {
    final lastSync = await getLastSyncTime();
    final childId = await getCachedChildId();
    final cachedRules = await getCachedAppRules();
    final isStale = await isCacheStale();
    
    return {
      'hasCache': cachedRules.isNotEmpty,
      'ruleCount': cachedRules.length,
      'lastSync': lastSync?.toIso8601String(),
      'childId': childId,
      'isStale': isStale,
    };
  }
}