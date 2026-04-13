import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/exceptions.dart';

class MedicalProfileLocalDataSource {
  late Box<String> _medicalProfileBox;

  MedicalProfileLocalDataSource();

  Future<void> init() async {
    _medicalProfileBox = await Hive.openBox<String>(AppConstants.medicalProfileBoxKey);
  }

  Future<void> saveMedicalProfile(Map<String, dynamic> profile) async {
    try {
      await _medicalProfileBox.put(profile['userId'], json.encode(profile));
    } catch (e) {
      throw DatabaseException(message: 'Failed to save medical profile locally', originalException: e);
    }
  }

  Future<Map<String, dynamic>?> getMedicalProfile(String userId) async {
    try {
      final raw = _medicalProfileBox.get(userId);
      if (raw == null) return null;
      return json.decode(raw) as Map<String, dynamic>;
    } catch (e) {
      throw DatabaseException(message: 'Failed to get local medical profile', originalException: e);
    }
  }

  Future<void> deleteMedicalProfile(String userId) async {
    try {
      await _medicalProfileBox.delete(userId);
    } catch (e) {
      throw DatabaseException(message: 'Failed to delete local medical profile', originalException: e);
    }
  }

  Future<void> clearAll() async {
    await _medicalProfileBox.clear();
  }
}
