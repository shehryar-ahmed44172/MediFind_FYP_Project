import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import '../../domain/entities/medical_report.dart';
import '../../domain/repositories/medical_report_repository.dart';
import '../../data/repositories/medical_report_repository_impl.dart';
import '../../data/datasources/remote/medical_reports_upload_service.dart';
import '../../presentation/providers/auth_provider.dart';

final medicalReportServiceProvider = Provider<MedicalReportsUploadService>((ref) {
  final dio = ref.watch(dioProvider);
  return MedicalReportsUploadService(dio: dio);
});

final medicalReportRepositoryProvider = Provider<MedicalReportRepository>((ref) {
  final service = ref.watch(medicalReportServiceProvider);
  return MedicalReportRepositoryImpl(remoteService: service);
});

final medicalReportsProvider = FutureProvider.family<List<MedicalReport>, String>((ref, userId) async {
  final repo = ref.watch(medicalReportRepositoryProvider);
  return await repo.getMedicalReports(userId);
});

final medicalReportsNotifierProvider = StateNotifierProvider<MedicalReportsNotifier, AsyncValue<void>>((ref) {
  return MedicalReportsNotifier(ref);
});

class MedicalReportsNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  MedicalReportsNotifier(this._ref) : super(const AsyncValue.data(null));

  Future<void> uploadReport({
    required File file,
    required String reportType,
    required String userId,
    Function(double)? onProgress,
  }) async {
    state = const AsyncValue.loading();
    try {
      final repo = _ref.read(medicalReportRepositoryProvider);
      await repo.uploadMedicalReport(
        file: file,
        reportType: reportType,
        userId: userId,
        onProgress: onProgress,
      );
      
      // Refresh the list
      _ref.invalidate(medicalReportsProvider(userId));
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> deleteReport(String reportId, String userId) async {
    state = const AsyncValue.loading();
    try {
      final repo = _ref.read(medicalReportRepositoryProvider);
      await repo.deleteMedicalReport(reportId);
      
      // Refresh the list
      _ref.invalidate(medicalReportsProvider(userId));
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}
