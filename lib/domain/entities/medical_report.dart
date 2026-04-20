import 'package:freezed_annotation/freezed_annotation.dart';
import '../../core/utils/parsers.dart';

part 'medical_report.freezed.dart';
part 'medical_report.g.dart';

@freezed
class MedicalReport with _$MedicalReport {
  const factory MedicalReport({
    required String id,
    required String fileName,
    required String reportType, // LAB, IMAGING, PRESCRIPTION, OTHER
    required String downloadUrl,
    required DateTime uploadedAt,
    @JsonKey(fromJson: intFromJson) required int fileSizeBytes,
    String? userId,
    String? mimeType,
  }) = _MedicalReport;

  factory MedicalReport.fromJson(Map<String, dynamic> json) =>
      _$MedicalReportFromJson(json);
}
