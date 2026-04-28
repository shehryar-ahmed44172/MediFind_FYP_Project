import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/medical_report_provider.dart';
import '../../../domain/entities/medical_report.dart';
import 'package:medifind_mobile_application/core/utils/responsive.dart';

class MedicalReportsScreen extends ConsumerStatefulWidget {
  const MedicalReportsScreen({super.key});

  @override
  ConsumerState<MedicalReportsScreen> createState() => _MedicalReportsScreenState();
}

class _MedicalReportsScreenState extends ConsumerState<MedicalReportsScreen> {
  final ImagePicker _picker = ImagePicker();
  double _uploadProgress = 0.0;

  Future<void> _pickAndUpload(String reportType) async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null) return;

    await _upload(File(picked.path), reportType);
  }

  Future<void> _takeCameraPhoto(String reportType) async {
    final picked = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (picked == null) return;

    await _upload(File(picked.path), reportType);
  }

  Future<void> _upload(File file, String reportType) async {
    final userId = ref.read(currentUserIdProvider).valueOrNull;
    if (userId == null) {
      _showError('User session not found. Please log in again.');
      return;
    }

    setState(() => _uploadProgress = 0.01);

    try {
      await ref.read(medicalReportsNotifierProvider.notifier).uploadReport(
            file: file,
            reportType: reportType,
            userId: userId,
            onProgress: (p) => setState(() => _uploadProgress = p),
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Medical report uploaded successfully'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _uploadProgress = 0.0);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _renameReport(MedicalReport report) {
    final userId = ref.read(currentUserIdProvider).valueOrNull;
    if (userId == null) return;

    final controller = TextEditingController(text: report.fileName);
    showDialog(
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
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isEmpty || newName == report.fileName) {
                Navigator.pop(ctx);
                return;
              }
              Navigator.pop(ctx);
              try {
                await ref
                    .read(medicalReportsNotifierProvider.notifier)
                    .renameReport(report.id, newName, userId);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Report renamed'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } catch (e) {
                _showError(e.toString());
              }
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  void _deleteReport(MedicalReport report) {
    final userId = ref.read(currentUserIdProvider).valueOrNull;
    if (userId == null) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Report'),
        content: Text('Are you sure you want to delete "${report.fileName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref
                    .read(medicalReportsNotifierProvider.notifier)
                    .deleteReport(report.id, userId);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Report deleted'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } catch (e) {
                _showError(e.toString());
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showReportOptions(MedicalReport report) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Rename'),
              onTap: () {
                Navigator.pop(ctx);
                _renameReport(report);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(ctx);
                _deleteReport(report);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(currentUserIdProvider).valueOrNull;
    final reportsAsync = userId != null
        ? ref.watch(medicalReportsProvider(userId))
        : const AsyncValue<List<MedicalReport>>.data([]);
    
    final isPageLoading = ref.watch(medicalReportsNotifierProvider).isLoading;

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
                  'Upload medical record images securely',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _uploadProgress > 0 ? null : () => _pickAndUpload('OTHER'),
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('Gallery'),
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _uploadProgress > 0 ? null : () => _takeCameraPhoto('OTHER'),
                        icon: const Icon(Icons.camera_alt_outlined),
                        label: const Text('Camera'),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_uploadProgress > 0) ...[
                  const SizedBox(height: 12),
                  LinearProgressIndicator(value: _uploadProgress),
                  const SizedBox(height: 4),
                  Text('Uploading... ${( _uploadProgress * 100).toInt()}%', 
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ],
            ),
          ),

          // Reports List
          Expanded(
            child: reportsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 48),
                    const SizedBox(height: 16),
                    Text('Error: $err'),
                    TextButton(
                      onPressed: () => userId != null ? ref.invalidate(medicalReportsProvider(userId)) : null,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              data: (reports) => reports.isEmpty && !isPageLoading
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.folder_outlined,
                              size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          const Text('No reports uploaded yet',
                              style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: reports.length,
                      itemBuilder: (ctx, i) {
                        final report = reports[i];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                             leading: Container(
                              width: 12.wp,
                              height: 12.wp,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.description_outlined, color: AppColors.primary),
                            ),
                            title: Text(report.fileName,
                                style:
                                    const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(
                              'Uploaded ${_formatDate(report.uploadedAt)}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.more_vert),
                              onPressed: () => _showReportOptions(report),
                              tooltip: 'Report options',
                            ),
                            onTap: () => _viewReport(report),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  void _viewReport(MedicalReport report) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => Scaffold(
          appBar: AppBar(title: Text(report.fileName)),
          backgroundColor: Colors.black,
          body: Center(
            child: InteractiveViewer(
              clipBehavior: Clip.none,
              maxScale: 5.0,
              child: Image.network(
                report.downloadUrl,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const Center(child: CircularProgressIndicator(color: Colors.white));
                },
                errorBuilder: (_, __, ___) => const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.broken_image_outlined, color: Colors.white54, size: 64),
                      SizedBox(height: 16),
                      Text('Cloud image not available', style: TextStyle(color: Colors.white70)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

