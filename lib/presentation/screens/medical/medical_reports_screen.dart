import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class MedicalReportsScreen extends StatefulWidget {
  const MedicalReportsScreen({Key? key}) : super(key: key);

  @override
  State<MedicalReportsScreen> createState() => _MedicalReportsScreenState();
}

class _MedicalReportsScreenState extends State<MedicalReportsScreen> {
  final List<_MedicalReport> _reports = [];
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;

  Future<void> _pickAndUpload() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null) return;

    setState(() => _isUploading = true);
    // Simulate upload delay
    await Future.delayed(const Duration(seconds: 1));

    setState(() {
      _reports.add(_MedicalReport(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        filePath: picked.path,
        name: 'Report ${_reports.length + 1}',
        uploadedAt: DateTime.now(),
      ));
      _isUploading = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Medical report uploaded successfully'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _takeCameraPhoto() async {
    final picked = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (picked == null) return;

    setState(() => _isUploading = true);
    await Future.delayed(const Duration(seconds: 1));

    setState(() {
      _reports.add(_MedicalReport(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        filePath: picked.path,
        name: 'Report ${_reports.length + 1}',
        uploadedAt: DateTime.now(),
      ));
      _isUploading = false;
    });
  }

  void _deleteReport(String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Report'),
        content: const Text('Are you sure you want to delete this medical report?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _reports.removeWhere((r) => r.id == id);
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Report deleted'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Medical Reports'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Upload Section
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              children: [
                const Icon(Icons.upload_file_outlined,
                    size: 40, color: Colors.blue),
                const SizedBox(height: 8),
                const Text('Upload Medical Reports',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
                        onPressed: _isUploading ? null : _pickAndUpload,
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
                        onPressed: _isUploading ? null : _takeCameraPhoto,
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
                if (_isUploading) ...[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(),
                  const SizedBox(height: 4),
                  const Text('Uploading...', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ],
            ),
          ),

          // Reports List
          Expanded(
            child: _reports.isEmpty
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
                    itemCount: _reports.length,
                    itemBuilder: (ctx, i) {
                      final report = _reports[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              File(report.filePath),
                              width: 56,
                              height: 56,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                  Icons.image_outlined,
                                  size: 40,
                                  color: Colors.blue),
                            ),
                          ),
                          title: Text(report.name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(
                            'Uploaded ${_formatDate(report.uploadedAt)}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.red),
                            onPressed: () => _deleteReport(report.id),
                            tooltip: 'Delete report',
                          ),
                          onTap: () => _viewReport(report),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _viewReport(_MedicalReport report) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => Scaffold(
          appBar: AppBar(title: Text(report.name)),
          body: Center(
            child: InteractiveViewer(
              child: Image.file(File(report.filePath)),
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

class _MedicalReport {
  final String id;
  final String filePath;
  final String name;
  final DateTime uploadedAt;

  _MedicalReport({
    required this.id,
    required this.filePath,
    required this.name,
    required this.uploadedAt,
  });
}
