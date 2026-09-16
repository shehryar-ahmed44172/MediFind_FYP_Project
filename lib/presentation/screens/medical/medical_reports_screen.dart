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

import '../../providers/auth_provider.dart';
import '../../providers/medical_report_provider.dart';
import '../../widgets/design_system/design_system.dart';
import '../../../domain/entities/medical_report.dart';

/// Backend multer limit for report uploads (uploadMiddleware.ts).
const int _maxReportBytes = 10 * 1024 * 1024;

enum _ReportAction { open, rename, delete }

enum _UploadSource { camera, gallery, pdf }

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

  /// Lets the user choose Camera / Gallery / PDF, then runs that picker.
  Future<void> _chooseUploadSource() async {
    final source = await showMfBottomSheet<_UploadSource>(
      context,
      title: 'Upload medical report',
      subtitle: 'Photos or PDF documents, max 10 MB',
      builder: (ctx) => MfListGroup(
        children: [
          MfIconTile(
            icon: Icons.camera_alt_outlined,
            label: 'Take a photo',
            subtitle: 'Use the camera',
            onTap: () => Navigator.pop(ctx, _UploadSource.camera),
          ),
          MfIconTile(
            icon: Icons.photo_library_outlined,
            label: 'Choose from gallery',
            subtitle: 'Upload an existing photo',
            onTap: () => Navigator.pop(ctx, _UploadSource.gallery),
          ),
          MfIconTile(
            icon: Icons.picture_as_pdf_outlined,
            label: 'Upload a PDF',
            subtitle: 'Select a PDF document',
            onTap: () => Navigator.pop(ctx, _UploadSource.pdf),
          ),
        ],
      ),
    );
    if (source == null || !mounted) return;
    switch (source) {
      case _UploadSource.camera:
        await _takeCameraPhoto('OTHER');
      case _UploadSource.gallery:
        await _pickFromGallery('OTHER');
      case _UploadSource.pdf:
        await _pickPdf('OTHER');
    }
  }

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
        final goToSettings = await showMfConfirmDialog(
          context,
          icon: Icons.camera_alt_outlined,
          title: 'Camera permission',
          message:
              'Camera access is required to take photos of your reports. Please enable it in your device settings.',
          confirmLabel: 'Go to settings',
        );
        if (goToSettings) openAppSettings();
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
        title: const Text('Rename report'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'File name',
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
          FilledButton(
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

    final confirmed = await showMfConfirmDialog(
      context,
      icon: Icons.delete_outline_rounded,
      title: 'Delete report?',
      message: 'Are you sure you want to delete "${report.fileName}"? This cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed) return;

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
    showMfSnackBar(context, 'Opening document...', duration: const Duration(seconds: 2));

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
    showMfSnackBar(context, message, tone: MfTone.danger);
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    showMfSnackBar(context, message, tone: MfTone.success);
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

  String? _reportTypeLabel(String type) {
    switch (type.toUpperCase()) {
      case 'LAB':
        return 'Lab result';
      case 'IMAGING':
        return 'Imaging';
      case 'PRESCRIPTION':
        return 'Prescription';
      default:
        return null;
    }
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

    return MfScaffold(
      title: 'Medical reports',
      subtitle: 'Lab results, scans and prescriptions',
      bottomBar: MfPrimaryButton(
        label: _uploading ? 'Uploading...' : 'Upload report',
        icon: Icons.upload_file_outlined,
        loading: isBusy,
        onPressed: _chooseUploadSource,
      ),
      body: Column(
        children: [
          if (_uploading)
            Padding(
              padding: const EdgeInsets.fromLTRB(MfSpace.gutter, MfSpace.sm, MfSpace.gutter, 0),
              child: MfCard(
                tone: MfTone.primary,
                semanticLabel: 'Uploading report',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Uploading report...', style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: MfSpace.xs),
                    const LinearProgressIndicator(),
                  ],
                ),
              ),
            ),

          // Reports List
          Expanded(
            child: reportsAsync.when(
              loading: () => Padding(
                padding: const EdgeInsets.all(MfSpace.gutter),
                child: MfSkeleton.list(count: 4, itemHeight: 80),
              ),
              error: (err, _) => MfErrorState(
                title: 'Unable to load reports',
                message: err.toString(),
                onRetry: userId == null
                    ? null
                    : () => ref.invalidate(medicalReportsProvider(userId)),
              ),
              data: (reports) => reports.isEmpty
                  ? MfEmptyState(
                      icon: Icons.folder_open_outlined,
                      title: 'No reports uploaded yet',
                      message:
                          'Upload photos or PDF documents (max 10 MB) so your records are ready when needed.',
                      actionLabel: 'Upload report',
                      actionIcon: Icons.upload_file_outlined,
                      onAction: isBusy ? null : _chooseUploadSource,
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
                      child: ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(MfSpace.gutter),
                        itemCount: reports.length,
                        separatorBuilder: (_, __) => const SizedBox(height: MfSpace.xs),
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
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final primary = MfColors.tone(context, MfTone.primary);
    final isPdf = _isPdf(report);
    final size = _formatSize(report.fileSizeBytes);
    final typeLabel = _reportTypeLabel(report.reportType);

    return MfCard(
      padding: const EdgeInsets.fromLTRB(MfSpace.sm, MfSpace.sm, MfSpace.xxs, MfSpace.sm),
      onTap: () => _viewReport(report),
      semanticLabel:
          '${report.fileName}, ${isPdf ? 'PDF' : 'image'}, uploaded ${_formatDate(report.uploadedAt)}. Tap to ${isPdf ? 'open' : 'view'}.',
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: primary.container, borderRadius: MfRadius.smAll),
            child: Icon(
              isPdf ? Icons.picture_as_pdf_outlined : Icons.image_outlined,
              color: primary.foreground,
            ),
          ),
          const SizedBox(width: MfSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  report.fileName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  'Uploaded ${_formatDate(report.uploadedAt)}${size.isEmpty ? '' : ' · $size'}',
                  style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: MfSpace.xxs),
                Wrap(
                  spacing: MfSpace.xxs,
                  runSpacing: MfSpace.xxs,
                  children: [
                    MfStatusChip(label: isPdf ? 'PDF' : 'Image'),
                    if (typeLabel != null) MfStatusChip(label: typeLabel, tone: MfTone.primary),
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<_ReportAction>(
            tooltip: 'Report options',
            icon: const Icon(Icons.more_vert_rounded),
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
                  leading: Icon(isPdf ? Icons.open_in_new_rounded : Icons.visibility_outlined),
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
              PopupMenuItem(
                value: _ReportAction.delete,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.delete_outline_rounded, color: MfColors.sos(ctx)),
                  title: Text('Delete', style: TextStyle(color: MfColors.sos(ctx))),
                ),
              ),
            ],
          ),
        ],
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
    return MfScaffold(
      title: widget.title,
      subtitle: 'Pinch to zoom',
      body: FutureBuilder<Uint8List>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const MfLoading(label: 'Loading report');
          }
          final bytes = snapshot.data;
          if (snapshot.hasError || bytes == null || bytes.isEmpty) {
            return _buildError();
          }
          return ColoredBox(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Center(
              child: InteractiveViewer(
                clipBehavior: Clip.none,
                maxScale: 5.0,
                child: Image.memory(
                  bytes,
                  semanticLabel: widget.title,
                  errorBuilder: (_, __, ___) => _buildError(),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildError() {
    return MfErrorState(
      title: 'Report image not available',
      onRetry: _retry,
    );
  }
}
