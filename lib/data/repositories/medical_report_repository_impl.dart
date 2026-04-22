import 'dart:io';
import '../../domain/entities/medical_report.dart';
import '../../domain/repositories/medical_report_repository.dart';
import '../datasources/remote/medifind_api_client.dart';
import '../../core/constants/app_constants.dart';

class MedicalReportRepositoryImpl implements MedicalReportRepository {
  final MediFindApiClient _apiClient;

  MedicalReportRepositoryImpl({
    required MediFindApiClient apiClient,
  }) : _apiClient = apiClient;

  @override
  Future<List<MedicalReport>> getMedicalReports(String userId) async {
    final reportsJson = await _apiClient.getReports();
    return reportsJson.map((json) {
      final normalized = _normalizeReportJson(json as Map<String, dynamic>);
      return MedicalReport.fromJson(normalized);
    }).toList();
  }

  @override
  Future<MedicalReport> uploadMedicalReport({
    required File file,
    required String reportType,
    required String userId,
    Function(double)? onProgress,
  }) async {
    final response = await _apiClient.uploadReport(file, reportType, userId);
    final normalized = _normalizeReportJson(response as Map<String, dynamic>);
    return MedicalReport.fromJson(normalized);
  }

  Map<String, dynamic> _normalizeReportJson(Map<String, dynamic> json) {
    // Backend field variation mapping
    final id = json['id'] ?? json['reportId'] ?? json['_id'] ?? '';
    final rawUrl = json['downloadUrl'] ?? json['url'] ?? json['fileUrl'] ?? '';
    
    // Construct absolute URL if it's relative
    String downloadUrl = '';
    if (rawUrl.isNotEmpty) {
      if (rawUrl.toString().startsWith('http')) {
        downloadUrl = rawUrl;
      } else {
        // Prepend base URL (removing /api/ suffix if present)
        final host = AppConstants.baseUrl.replaceAll('/api/', '');
        final path = rawUrl.toString().startsWith('/') ? rawUrl : '/$rawUrl';
        downloadUrl = '$host$path';
      }
    }

    return {
      ...json,
      'id': id,
      'fileName': json['fileName'] ?? json['name'] ?? 'Medical Report',
      'reportType': json['reportType'] ?? json['type'] ?? 'OTHER',
      'downloadUrl': downloadUrl,
      'uploadedAt': json['uploadedAt'] ?? DateTime.now().toIso8601String(),
      'fileSizeBytes': json['fileSizeBytes'] ?? json['size'] ?? 0,
    };
  }

  @override
  Future<void> deleteMedicalReport(String reportId) async {
    // Note: If you add a deleteReport endpoint to MediFindApiClient, call it here.
    // For now, we'll mark it as a TODO or leave it as is if the guide doesn't specify.
  }
}
