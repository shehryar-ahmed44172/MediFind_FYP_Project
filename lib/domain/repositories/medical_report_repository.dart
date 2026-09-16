import 'dart:io';
import '../entities/medical_report.dart';

abstract class MedicalReportRepository {
  /// Reports of the authenticated user (backend resolves the user from the token).
  Future<List<MedicalReport>> getMedicalReports();
  
  Future<MedicalReport> uploadMedicalReport({
    required File file,
    required String reportType,
    required String userId,
    Function(double)? onProgress,
  });
  
  Future<void> deleteMedicalReport(String reportId);
  
  Future<MedicalReport> renameMedicalReport(String reportId, String newName);
}
