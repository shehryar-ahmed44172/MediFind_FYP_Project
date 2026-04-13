// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'medical_report.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

MedicalReport _$MedicalReportFromJson(Map<String, dynamic> json) {
  return _MedicalReport.fromJson(json);
}

/// @nodoc
mixin _$MedicalReport {
  String get id => throw _privateConstructorUsedError;
  String get fileName => throw _privateConstructorUsedError;
  String get reportType =>
      throw _privateConstructorUsedError; // LAB, IMAGING, PRESCRIPTION, OTHER
  String get downloadUrl => throw _privateConstructorUsedError;
  DateTime get uploadedAt => throw _privateConstructorUsedError;
  int get fileSizeBytes => throw _privateConstructorUsedError;
  String? get userId => throw _privateConstructorUsedError;
  String? get mimeType => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $MedicalReportCopyWith<MedicalReport> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MedicalReportCopyWith<$Res> {
  factory $MedicalReportCopyWith(
          MedicalReport value, $Res Function(MedicalReport) then) =
      _$MedicalReportCopyWithImpl<$Res, MedicalReport>;
  @useResult
  $Res call(
      {String id,
      String fileName,
      String reportType,
      String downloadUrl,
      DateTime uploadedAt,
      int fileSizeBytes,
      String? userId,
      String? mimeType});
}

/// @nodoc
class _$MedicalReportCopyWithImpl<$Res, $Val extends MedicalReport>
    implements $MedicalReportCopyWith<$Res> {
  _$MedicalReportCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? fileName = null,
    Object? reportType = null,
    Object? downloadUrl = null,
    Object? uploadedAt = null,
    Object? fileSizeBytes = null,
    Object? userId = freezed,
    Object? mimeType = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      fileName: null == fileName
          ? _value.fileName
          : fileName // ignore: cast_nullable_to_non_nullable
              as String,
      reportType: null == reportType
          ? _value.reportType
          : reportType // ignore: cast_nullable_to_non_nullable
              as String,
      downloadUrl: null == downloadUrl
          ? _value.downloadUrl
          : downloadUrl // ignore: cast_nullable_to_non_nullable
              as String,
      uploadedAt: null == uploadedAt
          ? _value.uploadedAt
          : uploadedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      fileSizeBytes: null == fileSizeBytes
          ? _value.fileSizeBytes
          : fileSizeBytes // ignore: cast_nullable_to_non_nullable
              as int,
      userId: freezed == userId
          ? _value.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as String?,
      mimeType: freezed == mimeType
          ? _value.mimeType
          : mimeType // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$MedicalReportImplCopyWith<$Res>
    implements $MedicalReportCopyWith<$Res> {
  factory _$$MedicalReportImplCopyWith(
          _$MedicalReportImpl value, $Res Function(_$MedicalReportImpl) then) =
      __$$MedicalReportImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String fileName,
      String reportType,
      String downloadUrl,
      DateTime uploadedAt,
      int fileSizeBytes,
      String? userId,
      String? mimeType});
}

/// @nodoc
class __$$MedicalReportImplCopyWithImpl<$Res>
    extends _$MedicalReportCopyWithImpl<$Res, _$MedicalReportImpl>
    implements _$$MedicalReportImplCopyWith<$Res> {
  __$$MedicalReportImplCopyWithImpl(
      _$MedicalReportImpl _value, $Res Function(_$MedicalReportImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? fileName = null,
    Object? reportType = null,
    Object? downloadUrl = null,
    Object? uploadedAt = null,
    Object? fileSizeBytes = null,
    Object? userId = freezed,
    Object? mimeType = freezed,
  }) {
    return _then(_$MedicalReportImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      fileName: null == fileName
          ? _value.fileName
          : fileName // ignore: cast_nullable_to_non_nullable
              as String,
      reportType: null == reportType
          ? _value.reportType
          : reportType // ignore: cast_nullable_to_non_nullable
              as String,
      downloadUrl: null == downloadUrl
          ? _value.downloadUrl
          : downloadUrl // ignore: cast_nullable_to_non_nullable
              as String,
      uploadedAt: null == uploadedAt
          ? _value.uploadedAt
          : uploadedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      fileSizeBytes: null == fileSizeBytes
          ? _value.fileSizeBytes
          : fileSizeBytes // ignore: cast_nullable_to_non_nullable
              as int,
      userId: freezed == userId
          ? _value.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as String?,
      mimeType: freezed == mimeType
          ? _value.mimeType
          : mimeType // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$MedicalReportImpl implements _MedicalReport {
  const _$MedicalReportImpl(
      {required this.id,
      required this.fileName,
      required this.reportType,
      required this.downloadUrl,
      required this.uploadedAt,
      required this.fileSizeBytes,
      this.userId,
      this.mimeType});

  factory _$MedicalReportImpl.fromJson(Map<String, dynamic> json) =>
      _$$MedicalReportImplFromJson(json);

  @override
  final String id;
  @override
  final String fileName;
  @override
  final String reportType;
// LAB, IMAGING, PRESCRIPTION, OTHER
  @override
  final String downloadUrl;
  @override
  final DateTime uploadedAt;
  @override
  final int fileSizeBytes;
  @override
  final String? userId;
  @override
  final String? mimeType;

  @override
  String toString() {
    return 'MedicalReport(id: $id, fileName: $fileName, reportType: $reportType, downloadUrl: $downloadUrl, uploadedAt: $uploadedAt, fileSizeBytes: $fileSizeBytes, userId: $userId, mimeType: $mimeType)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MedicalReportImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.fileName, fileName) ||
                other.fileName == fileName) &&
            (identical(other.reportType, reportType) ||
                other.reportType == reportType) &&
            (identical(other.downloadUrl, downloadUrl) ||
                other.downloadUrl == downloadUrl) &&
            (identical(other.uploadedAt, uploadedAt) ||
                other.uploadedAt == uploadedAt) &&
            (identical(other.fileSizeBytes, fileSizeBytes) ||
                other.fileSizeBytes == fileSizeBytes) &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.mimeType, mimeType) ||
                other.mimeType == mimeType));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(runtimeType, id, fileName, reportType,
      downloadUrl, uploadedAt, fileSizeBytes, userId, mimeType);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$MedicalReportImplCopyWith<_$MedicalReportImpl> get copyWith =>
      __$$MedicalReportImplCopyWithImpl<_$MedicalReportImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$MedicalReportImplToJson(
      this,
    );
  }
}

abstract class _MedicalReport implements MedicalReport {
  const factory _MedicalReport(
      {required final String id,
      required final String fileName,
      required final String reportType,
      required final String downloadUrl,
      required final DateTime uploadedAt,
      required final int fileSizeBytes,
      final String? userId,
      final String? mimeType}) = _$MedicalReportImpl;

  factory _MedicalReport.fromJson(Map<String, dynamic> json) =
      _$MedicalReportImpl.fromJson;

  @override
  String get id;
  @override
  String get fileName;
  @override
  String get reportType;
  @override // LAB, IMAGING, PRESCRIPTION, OTHER
  String get downloadUrl;
  @override
  DateTime get uploadedAt;
  @override
  int get fileSizeBytes;
  @override
  String? get userId;
  @override
  String? get mimeType;
  @override
  @JsonKey(ignore: true)
  _$$MedicalReportImplCopyWith<_$MedicalReportImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
