/// Emergency Local Data Source
/// Handles Hive local storage for emergencies (offline support & caching)

import 'package:hive/hive.dart';
import '../../../domain/entities/emergency.dart';

class EmergencyLocalDataSource {
  static const String _activeEmergenciesBox = 'active_emergencies';
  static const String _emergencyHistoryBox = 'emergency_history';

  /// Get emergency by ID from cache
  Future<Emergency?> getEmergency(String emergencyId) async {
    try {
      // Check active emergencies first
      final activeBox = await Hive.openBox<Map<dynamic, dynamic>>(_activeEmergenciesBox);
      var data = activeBox.get(emergencyId);

      if (data != null) {
        return Emergency.fromJson(Map<String, dynamic>.from(data));
      }

      // Then check history
      final historyBox = await Hive.openBox<Map<dynamic, dynamic>>(_emergencyHistoryBox);
      data = historyBox.get(emergencyId);

      if (data != null) {
        return Emergency.fromJson(Map<String, dynamic>.from(data));
      }

      return null;
    } catch (e) {
      throw Exception('Failed to read emergency from cache: $e');
    }
  }

  /// Cache emergency locally
  /// Stores in active emergencies if status is ACTIVE, otherwise in history
  Future<void> cacheEmergency(Emergency emergency) async {
    try {
      final data = {
        'id': emergency.id,
        'patientId': emergency.patientId,
        'emergencyType': emergency.emergencyType,
        'status': emergency.status,
        'latitude': emergency.latitude,
        'longitude': emergency.longitude,
        'additionalInfo': emergency.additionalInfo,
        'createdAt': emergency.createdAt.toIso8601String(),
        'resolvedAt': emergency.resolvedAt?.toIso8601String(),
        'cancelledAt': emergency.cancelledAt?.toIso8601String(),
      };

      if (emergency.status == 'ACTIVE') {
        final box = await Hive.openBox<Map<dynamic, dynamic>>(_activeEmergenciesBox);
        await box.put(emergency.id, data);
      } else {
        final box = await Hive.openBox<Map<dynamic, dynamic>>(_emergencyHistoryBox);
        await box.put(emergency.id, data);
      }
    } catch (e) {
      throw Exception('Failed to cache emergency: $e');
    }
  }

  /// Get all emergencies for a patient from cache
  Future<List<Emergency>> getPatientEmergencies(String patientId) async {
    try {
      final emergencies = <Emergency>[];

      // Get from active emergencies
      final activeBox = await Hive.openBox<Map<dynamic, dynamic>>(_activeEmergenciesBox);
      for (final value in activeBox.values) {
        final emergency = Emergency.fromJson(Map<String, dynamic>.from(value));
        if (emergency.patientId == patientId) {
          emergencies.add(emergency);
        }
      }

      // Get from history
      final historyBox = await Hive.openBox<Map<dynamic, dynamic>>(_emergencyHistoryBox);
      for (final value in historyBox.values) {
        final emergency = Emergency.fromJson(Map<String, dynamic>.from(value));
        if (emergency.patientId == patientId) {
          emergencies.add(emergency);
        }
      }

      // Sort by creation date (newest first)
      emergencies.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return emergencies;
    } catch (e) {
      throw Exception('Failed to load patient emergencies: $e');
    }
  }

  /// Delete emergency from cache
  Future<void> deleteEmergency(String emergencyId) async {
    try {
      final activeBox = await Hive.openBox<Map<dynamic, dynamic>>(_activeEmergenciesBox);
      await activeBox.delete(emergencyId);

      final historyBox = await Hive.openBox<Map<dynamic, dynamic>>(_emergencyHistoryBox);
      await historyBox.delete(emergencyId);
    } catch (e) {
      throw Exception('Failed to delete emergency: $e');
    }
  }

  /// Move emergency from active to history
  /// Called when emergency is resolved or cancelled
  Future<void> archiveEmergency(String emergencyId) async {
    try {
      final activeBox = await Hive.openBox<Map<dynamic, dynamic>>(_activeEmergenciesBox);
      final data = activeBox.get(emergencyId);

      if (data != null) {
        final historyBox = await Hive.openBox<Map<dynamic, dynamic>>(_emergencyHistoryBox);
        await historyBox.put(emergencyId, data);
        await activeBox.delete(emergencyId);
      }
    } catch (e) {
      throw Exception('Failed to archive emergency: $e');
    }
  }

  /// Get all active emergencies
  Future<List<Emergency>> getActiveEmergencies() async {
    try {
      final box = await Hive.openBox<Map<dynamic, dynamic>>(_activeEmergenciesBox);
      final emergencies = <Emergency>[];

      for (final value in box.values) {
        emergencies.add(Emergency.fromJson(Map<String, dynamic>.from(value)));
      }

      return emergencies;
    } catch (e) {
      throw Exception('Failed to load active emergencies: $e');
    }
  }

  /// Clear all caches (called on logout)
  Future<void> clearAll() async {
    try {
      final activeBox = await Hive.openBox<Map<dynamic, dynamic>>(_activeEmergenciesBox);
      await activeBox.clear();

      final historyBox = await Hive.openBox<Map<dynamic, dynamic>>(_emergencyHistoryBox);
      await historyBox.clear();
    } catch (e) {
      throw Exception('Failed to clear emergency cache: $e');
    }
  }

  /// Check if emergency exists in cache
  Future<bool> exists(String emergencyId) async {
    try {
      final activeBox = await Hive.openBox<Map<dynamic, dynamic>>(_activeEmergenciesBox);
      if (activeBox.containsKey(emergencyId)) return true;

      final historyBox = await Hive.openBox<Map<dynamic, dynamic>>(_emergencyHistoryBox);
      return historyBox.containsKey(emergencyId);
    } catch (e) {
      return false;
    }
  }
}
