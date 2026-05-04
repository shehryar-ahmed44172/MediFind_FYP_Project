import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/medical_profile_provider.dart';
import '../../theme/app_theme.dart';

class EditMedicalProfileScreen extends ConsumerStatefulWidget {
  const EditMedicalProfileScreen({super.key});

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
        // Pop back to MedicalProfileScreen — it rebuilds from the Riverpod cache
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.error_outline_rounded, color: Colors.red, size: 28),
                SizedBox(width: 10),
                Text('Save Failed'),
              ],
            ),
            content: const Text(
              'Unable to save your medical profile. Please check your internet connection and try again.',
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('OK'),
              ),
            ],
          ),
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
            _buildSectionHeader('Blood Group', Icons.bloodtype_rounded, Colors.red),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _selectedBloodGroup,
              decoration: const InputDecoration(
                labelText: 'Blood Group',
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
            _buildSectionHeader('Disability Type', Icons.accessible_forward_rounded, Colors.purple),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _selectedDisabilityType,
              decoration: const InputDecoration(
                labelText: 'Disability Type',
              ),
              items: _disabilityTypes
                  .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                  .toList(),
              onChanged: (v) {
                if (v != null) {
                  setState(() => _selectedDisabilityType = v);
                }
              },
            ),
            const SizedBox(height: 24),

            // Allergies
            _buildSectionHeader('Allergies', Icons.science_outlined, Colors.orange),
            const SizedBox(height: 8),
            TextFormField(
              controller: _allergiesController,
              maxLines: 2,
              maxLength: 300,
              decoration: const InputDecoration(
                labelText: 'Allergies',
                hintText: 'e.g. Penicillin, Peanuts (comma-separated)',
              ),
              validator: (v) {
                if (v != null && v.trim().length > 300) return 'Maximum 300 characters';
                return null;
              },
            ),
            const SizedBox(height: 24),

            // Chronic Diseases
            _buildSectionHeader('Chronic Diseases', Icons.health_and_safety_outlined, Colors.pink),
            const SizedBox(height: 8),
            TextFormField(
              controller: _diseasesController,
              maxLines: 2,
              maxLength: 300,
              decoration: const InputDecoration(
                labelText: 'Chronic Diseases',
                hintText: 'e.g. Diabetes, Hypertension (comma-separated)',
              ),
              validator: (v) {
                if (v != null && v.trim().length > 300) return 'Maximum 300 characters';
                return null;
              },
            ),
            const SizedBox(height: 24),

            // Medications
            _buildSectionHeader('Current Medications', Icons.medication_outlined, AppColors.primary),
            const SizedBox(height: 8),
            TextFormField(
              controller: _medicationsController,
              maxLines: 3,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: 'Medications',
                hintText: 'e.g. Metformin 500mg, Lisinopril 10mg (comma-separated)',
              ),
              validator: (v) {
                if (v != null && v.trim().length > 500) return 'Maximum 500 characters';
                return null;
              },
            ),
            const SizedBox(height: 24),

            // Additional Notes
            _buildSectionHeader('Additional Notes', Icons.notes_outlined, Colors.teal),
            const SizedBox(height: 8),
            TextFormField(
              controller: _additionalNotesController,
              maxLines: 4,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: 'Additional Medical Information',
                hintText: 'Any other important medical information',
              ),
              validator: (v) {
                if (v != null && v.trim().length > 500) return 'Maximum 500 characters';
                return null;
              },
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
