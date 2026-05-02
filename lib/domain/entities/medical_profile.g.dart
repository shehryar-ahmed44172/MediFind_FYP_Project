// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'medical_profile.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$MedicalProfileImpl _$$MedicalProfileImplFromJson(Map<String, dynamic> json) =>
    _$MedicalProfileImpl(
      id: json['id'] as String,
      userId: json['userId'] as String,
      bloodType: json['bloodType'] as String,
      chronicDiseases: (json['chronicDiseases'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      allergies: (json['allergies'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      medications: (json['medications'] as List<dynamic>?)
              ?.map((e) => Medication.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      emergencyContacts: (json['emergencyContacts'] as List<dynamic>?)
              ?.map((e) => EmergencyContact.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      medicalHistory: json['medicalHistory'] as String?,
      disabilityType: json['disabilityType'] as String?,
      patientType: json['patientType'] as String? ?? 'NORMAL',
      additionalNotes: json['additionalNotes'] as String?,
      lastUpdated: json['lastUpdated'] == null
          ? null
          : DateTime.parse(json['lastUpdated'] as String),
    );

Map<String, dynamic> _$$MedicalProfileImplToJson(
        _$MedicalProfileImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'userId': instance.userId,
      'bloodType': instance.bloodType,
      'chronicDiseases': instance.chronicDiseases,
      'allergies': instance.allergies,
      'medications': instance.medications,
      'emergencyContacts': instance.emergencyContacts,
      'medicalHistory': instance.medicalHistory,
      'disabilityType': instance.disabilityType,
      'patientType': instance.patientType,
      'additionalNotes': instance.additionalNotes,
      'lastUpdated': instance.lastUpdated?.toIso8601String(),
    };

_$MedicationImpl _$$MedicationImplFromJson(Map<String, dynamic> json) =>
    _$MedicationImpl(
      name: json['name'] as String,
      dosage: json['dosage'] as String? ?? '',
      frequency: json['frequency'] as String? ?? '',
      reason: json['reason'] as String?,
    );

Map<String, dynamic> _$$MedicationImplToJson(_$MedicationImpl instance) =>
    <String, dynamic>{
      'name': instance.name,
      'dosage': instance.dosage,
      'frequency': instance.frequency,
      'reason': instance.reason,
    };

_$EmergencyContactImpl _$$EmergencyContactImplFromJson(
        Map<String, dynamic> json) =>
    _$EmergencyContactImpl(
      name: json['name'] as String,
      phoneNumber: json['phoneNumber'] as String,
      relationship: json['relationship'] as String? ?? 'Family',
    );

Map<String, dynamic> _$$EmergencyContactImplToJson(
        _$EmergencyContactImpl instance) =>
    <String, dynamic>{
      'name': instance.name,
      'phoneNumber': instance.phoneNumber,
      'relationship': instance.relationship,
    };

_$UpdateMedicalProfileRequestImpl _$$UpdateMedicalProfileRequestImplFromJson(
        Map<String, dynamic> json) =>
    _$UpdateMedicalProfileRequestImpl(
      bloodType: json['bloodType'] as String,
      chronicDiseases: (json['chronicDiseases'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      allergies:
          (json['allergies'] as List<dynamic>).map((e) => e as String).toList(),
      medications: (json['medications'] as List<dynamic>)
          .map((e) => e as Map<String, dynamic>)
          .toList(),
      emergencyContacts: (json['emergencyContacts'] as List<dynamic>)
          .map((e) => e as Map<String, dynamic>)
          .toList(),
      medicalHistory: json['medicalHistory'] as String?,
      disabilityType: json['disabilityType'] as String?,
      patientType: json['patientType'] as String? ?? 'NORMAL',
      additionalNotes: json['additionalNotes'] as String?,
    );

Map<String, dynamic> _$$UpdateMedicalProfileRequestImplToJson(
        _$UpdateMedicalProfileRequestImpl instance) =>
    <String, dynamic>{
      'bloodType': instance.bloodType,
      'chronicDiseases': instance.chronicDiseases,
      'allergies': instance.allergies,
      'medications': instance.medications,
      'emergencyContacts': instance.emergencyContacts,
      'medicalHistory': instance.medicalHistory,
      'disabilityType': instance.disabilityType,
      'patientType': instance.patientType,
      'additionalNotes': instance.additionalNotes,
    };
