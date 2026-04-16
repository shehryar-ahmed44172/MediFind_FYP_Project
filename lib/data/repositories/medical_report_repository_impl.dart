import 'dart:io';
import '../../domain/entities/medical_report.dart';
import '../../domain/repositories/medical_report_repository.dart';
import '../datasources/remote/medifind_api_client.dart';

class MedicalReportRepositoryImpl implements MedicalReportRepository {
  final MediFindApiClient _apiClient;

  MedicalReportRepositoryImpl({
    required MediFindApiClient apiClient,
  }) : _apiClient = apiClient;

  @override
  Future<List<MedicalReport>> getMedicalReports(String userId) async {
    final reportsJson = await _apiClient.getReports();
    return reportsJson.map((json) => MedicalReport.fromJson(json as Map<String, dynamic>)).toList();
  }

  @override
  Future<MedicalReport> uploadMedicalReport({
    required File file,
    required String reportType,
    required String userId,
    Function(double)? onProgress,
  }) async {
    final response = await _apiClient.uploadReport(file, reportType);
    return MedicalReport.fromJson(response as Map<String, dynamic>);
  }

  @override
  Future<void> deleteMedicalReport(String reportId) async {
    // Note: If you add a deleteReport endpoint to MediFindApiClient, call it here.
    // For now, we'll mark it as a TODO or leave it as is if the guide doesn't specify.
  }
}
