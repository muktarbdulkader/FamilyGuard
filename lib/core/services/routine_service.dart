import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/routine_model.dart';
import '../constants/app_constants.dart';

final routineServiceProvider = Provider<RoutineService>((ref) {
  return RoutineService.instance;
});

final childRoutinesProvider =
    StreamProvider.family<
      List<RoutineModel>,
      ({String familyId, String childId})
    >((ref, arg) {
      final service = ref.watch(routineServiceProvider);
      return service.getRoutinesStream(arg.familyId, arg.childId);
    });

class RoutineConflictException implements Exception {
  final List<String> conflicts;

  const RoutineConflictException(this.conflicts);

  @override
  String toString() => conflicts.join('\n');
}

class RoutineService {
  static final RoutineService instance = RoutineService._internal();
  factory RoutineService() => instance;
  RoutineService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _routinesCollection(
    String familyId,
  ) {
    return _firestore
        .collection(AppConstants.familiesCollection)
        .doc(familyId)
        .collection('routines');
  }

  /// Create a new routine with conflict check
  Future<({String id, List<String> conflicts})> createRoutine({
    required String familyId,
    required RoutineModel routine,
  }) async {
    // Check conflicts against existing routines
    final existing = await getRoutinesOnce(familyId, routine.childId);
    final conflicts = RoutineModel.findConflicts(routine, existing);
    if (conflicts.isNotEmpty) throw RoutineConflictException(conflicts);

    final docRef = await _routinesCollection(
      familyId,
    ).add(routine.toFirestore());
    return (id: docRef.id, conflicts: conflicts);
  }

  /// Update an existing routine
  Future<List<String>> updateRoutine({
    required String familyId,
    required RoutineModel routine,
  }) async {
    final existing = await getRoutinesOnce(familyId, routine.childId);
    final conflicts = RoutineModel.findConflicts(routine, existing);
    if (conflicts.isNotEmpty) throw RoutineConflictException(conflicts);

    await _routinesCollection(
      familyId,
    ).doc(routine.id).update(routine.toFirestore());
    return conflicts;
  }

  /// Toggle routine on or off
  Future<void> toggleRoutine({
    required String familyId,
    required String routineId,
    required bool isActive,
  }) async {
    await _routinesCollection(familyId).doc(routineId).update({
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Delete a routine
  Future<void> deleteRoutine({
    required String familyId,
    required String routineId,
  }) async {
    await _routinesCollection(familyId).doc(routineId).delete();
  }

  /// Stream routines for a child
  Stream<List<RoutineModel>> getRoutinesStream(
    String familyId,
    String childId,
  ) {
    if (familyId.isEmpty || childId.isEmpty) return Stream.value([]);

    return _routinesCollection(
      familyId,
    ).where('childId', isEqualTo: childId).snapshots().map((snap) {
      final list = snap.docs.map((d) => RoutineModel.fromFirestore(d)).toList();
      list.sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
      return list;
    });
  }

  /// One-time fetch for conflict detection
  Future<List<RoutineModel>> getRoutinesOnce(
    String familyId,
    String childId,
  ) async {
    if (familyId.isEmpty || childId.isEmpty) return [];

    final snap = await _routinesCollection(
      familyId,
    ).where('childId', isEqualTo: childId).get();
    return snap.docs.map((d) => RoutineModel.fromFirestore(d)).toList();
  }
}
