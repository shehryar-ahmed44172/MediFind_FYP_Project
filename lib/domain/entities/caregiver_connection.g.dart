// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'caregiver_connection.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$CaregiverConnectionImpl _$$CaregiverConnectionImplFromJson(
        Map<String, dynamic> json) =>
    _$CaregiverConnectionImpl(
      id: json['id'] as String,
      patientId: json['patientId'] as String,
      caregiverId: json['caregiverId'] as String,
      patientName: json['patientName'] as String?,
      patientEmail: json['patientEmail'] as String?,
      caregiverName: json['caregiverName'] as String?,
      caregiverEmail: json['caregiverEmail'] as String?,
      relationship: json['relationship'] as String,
      status: json['status'] as String,
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
      hasActiveEmergency: json['hasActiveEmergency'] as bool?,
      activeEmergencyId: json['activeEmergencyId'] as String?,
      patientAge: (json['patientAge'] as num?)?.toInt(),
      bloodType: json['bloodType'] as String?,
    );

Map<String, dynamic> _$$CaregiverConnectionImplToJson(
        _$CaregiverConnectionImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'patientId': instance.patientId,
      'caregiverId': instance.caregiverId,
      'patientName': instance.patientName,
      'patientEmail': instance.patientEmail,
      'caregiverName': instance.caregiverName,
      'caregiverEmail': instance.caregiverEmail,
      'relationship': instance.relationship,
      'status': instance.status,
      'createdAt': instance.createdAt?.toIso8601String(),
      'updatedAt': instance.updatedAt?.toIso8601String(),
      'hasActiveEmergency': instance.hasActiveEmergency,
      'activeEmergencyId': instance.activeEmergencyId,
      'patientAge': instance.patientAge,
      'bloodType': instance.bloodType,
    };
