/// Medical Profile Local Data Source
/// Handles Hive local storage for medical profiles (offline support)

import 'package:hive/hive.dart';
import '../../../domain/entities/medical_profile.dart';

class MedicalProfileLocalDataSource {
  static const String _boxName = 'medical_profiles';

  /// Get cached medical profile
  Future<MedicalProfile?> getMedicalProfile(String userId) async {
    try {
      final box = await Hive.openBox<Map<dynamic, dynamic>>(_boxName);
      final data = box.get(userId);

      if (data == null) return null;

      return MedicalProfile.fromJson(Map<String, dynamic>.from(data));
    } catch (e) {
      throw Exception('Failed to read medical profile from cache: $e');
    }
  }

  /// Cache medical profile locally
  Future<void> cacheMedicalProfile(MedicalProfile profile) async {
    try {
      final box = await Hive.openBox<Map<dynamic, dynamic>>(_boxName);

      final data = {
        'id': profile.id,
        'userId': profile.userId,
        'bloodGroup': profile.bloodGroup,
        'allergies': profile.allergies ?? [],
        'chronicDiseases': profile.chronicDiseases ?? [],
        'medications': profile.medications ?? [],
        'disabilities': profile.disabilities ?? [],
        'emergencyContactName': profile.emergencyContactName,
        'emergencyContactPhone': profile.emergencyContactPhone,
        'medicalHistory': profile.medicalHistory,
        'lastUpdated': profile.lastUpdated?.toIso8601String(),
      };

      await box.put(profile.userId, data);
    } catch (e) {
      throw Exception('Failed to cache medical profile: $e');
    }
  }

  /// Delete cached medical profile
  Future<void> deleteMedicalProfile(String userId) async {
    try {
      final box = await Hive.openBox<Map<dynamic, dynamic>>(_boxName);
      await box.delete(userId);
    } catch (e) {
      throw Exception('Failed to delete cached medical profile: $e');
    }
  }

  /// Clear all cached profiles
  Future<void> clearAll() async {
    try {
      final box = await Hive.openBox<Map<dynamic, dynamic>>(_boxName);
      await box.clear();
    } catch (e) {
      throw Exception('Failed to clear medical profile cache: $e');
    }
  }

  /// Get all cached profiles (useful for sync operations)
  Future<List<MedicalProfile>> getAllCachedProfiles() async {
    try {
      final box = await Hive.openBox<Map<dynamic, dynamic>>(_boxName);
      final profiles = <MedicalProfile>[];

      for (final value in box.values) {
        profiles.add(MedicalProfile.fromJson(Map<String, dynamic>.from(value)));
      }

      return profiles;
    } catch (e) {
      throw Exception('Failed to load cached profiles: $e');
    }
  }

  /// Check if profile exists in cache
  Future<bool> exists(String userId) async {
    try {
      final box = await Hive.openBox<Map<dynamic, dynamic>>(_boxName);
      return box.containsKey(userId);
    } catch (e) {
      return false;
    }
  }
}
