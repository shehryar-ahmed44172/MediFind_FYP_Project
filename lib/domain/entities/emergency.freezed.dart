// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'emergency.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

Emergency _$EmergencyFromJson(Map<String, dynamic> json) {
  return _Emergency.fromJson(json);
}

/// @nodoc
mixin _$Emergency {
  String get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'patientId')
  String get userId => throw _privateConstructorUsedError;
  String get status => throw _privateConstructorUsedError;
  String get emergencyType => throw _privateConstructorUsedError;
  @JsonKey(fromJson: doubleFromJson)
  double get latitude => throw _privateConstructorUsedError;
  @JsonKey(fromJson: doubleFromJson)
  double get longitude => throw _privateConstructorUsedError;
  DateTime? get createdAt => throw _privateConstructorUsedError;
  DateTime? get updatedAt => throw _privateConstructorUsedError;
  String? get responderId => throw _privateConstructorUsedError;
  bool get voiceAlertGenerated => throw _privateConstructorUsedError;
  String? get additionalInfo => throw _privateConstructorUsedError;
  DateTime? get completedAt => throw _privateConstructorUsedError;
  String get priority => throw _privateConstructorUsedError;
  DateTime? get expiresAt => throw _privateConstructorUsedError;
  String get patientType => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $EmergencyCopyWith<Emergency> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $EmergencyCopyWith<$Res> {
  factory $EmergencyCopyWith(Emergency value, $Res Function(Emergency) then) =
      _$EmergencyCopyWithImpl<$Res, Emergency>;
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'patientId') String userId,
      String status,
      String emergencyType,
      @JsonKey(fromJson: doubleFromJson) double latitude,
      @JsonKey(fromJson: doubleFromJson) double longitude,
      DateTime? createdAt,
      DateTime? updatedAt,
      String? responderId,
      bool voiceAlertGenerated,
      String? additionalInfo,
      DateTime? completedAt,
      String priority,
      DateTime? expiresAt,
      String patientType});
}

/// @nodoc
class _$EmergencyCopyWithImpl<$Res, $Val extends Emergency>
    implements $EmergencyCopyWith<$Res> {
  _$EmergencyCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? userId = null,
    Object? status = null,
    Object? emergencyType = null,
    Object? latitude = null,
    Object? longitude = null,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
    Object? responderId = freezed,
    Object? voiceAlertGenerated = null,
    Object? additionalInfo = freezed,
    Object? completedAt = freezed,
    Object? priority = null,
    Object? expiresAt = freezed,
    Object? patientType = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      userId: null == userId
          ? _value.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as String,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      emergencyType: null == emergencyType
          ? _value.emergencyType
          : emergencyType // ignore: cast_nullable_to_non_nullable
              as String,
      latitude: null == latitude
          ? _value.latitude
          : latitude // ignore: cast_nullable_to_non_nullable
              as double,
      longitude: null == longitude
          ? _value.longitude
          : longitude // ignore: cast_nullable_to_non_nullable
              as double,
      createdAt: freezed == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      updatedAt: freezed == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      responderId: freezed == responderId
          ? _value.responderId
          : responderId // ignore: cast_nullable_to_non_nullable
              as String?,
      voiceAlertGenerated: null == voiceAlertGenerated
          ? _value.voiceAlertGenerated
          : voiceAlertGenerated // ignore: cast_nullable_to_non_nullable
              as bool,
      additionalInfo: freezed == additionalInfo
          ? _value.additionalInfo
          : additionalInfo // ignore: cast_nullable_to_non_nullable
              as String?,
      completedAt: freezed == completedAt
          ? _value.completedAt
          : completedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      priority: null == priority
          ? _value.priority
          : priority // ignore: cast_nullable_to_non_nullable
              as String,
      expiresAt: freezed == expiresAt
          ? _value.expiresAt
          : expiresAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      patientType: null == patientType
          ? _value.patientType
          : patientType // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$EmergencyImplCopyWith<$Res>
    implements $EmergencyCopyWith<$Res> {
  factory _$$EmergencyImplCopyWith(
          _$EmergencyImpl value, $Res Function(_$EmergencyImpl) then) =
      __$$EmergencyImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'patientId') String userId,
      String status,
      String emergencyType,
      @JsonKey(fromJson: doubleFromJson) double latitude,
      @JsonKey(fromJson: doubleFromJson) double longitude,
      DateTime? createdAt,
      DateTime? updatedAt,
      String? responderId,
      bool voiceAlertGenerated,
      String? additionalInfo,
      DateTime? completedAt,
      String priority,
      DateTime? expiresAt,
      String patientType});
}

/// @nodoc
class __$$EmergencyImplCopyWithImpl<$Res>
    extends _$EmergencyCopyWithImpl<$Res, _$EmergencyImpl>
    implements _$$EmergencyImplCopyWith<$Res> {
  __$$EmergencyImplCopyWithImpl(
      _$EmergencyImpl _value, $Res Function(_$EmergencyImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? userId = null,
    Object? status = null,
    Object? emergencyType = null,
    Object? latitude = null,
    Object? longitude = null,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
    Object? responderId = freezed,
    Object? voiceAlertGenerated = null,
    Object? additionalInfo = freezed,
    Object? completedAt = freezed,
    Object? priority = null,
    Object? expiresAt = freezed,
    Object? patientType = null,
  }) {
    return _then(_$EmergencyImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      userId: null == userId
          ? _value.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as String,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      emergencyType: null == emergencyType
          ? _value.emergencyType
          : emergencyType // ignore: cast_nullable_to_non_nullable
              as String,
      latitude: null == latitude
          ? _value.latitude
          : latitude // ignore: cast_nullable_to_non_nullable
              as double,
      longitude: null == longitude
          ? _value.longitude
          : longitude // ignore: cast_nullable_to_non_nullable
              as double,
      createdAt: freezed == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      updatedAt: freezed == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      responderId: freezed == responderId
          ? _value.responderId
          : responderId // ignore: cast_nullable_to_non_nullable
              as String?,
      voiceAlertGenerated: null == voiceAlertGenerated
          ? _value.voiceAlertGenerated
          : voiceAlertGenerated // ignore: cast_nullable_to_non_nullable
              as bool,
      additionalInfo: freezed == additionalInfo
          ? _value.additionalInfo
          : additionalInfo // ignore: cast_nullable_to_non_nullable
              as String?,
      completedAt: freezed == completedAt
          ? _value.completedAt
          : completedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      priority: null == priority
          ? _value.priority
          : priority // ignore: cast_nullable_to_non_nullable
              as String,
      expiresAt: freezed == expiresAt
          ? _value.expiresAt
          : expiresAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      patientType: null == patientType
          ? _value.patientType
          : patientType // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$EmergencyImpl implements _Emergency {
  const _$EmergencyImpl(
      {this.id = '',
      @JsonKey(name: 'patientId') this.userId = '',
      this.status = 'PENDING',
      this.emergencyType = 'OTHER',
      @JsonKey(fromJson: doubleFromJson) this.latitude = 0.0,
      @JsonKey(fromJson: doubleFromJson) this.longitude = 0.0,
      this.createdAt,
      this.updatedAt,
      this.responderId,
      this.voiceAlertGenerated = false,
      this.additionalInfo,
      this.completedAt,
      this.priority = 'NORMAL',
      this.expiresAt,
      this.patientType = 'NORMAL'});

  factory _$EmergencyImpl.fromJson(Map<String, dynamic> json) =>
      _$$EmergencyImplFromJson(json);

  @override
  @JsonKey()
  final String id;
  @override
  @JsonKey(name: 'patientId')
  final String userId;
  @override
  @JsonKey()
  final String status;
  @override
  @JsonKey()
  final String emergencyType;
  @override
  @JsonKey(fromJson: doubleFromJson)
  final double latitude;
  @override
  @JsonKey(fromJson: doubleFromJson)
  final double longitude;
  @override
  final DateTime? createdAt;
  @override
  final DateTime? updatedAt;
  @override
  final String? responderId;
  @override
  @JsonKey()
  final bool voiceAlertGenerated;
  @override
  final String? additionalInfo;
  @override
  final DateTime? completedAt;
  @override
  @JsonKey()
  final String priority;
  @override
  final DateTime? expiresAt;
  @override
  @JsonKey()
  final String patientType;

  @override
  String toString() {
    return 'Emergency(id: $id, userId: $userId, status: $status, emergencyType: $emergencyType, latitude: $latitude, longitude: $longitude, createdAt: $createdAt, updatedAt: $updatedAt, responderId: $responderId, voiceAlertGenerated: $voiceAlertGenerated, additionalInfo: $additionalInfo, completedAt: $completedAt, priority: $priority, expiresAt: $expiresAt, patientType: $patientType)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$EmergencyImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.emergencyType, emergencyType) ||
                other.emergencyType == emergencyType) &&
            (identical(other.latitude, latitude) ||
                other.latitude == latitude) &&
            (identical(other.longitude, longitude) ||
                other.longitude == longitude) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            (identical(other.responderId, responderId) ||
                other.responderId == responderId) &&
            (identical(other.voiceAlertGenerated, voiceAlertGenerated) ||
                other.voiceAlertGenerated == voiceAlertGenerated) &&
            (identical(other.additionalInfo, additionalInfo) ||
                other.additionalInfo == additionalInfo) &&
            (identical(other.completedAt, completedAt) ||
                other.completedAt == completedAt) &&
            (identical(other.priority, priority) ||
                other.priority == priority) &&
            (identical(other.expiresAt, expiresAt) ||
                other.expiresAt == expiresAt) &&
            (identical(other.patientType, patientType) ||
                other.patientType == patientType));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      userId,
      status,
      emergencyType,
      latitude,
      longitude,
      createdAt,
      updatedAt,
      responderId,
      voiceAlertGenerated,
      additionalInfo,
      completedAt,
      priority,
      expiresAt,
      patientType);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$EmergencyImplCopyWith<_$EmergencyImpl> get copyWith =>
      __$$EmergencyImplCopyWithImpl<_$EmergencyImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$EmergencyImplToJson(
      this,
    );
  }
}

abstract class _Emergency implements Emergency {
  const factory _Emergency(
      {final String id,
      @JsonKey(name: 'patientId') final String userId,
      final String status,
      final String emergencyType,
      @JsonKey(fromJson: doubleFromJson) final double latitude,
      @JsonKey(fromJson: doubleFromJson) final double longitude,
      final DateTime? createdAt,
      final DateTime? updatedAt,
      final String? responderId,
      final bool voiceAlertGenerated,
      final String? additionalInfo,
      final DateTime? completedAt,
      final String priority,
      final DateTime? expiresAt,
      final String patientType}) = _$EmergencyImpl;

  factory _Emergency.fromJson(Map<String, dynamic> json) =
      _$EmergencyImpl.fromJson;

  @override
  String get id;
  @override
  @JsonKey(name: 'patientId')
  String get userId;
  @override
  String get status;
  @override
  String get emergencyType;
  @override
  @JsonKey(fromJson: doubleFromJson)
  double get latitude;
  @override
  @JsonKey(fromJson: doubleFromJson)
  double get longitude;
  @override
  DateTime? get createdAt;
  @override
  DateTime? get updatedAt;
  @override
  String? get responderId;
  @override
  bool get voiceAlertGenerated;
  @override
  String? get additionalInfo;
  @override
  DateTime? get completedAt;
  @override
  String get priority;
  @override
  DateTime? get expiresAt;
  @override
  String get patientType;
  @override
  @JsonKey(ignore: true)
  _$$EmergencyImplCopyWith<_$EmergencyImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

CreateEmergencyRequest _$CreateEmergencyRequestFromJson(
    Map<String, dynamic> json) {
  return _CreateEmergencyRequest.fromJson(json);
}

/// @nodoc
mixin _$CreateEmergencyRequest {
  String get emergencyType => throw _privateConstructorUsedError;
  @JsonKey(fromJson: doubleFromJson)
  double get latitude => throw _privateConstructorUsedError;
  @JsonKey(fromJson: doubleFromJson)
  double get longitude => throw _privateConstructorUsedError;
  String? get additionalInfo => throw _privateConstructorUsedError;
  String get priority => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $CreateEmergencyRequestCopyWith<CreateEmergencyRequest> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CreateEmergencyRequestCopyWith<$Res> {
  factory $CreateEmergencyRequestCopyWith(CreateEmergencyRequest value,
          $Res Function(CreateEmergencyRequest) then) =
      _$CreateEmergencyRequestCopyWithImpl<$Res, CreateEmergencyRequest>;
  @useResult
  $Res call(
      {String emergencyType,
      @JsonKey(fromJson: doubleFromJson) double latitude,
      @JsonKey(fromJson: doubleFromJson) double longitude,
      String? additionalInfo,
      String priority});
}

/// @nodoc
class _$CreateEmergencyRequestCopyWithImpl<$Res,
        $Val extends CreateEmergencyRequest>
    implements $CreateEmergencyRequestCopyWith<$Res> {
  _$CreateEmergencyRequestCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? emergencyType = null,
    Object? latitude = null,
    Object? longitude = null,
    Object? additionalInfo = freezed,
    Object? priority = null,
  }) {
    return _then(_value.copyWith(
      emergencyType: null == emergencyType
          ? _value.emergencyType
          : emergencyType // ignore: cast_nullable_to_non_nullable
              as String,
      latitude: null == latitude
          ? _value.latitude
          : latitude // ignore: cast_nullable_to_non_nullable
              as double,
      longitude: null == longitude
          ? _value.longitude
          : longitude // ignore: cast_nullable_to_non_nullable
              as double,
      additionalInfo: freezed == additionalInfo
          ? _value.additionalInfo
          : additionalInfo // ignore: cast_nullable_to_non_nullable
              as String?,
      priority: null == priority
          ? _value.priority
          : priority // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$CreateEmergencyRequestImplCopyWith<$Res>
    implements $CreateEmergencyRequestCopyWith<$Res> {
  factory _$$CreateEmergencyRequestImplCopyWith(
          _$CreateEmergencyRequestImpl value,
          $Res Function(_$CreateEmergencyRequestImpl) then) =
      __$$CreateEmergencyRequestImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String emergencyType,
      @JsonKey(fromJson: doubleFromJson) double latitude,
      @JsonKey(fromJson: doubleFromJson) double longitude,
      String? additionalInfo,
      String priority});
}

/// @nodoc
class __$$CreateEmergencyRequestImplCopyWithImpl<$Res>
    extends _$CreateEmergencyRequestCopyWithImpl<$Res,
        _$CreateEmergencyRequestImpl>
    implements _$$CreateEmergencyRequestImplCopyWith<$Res> {
  __$$CreateEmergencyRequestImplCopyWithImpl(
      _$CreateEmergencyRequestImpl _value,
      $Res Function(_$CreateEmergencyRequestImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? emergencyType = null,
    Object? latitude = null,
    Object? longitude = null,
    Object? additionalInfo = freezed,
    Object? priority = null,
  }) {
    return _then(_$CreateEmergencyRequestImpl(
      emergencyType: null == emergencyType
          ? _value.emergencyType
          : emergencyType // ignore: cast_nullable_to_non_nullable
              as String,
      latitude: null == latitude
          ? _value.latitude
          : latitude // ignore: cast_nullable_to_non_nullable
              as double,
      longitude: null == longitude
          ? _value.longitude
          : longitude // ignore: cast_nullable_to_non_nullable
              as double,
      additionalInfo: freezed == additionalInfo
          ? _value.additionalInfo
          : additionalInfo // ignore: cast_nullable_to_non_nullable
              as String?,
      priority: null == priority
          ? _value.priority
          : priority // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$CreateEmergencyRequestImpl implements _CreateEmergencyRequest {
  const _$CreateEmergencyRequestImpl(
      {required this.emergencyType,
      @JsonKey(fromJson: doubleFromJson) required this.latitude,
      @JsonKey(fromJson: doubleFromJson) required this.longitude,
      this.additionalInfo,
      this.priority = 'NORMAL'});

  factory _$CreateEmergencyRequestImpl.fromJson(Map<String, dynamic> json) =>
      _$$CreateEmergencyRequestImplFromJson(json);

  @override
  final String emergencyType;
  @override
  @JsonKey(fromJson: doubleFromJson)
  final double latitude;
  @override
  @JsonKey(fromJson: doubleFromJson)
  final double longitude;
  @override
  final String? additionalInfo;
  @override
  @JsonKey()
  final String priority;

  @override
  String toString() {
    return 'CreateEmergencyRequest(emergencyType: $emergencyType, latitude: $latitude, longitude: $longitude, additionalInfo: $additionalInfo, priority: $priority)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CreateEmergencyRequestImpl &&
            (identical(other.emergencyType, emergencyType) ||
                other.emergencyType == emergencyType) &&
            (identical(other.latitude, latitude) ||
                other.latitude == latitude) &&
            (identical(other.longitude, longitude) ||
                other.longitude == longitude) &&
            (identical(other.additionalInfo, additionalInfo) ||
                other.additionalInfo == additionalInfo) &&
            (identical(other.priority, priority) ||
                other.priority == priority));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(runtimeType, emergencyType, latitude,
      longitude, additionalInfo, priority);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$CreateEmergencyRequestImplCopyWith<_$CreateEmergencyRequestImpl>
      get copyWith => __$$CreateEmergencyRequestImplCopyWithImpl<
          _$CreateEmergencyRequestImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$CreateEmergencyRequestImplToJson(
      this,
    );
  }
}

abstract class _CreateEmergencyRequest implements CreateEmergencyRequest {
  const factory _CreateEmergencyRequest(
      {required final String emergencyType,
      @JsonKey(fromJson: doubleFromJson) required final double latitude,
      @JsonKey(fromJson: doubleFromJson) required final double longitude,
      final String? additionalInfo,
      final String priority}) = _$CreateEmergencyRequestImpl;

  factory _CreateEmergencyRequest.fromJson(Map<String, dynamic> json) =
      _$CreateEmergencyRequestImpl.fromJson;

  @override
  String get emergencyType;
  @override
  @JsonKey(fromJson: doubleFromJson)
  double get latitude;
  @override
  @JsonKey(fromJson: doubleFromJson)
  double get longitude;
  @override
  String? get additionalInfo;
  @override
  String get priority;
  @override
  @JsonKey(ignore: true)
  _$$CreateEmergencyRequestImplCopyWith<_$CreateEmergencyRequestImpl>
      get copyWith => throw _privateConstructorUsedError;
}

UpdateEmergencyStatusRequest _$UpdateEmergencyStatusRequestFromJson(
    Map<String, dynamic> json) {
  return _UpdateEmergencyStatusRequest.fromJson(json);
}

/// @nodoc
mixin _$UpdateEmergencyStatusRequest {
  String get status => throw _privateConstructorUsedError;
  String? get responderId => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $UpdateEmergencyStatusRequestCopyWith<UpdateEmergencyStatusRequest>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $UpdateEmergencyStatusRequestCopyWith<$Res> {
  factory $UpdateEmergencyStatusRequestCopyWith(
          UpdateEmergencyStatusRequest value,
          $Res Function(UpdateEmergencyStatusRequest) then) =
      _$UpdateEmergencyStatusRequestCopyWithImpl<$Res,
          UpdateEmergencyStatusRequest>;
  @useResult
  $Res call({String status, String? responderId});
}

/// @nodoc
class _$UpdateEmergencyStatusRequestCopyWithImpl<$Res,
        $Val extends UpdateEmergencyStatusRequest>
    implements $UpdateEmergencyStatusRequestCopyWith<$Res> {
  _$UpdateEmergencyStatusRequestCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? status = null,
    Object? responderId = freezed,
  }) {
    return _then(_value.copyWith(
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      responderId: freezed == responderId
          ? _value.responderId
          : responderId // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$UpdateEmergencyStatusRequestImplCopyWith<$Res>
    implements $UpdateEmergencyStatusRequestCopyWith<$Res> {
  factory _$$UpdateEmergencyStatusRequestImplCopyWith(
          _$UpdateEmergencyStatusRequestImpl value,
          $Res Function(_$UpdateEmergencyStatusRequestImpl) then) =
      __$$UpdateEmergencyStatusRequestImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String status, String? responderId});
}

/// @nodoc
class __$$UpdateEmergencyStatusRequestImplCopyWithImpl<$Res>
    extends _$UpdateEmergencyStatusRequestCopyWithImpl<$Res,
        _$UpdateEmergencyStatusRequestImpl>
    implements _$$UpdateEmergencyStatusRequestImplCopyWith<$Res> {
  __$$UpdateEmergencyStatusRequestImplCopyWithImpl(
      _$UpdateEmergencyStatusRequestImpl _value,
      $Res Function(_$UpdateEmergencyStatusRequestImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? status = null,
    Object? responderId = freezed,
  }) {
    return _then(_$UpdateEmergencyStatusRequestImpl(
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      responderId: freezed == responderId
          ? _value.responderId
          : responderId // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$UpdateEmergencyStatusRequestImpl
    implements _UpdateEmergencyStatusRequest {
  const _$UpdateEmergencyStatusRequestImpl(
      {required this.status, this.responderId});

  factory _$UpdateEmergencyStatusRequestImpl.fromJson(
          Map<String, dynamic> json) =>
      _$$UpdateEmergencyStatusRequestImplFromJson(json);

  @override
  final String status;
  @override
  final String? responderId;

  @override
  String toString() {
    return 'UpdateEmergencyStatusRequest(status: $status, responderId: $responderId)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$UpdateEmergencyStatusRequestImpl &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.responderId, responderId) ||
                other.responderId == responderId));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(runtimeType, status, responderId);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$UpdateEmergencyStatusRequestImplCopyWith<
          _$UpdateEmergencyStatusRequestImpl>
      get copyWith => __$$UpdateEmergencyStatusRequestImplCopyWithImpl<
          _$UpdateEmergencyStatusRequestImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$UpdateEmergencyStatusRequestImplToJson(
      this,
    );
  }
}

abstract class _UpdateEmergencyStatusRequest
    implements UpdateEmergencyStatusRequest {
  const factory _UpdateEmergencyStatusRequest(
      {required final String status,
      final String? responderId}) = _$UpdateEmergencyStatusRequestImpl;

  factory _UpdateEmergencyStatusRequest.fromJson(Map<String, dynamic> json) =
      _$UpdateEmergencyStatusRequestImpl.fromJson;

  @override
  String get status;
  @override
  String? get responderId;
  @override
  @JsonKey(ignore: true)
  _$$UpdateEmergencyStatusRequestImplCopyWith<
          _$UpdateEmergencyStatusRequestImpl>
      get copyWith => throw _privateConstructorUsedError;
}

EmergencyLocation _$EmergencyLocationFromJson(Map<String, dynamic> json) {
  return _EmergencyLocation.fromJson(json);
}

/// @nodoc
mixin _$EmergencyLocation {
  String get emergencyId => throw _privateConstructorUsedError;
  @JsonKey(fromJson: doubleFromJson)
  double get latitude => throw _privateConstructorUsedError;
  @JsonKey(fromJson: doubleFromJson)
  double get longitude => throw _privateConstructorUsedError;
  DateTime get timestamp => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $EmergencyLocationCopyWith<EmergencyLocation> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $EmergencyLocationCopyWith<$Res> {
  factory $EmergencyLocationCopyWith(
          EmergencyLocation value, $Res Function(EmergencyLocation) then) =
      _$EmergencyLocationCopyWithImpl<$Res, EmergencyLocation>;
  @useResult
  $Res call(
      {String emergencyId,
      @JsonKey(fromJson: doubleFromJson) double latitude,
      @JsonKey(fromJson: doubleFromJson) double longitude,
      DateTime timestamp});
}

/// @nodoc
class _$EmergencyLocationCopyWithImpl<$Res, $Val extends EmergencyLocation>
    implements $EmergencyLocationCopyWith<$Res> {
  _$EmergencyLocationCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? emergencyId = null,
    Object? latitude = null,
    Object? longitude = null,
    Object? timestamp = null,
  }) {
    return _then(_value.copyWith(
      emergencyId: null == emergencyId
          ? _value.emergencyId
          : emergencyId // ignore: cast_nullable_to_non_nullable
              as String,
      latitude: null == latitude
          ? _value.latitude
          : latitude // ignore: cast_nullable_to_non_nullable
              as double,
      longitude: null == longitude
          ? _value.longitude
          : longitude // ignore: cast_nullable_to_non_nullable
              as double,
      timestamp: null == timestamp
          ? _value.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$EmergencyLocationImplCopyWith<$Res>
    implements $EmergencyLocationCopyWith<$Res> {
  factory _$$EmergencyLocationImplCopyWith(_$EmergencyLocationImpl value,
          $Res Function(_$EmergencyLocationImpl) then) =
      __$$EmergencyLocationImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String emergencyId,
      @JsonKey(fromJson: doubleFromJson) double latitude,
      @JsonKey(fromJson: doubleFromJson) double longitude,
      DateTime timestamp});
}

/// @nodoc
class __$$EmergencyLocationImplCopyWithImpl<$Res>
    extends _$EmergencyLocationCopyWithImpl<$Res, _$EmergencyLocationImpl>
    implements _$$EmergencyLocationImplCopyWith<$Res> {
  __$$EmergencyLocationImplCopyWithImpl(_$EmergencyLocationImpl _value,
      $Res Function(_$EmergencyLocationImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? emergencyId = null,
    Object? latitude = null,
    Object? longitude = null,
    Object? timestamp = null,
  }) {
    return _then(_$EmergencyLocationImpl(
      emergencyId: null == emergencyId
          ? _value.emergencyId
          : emergencyId // ignore: cast_nullable_to_non_nullable
              as String,
      latitude: null == latitude
          ? _value.latitude
          : latitude // ignore: cast_nullable_to_non_nullable
              as double,
      longitude: null == longitude
          ? _value.longitude
          : longitude // ignore: cast_nullable_to_non_nullable
              as double,
      timestamp: null == timestamp
          ? _value.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$EmergencyLocationImpl implements _EmergencyLocation {
  const _$EmergencyLocationImpl(
      {required this.emergencyId,
      @JsonKey(fromJson: doubleFromJson) required this.latitude,
      @JsonKey(fromJson: doubleFromJson) required this.longitude,
      required this.timestamp});

  factory _$EmergencyLocationImpl.fromJson(Map<String, dynamic> json) =>
      _$$EmergencyLocationImplFromJson(json);

  @override
  final String emergencyId;
  @override
  @JsonKey(fromJson: doubleFromJson)
  final double latitude;
  @override
  @JsonKey(fromJson: doubleFromJson)
  final double longitude;
  @override
  final DateTime timestamp;

  @override
  String toString() {
    return 'EmergencyLocation(emergencyId: $emergencyId, latitude: $latitude, longitude: $longitude, timestamp: $timestamp)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$EmergencyLocationImpl &&
            (identical(other.emergencyId, emergencyId) ||
                other.emergencyId == emergencyId) &&
            (identical(other.latitude, latitude) ||
                other.latitude == latitude) &&
            (identical(other.longitude, longitude) ||
                other.longitude == longitude) &&
            (identical(other.timestamp, timestamp) ||
                other.timestamp == timestamp));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode =>
      Object.hash(runtimeType, emergencyId, latitude, longitude, timestamp);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$EmergencyLocationImplCopyWith<_$EmergencyLocationImpl> get copyWith =>
      __$$EmergencyLocationImplCopyWithImpl<_$EmergencyLocationImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$EmergencyLocationImplToJson(
      this,
    );
  }
}

abstract class _EmergencyLocation implements EmergencyLocation {
  const factory _EmergencyLocation(
      {required final String emergencyId,
      @JsonKey(fromJson: doubleFromJson) required final double latitude,
      @JsonKey(fromJson: doubleFromJson) required final double longitude,
      required final DateTime timestamp}) = _$EmergencyLocationImpl;

  factory _EmergencyLocation.fromJson(Map<String, dynamic> json) =
      _$EmergencyLocationImpl.fromJson;

  @override
  String get emergencyId;
  @override
  @JsonKey(fromJson: doubleFromJson)
  double get latitude;
  @override
  @JsonKey(fromJson: doubleFromJson)
  double get longitude;
  @override
  DateTime get timestamp;
  @override
  @JsonKey(ignore: true)
  _$$EmergencyLocationImplCopyWith<_$EmergencyLocationImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

EmergencyResponse _$EmergencyResponseFromJson(Map<String, dynamic> json) {
  return _EmergencyResponse.fromJson(json);
}

/// @nodoc
mixin _$EmergencyResponse {
  String get responderId => throw _privateConstructorUsedError;
  String get emergencyId => throw _privateConstructorUsedError;
  String get status => throw _privateConstructorUsedError;
  DateTime? get estimatedArrivalTime => throw _privateConstructorUsedError;
  String? get notes => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $EmergencyResponseCopyWith<EmergencyResponse> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $EmergencyResponseCopyWith<$Res> {
  factory $EmergencyResponseCopyWith(
          EmergencyResponse value, $Res Function(EmergencyResponse) then) =
      _$EmergencyResponseCopyWithImpl<$Res, EmergencyResponse>;
  @useResult
  $Res call(
      {String responderId,
      String emergencyId,
      String status,
      DateTime? estimatedArrivalTime,
      String? notes});
}

/// @nodoc
class _$EmergencyResponseCopyWithImpl<$Res, $Val extends EmergencyResponse>
    implements $EmergencyResponseCopyWith<$Res> {
  _$EmergencyResponseCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? responderId = null,
    Object? emergencyId = null,
    Object? status = null,
    Object? estimatedArrivalTime = freezed,
    Object? notes = freezed,
  }) {
    return _then(_value.copyWith(
      responderId: null == responderId
          ? _value.responderId
          : responderId // ignore: cast_nullable_to_non_nullable
              as String,
      emergencyId: null == emergencyId
          ? _value.emergencyId
          : emergencyId // ignore: cast_nullable_to_non_nullable
              as String,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      estimatedArrivalTime: freezed == estimatedArrivalTime
          ? _value.estimatedArrivalTime
          : estimatedArrivalTime // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      notes: freezed == notes
          ? _value.notes
          : notes // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$EmergencyResponseImplCopyWith<$Res>
    implements $EmergencyResponseCopyWith<$Res> {
  factory _$$EmergencyResponseImplCopyWith(_$EmergencyResponseImpl value,
          $Res Function(_$EmergencyResponseImpl) then) =
      __$$EmergencyResponseImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String responderId,
      String emergencyId,
      String status,
      DateTime? estimatedArrivalTime,
      String? notes});
}

/// @nodoc
class __$$EmergencyResponseImplCopyWithImpl<$Res>
    extends _$EmergencyResponseCopyWithImpl<$Res, _$EmergencyResponseImpl>
    implements _$$EmergencyResponseImplCopyWith<$Res> {
  __$$EmergencyResponseImplCopyWithImpl(_$EmergencyResponseImpl _value,
      $Res Function(_$EmergencyResponseImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? responderId = null,
    Object? emergencyId = null,
    Object? status = null,
    Object? estimatedArrivalTime = freezed,
    Object? notes = freezed,
  }) {
    return _then(_$EmergencyResponseImpl(
      responderId: null == responderId
          ? _value.responderId
          : responderId // ignore: cast_nullable_to_non_nullable
              as String,
      emergencyId: null == emergencyId
          ? _value.emergencyId
          : emergencyId // ignore: cast_nullable_to_non_nullable
              as String,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      estimatedArrivalTime: freezed == estimatedArrivalTime
          ? _value.estimatedArrivalTime
          : estimatedArrivalTime // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      notes: freezed == notes
          ? _value.notes
          : notes // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$EmergencyResponseImpl implements _EmergencyResponse {
  const _$EmergencyResponseImpl(
      {required this.responderId,
      required this.emergencyId,
      required this.status,
      this.estimatedArrivalTime,
      this.notes});

  factory _$EmergencyResponseImpl.fromJson(Map<String, dynamic> json) =>
      _$$EmergencyResponseImplFromJson(json);

  @override
  final String responderId;
  @override
  final String emergencyId;
  @override
  final String status;
  @override
  final DateTime? estimatedArrivalTime;
  @override
  final String? notes;

  @override
  String toString() {
    return 'EmergencyResponse(responderId: $responderId, emergencyId: $emergencyId, status: $status, estimatedArrivalTime: $estimatedArrivalTime, notes: $notes)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$EmergencyResponseImpl &&
            (identical(other.responderId, responderId) ||
                other.responderId == responderId) &&
            (identical(other.emergencyId, emergencyId) ||
                other.emergencyId == emergencyId) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.estimatedArrivalTime, estimatedArrivalTime) ||
                other.estimatedArrivalTime == estimatedArrivalTime) &&
            (identical(other.notes, notes) || other.notes == notes));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(runtimeType, responderId, emergencyId, status,
      estimatedArrivalTime, notes);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$EmergencyResponseImplCopyWith<_$EmergencyResponseImpl> get copyWith =>
      __$$EmergencyResponseImplCopyWithImpl<_$EmergencyResponseImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$EmergencyResponseImplToJson(
      this,
    );
  }
}

abstract class _EmergencyResponse implements EmergencyResponse {
  const factory _EmergencyResponse(
      {required final String responderId,
      required final String emergencyId,
      required final String status,
      final DateTime? estimatedArrivalTime,
      final String? notes}) = _$EmergencyResponseImpl;

  factory _EmergencyResponse.fromJson(Map<String, dynamic> json) =
      _$EmergencyResponseImpl.fromJson;

  @override
  String get responderId;
  @override
  String get emergencyId;
  @override
  String get status;
  @override
  DateTime? get estimatedArrivalTime;
  @override
  String? get notes;
  @override
  @JsonKey(ignore: true)
  _$$EmergencyResponseImplCopyWith<_$EmergencyResponseImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
