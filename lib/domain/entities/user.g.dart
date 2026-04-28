// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$UserImpl _$$UserImplFromJson(Map<String, dynamic> json) => _$UserImpl(
      id: json['id'] as String,
      fullName: json['fullName'] as String,
      email: json['email'] as String,
      phoneNumber: json['phoneNumber'] as String,
      role: json['role'] as String,
      patientType: json['patientType'] as String?,
      organization: json['organization'] as String?,
      licenseNumber: json['licenseNumber'] as String?,
      responderType: json['responderType'] as String?,
      vehicleType: json['vehicleType'] as String?,
      cnic: json['cnic'] as String?,
      dateOfBirth: json['dateOfBirth'] == null
          ? null
          : DateTime.parse(json['dateOfBirth'] as String),
      verificationStatus: json['verificationStatus'] as String?,
      rating: (json['rating'] as num?)?.toDouble(),
      totalResponsesHandled: (json['totalResponsesHandled'] as num?)?.toInt(),
      voiceAlertGenerated: json['voiceAlertGenerated'] as bool? ?? false,
      additionalInfo: json['additionalInfo'] as String?,
      completedAt: json['completedAt'] == null
          ? null
          : DateTime.parse(json['completedAt'] as String),
      priority: json['priority'] as String? ?? 'NORMAL',
      expiresAt: json['expiresAt'] == null
          ? null
          : DateTime.parse(json['expiresAt'] as String),
      profileImageUrl: json['profileImageUrl'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$$UserImplToJson(_$UserImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'fullName': instance.fullName,
      'email': instance.email,
      'phoneNumber': instance.phoneNumber,
      'role': instance.role,
      'patientType': instance.patientType,
      'organization': instance.organization,
      'licenseNumber': instance.licenseNumber,
      'responderType': instance.responderType,
      'vehicleType': instance.vehicleType,
      'cnic': instance.cnic,
      'dateOfBirth': instance.dateOfBirth?.toIso8601String(),
      'verificationStatus': instance.verificationStatus,
      'rating': instance.rating,
      'totalResponsesHandled': instance.totalResponsesHandled,
      'voiceAlertGenerated': instance.voiceAlertGenerated,
      'additionalInfo': instance.additionalInfo,
      'completedAt': instance.completedAt?.toIso8601String(),
      'priority': instance.priority,
      'expiresAt': instance.expiresAt?.toIso8601String(),
      'profileImageUrl': instance.profileImageUrl,
      'isActive': instance.isActive,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
    };

_$UserProfileImpl _$$UserProfileImplFromJson(Map<String, dynamic> json) =>
    _$UserProfileImpl(
      userId: json['userId'] as String,
      fullName: json['fullName'] as String,
      email: json['email'] as String,
      phoneNumber: json['phoneNumber'] as String,
      role: json['role'] as String,
      patientType: json['patientType'] as String?,
      organization: json['organization'] as String?,
      licenseNumber: json['licenseNumber'] as String?,
      responderType: json['responderType'] as String?,
      vehicleType: json['vehicleType'] as String?,
      cnic: json['cnic'] as String?,
      dateOfBirth: json['dateOfBirth'] == null
          ? null
          : DateTime.parse(json['dateOfBirth'] as String),
      verificationStatus: json['verificationStatus'] as String?,
      rating: (json['rating'] as num?)?.toDouble(),
      totalResponsesHandled: (json['totalResponsesHandled'] as num?)?.toInt(),
      profileImageUrl: json['profileImageUrl'] as String?,
      bio: json['bio'] as String?,
      address: json['address'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
      country: json['country'] as String?,
      zipCode: json['zipCode'] as String?,
      isActive: json['isActive'] as bool?,
      lastUpdated: json['lastUpdated'] == null
          ? null
          : DateTime.parse(json['lastUpdated'] as String),
    );

Map<String, dynamic> _$$UserProfileImplToJson(_$UserProfileImpl instance) =>
    <String, dynamic>{
      'userId': instance.userId,
      'fullName': instance.fullName,
      'email': instance.email,
      'phoneNumber': instance.phoneNumber,
      'role': instance.role,
      'patientType': instance.patientType,
      'organization': instance.organization,
      'licenseNumber': instance.licenseNumber,
      'responderType': instance.responderType,
      'vehicleType': instance.vehicleType,
      'cnic': instance.cnic,
      'dateOfBirth': instance.dateOfBirth?.toIso8601String(),
      'verificationStatus': instance.verificationStatus,
      'rating': instance.rating,
      'totalResponsesHandled': instance.totalResponsesHandled,
      'profileImageUrl': instance.profileImageUrl,
      'bio': instance.bio,
      'address': instance.address,
      'city': instance.city,
      'state': instance.state,
      'country': instance.country,
      'zipCode': instance.zipCode,
      'isActive': instance.isActive,
      'lastUpdated': instance.lastUpdated?.toIso8601String(),
    };

_$AuthResponseImpl _$$AuthResponseImplFromJson(Map<String, dynamic> json) =>
    _$AuthResponseImpl(
      accessToken: json['token'] as String,
      refreshToken: json['refreshToken'] as String? ?? '',
      expiresIn:
          json['expiresIn'] == null ? 3600 : intFromJson(json['expiresIn']),
      userId: json['userId'] as String,
      fullName: json['fullName'] as String,
      email: json['email'] as String,
      role: json['role'] as String,
    );

Map<String, dynamic> _$$AuthResponseImplToJson(_$AuthResponseImpl instance) =>
    <String, dynamic>{
      'token': instance.accessToken,
      'refreshToken': instance.refreshToken,
      'expiresIn': instance.expiresIn,
      'userId': instance.userId,
      'fullName': instance.fullName,
      'email': instance.email,
      'role': instance.role,
    };

_$AuthUserImpl _$$AuthUserImplFromJson(Map<String, dynamic> json) =>
    _$AuthUserImpl(
      id: json['userId'] as String,
      email: json['email'] as String,
      fullName: json['fullName'] as String,
      role: json['role'] as String,
    );

Map<String, dynamic> _$$AuthUserImplToJson(_$AuthUserImpl instance) =>
    <String, dynamic>{
      'userId': instance.id,
      'email': instance.email,
      'fullName': instance.fullName,
      'role': instance.role,
    };

_$LoginRequestImpl _$$LoginRequestImplFromJson(Map<String, dynamic> json) =>
    _$LoginRequestImpl(
      email: json['email'] as String,
      password: json['password'] as String,
    );

Map<String, dynamic> _$$LoginRequestImplToJson(_$LoginRequestImpl instance) =>
    <String, dynamic>{
      'email': instance.email,
      'password': instance.password,
    };

_$RegisterRequestImpl _$$RegisterRequestImplFromJson(
        Map<String, dynamic> json) =>
    _$RegisterRequestImpl(
      fullName: json['fullName'] as String,
      email: json['email'] as String,
      phoneNumber: json['phoneNumber'] as String,
      password: json['password'] as String,
      role: json['role'] as String,
      city: json['city'] as String?,
      address: json['address'] as String?,
      cnic: json['cnic'] as String?,
      dateOfBirth: json['dateOfBirth'] as String?,
      patientType: json['patientType'] as String?,
      organization: json['organization'] as String?,
      licenseNumber: json['licenseNumber'] as String?,
      responderType: json['responderType'] as String?,
      vehicleType: json['vehicleType'] as String?,
    );

Map<String, dynamic> _$$RegisterRequestImplToJson(
        _$RegisterRequestImpl instance) =>
    <String, dynamic>{
      'fullName': instance.fullName,
      'email': instance.email,
      'phoneNumber': instance.phoneNumber,
      'password': instance.password,
      'role': instance.role,
      'city': instance.city,
      'address': instance.address,
      'cnic': instance.cnic,
      'dateOfBirth': instance.dateOfBirth,
      'patientType': instance.patientType,
      'organization': instance.organization,
      'licenseNumber': instance.licenseNumber,
      'responderType': instance.responderType,
      'vehicleType': instance.vehicleType,
    };
