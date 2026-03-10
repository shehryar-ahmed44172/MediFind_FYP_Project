// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'medical_profile.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

MedicalProfile _$MedicalProfileFromJson(Map<String, dynamic> json) {
  return _MedicalProfile.fromJson(json);
}

/// @nodoc
mixin _$MedicalProfile {
  String get id => throw _privateConstructorUsedError;
  String get userId => throw _privateConstructorUsedError;
  String get bloodType => throw _privateConstructorUsedError;
  List<String> get chronicDiseases => throw _privateConstructorUsedError;
  List<String> get allergies => throw _privateConstructorUsedError;
  List<Medication> get medications => throw _privateConstructorUsedError;
  List<EmergencyContact> get emergencyContacts =>
      throw _privateConstructorUsedError;
  String? get medicalHistory => throw _privateConstructorUsedError;
  String? get disabilityType => throw _privateConstructorUsedError;
  String? get additionalNotes => throw _privateConstructorUsedError;
  DateTime? get lastUpdated => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $MedicalProfileCopyWith<MedicalProfile> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MedicalProfileCopyWith<$Res> {
  factory $MedicalProfileCopyWith(
          MedicalProfile value, $Res Function(MedicalProfile) then) =
      _$MedicalProfileCopyWithImpl<$Res, MedicalProfile>;
  @useResult
  $Res call(
      {String id,
      String userId,
      String bloodType,
      List<String> chronicDiseases,
      List<String> allergies,
      List<Medication> medications,
      List<EmergencyContact> emergencyContacts,
      String? medicalHistory,
      String? disabilityType,
      String? additionalNotes,
      DateTime? lastUpdated});
}

/// @nodoc
class _$MedicalProfileCopyWithImpl<$Res, $Val extends MedicalProfile>
    implements $MedicalProfileCopyWith<$Res> {
  _$MedicalProfileCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? userId = null,
    Object? bloodType = null,
    Object? chronicDiseases = null,
    Object? allergies = null,
    Object? medications = null,
    Object? emergencyContacts = null,
    Object? medicalHistory = freezed,
    Object? disabilityType = freezed,
    Object? additionalNotes = freezed,
    Object? lastUpdated = freezed,
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
      bloodType: null == bloodType
          ? _value.bloodType
          : bloodType // ignore: cast_nullable_to_non_nullable
              as String,
      chronicDiseases: null == chronicDiseases
          ? _value.chronicDiseases
          : chronicDiseases // ignore: cast_nullable_to_non_nullable
              as List<String>,
      allergies: null == allergies
          ? _value.allergies
          : allergies // ignore: cast_nullable_to_non_nullable
              as List<String>,
      medications: null == medications
          ? _value.medications
          : medications // ignore: cast_nullable_to_non_nullable
              as List<Medication>,
      emergencyContacts: null == emergencyContacts
          ? _value.emergencyContacts
          : emergencyContacts // ignore: cast_nullable_to_non_nullable
              as List<EmergencyContact>,
      medicalHistory: freezed == medicalHistory
          ? _value.medicalHistory
          : medicalHistory // ignore: cast_nullable_to_non_nullable
              as String?,
      disabilityType: freezed == disabilityType
          ? _value.disabilityType
          : disabilityType // ignore: cast_nullable_to_non_nullable
              as String?,
      additionalNotes: freezed == additionalNotes
          ? _value.additionalNotes
          : additionalNotes // ignore: cast_nullable_to_non_nullable
              as String?,
      lastUpdated: freezed == lastUpdated
          ? _value.lastUpdated
          : lastUpdated // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$MedicalProfileImplCopyWith<$Res>
    implements $MedicalProfileCopyWith<$Res> {
  factory _$$MedicalProfileImplCopyWith(_$MedicalProfileImpl value,
          $Res Function(_$MedicalProfileImpl) then) =
      __$$MedicalProfileImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String userId,
      String bloodType,
      List<String> chronicDiseases,
      List<String> allergies,
      List<Medication> medications,
      List<EmergencyContact> emergencyContacts,
      String? medicalHistory,
      String? disabilityType,
      String? additionalNotes,
      DateTime? lastUpdated});
}

/// @nodoc
class __$$MedicalProfileImplCopyWithImpl<$Res>
    extends _$MedicalProfileCopyWithImpl<$Res, _$MedicalProfileImpl>
    implements _$$MedicalProfileImplCopyWith<$Res> {
  __$$MedicalProfileImplCopyWithImpl(
      _$MedicalProfileImpl _value, $Res Function(_$MedicalProfileImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? userId = null,
    Object? bloodType = null,
    Object? chronicDiseases = null,
    Object? allergies = null,
    Object? medications = null,
    Object? emergencyContacts = null,
    Object? medicalHistory = freezed,
    Object? disabilityType = freezed,
    Object? additionalNotes = freezed,
    Object? lastUpdated = freezed,
  }) {
    return _then(_$MedicalProfileImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      userId: null == userId
          ? _value.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as String,
      bloodType: null == bloodType
          ? _value.bloodType
          : bloodType // ignore: cast_nullable_to_non_nullable
              as String,
      chronicDiseases: null == chronicDiseases
          ? _value._chronicDiseases
          : chronicDiseases // ignore: cast_nullable_to_non_nullable
              as List<String>,
      allergies: null == allergies
          ? _value._allergies
          : allergies // ignore: cast_nullable_to_non_nullable
              as List<String>,
      medications: null == medications
          ? _value._medications
          : medications // ignore: cast_nullable_to_non_nullable
              as List<Medication>,
      emergencyContacts: null == emergencyContacts
          ? _value._emergencyContacts
          : emergencyContacts // ignore: cast_nullable_to_non_nullable
              as List<EmergencyContact>,
      medicalHistory: freezed == medicalHistory
          ? _value.medicalHistory
          : medicalHistory // ignore: cast_nullable_to_non_nullable
              as String?,
      disabilityType: freezed == disabilityType
          ? _value.disabilityType
          : disabilityType // ignore: cast_nullable_to_non_nullable
              as String?,
      additionalNotes: freezed == additionalNotes
          ? _value.additionalNotes
          : additionalNotes // ignore: cast_nullable_to_non_nullable
              as String?,
      lastUpdated: freezed == lastUpdated
          ? _value.lastUpdated
          : lastUpdated // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$MedicalProfileImpl implements _MedicalProfile {
  const _$MedicalProfileImpl(
      {required this.id,
      required this.userId,
      required this.bloodType,
      final List<String> chronicDiseases = const [],
      final List<String> allergies = const [],
      final List<Medication> medications = const [],
      final List<EmergencyContact> emergencyContacts = const [],
      this.medicalHistory,
      this.disabilityType,
      this.additionalNotes,
      this.lastUpdated})
      : _chronicDiseases = chronicDiseases,
        _allergies = allergies,
        _medications = medications,
        _emergencyContacts = emergencyContacts;

  factory _$MedicalProfileImpl.fromJson(Map<String, dynamic> json) =>
      _$$MedicalProfileImplFromJson(json);

  @override
  final String id;
  @override
  final String userId;
  @override
  final String bloodType;
  final List<String> _chronicDiseases;
  @override
  @JsonKey()
  List<String> get chronicDiseases {
    if (_chronicDiseases is EqualUnmodifiableListView) return _chronicDiseases;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_chronicDiseases);
  }

  final List<String> _allergies;
  @override
  @JsonKey()
  List<String> get allergies {
    if (_allergies is EqualUnmodifiableListView) return _allergies;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_allergies);
  }

  final List<Medication> _medications;
  @override
  @JsonKey()
  List<Medication> get medications {
    if (_medications is EqualUnmodifiableListView) return _medications;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_medications);
  }

  final List<EmergencyContact> _emergencyContacts;
  @override
  @JsonKey()
  List<EmergencyContact> get emergencyContacts {
    if (_emergencyContacts is EqualUnmodifiableListView)
      return _emergencyContacts;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_emergencyContacts);
  }

  @override
  final String? medicalHistory;
  @override
  final String? disabilityType;
  @override
  final String? additionalNotes;
  @override
  final DateTime? lastUpdated;

  @override
  String toString() {
    return 'MedicalProfile(id: $id, userId: $userId, bloodType: $bloodType, chronicDiseases: $chronicDiseases, allergies: $allergies, medications: $medications, emergencyContacts: $emergencyContacts, medicalHistory: $medicalHistory, disabilityType: $disabilityType, additionalNotes: $additionalNotes, lastUpdated: $lastUpdated)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MedicalProfileImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.bloodType, bloodType) ||
                other.bloodType == bloodType) &&
            const DeepCollectionEquality()
                .equals(other._chronicDiseases, _chronicDiseases) &&
            const DeepCollectionEquality()
                .equals(other._allergies, _allergies) &&
            const DeepCollectionEquality()
                .equals(other._medications, _medications) &&
            const DeepCollectionEquality()
                .equals(other._emergencyContacts, _emergencyContacts) &&
            (identical(other.medicalHistory, medicalHistory) ||
                other.medicalHistory == medicalHistory) &&
            (identical(other.disabilityType, disabilityType) ||
                other.disabilityType == disabilityType) &&
            (identical(other.additionalNotes, additionalNotes) ||
                other.additionalNotes == additionalNotes) &&
            (identical(other.lastUpdated, lastUpdated) ||
                other.lastUpdated == lastUpdated));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      userId,
      bloodType,
      const DeepCollectionEquality().hash(_chronicDiseases),
      const DeepCollectionEquality().hash(_allergies),
      const DeepCollectionEquality().hash(_medications),
      const DeepCollectionEquality().hash(_emergencyContacts),
      medicalHistory,
      disabilityType,
      additionalNotes,
      lastUpdated);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$MedicalProfileImplCopyWith<_$MedicalProfileImpl> get copyWith =>
      __$$MedicalProfileImplCopyWithImpl<_$MedicalProfileImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$MedicalProfileImplToJson(
      this,
    );
  }
}

abstract class _MedicalProfile implements MedicalProfile {
  const factory _MedicalProfile(
      {required final String id,
      required final String userId,
      required final String bloodType,
      final List<String> chronicDiseases,
      final List<String> allergies,
      final List<Medication> medications,
      final List<EmergencyContact> emergencyContacts,
      final String? medicalHistory,
      final String? disabilityType,
      final String? additionalNotes,
      final DateTime? lastUpdated}) = _$MedicalProfileImpl;

  factory _MedicalProfile.fromJson(Map<String, dynamic> json) =
      _$MedicalProfileImpl.fromJson;

  @override
  String get id;
  @override
  String get userId;
  @override
  String get bloodType;
  @override
  List<String> get chronicDiseases;
  @override
  List<String> get allergies;
  @override
  List<Medication> get medications;
  @override
  List<EmergencyContact> get emergencyContacts;
  @override
  String? get medicalHistory;
  @override
  String? get disabilityType;
  @override
  String? get additionalNotes;
  @override
  DateTime? get lastUpdated;
  @override
  @JsonKey(ignore: true)
  _$$MedicalProfileImplCopyWith<_$MedicalProfileImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

Medication _$MedicationFromJson(Map<String, dynamic> json) {
  return _Medication.fromJson(json);
}

/// @nodoc
mixin _$Medication {
  String get name => throw _privateConstructorUsedError;
  String get dosage => throw _privateConstructorUsedError;
  String get frequency => throw _privateConstructorUsedError;
  String? get reason => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $MedicationCopyWith<Medication> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MedicationCopyWith<$Res> {
  factory $MedicationCopyWith(
          Medication value, $Res Function(Medication) then) =
      _$MedicationCopyWithImpl<$Res, Medication>;
  @useResult
  $Res call({String name, String dosage, String frequency, String? reason});
}

/// @nodoc
class _$MedicationCopyWithImpl<$Res, $Val extends Medication>
    implements $MedicationCopyWith<$Res> {
  _$MedicationCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = null,
    Object? dosage = null,
    Object? frequency = null,
    Object? reason = freezed,
  }) {
    return _then(_value.copyWith(
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      dosage: null == dosage
          ? _value.dosage
          : dosage // ignore: cast_nullable_to_non_nullable
              as String,
      frequency: null == frequency
          ? _value.frequency
          : frequency // ignore: cast_nullable_to_non_nullable
              as String,
      reason: freezed == reason
          ? _value.reason
          : reason // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$MedicationImplCopyWith<$Res>
    implements $MedicationCopyWith<$Res> {
  factory _$$MedicationImplCopyWith(
          _$MedicationImpl value, $Res Function(_$MedicationImpl) then) =
      __$$MedicationImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String name, String dosage, String frequency, String? reason});
}

/// @nodoc
class __$$MedicationImplCopyWithImpl<$Res>
    extends _$MedicationCopyWithImpl<$Res, _$MedicationImpl>
    implements _$$MedicationImplCopyWith<$Res> {
  __$$MedicationImplCopyWithImpl(
      _$MedicationImpl _value, $Res Function(_$MedicationImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = null,
    Object? dosage = null,
    Object? frequency = null,
    Object? reason = freezed,
  }) {
    return _then(_$MedicationImpl(
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      dosage: null == dosage
          ? _value.dosage
          : dosage // ignore: cast_nullable_to_non_nullable
              as String,
      frequency: null == frequency
          ? _value.frequency
          : frequency // ignore: cast_nullable_to_non_nullable
              as String,
      reason: freezed == reason
          ? _value.reason
          : reason // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$MedicationImpl implements _Medication {
  const _$MedicationImpl(
      {required this.name, this.dosage = '', this.frequency = '', this.reason});

  factory _$MedicationImpl.fromJson(Map<String, dynamic> json) =>
      _$$MedicationImplFromJson(json);

  @override
  final String name;
  @override
  @JsonKey()
  final String dosage;
  @override
  @JsonKey()
  final String frequency;
  @override
  final String? reason;

  @override
  String toString() {
    return 'Medication(name: $name, dosage: $dosage, frequency: $frequency, reason: $reason)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MedicationImpl &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.dosage, dosage) || other.dosage == dosage) &&
            (identical(other.frequency, frequency) ||
                other.frequency == frequency) &&
            (identical(other.reason, reason) || other.reason == reason));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(runtimeType, name, dosage, frequency, reason);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$MedicationImplCopyWith<_$MedicationImpl> get copyWith =>
      __$$MedicationImplCopyWithImpl<_$MedicationImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$MedicationImplToJson(
      this,
    );
  }
}

abstract class _Medication implements Medication {
  const factory _Medication(
      {required final String name,
      final String dosage,
      final String frequency,
      final String? reason}) = _$MedicationImpl;

  factory _Medication.fromJson(Map<String, dynamic> json) =
      _$MedicationImpl.fromJson;

  @override
  String get name;
  @override
  String get dosage;
  @override
  String get frequency;
  @override
  String? get reason;
  @override
  @JsonKey(ignore: true)
  _$$MedicationImplCopyWith<_$MedicationImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

EmergencyContact _$EmergencyContactFromJson(Map<String, dynamic> json) {
  return _EmergencyContact.fromJson(json);
}

/// @nodoc
mixin _$EmergencyContact {
  String get name => throw _privateConstructorUsedError;
  String get phoneNumber => throw _privateConstructorUsedError;
  String get relationship => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $EmergencyContactCopyWith<EmergencyContact> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $EmergencyContactCopyWith<$Res> {
  factory $EmergencyContactCopyWith(
          EmergencyContact value, $Res Function(EmergencyContact) then) =
      _$EmergencyContactCopyWithImpl<$Res, EmergencyContact>;
  @useResult
  $Res call({String name, String phoneNumber, String relationship});
}

/// @nodoc
class _$EmergencyContactCopyWithImpl<$Res, $Val extends EmergencyContact>
    implements $EmergencyContactCopyWith<$Res> {
  _$EmergencyContactCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = null,
    Object? phoneNumber = null,
    Object? relationship = null,
  }) {
    return _then(_value.copyWith(
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      phoneNumber: null == phoneNumber
          ? _value.phoneNumber
          : phoneNumber // ignore: cast_nullable_to_non_nullable
              as String,
      relationship: null == relationship
          ? _value.relationship
          : relationship // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$EmergencyContactImplCopyWith<$Res>
    implements $EmergencyContactCopyWith<$Res> {
  factory _$$EmergencyContactImplCopyWith(_$EmergencyContactImpl value,
          $Res Function(_$EmergencyContactImpl) then) =
      __$$EmergencyContactImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String name, String phoneNumber, String relationship});
}

/// @nodoc
class __$$EmergencyContactImplCopyWithImpl<$Res>
    extends _$EmergencyContactCopyWithImpl<$Res, _$EmergencyContactImpl>
    implements _$$EmergencyContactImplCopyWith<$Res> {
  __$$EmergencyContactImplCopyWithImpl(_$EmergencyContactImpl _value,
      $Res Function(_$EmergencyContactImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = null,
    Object? phoneNumber = null,
    Object? relationship = null,
  }) {
    return _then(_$EmergencyContactImpl(
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      phoneNumber: null == phoneNumber
          ? _value.phoneNumber
          : phoneNumber // ignore: cast_nullable_to_non_nullable
              as String,
      relationship: null == relationship
          ? _value.relationship
          : relationship // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$EmergencyContactImpl implements _EmergencyContact {
  const _$EmergencyContactImpl(
      {required this.name,
      required this.phoneNumber,
      this.relationship = 'Family'});

  factory _$EmergencyContactImpl.fromJson(Map<String, dynamic> json) =>
      _$$EmergencyContactImplFromJson(json);

  @override
  final String name;
  @override
  final String phoneNumber;
  @override
  @JsonKey()
  final String relationship;

  @override
  String toString() {
    return 'EmergencyContact(name: $name, phoneNumber: $phoneNumber, relationship: $relationship)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$EmergencyContactImpl &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.phoneNumber, phoneNumber) ||
                other.phoneNumber == phoneNumber) &&
            (identical(other.relationship, relationship) ||
                other.relationship == relationship));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(runtimeType, name, phoneNumber, relationship);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$EmergencyContactImplCopyWith<_$EmergencyContactImpl> get copyWith =>
      __$$EmergencyContactImplCopyWithImpl<_$EmergencyContactImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$EmergencyContactImplToJson(
      this,
    );
  }
}

abstract class _EmergencyContact implements EmergencyContact {
  const factory _EmergencyContact(
      {required final String name,
      required final String phoneNumber,
      final String relationship}) = _$EmergencyContactImpl;

  factory _EmergencyContact.fromJson(Map<String, dynamic> json) =
      _$EmergencyContactImpl.fromJson;

  @override
  String get name;
  @override
  String get phoneNumber;
  @override
  String get relationship;
  @override
  @JsonKey(ignore: true)
  _$$EmergencyContactImplCopyWith<_$EmergencyContactImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

UpdateMedicalProfileRequest _$UpdateMedicalProfileRequestFromJson(
    Map<String, dynamic> json) {
  return _UpdateMedicalProfileRequest.fromJson(json);
}

/// @nodoc
mixin _$UpdateMedicalProfileRequest {
  String get bloodType => throw _privateConstructorUsedError;
  List<String> get chronicDiseases => throw _privateConstructorUsedError;
  List<String> get allergies => throw _privateConstructorUsedError;
  List<Map<String, dynamic>> get medications =>
      throw _privateConstructorUsedError;
  List<Map<String, dynamic>> get emergencyContacts =>
      throw _privateConstructorUsedError;
  String? get medicalHistory => throw _privateConstructorUsedError;
  String? get disabilityType => throw _privateConstructorUsedError;
  String? get additionalNotes => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $UpdateMedicalProfileRequestCopyWith<UpdateMedicalProfileRequest>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $UpdateMedicalProfileRequestCopyWith<$Res> {
  factory $UpdateMedicalProfileRequestCopyWith(
          UpdateMedicalProfileRequest value,
          $Res Function(UpdateMedicalProfileRequest) then) =
      _$UpdateMedicalProfileRequestCopyWithImpl<$Res,
          UpdateMedicalProfileRequest>;
  @useResult
  $Res call(
      {String bloodType,
      List<String> chronicDiseases,
      List<String> allergies,
      List<Map<String, dynamic>> medications,
      List<Map<String, dynamic>> emergencyContacts,
      String? medicalHistory,
      String? disabilityType,
      String? additionalNotes});
}

/// @nodoc
class _$UpdateMedicalProfileRequestCopyWithImpl<$Res,
        $Val extends UpdateMedicalProfileRequest>
    implements $UpdateMedicalProfileRequestCopyWith<$Res> {
  _$UpdateMedicalProfileRequestCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? bloodType = null,
    Object? chronicDiseases = null,
    Object? allergies = null,
    Object? medications = null,
    Object? emergencyContacts = null,
    Object? medicalHistory = freezed,
    Object? disabilityType = freezed,
    Object? additionalNotes = freezed,
  }) {
    return _then(_value.copyWith(
      bloodType: null == bloodType
          ? _value.bloodType
          : bloodType // ignore: cast_nullable_to_non_nullable
              as String,
      chronicDiseases: null == chronicDiseases
          ? _value.chronicDiseases
          : chronicDiseases // ignore: cast_nullable_to_non_nullable
              as List<String>,
      allergies: null == allergies
          ? _value.allergies
          : allergies // ignore: cast_nullable_to_non_nullable
              as List<String>,
      medications: null == medications
          ? _value.medications
          : medications // ignore: cast_nullable_to_non_nullable
              as List<Map<String, dynamic>>,
      emergencyContacts: null == emergencyContacts
          ? _value.emergencyContacts
          : emergencyContacts // ignore: cast_nullable_to_non_nullable
              as List<Map<String, dynamic>>,
      medicalHistory: freezed == medicalHistory
          ? _value.medicalHistory
          : medicalHistory // ignore: cast_nullable_to_non_nullable
              as String?,
      disabilityType: freezed == disabilityType
          ? _value.disabilityType
          : disabilityType // ignore: cast_nullable_to_non_nullable
              as String?,
      additionalNotes: freezed == additionalNotes
          ? _value.additionalNotes
          : additionalNotes // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$UpdateMedicalProfileRequestImplCopyWith<$Res>
    implements $UpdateMedicalProfileRequestCopyWith<$Res> {
  factory _$$UpdateMedicalProfileRequestImplCopyWith(
          _$UpdateMedicalProfileRequestImpl value,
          $Res Function(_$UpdateMedicalProfileRequestImpl) then) =
      __$$UpdateMedicalProfileRequestImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String bloodType,
      List<String> chronicDiseases,
      List<String> allergies,
      List<Map<String, dynamic>> medications,
      List<Map<String, dynamic>> emergencyContacts,
      String? medicalHistory,
      String? disabilityType,
      String? additionalNotes});
}

/// @nodoc
class __$$UpdateMedicalProfileRequestImplCopyWithImpl<$Res>
    extends _$UpdateMedicalProfileRequestCopyWithImpl<$Res,
        _$UpdateMedicalProfileRequestImpl>
    implements _$$UpdateMedicalProfileRequestImplCopyWith<$Res> {
  __$$UpdateMedicalProfileRequestImplCopyWithImpl(
      _$UpdateMedicalProfileRequestImpl _value,
      $Res Function(_$UpdateMedicalProfileRequestImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? bloodType = null,
    Object? chronicDiseases = null,
    Object? allergies = null,
    Object? medications = null,
    Object? emergencyContacts = null,
    Object? medicalHistory = freezed,
    Object? disabilityType = freezed,
    Object? additionalNotes = freezed,
  }) {
    return _then(_$UpdateMedicalProfileRequestImpl(
      bloodType: null == bloodType
          ? _value.bloodType
          : bloodType // ignore: cast_nullable_to_non_nullable
              as String,
      chronicDiseases: null == chronicDiseases
          ? _value._chronicDiseases
          : chronicDiseases // ignore: cast_nullable_to_non_nullable
              as List<String>,
      allergies: null == allergies
          ? _value._allergies
          : allergies // ignore: cast_nullable_to_non_nullable
              as List<String>,
      medications: null == medications
          ? _value._medications
          : medications // ignore: cast_nullable_to_non_nullable
              as List<Map<String, dynamic>>,
      emergencyContacts: null == emergencyContacts
          ? _value._emergencyContacts
          : emergencyContacts // ignore: cast_nullable_to_non_nullable
              as List<Map<String, dynamic>>,
      medicalHistory: freezed == medicalHistory
          ? _value.medicalHistory
          : medicalHistory // ignore: cast_nullable_to_non_nullable
              as String?,
      disabilityType: freezed == disabilityType
          ? _value.disabilityType
          : disabilityType // ignore: cast_nullable_to_non_nullable
              as String?,
      additionalNotes: freezed == additionalNotes
          ? _value.additionalNotes
          : additionalNotes // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$UpdateMedicalProfileRequestImpl
    implements _UpdateMedicalProfileRequest {
  const _$UpdateMedicalProfileRequestImpl(
      {required this.bloodType,
      required final List<String> chronicDiseases,
      required final List<String> allergies,
      required final List<Map<String, dynamic>> medications,
      required final List<Map<String, dynamic>> emergencyContacts,
      this.medicalHistory,
      this.disabilityType,
      this.additionalNotes})
      : _chronicDiseases = chronicDiseases,
        _allergies = allergies,
        _medications = medications,
        _emergencyContacts = emergencyContacts;

  factory _$UpdateMedicalProfileRequestImpl.fromJson(
          Map<String, dynamic> json) =>
      _$$UpdateMedicalProfileRequestImplFromJson(json);

  @override
  final String bloodType;
  final List<String> _chronicDiseases;
  @override
  List<String> get chronicDiseases {
    if (_chronicDiseases is EqualUnmodifiableListView) return _chronicDiseases;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_chronicDiseases);
  }

  final List<String> _allergies;
  @override
  List<String> get allergies {
    if (_allergies is EqualUnmodifiableListView) return _allergies;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_allergies);
  }

  final List<Map<String, dynamic>> _medications;
  @override
  List<Map<String, dynamic>> get medications {
    if (_medications is EqualUnmodifiableListView) return _medications;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_medications);
  }

  final List<Map<String, dynamic>> _emergencyContacts;
  @override
  List<Map<String, dynamic>> get emergencyContacts {
    if (_emergencyContacts is EqualUnmodifiableListView)
      return _emergencyContacts;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_emergencyContacts);
  }

  @override
  final String? medicalHistory;
  @override
  final String? disabilityType;
  @override
  final String? additionalNotes;

  @override
  String toString() {
    return 'UpdateMedicalProfileRequest(bloodType: $bloodType, chronicDiseases: $chronicDiseases, allergies: $allergies, medications: $medications, emergencyContacts: $emergencyContacts, medicalHistory: $medicalHistory, disabilityType: $disabilityType, additionalNotes: $additionalNotes)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$UpdateMedicalProfileRequestImpl &&
            (identical(other.bloodType, bloodType) ||
                other.bloodType == bloodType) &&
            const DeepCollectionEquality()
                .equals(other._chronicDiseases, _chronicDiseases) &&
            const DeepCollectionEquality()
                .equals(other._allergies, _allergies) &&
            const DeepCollectionEquality()
                .equals(other._medications, _medications) &&
            const DeepCollectionEquality()
                .equals(other._emergencyContacts, _emergencyContacts) &&
            (identical(other.medicalHistory, medicalHistory) ||
                other.medicalHistory == medicalHistory) &&
            (identical(other.disabilityType, disabilityType) ||
                other.disabilityType == disabilityType) &&
            (identical(other.additionalNotes, additionalNotes) ||
                other.additionalNotes == additionalNotes));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      bloodType,
      const DeepCollectionEquality().hash(_chronicDiseases),
      const DeepCollectionEquality().hash(_allergies),
      const DeepCollectionEquality().hash(_medications),
      const DeepCollectionEquality().hash(_emergencyContacts),
      medicalHistory,
      disabilityType,
      additionalNotes);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$UpdateMedicalProfileRequestImplCopyWith<_$UpdateMedicalProfileRequestImpl>
      get copyWith => __$$UpdateMedicalProfileRequestImplCopyWithImpl<
          _$UpdateMedicalProfileRequestImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$UpdateMedicalProfileRequestImplToJson(
      this,
    );
  }
}

abstract class _UpdateMedicalProfileRequest
    implements UpdateMedicalProfileRequest {
  const factory _UpdateMedicalProfileRequest(
      {required final String bloodType,
      required final List<String> chronicDiseases,
      required final List<String> allergies,
      required final List<Map<String, dynamic>> medications,
      required final List<Map<String, dynamic>> emergencyContacts,
      final String? medicalHistory,
      final String? disabilityType,
      final String? additionalNotes}) = _$UpdateMedicalProfileRequestImpl;

  factory _UpdateMedicalProfileRequest.fromJson(Map<String, dynamic> json) =
      _$UpdateMedicalProfileRequestImpl.fromJson;

  @override
  String get bloodType;
  @override
  List<String> get chronicDiseases;
  @override
  List<String> get allergies;
  @override
  List<Map<String, dynamic>> get medications;
  @override
  List<Map<String, dynamic>> get emergencyContacts;
  @override
  String? get medicalHistory;
  @override
  String? get disabilityType;
  @override
  String? get additionalNotes;
  @override
  @JsonKey(ignore: true)
  _$$UpdateMedicalProfileRequestImplCopyWith<_$UpdateMedicalProfileRequestImpl>
      get copyWith => throw _privateConstructorUsedError;
}
