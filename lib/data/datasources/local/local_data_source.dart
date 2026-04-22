import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '/core/constants/app_constants.dart';
import '/core/utils/exceptions.dart';

/// LocalDataSource stores all data as JSON strings in Hive boxes.
/// This avoids the need for HiveAdapters on Freezed-generated classes.
class LocalDataSource {
  late Box<String> _userBox;
  late Box<String> _emergencyBox;
  late Box<String> _medicalProfileBox;
  late Box<String> _authBox;
  late Box<String> _caregiverBox;
  late Box<String> _generalBox;

  Future<void> initializeHive() async {
    try {
      // Open all boxes as JSON string boxes
      _userBox = await Hive.openBox<String>(AppConstants.userBoxKey);
      _emergencyBox = await Hive.openBox<String>(AppConstants.emergencyBoxKey);
      _medicalProfileBox = await Hive.openBox<String>(AppConstants.medicalProfileBoxKey);
      _authBox = await Hive.openBox<String>(AppConstants.authBoxKey);
      _caregiverBox = await Hive.openBox<String>('caregivers');
      _generalBox = await Hive.openBox<String>('general');
    } catch (e) {
      throw DatabaseException(
        message: 'Failed to initialize local database',
        originalException: e,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Auth operations
  // ---------------------------------------------------------------------------

  Future<void> saveAuthToken(String token) async {
    try {
      await _authBox.put(AppConstants.jwtTokenKey, token);
    } catch (e) {
      throw DatabaseException(message: 'Failed to save auth token', originalException: e);
    }
  }

  Future<void> saveRefreshToken(String token) async {
    try {
      await _authBox.put('refresh_token', token);
    } catch (e) {
      throw DatabaseException(message: 'Failed to save refresh token', originalException: e);
    }
  }

  Future<String?> getAuthToken() async {
    try {
      return _authBox.get(AppConstants.jwtTokenKey);
    } catch (e) {
      throw DatabaseException(message: 'Failed to retrieve auth token', originalException: e);
    }
  }

  Future<String?> getRefreshToken() async {
    try {
      return _authBox.get('refresh_token');
    } catch (e) {
      throw DatabaseException(message: 'Failed to retrieve refresh token', originalException: e);
    }
  }

  Future<void> clearAuthToken() async {
    try {
      await _authBox.delete(AppConstants.jwtTokenKey);
      await _authBox.delete('refresh_token');
    } catch (e) {
      throw DatabaseException(message: 'Failed to clear tokens', originalException: e);
    }
  }

  Future<void> saveCurrentUserId(String userId) async {
    await _authBox.put('current_user_id', userId);
  }

  Future<String?> getCurrentUserId() async {
    return _authBox.get('current_user_id');
  }

  Future<void> saveCurrentUserRole(String role) async {
    await _authBox.put('current_user_role', role);
  }

  Future<String?> getCurrentUserRole() async {
    return _authBox.get('current_user_role');
  }

  // ---------------------------------------------------------------------------
  // User operations (JSON storage)
  // ---------------------------------------------------------------------------

  Future<void> saveUser(Map<String, dynamic> user) async {
    try {
      await _userBox.put(user['id'], json.encode(user));
    } catch (e) {
      throw DatabaseException(message: 'Failed to save user', originalException: e);
    }
  }

  Future<Map<String, dynamic>?> getUser(String userId) async {
    try {
      final raw = _userBox.get(userId);
      if (raw == null) return null;
      return json.decode(raw) as Map<String, dynamic>;
    } catch (e) {
      throw DatabaseException(message: 'Failed to get user', originalException: e);
    }
  }

  Future<void> deleteUser(String userId) async {
    try {
      await _userBox.delete(userId);
    } catch (e) {
      throw DatabaseException(message: 'Failed to delete user', originalException: e);
    }
  }

  // ---------------------------------------------------------------------------
  // Emergency operations (JSON storage)
  // ---------------------------------------------------------------------------

  Future<void> saveEmergency(Map<String, dynamic> emergency) async {
    try {
      await _emergencyBox.put(emergency['id'], json.encode(emergency));
    } catch (e) {
      throw DatabaseException(message: 'Failed to save emergency', originalException: e);
    }
  }

  Future<Map<String, dynamic>?> getEmergency(String emergencyId) async {
    try {
      final raw = _emergencyBox.get(emergencyId);
      if (raw == null) return null;
      return json.decode(raw) as Map<String, dynamic>;
    } catch (e) {
      throw DatabaseException(message: 'Failed to get emergency', originalException: e);
    }
  }

  Future<List<Map<String, dynamic>>> getUserEmergencies(String userId) async {
    try {
      return _emergencyBox.values
          .map((raw) => json.decode(raw) as Map<String, dynamic>)
          .where((e) => e['userId'] == userId)
          .toList();
    } catch (e) {
      throw DatabaseException(message: 'Failed to get user emergencies', originalException: e);
    }
  }

  Future<List<Map<String, dynamic>>> getAllEmergencies() async {
    try {
      return _emergencyBox.values
          .map((raw) => json.decode(raw) as Map<String, dynamic>)
          .toList();
    } catch (e) {
      throw DatabaseException(message: 'Failed to get all emergencies', originalException: e);
    }
  }

  Future<void> deleteEmergency(String emergencyId) async {
    try {
      await _emergencyBox.delete(emergencyId);
    } catch (e) {
      throw DatabaseException(message: 'Failed to delete emergency', originalException: e);
    }
  }

  Future<void> clearAllEmergencies() async {
    try {
      await _emergencyBox.clear();
    } catch (e) {
      throw DatabaseException(message: 'Failed to clear emergencies', originalException: e);
    }
  }

  // ---------------------------------------------------------------------------
  // Medical Profile operations (JSON storage)
  // ---------------------------------------------------------------------------

  Future<void> saveMedicalProfile(Map<String, dynamic> profile) async {
    try {
      await _medicalProfileBox.put(profile['userId'], json.encode(profile));
    } catch (e) {
      throw DatabaseException(message: 'Failed to save medical profile', originalException: e);
    }
  }

  Future<Map<String, dynamic>?> getMedicalProfile(String userId) async {
    try {
      final raw = _medicalProfileBox.get(userId);
      if (raw == null) return null;
      return json.decode(raw) as Map<String, dynamic>;
    } catch (e) {
      throw DatabaseException(message: 'Failed to get medical profile', originalException: e);
    }
  }

  Future<void> deleteMedicalProfile(String userId) async {
    try {
      await _medicalProfileBox.delete(userId);
    } catch (e) {
      throw DatabaseException(message: 'Failed to delete medical profile', originalException: e);
    }
  }

  // ---------------------------------------------------------------------------
  // Caregiver operations (JSON storage)
  // ---------------------------------------------------------------------------

  Future<void> saveCaregiverLinks(String userId, List<Map<String, dynamic>> caregivers) async {
    try {
      await _caregiverBox.put(userId, json.encode(caregivers));
    } catch (e) {
      throw DatabaseException(message: 'Failed to save caregivers', originalException: e);
    }
  }

  Future<List<Map<String, dynamic>>> getCaregiverLinks(String userId) async {
    try {
      final raw = _caregiverBox.get(userId);
      if (raw == null) return [];
      final decoded = json.decode(raw) as List<dynamic>;
      return decoded.cast<Map<String, dynamic>>();
    } catch (e) {
      throw DatabaseException(message: 'Failed to get caregivers', originalException: e);
    }
  }

  // ---------------------------------------------------------------------------
  // General key-value storage
  // ---------------------------------------------------------------------------

  Future<void> setValue(String key, String value) async {
    await _generalBox.put(key, value);
  }

  Future<String?> getValue(String key) async {
    return _generalBox.get(key);
  }

  // ---------------------------------------------------------------------------
  // Clear all data
  // ---------------------------------------------------------------------------

  Future<void> clearAll() async {
    try {
      await Future.wait([
        _userBox.clear(),
        _emergencyBox.clear(),
        _medicalProfileBox.clear(),
        _authBox.clear(),
        _caregiverBox.clear(),
        _generalBox.clear(),
      ]);
    } catch (e) {
      throw DatabaseException(message: 'Failed to clear all data', originalException: e);
    }
  }

  // ---------------------------------------------------------------------------
  // Watch operations
  // ---------------------------------------------------------------------------

  Stream<BoxEvent> watchEmergencies() {
    return _emergencyBox.watch();
  }
}
