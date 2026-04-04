import 'package:freezed_annotation/freezed_annotation.dart';

part 'user.freezed.dart';
part 'user.g.dart';

@freezed
class User with _$User {
  const factory User({
    required String id,
    required String fullName,
    required String email,
    required String phoneNumber,
    required String role,
    String? patientType, // NORMAL, DEAF
    String? organization, // For Responders
    String? licenseNumber, // For Responders
    String? responderType, // For Responders
    String? vehicleType, // For Responders
    String? profileImageUrl,
    @Default(true) bool isActive,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _User;

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
}

@freezed
class UserProfile with _$UserProfile {
  const factory UserProfile({
    required String userId,
    required String fullName,
    required String email,
    required String phoneNumber,
    required String role,
    String? patientType,
    String? organization,
    String? licenseNumber,
    String? responderType,
    String? vehicleType,
    String? profileImageUrl,
    String? bio,
    String? address,
    String? city,
    String? state,
    String? country,
    String? zipCode,
    DateTime? lastUpdated,
  }) = _UserProfile;

  factory UserProfile.fromJson(Map<String, dynamic> json) =>
      _$UserProfileFromJson(json);
}

@freezed
class AuthResponse with _$AuthResponse {
  const factory AuthResponse({
    required String userId,
    required String fullName,
    required String email,
    required String role,
    required String token,
    required int expiresIn,
  }) = _AuthResponse;

  factory AuthResponse.fromJson(Map<String, dynamic> json) =>
      _$AuthResponseFromJson(json);
}

@freezed
class LoginRequest with _$LoginRequest {
  const factory LoginRequest({
    required String email,
    required String password,
  }) = _LoginRequest;

  factory LoginRequest.fromJson(Map<String, dynamic> json) =>
      _$LoginRequestFromJson(json);
}

@freezed
class RegisterRequest with _$RegisterRequest {
  const factory RegisterRequest({
    required String fullName,
    required String email,
    required String phoneNumber,
    required String password,
    required String role,
    String? patientType,
    String? organization,
    String? licenseNumber,
    String? responderType,
    String? vehicleType,
  }) = _RegisterRequest;

  factory RegisterRequest.fromJson(Map<String, dynamic> json) =>
      _$RegisterRequestFromJson(json);
}
