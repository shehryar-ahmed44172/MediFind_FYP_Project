import 'package:freezed_annotation/freezed_annotation.dart';
import '../../core/utils/parsers.dart';

part 'emergency.freezed.dart';
part 'emergency.g.dart';

@freezed
class Emergency with _$Emergency {
  const factory Emergency({
    @Default('') String id,
    @Default('') String userId,
    @Default('PENDING') String status,
    @Default('OTHER') String emergencyType,
    @JsonKey(fromJson: doubleFromJson) @Default(0.0) double latitude,
    @JsonKey(fromJson: doubleFromJson) @Default(0.0) double longitude,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? responderId,
    @Default(false) bool voiceAlertGenerated,
    String? additionalInfo,
    DateTime? completedAt,
    @Default('NORMAL') String priority,
    DateTime? expiresAt,
  }) = _Emergency;

  factory Emergency.fromJson(Map<String, dynamic> json) =>
      _$EmergencyFromJson(json);
}

@freezed
class CreateEmergencyRequest with _$CreateEmergencyRequest {
  const factory CreateEmergencyRequest({
    required String emergencyType,
    @JsonKey(fromJson: doubleFromJson) required double latitude,
    @JsonKey(fromJson: doubleFromJson) required double longitude,
    String? additionalInfo,
    @Default('NORMAL') String priority,
  }) = _CreateEmergencyRequest;

  factory CreateEmergencyRequest.fromJson(Map<String, dynamic> json) =>
      _$CreateEmergencyRequestFromJson(json);
}

@freezed
class UpdateEmergencyStatusRequest with _$UpdateEmergencyStatusRequest {
  const factory UpdateEmergencyStatusRequest({
    required String status,
    String? responderId,
  }) = _UpdateEmergencyStatusRequest;

  factory UpdateEmergencyStatusRequest.fromJson(Map<String, dynamic> json) =>
      _$UpdateEmergencyStatusRequestFromJson(json);
}

@freezed
class EmergencyLocation with _$EmergencyLocation {
  const factory EmergencyLocation({
    required String emergencyId,
    @JsonKey(fromJson: doubleFromJson) required double latitude,
    @JsonKey(fromJson: doubleFromJson) required double longitude,
    required DateTime timestamp,
  }) = _EmergencyLocation;

  factory EmergencyLocation.fromJson(Map<String, dynamic> json) =>
      _$EmergencyLocationFromJson(json);
}

@freezed
class EmergencyResponse with _$EmergencyResponse {
  const factory EmergencyResponse({
    required String responderId,
    required String emergencyId,
    required String status,
    DateTime? estimatedArrivalTime,
    String? notes,
  }) = _EmergencyResponse;

  factory EmergencyResponse.fromJson(Map<String, dynamic> json) =>
      _$EmergencyResponseFromJson(json);
}
