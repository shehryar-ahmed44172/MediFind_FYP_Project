import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/medical_profile_provider.dart';
import '../../theme/app_theme.dart';

class EditMedicalProfileScreen extends ConsumerStatefulWidget {
  const EditMedicalProfileScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<EditMedicalProfileScreen> createState() =>
      _EditMedicalProfileScreenState();
}

class _EditMedicalProfileScreenState
    extends ConsumerState<EditMedicalProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _allergiesController = TextEditingController();
  final _diseasesController = TextEditingController();
  final _medicationsController = TextEditingController();
  final _additionalNotesController = TextEditingController();
  String _selectedBloodGroup = 'O+';
  String _selectedDisabilityType = 'None';
  bool _isLoading = false;
  bool _initialized = false;

  static const List<String> _bloodGroups = [
    'O+', 'O-', 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'Unknown'
  ];

  static const List<String> _disabilityTypes = [
    'None',
    'Visual Impairment',
    'Hearing Impairment',
    'Physical / Mobility Disability',
    'Cognitive / Intellectual Disability',
    'Mental Health Condition',
    'Chronic Illness',
    'Other',
  ];

  @override
  void dispose() {
    _allergiesController.dispose();
    _diseasesController.dispose();
    _medicationsController.dispose();
    _additionalNotesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final userId = await ref.read(currentUserIdProvider.future);
      if (userId == null) throw Exception('Not logged in');

      final params = UpdateMedicalProfileParams(
        userId: userId,
        bloodType: _selectedBloodGroup,
        disabilityType:
            _selectedDisabilityType == 'None' ? null : _selectedDisabilityType,
        allergies: _parseList(_allergiesController.text),
        chronicDiseases: _parseList(_diseasesController.text),
        medications: _parseList(_medicationsController.text),
        additionalNotes: _additionalNotesController.text.trim(),
      );

      await ref.read(updateMedicalProfileProvider(params).future);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Medical profile updated!'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating),
        );
        context.go('/home/medical-profile');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Save failed: $e'),
              backgroundColor: Colors.red.shade700,
              behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<String> _parseList(String input) {
    return input
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    // Pre-fill form with existing profile data
    if (!_initialized) {
      final userId = ref.watch(currentUserIdProvider).valueOrNull;
      if (userId != null) {
        final existing = ref.watch(getMedicalProfileProvider(userId));
        existing.whenData((profile) {
          if (profile != null && !_initialized) {
            _initialized = true;
            _selectedBloodGroup = profile.bloodType.isNotEmpty
                ? profile.bloodType
                : 'O+';
            _selectedDisabilityType =
                profile.disabilityType ?? 'None';
            _allergiesController.text = profile.allergies.join(', ');
            _diseasesController.text = profile.chronicDiseases.join(', ');
            _medicationsController.text =
                profile.medications.map((m) => m.name).join(', ');
            _additionalNotesController.text =
                profile.additionalNotes ?? '';
          }
        });
      }
    }

    return Scaffold(
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Blood Group
            _buildSectionHeader('Blood Group', Icons.bloodtype_outlined, Colors.red),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedBloodGroup,
              decoration: const InputDecoration(
                labelText: 'Blood Group',
                prefixIcon: Icon(Icons.bloodtype_outlined),
              ),
              items: _bloodGroups
                  .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _selectedBloodGroup = v);
              },
            ),
            const SizedBox(height: 24),

            // Disability Type
            _buildSectionHeader('Disability Type', Icons.accessibility_new_outlined, Colors.purple),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedDisabilityType,
              decoration: const InputDecoration(
                labelText: 'Disability Type',
                prefixIcon: Icon(Icons.accessibility_new_outlined),
              ),
              items: _disabilityTypes
                  .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                  .toList(),
              onChanged: (v) {
                if (v != null)
                  setState(() => _selectedDisabilityType = v);
              },
            ),
            const SizedBox(height: 24),

            // Allergies
            _buildSectionHeader('Allergies', Icons.warning_amber_outlined, Colors.orange),
            const SizedBox(height: 8),
            TextFormField(
              controller: _allergiesController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Allergies',
                hintText: 'e.g. Penicillin, Peanuts (comma-separated)',
                prefixIcon: Icon(Icons.warning_amber_outlined),
              ),
            ),
            const SizedBox(height: 24),

            // Chronic Diseases
            _buildSectionHeader('Chronic Diseases', Icons.healing_outlined, Colors.pink),
            const SizedBox(height: 8),
            TextFormField(
              controller: _diseasesController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Chronic Diseases',
                hintText: 'e.g. Diabetes, Hypertension (comma-separated)',
                prefixIcon: Icon(Icons.healing_outlined),
              ),
            ),
            const SizedBox(height: 24),

            // Medications
            _buildSectionHeader('Current Medications', Icons.medication_outlined, AppColors.primary),
            const SizedBox(height: 8),
            TextFormField(
              controller: _medicationsController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Medications',
                hintText: 'e.g. Metformin 500mg, Lisinopril 10mg (comma-separated)',
                prefixIcon: Icon(Icons.medication_outlined),
              ),
            ),
            const SizedBox(height: 24),

            // Additional Notes
            _buildSectionHeader('Additional Notes', Icons.notes_outlined, Colors.teal),
            const SizedBox(height: 8),
            TextFormField(
              controller: _additionalNotesController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Additional Medical Information',
                hintText: 'Any other important medical information',
                prefixIcon: Icon(Icons.notes_outlined),
              ),
            ),
            const SizedBox(height: 32),

            ElevatedButton(
              onPressed: _isLoading ? null : _save,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Save Medical Profile',
                      style: TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Text(title,
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}
