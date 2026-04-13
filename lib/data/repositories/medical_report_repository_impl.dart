import 'dart:io';
import '../../domain/entities/medical_report.dart';
import '../../domain/repositories/medical_report_repository.dart';
import '../datasources/remote/medical_reports_upload_service.dart';

class MedicalReportRepositoryImpl implements MedicalReportRepository {
  final MedicalReportsUploadService _remoteService;

  MedicalReportRepositoryImpl({
    required MedicalReportsUploadService remoteService,
  }) : _remoteService = remoteService;

  @override
  Future<List<MedicalReport>> getMedicalReports(String userId) async {
    final reportInfos = await _remoteService.getMedicalReports(userId);
    return reportInfos.map((info) => MedicalReport(
      id: info.reportId,
      fileName: info.fileName,
      reportType: info.reportType,
      downloadUrl: info.downloadUrl,
      uploadedAt: info.uploadedAt,
      fileSizeBytes: info.fileSizeBytes,
      userId: userId,
      mimeType: info.mimeType,
    )).toList();
  }

  @override
  Future<MedicalReport> uploadMedicalReport({
    required File file,
    required String reportType,
    required String userId,
    Function(double)? onProgress,
  }) async {
    // Note: The service currently returns the URL string, 
    // but the getMedicalReports call returns the full object list.
    // For consistency, after upload we should probably fetch the list 
    // or the service should return the full object.
    // Given current service implementation:
    final url = await _remoteService.uploadMedicalReport(
      file: file,
      reportType: reportType,
      userId: userId,
      onProgress: onProgress,
    );

    // After a successful upload, we fetch the updated list to find the new report
    // Or we create a temporary one for the UI.
    // Let's assume we want to return a full object. 
    // We'll create a local representation since the backend URL is known.
    return MedicalReport(
      id: DateTime.now().millisecondsSinceEpoch.toString(), // Temp ID until refresh
      fileName: file.path.split('/').last,
      reportType: reportType,
      downloadUrl: url,
      uploadedAt: DateTime.now(),
      fileSizeBytes: file.lengthSync(),
      userId: userId,
    );
  }

  @override
  Future<void> deleteMedicalReport(String reportId) async {
    await _remoteService.deleteMedicalReport(reportId);
  }
}
