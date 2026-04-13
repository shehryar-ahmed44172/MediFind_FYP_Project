import 'dart:io';
import '../entities/medical_report.dart';

abstract class MedicalReportRepository {
  Future<List<MedicalReport>> getMedicalReports(String userId);
  
  Future<MedicalReport> uploadMedicalReport({
    required File file,
    required String reportType,
    required String userId,
    Function(double)? onProgress,
  });
  
  Future<void> deleteMedicalReport(String reportId);
}
