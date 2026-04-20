// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'caregiver_connection.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

CaregiverConnection _$CaregiverConnectionFromJson(Map<String, dynamic> json) {
  return _CaregiverConnection.fromJson(json);
}

/// @nodoc
mixin _$CaregiverConnection {
  String get id => throw _privateConstructorUsedError;
  String get patientId => throw _privateConstructorUsedError;
  String get caregiverId => throw _privateConstructorUsedError;
  String? get requesterId => throw _privateConstructorUsedError;
  String? get patientName => throw _privateConstructorUsedError;
  String? get patientEmail => throw _privateConstructorUsedError;
  String? get caregiverName => throw _privateConstructorUsedError;
  String? get caregiverEmail => throw _privateConstructorUsedError;
  String get relationship => throw _privateConstructorUsedError;
  String get status =>
      throw _privateConstructorUsedError; // PENDING, ACCEPTED, REJECTED
  DateTime? get createdAt => throw _privateConstructorUsedError;
  DateTime? get updatedAt => throw _privateConstructorUsedError;
  bool? get hasActiveEmergency => throw _privateConstructorUsedError;
  String? get activeEmergencyId => throw _privateConstructorUsedError;
  @JsonKey(fromJson: intFromJson)
  int? get patientAge => throw _privateConstructorUsedError;
  String? get bloodType => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $CaregiverConnectionCopyWith<CaregiverConnection> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CaregiverConnectionCopyWith<$Res> {
  factory $CaregiverConnectionCopyWith(
          CaregiverConnection value, $Res Function(CaregiverConnection) then) =
      _$CaregiverConnectionCopyWithImpl<$Res, CaregiverConnection>;
  @useResult
  $Res call(
      {String id,
      String patientId,
      String caregiverId,
      String? requesterId,
      String? patientName,
      String? patientEmail,
      String? caregiverName,
      String? caregiverEmail,
      String relationship,
      String status,
      DateTime? createdAt,
      DateTime? updatedAt,
      bool? hasActiveEmergency,
      String? activeEmergencyId,
      @JsonKey(fromJson: intFromJson) int? patientAge,
      String? bloodType});
}

/// @nodoc
class _$CaregiverConnectionCopyWithImpl<$Res, $Val extends CaregiverConnection>
    implements $CaregiverConnectionCopyWith<$Res> {
  _$CaregiverConnectionCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? patientId = null,
    Object? caregiverId = null,
    Object? requesterId = freezed,
    Object? patientName = freezed,
    Object? patientEmail = freezed,
    Object? caregiverName = freezed,
    Object? caregiverEmail = freezed,
    Object? relationship = null,
    Object? status = null,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
    Object? hasActiveEmergency = freezed,
    Object? activeEmergencyId = freezed,
    Object? patientAge = freezed,
    Object? bloodType = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      patientId: null == patientId
          ? _value.patientId
          : patientId // ignore: cast_nullable_to_non_nullable
              as String,
      caregiverId: null == caregiverId
          ? _value.caregiverId
          : caregiverId // ignore: cast_nullable_to_non_nullable
              as String,
      requesterId: freezed == requesterId
          ? _value.requesterId
          : requesterId // ignore: cast_nullable_to_non_nullable
              as String?,
      patientName: freezed == patientName
          ? _value.patientName
          : patientName // ignore: cast_nullable_to_non_nullable
              as String?,
      patientEmail: freezed == patientEmail
          ? _value.patientEmail
          : patientEmail // ignore: cast_nullable_to_non_nullable
              as String?,
      caregiverName: freezed == caregiverName
          ? _value.caregiverName
          : caregiverName // ignore: cast_nullable_to_non_nullable
              as String?,
      caregiverEmail: freezed == caregiverEmail
          ? _value.caregiverEmail
          : caregiverEmail // ignore: cast_nullable_to_non_nullable
              as String?,
      relationship: null == relationship
          ? _value.relationship
          : relationship // ignore: cast_nullable_to_non_nullable
              as String,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: freezed == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      updatedAt: freezed == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      hasActiveEmergency: freezed == hasActiveEmergency
          ? _value.hasActiveEmergency
          : hasActiveEmergency // ignore: cast_nullable_to_non_nullable
              as bool?,
      activeEmergencyId: freezed == activeEmergencyId
          ? _value.activeEmergencyId
          : activeEmergencyId // ignore: cast_nullable_to_non_nullable
              as String?,
      patientAge: freezed == patientAge
          ? _value.patientAge
          : patientAge // ignore: cast_nullable_to_non_nullable
              as int?,
      bloodType: freezed == bloodType
          ? _value.bloodType
          : bloodType // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$CaregiverConnectionImplCopyWith<$Res>
    implements $CaregiverConnectionCopyWith<$Res> {
  factory _$$CaregiverConnectionImplCopyWith(_$CaregiverConnectionImpl value,
          $Res Function(_$CaregiverConnectionImpl) then) =
      __$$CaregiverConnectionImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String patientId,
      String caregiverId,
      String? requesterId,
      String? patientName,
      String? patientEmail,
      String? caregiverName,
      String? caregiverEmail,
      String relationship,
      String status,
      DateTime? createdAt,
      DateTime? updatedAt,
      bool? hasActiveEmergency,
      String? activeEmergencyId,
      @JsonKey(fromJson: intFromJson) int? patientAge,
      String? bloodType});
}

/// @nodoc
class __$$CaregiverConnectionImplCopyWithImpl<$Res>
    extends _$CaregiverConnectionCopyWithImpl<$Res, _$CaregiverConnectionImpl>
    implements _$$CaregiverConnectionImplCopyWith<$Res> {
  __$$CaregiverConnectionImplCopyWithImpl(_$CaregiverConnectionImpl _value,
      $Res Function(_$CaregiverConnectionImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? patientId = null,
    Object? caregiverId = null,
    Object? requesterId = freezed,
    Object? patientName = freezed,
    Object? patientEmail = freezed,
    Object? caregiverName = freezed,
    Object? caregiverEmail = freezed,
    Object? relationship = null,
    Object? status = null,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
    Object? hasActiveEmergency = freezed,
    Object? activeEmergencyId = freezed,
    Object? patientAge = freezed,
    Object? bloodType = freezed,
  }) {
    return _then(_$CaregiverConnectionImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      patientId: null == patientId
          ? _value.patientId
          : patientId // ignore: cast_nullable_to_non_nullable
              as String,
      caregiverId: null == caregiverId
          ? _value.caregiverId
          : caregiverId // ignore: cast_nullable_to_non_nullable
              as String,
      requesterId: freezed == requesterId
          ? _value.requesterId
          : requesterId // ignore: cast_nullable_to_non_nullable
              as String?,
      patientName: freezed == patientName
          ? _value.patientName
          : patientName // ignore: cast_nullable_to_non_nullable
              as String?,
      patientEmail: freezed == patientEmail
          ? _value.patientEmail
          : patientEmail // ignore: cast_nullable_to_non_nullable
              as String?,
      caregiverName: freezed == caregiverName
          ? _value.caregiverName
          : caregiverName // ignore: cast_nullable_to_non_nullable
              as String?,
      caregiverEmail: freezed == caregiverEmail
          ? _value.caregiverEmail
          : caregiverEmail // ignore: cast_nullable_to_non_nullable
              as String?,
      relationship: null == relationship
          ? _value.relationship
          : relationship // ignore: cast_nullable_to_non_nullable
              as String,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: freezed == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      updatedAt: freezed == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      hasActiveEmergency: freezed == hasActiveEmergency
          ? _value.hasActiveEmergency
          : hasActiveEmergency // ignore: cast_nullable_to_non_nullable
              as bool?,
      activeEmergencyId: freezed == activeEmergencyId
          ? _value.activeEmergencyId
          : activeEmergencyId // ignore: cast_nullable_to_non_nullable
              as String?,
      patientAge: freezed == patientAge
          ? _value.patientAge
          : patientAge // ignore: cast_nullable_to_non_nullable
              as int?,
      bloodType: freezed == bloodType
          ? _value.bloodType
          : bloodType // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$CaregiverConnectionImpl implements _CaregiverConnection {
  const _$CaregiverConnectionImpl(
      {required this.id,
      required this.patientId,
      required this.caregiverId,
      this.requesterId,
      this.patientName,
      this.patientEmail,
      this.caregiverName,
      this.caregiverEmail,
      required this.relationship,
      required this.status,
      this.createdAt,
      this.updatedAt,
      this.hasActiveEmergency,
      this.activeEmergencyId,
      @JsonKey(fromJson: intFromJson) this.patientAge,
      this.bloodType});

  factory _$CaregiverConnectionImpl.fromJson(Map<String, dynamic> json) =>
      _$$CaregiverConnectionImplFromJson(json);

  @override
  final String id;
  @override
  final String patientId;
  @override
  final String caregiverId;
  @override
  final String? requesterId;
  @override
  final String? patientName;
  @override
  final String? patientEmail;
  @override
  final String? caregiverName;
  @override
  final String? caregiverEmail;
  @override
  final String relationship;
  @override
  final String status;
// PENDING, ACCEPTED, REJECTED
  @override
  final DateTime? createdAt;
  @override
  final DateTime? updatedAt;
  @override
  final bool? hasActiveEmergency;
  @override
  final String? activeEmergencyId;
  @override
  @JsonKey(fromJson: intFromJson)
  final int? patientAge;
  @override
  final String? bloodType;

  @override
  String toString() {
    return 'CaregiverConnection(id: $id, patientId: $patientId, caregiverId: $caregiverId, requesterId: $requesterId, patientName: $patientName, patientEmail: $patientEmail, caregiverName: $caregiverName, caregiverEmail: $caregiverEmail, relationship: $relationship, status: $status, createdAt: $createdAt, updatedAt: $updatedAt, hasActiveEmergency: $hasActiveEmergency, activeEmergencyId: $activeEmergencyId, patientAge: $patientAge, bloodType: $bloodType)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CaregiverConnectionImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.patientId, patientId) ||
                other.patientId == patientId) &&
            (identical(other.caregiverId, caregiverId) ||
                other.caregiverId == caregiverId) &&
            (identical(other.requesterId, requesterId) ||
                other.requesterId == requesterId) &&
            (identical(other.patientName, patientName) ||
                other.patientName == patientName) &&
            (identical(other.patientEmail, patientEmail) ||
                other.patientEmail == patientEmail) &&
            (identical(other.caregiverName, caregiverName) ||
                other.caregiverName == caregiverName) &&
            (identical(other.caregiverEmail, caregiverEmail) ||
                other.caregiverEmail == caregiverEmail) &&
            (identical(other.relationship, relationship) ||
                other.relationship == relationship) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            (identical(other.hasActiveEmergency, hasActiveEmergency) ||
                other.hasActiveEmergency == hasActiveEmergency) &&
            (identical(other.activeEmergencyId, activeEmergencyId) ||
                other.activeEmergencyId == activeEmergencyId) &&
            (identical(other.patientAge, patientAge) ||
                other.patientAge == patientAge) &&
            (identical(other.bloodType, bloodType) ||
                other.bloodType == bloodType));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      patientId,
      caregiverId,
      requesterId,
      patientName,
      patientEmail,
      caregiverName,
      caregiverEmail,
      relationship,
      status,
      createdAt,
      updatedAt,
      hasActiveEmergency,
      activeEmergencyId,
      patientAge,
      bloodType);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$CaregiverConnectionImplCopyWith<_$CaregiverConnectionImpl> get copyWith =>
      __$$CaregiverConnectionImplCopyWithImpl<_$CaregiverConnectionImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$CaregiverConnectionImplToJson(
      this,
    );
  }
}

abstract class _CaregiverConnection implements CaregiverConnection {
  const factory _CaregiverConnection(
      {required final String id,
      required final String patientId,
      required final String caregiverId,
      final String? requesterId,
      final String? patientName,
      final String? patientEmail,
      final String? caregiverName,
      final String? caregiverEmail,
      required final String relationship,
      required final String status,
      final DateTime? createdAt,
      final DateTime? updatedAt,
      final bool? hasActiveEmergency,
      final String? activeEmergencyId,
      @JsonKey(fromJson: intFromJson) final int? patientAge,
      final String? bloodType}) = _$CaregiverConnectionImpl;

  factory _CaregiverConnection.fromJson(Map<String, dynamic> json) =
      _$CaregiverConnectionImpl.fromJson;

  @override
  String get id;
  @override
  String get patientId;
  @override
  String get caregiverId;
  @override
  String? get requesterId;
  @override
  String? get patientName;
  @override
  String? get patientEmail;
  @override
  String? get caregiverName;
  @override
  String? get caregiverEmail;
  @override
  String get relationship;
  @override
  String get status;
  @override // PENDING, ACCEPTED, REJECTED
  DateTime? get createdAt;
  @override
  DateTime? get updatedAt;
  @override
  bool? get hasActiveEmergency;
  @override
  String? get activeEmergencyId;
  @override
  @JsonKey(fromJson: intFromJson)
  int? get patientAge;
  @override
  String? get bloodType;
  @override
  @JsonKey(ignore: true)
  _$$CaregiverConnectionImplCopyWith<_$CaregiverConnectionImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
