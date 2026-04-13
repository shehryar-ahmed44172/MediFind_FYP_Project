// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'medical_report.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$MedicalReportImpl _$$MedicalReportImplFromJson(Map<String, dynamic> json) =>
    _$MedicalReportImpl(
      id: json['id'] as String,
      fileName: json['fileName'] as String,
      reportType: json['reportType'] as String,
      downloadUrl: json['downloadUrl'] as String,
      uploadedAt: DateTime.parse(json['uploadedAt'] as String),
      fileSizeBytes: (json['fileSizeBytes'] as num).toInt(),
      userId: json['userId'] as String?,
      mimeType: json['mimeType'] as String?,
    );

Map<String, dynamic> _$$MedicalReportImplToJson(_$MedicalReportImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'fileName': instance.fileName,
      'reportType': instance.reportType,
      'downloadUrl': instance.downloadUrl,
      'uploadedAt': instance.uploadedAt.toIso8601String(),
      'fileSizeBytes': instance.fileSizeBytes,
      'userId': instance.userId,
      'mimeType': instance.mimeType,
    };
