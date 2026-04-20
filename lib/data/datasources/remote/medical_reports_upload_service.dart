/// Medical Reports Upload Service
/// Handles medical report file uploads to cloud storage
/// Supports both Azure Blob Storage and generic HTTP upload

import 'dart:io';
import 'package:dio/dio.dart';

class MedicalReportsUploadService {
  final Dio _dio;
  static const String _baseUrl = 'reports';

  MedicalReportsUploadService({Dio? dio}) : _dio = dio ?? Dio();

  /// Upload medical report file to backend
  /// Returns the file URL from the server
  /// 
  /// [file] - Image or document file to upload
  /// [reportType] - Type of report: 'LAB', 'IMAGING', 'PRESCRIPTION', 'OTHER'
  /// [onProgress] - Callback to track upload progress (0.0 to 1.0)
  Future<String> uploadMedicalReport({
    required File file,
    required String reportType,
    required String userId,
    Function(double)? onProgress,
  }) async {
    try {
      if (!file.existsSync()) {
        throw Exception('File does not exist: ${file.path}');
      }

      // Validate file size (max 50 MB)
      final fileSize = file.lengthSync();
      const maxSize = 50 * 1024 * 1024; // 50 MB
      if (fileSize > maxSize) {
        throw Exception('File size exceeds 50 MB limit');
      }

      // Validate file type
      _validateFileType(file.path);

      // Create form data (Backend expects field name 'report')
      final formData = FormData.fromMap({
        'report': await MultipartFile.fromFile(
          file.path,
          filename: file.path.split('/').last,
        ),
        'reportType': reportType,
        'userId': userId,
      });

      // Upload with progress tracking to the /profile endpoint
      final response = await _dio.post(
        '$_baseUrl/profile',
        data: formData,
        onSendProgress: (sent, total) {
          final progress = sent / total;
          onProgress?.call(progress);
        },
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = response.data['data'] as Map<String, dynamic>;
        return data['downloadUrl'] as String? ?? data['url'] as String;
      }

      throw Exception('Upload failed: ${response.statusCode}');
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  Future<List<MedicalReportInfo>> getMedicalReports(String userId) async {
    try {
      // Backend uses /api/reports/profile to get current user's reports
      final response = await _dio.get('$_baseUrl/profile');

      if (response.statusCode == 200) {
        final data = response.data['data'];
        final items = data is List ? data : [];
        return items
            .map((e) => MedicalReportInfo.fromJson(e as Map<String, dynamic>))
            .toList();
      }

      throw Exception('Failed to fetch reports: ${response.statusCode}');
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  /// Delete a medical report
  /// API: DELETE /api/medical-reports/{reportId}
  Future<void> deleteMedicalReport(String reportId) async {
    try {
      final response = await _dio.delete('$_baseUrl/$reportId');

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Delete failed: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  /// Validate file type
  /// Allowed: jpg, png, pdf, doc, docx
  void _validateFileType(String filePath) {
    final allowedExtensions = ['jpg', 'jpeg', 'png', 'pdf', 'doc', 'docx'];
    final extension = filePath.split('.').last.toLowerCase();

    if (!allowedExtensions.contains(extension)) {
      throw Exception(
        'Invalid file type: $extension. Allowed: ${allowedExtensions.join(', ')}',
      );
    }
  }

  /// Handle Dio exceptions
  Exception _handleDioException(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout) {
      return Exception('Upload timeout - connection lost');
    }
    if (e.type == DioExceptionType.receiveTimeout) {
      return Exception('Upload timeout - server not responding');
    }
    if (e.type == DioExceptionType.unknown) {
      return Exception('Network error during upload: ${e.message}');
    }
    return Exception('Upload failed: ${e.message}');
  }
}

/// Model for medical report information
class MedicalReportInfo {
  final String reportId;
  final String fileName;
  final String reportType; // LAB, IMAGING, PRESCRIPTION, OTHER
  final String downloadUrl;
  final DateTime uploadedAt;
  final int fileSizeBytes;
  final String? mimeType;

  MedicalReportInfo({
    required this.reportId,
    required this.fileName,
    required this.reportType,
    required this.downloadUrl,
    required this.uploadedAt,
    required this.fileSizeBytes,
    this.mimeType,
  });

  /// Create from JSON
  factory MedicalReportInfo.fromJson(Map<String, dynamic> json) {
    return MedicalReportInfo(
      reportId: json['id'] ?? json['reportId'] ?? '',
      fileName: json['fileName'] ?? json['name'] ?? '',
      reportType: json['reportType'] ?? json['type'] ?? 'OTHER',
      downloadUrl: json['downloadUrl'] ?? json['url'] ?? '',
      uploadedAt: json['uploadedAt'] != null
          ? DateTime.parse(json['uploadedAt'] as String)
          : DateTime.now(),
      fileSizeBytes: json['fileSizeBytes'] ?? json['size'] ?? 0,
      mimeType: json['mimeType'] ?? json['contentType'],
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() => {
    'id': reportId,
    'fileName': fileName,
    'reportType': reportType,
    'downloadUrl': downloadUrl,
    'uploadedAt': uploadedAt.toIso8601String(),
    'fileSizeBytes': fileSizeBytes,
    'mimeType': mimeType,
  };

  /// Get human-readable file size
  String getFormattedSize() {
    if (fileSizeBytes < 1024) {
      return '$fileSizeBytes B';
    } else if (fileSizeBytes < 1024 * 1024) {
      return '${(fileSizeBytes / 1024).toStringAsFixed(2)} KB';
    } else {
      return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
  }

  /// Get report type display name
  String getReportTypeDisplay() {
    switch (reportType.toUpperCase()) {
      case 'LAB':
        return 'Lab Report';
      case 'IMAGING':
        return 'Imaging (X-Ray, CT, MRI)';
      case 'PRESCRIPTION':
        return 'Prescription';
      case 'OTHER':
        return 'Medical Document';
      default:
        return reportType;
    }
  }
}
