import 'package:freezed_annotation/freezed_annotation.dart';

part 'caregiver_connection.freezed.dart';
part 'caregiver_connection.g.dart';

@freezed
class CaregiverConnection with _$CaregiverConnection {
  const factory CaregiverConnection({
    required String id,
    required String patientId,
    required String caregiverId,
    String? patientName,
    String? patientEmail,
    String? caregiverName,
    String? caregiverEmail,
    required String relationship,
    required String status, // PENDING, ACCEPTED, REJECTED
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? hasActiveEmergency,
    String? activeEmergencyId,
    int? patientAge,
    String? bloodType,
  }) = _CaregiverConnection;

  factory CaregiverConnection.fromJson(Map<String, dynamic> json) =>
      _$CaregiverConnectionFromJson(json);
}
