import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/medical_report_provider.dart';
import '../../../domain/entities/medical_report.dart';
import 'package:medifind_mobile_application/core/utils/responsive.dart';

/// Backend multer limit for report uploads (uploadMiddleware.ts).
const int _maxReportBytes = 10 * 1024 * 1024;

enum _ReportAction { open, rename, delete }

class MedicalReportsScreen extends ConsumerStatefulWidget {
  const MedicalReportsScreen({super.key});

  @override
  ConsumerState<MedicalReportsScreen> createState() => _MedicalReportsScreenState();
}

class _MedicalReportsScreenState extends ConsumerState<MedicalReportsScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _uploading = false;

  // ---------------------------------------------------------------------------
  // Picking
  // ---------------------------------------------------------------------------

  Future<void> _pickFromGallery(String reportType) async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null) return;

    await _upload(File(picked.path), reportType);
  }

  Future<void> _pickPdf(String reportType) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
      );
      final path = result?.files.single.path;
      if (path == null) return;
      await _upload(File(path), reportType);
    } catch (e) {
      debugPrint('PDF pick failed: $e');
      _showError('Could not open the document picker.');
    }
  }

  Future<void> _takeCameraPhoto(String reportType) async {
    final status = await Permission.camera.request();
    if (status.isPermanentlyDenied) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.camera_alt_outlined, color: AppColors.warning, size: 28),
                SizedBox(width: 10),
                Text('Camera Permission'),
              ],
            ),
            content: const Text(
              'Camera access is required to take photos of your reports. Please enable it in your device settings.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  openAppSettings();
                },
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Go to Settings'),
              ),
            ],
          ),
        );
      }
      return;
    }
    if (!status.isGranted) {
      _showError('Camera permission is required to take a photo.');
      return;
    }

    final picked = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (picked == null) return;

    await _upload(File(picked.path), reportType);
  }

  // ---------------------------------------------------------------------------
  // Mutations
  // ---------------------------------------------------------------------------

  Future<void> _upload(File file, String reportType) async {
    final userId = ref.read(currentUserIdProvider).valueOrNull;
    if (userId == null) {
      _showError('User session not found. Please log in again.');
      return;
    }

    try {
      if (await file.length() > _maxReportBytes) {
        _showError('File is too large. Maximum size is 10 MB.');
        return;
      }
    } catch (_) {
      // If the size can't be read, let the server decide.
    }

    setState(() => _uploading = true);

    try {
      await ref.read(medicalReportsNotifierProvider.notifier).uploadReport(
            file: file,
            reportType: reportType,
            userId: userId,
          );
      _showSuccess('Medical report uploaded successfully');
    } catch (e) {
      _showError('Upload failed: $e');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _renameReport(MedicalReport report) async {
    final userId = ref.read(currentUserIdProvider).valueOrNull;
    if (userId == null) return;

    final controller = TextEditingController(text: report.fileName);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Report'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'File Name',
            hintText: 'Enter new name',
          ),
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (value) => Navigator.pop(ctx, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Rename'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (newName == null || newName.isEmpty || newName == report.fileName) return;

    try {
      await ref
          .read(medicalReportsNotifierProvider.notifier)
          .renameReport(report.id, newName, userId);
      _showSuccess('Report renamed');
    } catch (e) {
      _showError('Rename failed: $e');
    }
  }

  Future<void> _deleteReport(MedicalReport report) async {
    final userId = ref.read(currentUserIdProvider).valueOrNull;
    if (userId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Report'),
        content: Text(
          'Are you sure you want to delete "${report.fileName}"? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref
          .read(medicalReportsNotifierProvider.notifier)
          .deleteReport(report.id, userId);
      _showSuccess('Report deleted');
    } catch (e) {
      _showError('Delete failed: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Viewing
  // ---------------------------------------------------------------------------

  bool _isPdf(MedicalReport report) {
    if (report.mimeType?.toLowerCase() == 'application/pdf') return true;
    bool endsWithPdf(String s) =>
        s.toLowerCase().split('?').first.endsWith('.pdf');
    return endsWithPdf(report.fileName) || endsWithPdf(report.downloadUrl);
  }

  /// Report files are served from /api/files/reports/* which requires the
  /// Authorization header, so they are always fetched through the
  /// authenticated Dio client rather than a plain URL.
  Future<Uint8List> _fetchReportBytes(MedicalReport report) async {
    final dio = ref.read(apiClientProvider).dio;
    final response = await dio.get<List<int>>(
      report.downloadUrl,
      options: Options(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList(response.data ?? const []);
  }

  Future<void> _openPdf(MedicalReport report) async {
    if (report.downloadUrl.isEmpty) {
      _showError('This report has no file attached.');
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Opening document...'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );

    String? savedPath;
    try {
      final bytes = await _fetchReportBytes(report);
      Directory? dir;
      try {
        dir = await getExternalStorageDirectory();
      } catch (_) {
        dir = null;
      }
      dir ??= await getApplicationDocumentsDirectory();
      final safeName = report.fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final fileName = safeName.toLowerCase().endsWith('.pdf') ? safeName : '$safeName.pdf';
      final file = File('${dir.path}${Platform.pathSeparator}$fileName');
      await file.writeAsBytes(bytes, flush: true);
      savedPath = file.path;

      final launched = await launchUrl(
        Uri.file(file.path),
        mode: LaunchMode.externalApplication,
      );
      if (!launched) throw Exception('No app available to open PDF');
    } catch (e) {
      debugPrint('Open PDF failed: $e');
      if (savedPath != null) {
        _showError('No PDF viewer could open the file. It was saved to: $savedPath');
      } else {
        _showError('Could not download the document: $e');
      }
    }
  }

  void _viewReport(MedicalReport report) {
    if (_isPdf(report)) {
      _openPdf(report);
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => _ReportImageViewer(
          title: report.fileName,
          loadBytes: () => _fetchReportBytes(report),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  String _formatSize(int bytes) {
    if (bytes <= 0) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(currentUserIdProvider).valueOrNull;
    final reportsAsync = userId != null
        ? ref.watch(medicalReportsProvider(userId))
        : const AsyncValue<List<MedicalReport>>.data([]);

    final isBusy = _uploading || ref.watch(medicalReportsNotifierProvider).isLoading;

    final buttonShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(8));
    const minButtonSize = Size(0, 48);

    return Scaffold(
      body: Column(
        children: [
          // Upload Section
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primary.shade200),
            ),
            child: Column(
              children: [
                const Icon(Icons.upload_file_outlined,
                    size: 40, color: AppColors.primary),
                const SizedBox(height: 8),
                Text('Upload Medical Reports',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 18.sp)),
                const SizedBox(height: 4),
                const Text(
                  'Upload photos or PDF documents (max 10 MB)',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: isBusy ? null : () => _takeCameraPhoto('OTHER'),
                        icon: const Icon(Icons.camera_alt_outlined),
                        label: const Text('Camera'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: minButtonSize,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          shape: buttonShape,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: isBusy ? null : () => _pickFromGallery('OTHER'),
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('Gallery'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: minButtonSize,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          shape: buttonShape,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: isBusy ? null : () => _pickPdf('OTHER'),
                        icon: const Icon(Icons.picture_as_pdf_outlined),
                        label: const Text('PDF'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: minButtonSize,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          shape: buttonShape,
                        ),
                      ),
                    ),
                  ],
                ),
                if (_uploading) ...[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(),
                  const SizedBox(height: 4),
                  const Text('Uploading...',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ],
            ),
          ),

          // Reports List
          Expanded(
            child: reportsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.cloud_off_rounded, color: Colors.grey, size: 56),
                      const SizedBox(height: 16),
                      const Text(
                        'Unable to load reports',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        err.toString(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: userId == null
                            ? null
                            : () => ref.invalidate(medicalReportsProvider(userId)),
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Retry'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: minButtonSize,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              data: (reports) => reports.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.folder_outlined,
                              size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          const Text('No reports uploaded yet',
                              style: TextStyle(
                                  color: Colors.grey, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          const Text(
                            'Use Camera, Gallery or PDF above to add one.',
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () async {
                        if (userId == null) return;
                        ref.invalidate(medicalReportsProvider(userId));
                        try {
                          await ref.read(medicalReportsProvider(userId).future);
                        } catch (_) {
                          // Error state is rendered by the provider.
                        }
                      },
                      child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: reports.length,
                        itemBuilder: (ctx, i) => _buildReportCard(reports[i]),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportCard(MedicalReport report) {
    final isPdf = _isPdf(report);
    final size = _formatSize(report.fileSizeBytes);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        minVerticalPadding: 12,
        leading: Container(
          width: 12.wp,
          height: 12.wp,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            isPdf ? Icons.picture_as_pdf_outlined : Icons.image_outlined,
            color: AppColors.primary,
          ),
        ),
        title: Text(
          report.fileName,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          'Uploaded ${_formatDate(report.uploadedAt)}${size.isEmpty ? '' : ' - $size'}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: PopupMenuButton<_ReportAction>(
          tooltip: 'Report options',
          icon: const Icon(Icons.more_vert),
          onSelected: (action) {
            switch (action) {
              case _ReportAction.open:
                _viewReport(report);
              case _ReportAction.rename:
                _renameReport(report);
              case _ReportAction.delete:
                _deleteReport(report);
            }
          },
          itemBuilder: (ctx) => [
            PopupMenuItem(
              value: _ReportAction.open,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(isPdf ? Icons.open_in_new : Icons.visibility_outlined),
                title: Text(isPdf ? 'Open' : 'View'),
              ),
            ),
            const PopupMenuItem(
              value: _ReportAction.rename,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.edit_outlined),
                title: Text('Rename'),
              ),
            ),
            const PopupMenuItem(
              value: _ReportAction.delete,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.delete_outline, color: AppColors.error),
                title: Text('Delete', style: TextStyle(color: AppColors.error)),
              ),
            ),
          ],
        ),
        onTap: () => _viewReport(report),
      ),
    );
  }
}

/// Full-screen, zoomable preview of an image report loaded with auth.
class _ReportImageViewer extends StatefulWidget {
  final String title;
  final Future<Uint8List> Function() loadBytes;

  const _ReportImageViewer({required this.title, required this.loadBytes});

  @override
  State<_ReportImageViewer> createState() => _ReportImageViewerState();
}

class _ReportImageViewerState extends State<_ReportImageViewer> {
  late Future<Uint8List> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.loadBytes();
  }

  void _retry() => setState(() => _future = widget.loadBytes());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      backgroundColor: Colors.black,
      body: FutureBuilder<Uint8List>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator(color: Colors.white));
          }
          final bytes = snapshot.data;
          if (snapshot.hasError || bytes == null || bytes.isEmpty) {
            return _buildError();
          }
          return Center(
            child: InteractiveViewer(
              clipBehavior: Clip.none,
              maxScale: 5.0,
              child: Image.memory(
                bytes,
                errorBuilder: (_, __, ___) => _buildError(),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.broken_image_outlined, color: Colors.white54, size: 64),
          const SizedBox(height: 16),
          const Text('Report image not available',
              style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _retry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(minimumSize: const Size(0, 48)),
          ),
        ],
      ),
    );
  }
}
