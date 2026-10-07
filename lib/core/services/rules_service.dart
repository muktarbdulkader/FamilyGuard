import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/rule_model.dart';

/// Service for managing parental control rules in Firebase
class RulesService {
  static final RulesService _instance = RulesService._internal();
  factory RulesService() => _instance;
  RulesService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Collection names
  static const String rulesCollection = 'rules';
  static const String enforcementLogsCollection = 'rule_enforcement_logs';

  /// Create a new rule
  Future<String> createRule(RuleModel rule) async {
    try {
      final docRef = await _firestore
          .collection(rulesCollection)
          .add(rule.toFirestore());
      
      if (kDebugMode) {
        print('Rule created with ID: ${docRef.id}');
      }
      
      return docRef.id;
    } catch (e) {
      if (kDebugMode) {
        print('Error creating rule: $e');
      }
      rethrow;
    }
  }

  /// Update an existing rule
  Future<void> updateRule(String ruleId, RuleModel rule) async {
    try {
      await _firestore
          .collection(rulesCollection)
          .doc(ruleId)
          .update(rule.toFirestore());
      
      if (kDebugMode) {
        print('Rule updated: $ruleId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error updating rule: $e');
      }
      rethrow;
    }
  }

  /// Delete a rule
  Future<void> deleteRule(String ruleId) async {
    try {
      await _firestore
          .collection(rulesCollection)
          .doc(ruleId)
          .delete();
      
      if (kDebugMode) {
        print('Rule deleted: $ruleId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error deleting rule: $e');
      }
      rethrow;
    }
  }

  /// Get a single rule by ID
  Future<RuleModel?> getRule(String ruleId) async {
    try {
      final doc = await _firestore
          .collection(rulesCollection)
          .doc(ruleId)
          .get();
      
      if (doc.exists) {
        return RuleModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting rule: $e');
      }
      return null;
    }
  }

  /// Get all rules for a specific child
  Stream<List<RuleModel>> getRulesForChild(String childId) {
    return _firestore
        .collection(rulesCollection)
        .where('childId', isEqualTo: childId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => RuleModel.fromFirestore(doc))
            .toList());
  }

  /// Get all rules for a family
  Stream<List<RuleModel>> getRulesForFamily(String familyId) {
    return _firestore
        .collection(rulesCollection)
        .where('familyId', isEqualTo: familyId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => RuleModel.fromFirestore(doc))
            .toList());
  }

  /// Get active rules for a child
  Stream<List<RuleModel>> getActiveRulesForChild(String childId) {
    return _firestore
        .collection(rulesCollection)
        .where('childId', isEqualTo: childId)
        .where('status', isEqualTo: RuleStatus.active.name)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => RuleModel.fromFirestore(doc))
            .where((rule) => rule.isActive)
            .toList());
  }

  /// Get rules by type for a child
  Stream<List<RuleModel>> getRulesByType(String childId, RuleType type) {
    return _firestore
        .collection(rulesCollection)
        .where('childId', isEqualTo: childId)
        .where('type', isEqualTo: type.name)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => RuleModel.fromFirestore(doc))
            .toList());
  }

  /// Get rules for a specific app
  Future<List<RuleModel>> getRulesForApp(String childId, String packageName) async {
    try {
      final snapshot = await _firestore
          .collection(rulesCollection)
          .where('childId', isEqualTo: childId)
          .where('appPackageName', isEqualTo: packageName)
          .where('status', isEqualTo: RuleStatus.active.name)
          .get();

      return snapshot.docs
          .map((doc) => RuleModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting rules for app: $e');
      }
      return [];
    }
  }

  /// Toggle rule status (active/paused)
  Future<void> toggleRuleStatus(String ruleId, RuleStatus status) async {
    try {
      await _firestore
          .collection(rulesCollection)
          .doc(ruleId)
          .update({
        'status': status.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      if (kDebugMode) {
        print('Rule status updated: $ruleId -> ${status.name}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error toggling rule status: $e');
      }
      rethrow;
    }
  }

  /// Bulk update rules
  Future<void> bulkUpdateRules(Map<String, Map<String, dynamic>> updates) async {
    try {
      final batch = _firestore.batch();
      
      for (final entry in updates.entries) {
        final ruleRef = _firestore.collection(rulesCollection).doc(entry.key);
        batch.update(ruleRef, {
          ...entry.value,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      
      await batch.commit();
      
      if (kDebugMode) {
        print('Bulk updated ${updates.length} rules');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error in bulk update: $e');
      }
      rethrow;
    }
  }

  /// Log rule enforcement
  Future<void> logRuleEnforcement(RuleEnforcementLog log) async {
    try {
      await _firestore
          .collection(enforcementLogsCollection)
          .add(log.toFirestore());
      
      if (kDebugMode) {
        print('Rule enforcement logged: ${log.action}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error logging rule enforcement: $e');
      }
    }
  }

  /// Get enforcement logs for a child
  Stream<List<RuleEnforcementLog>> getEnforcementLogs(String childId, {int limit = 50}) {
    return _firestore
        .collection(enforcementLogsCollection)
        .where('childId', isEqualTo: childId)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => RuleEnforcementLog.fromFirestore(doc))
            .toList());
  }

  /// Get enforcement statistics
  Future<Map<String, int>> getEnforcementStats(String childId, DateTime startDate, DateTime endDate) async {
    try {
      final snapshot = await _firestore
          .collection(enforcementLogsCollection)
          .where('childId', isEqualTo: childId)
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .get();

      final stats = <String, int>{};
      for (final doc in snapshot.docs) {
        final log = RuleEnforcementLog.fromFirestore(doc);
        stats[log.action] = (stats[log.action] ?? 0) + 1;
      }

      return stats;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting enforcement stats: $e');
      }
      return {};
    }
  }

  /// Check if app is currently allowed for child
  Future<bool> isAppAllowed(String childId, String packageName) async {
    try {
      final rules = await getRulesForApp(childId, packageName);
      
      for (final rule in rules) {
        if (!rule.isActive) continue;
        
        // Check if app is blocked
        if (rule.type == RuleType.appBlock) {
          return false;
        }
        
        // Check time windows
        if (rule.type == RuleType.appSchedule && !rule.isCurrentlyApplicable) {
          return false;
        }
      }
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error checking app allowance: $e');
      }
      return true; // Default to allowing if there's an error
    }
  }

  /// Get remaining time for an app (in minutes)
  Future<int?> getRemainingAppTime(String childId, String packageName, int todayUsage) async {
    try {
      final rules = await getRulesForApp(childId, packageName);
      
      for (final rule in rules) {
        if (rule.type == RuleType.appLimit && rule.dailyLimitMinutes != null) {
          final remaining = rule.dailyLimitMinutes! - todayUsage;
          return remaining > 0 ? remaining : 0;
        }
      }
      
      return null; // No limit set
    } catch (e) {
      if (kDebugMode) {
        print('Error getting remaining app time: $e');
      }
      return null;
    }
  }

  /// Clean up expired rules
  Future<void> cleanupExpiredRules() async {
    try {
      final now = Timestamp.now();
      final snapshot = await _firestore
          .collection(rulesCollection)
          .where('expiresAt', isLessThan: now)
          .get();

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {'status': RuleStatus.expired.name});
      }

      if (snapshot.docs.isNotEmpty) {
        await batch.commit();
        if (kDebugMode) {
          print('Cleaned up ${snapshot.docs.length} expired rules');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error cleaning up expired rules: $e');
      }
    }
  }
}

/// Exception class for rules-related errors
class RulesException implements Exception {
  final String message;
  const RulesException(this.message);
  
  @override
  String toString() => 'RulesException: $message';
}