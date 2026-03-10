// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'emergency.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$EmergencyImpl _$$EmergencyImplFromJson(Map<String, dynamic> json) =>
    _$EmergencyImpl(
      id: json['id'] as String,
      userId: json['userId'] as String,
      status: json['status'] as String,
      emergencyType: json['emergencyType'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      responderId: json['responderId'] as String?,
      voiceAlertGenerated: json['voiceAlertGenerated'] as bool? ?? false,
      additionalInfo: json['additionalInfo'] as String?,
      completedAt: json['completedAt'] == null
          ? null
          : DateTime.parse(json['completedAt'] as String),
    );

Map<String, dynamic> _$$EmergencyImplToJson(_$EmergencyImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'userId': instance.userId,
      'status': instance.status,
      'emergencyType': instance.emergencyType,
      'latitude': instance.latitude,
      'longitude': instance.longitude,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
      'responderId': instance.responderId,
      'voiceAlertGenerated': instance.voiceAlertGenerated,
      'additionalInfo': instance.additionalInfo,
      'completedAt': instance.completedAt?.toIso8601String(),
    };

_$CreateEmergencyRequestImpl _$$CreateEmergencyRequestImplFromJson(
        Map<String, dynamic> json) =>
    _$CreateEmergencyRequestImpl(
      emergencyType: json['emergencyType'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      additionalInfo: json['additionalInfo'] as String?,
    );

Map<String, dynamic> _$$CreateEmergencyRequestImplToJson(
        _$CreateEmergencyRequestImpl instance) =>
    <String, dynamic>{
      'emergencyType': instance.emergencyType,
      'latitude': instance.latitude,
      'longitude': instance.longitude,
      'additionalInfo': instance.additionalInfo,
    };

_$UpdateEmergencyStatusRequestImpl _$$UpdateEmergencyStatusRequestImplFromJson(
        Map<String, dynamic> json) =>
    _$UpdateEmergencyStatusRequestImpl(
      status: json['status'] as String,
      responderId: json['responderId'] as String?,
    );

Map<String, dynamic> _$$UpdateEmergencyStatusRequestImplToJson(
        _$UpdateEmergencyStatusRequestImpl instance) =>
    <String, dynamic>{
      'status': instance.status,
      'responderId': instance.responderId,
    };

_$EmergencyLocationImpl _$$EmergencyLocationImplFromJson(
        Map<String, dynamic> json) =>
    _$EmergencyLocationImpl(
      emergencyId: json['emergencyId'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      timestamp: DateTime.parse(json['timestamp'] as String),
    );

Map<String, dynamic> _$$EmergencyLocationImplToJson(
        _$EmergencyLocationImpl instance) =>
    <String, dynamic>{
      'emergencyId': instance.emergencyId,
      'latitude': instance.latitude,
      'longitude': instance.longitude,
      'timestamp': instance.timestamp.toIso8601String(),
    };

_$EmergencyResponseImpl _$$EmergencyResponseImplFromJson(
        Map<String, dynamic> json) =>
    _$EmergencyResponseImpl(
      responderId: json['responderId'] as String,
      emergencyId: json['emergencyId'] as String,
      status: json['status'] as String,
      estimatedArrivalTime: json['estimatedArrivalTime'] == null
          ? null
          : DateTime.parse(json['estimatedArrivalTime'] as String),
      notes: json['notes'] as String?,
    );

Map<String, dynamic> _$$EmergencyResponseImplToJson(
        _$EmergencyResponseImpl instance) =>
    <String, dynamic>{
      'responderId': instance.responderId,
      'emergencyId': instance.emergencyId,
      'status': instance.status,
      'estimatedArrivalTime': instance.estimatedArrivalTime?.toIso8601String(),
      'notes': instance.notes,
    };
