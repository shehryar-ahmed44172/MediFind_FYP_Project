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
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
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
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Pre-fill form with existing profile data
    if (!_initialized) {
      final userId = ref.watch(currentUserIdProvider).valueOrNull;
      if (userId != null) {
        final existing = ref.watch(getMedicalProfileProvider(userId));
        existing.whenData((profile) {
          if (profile != null && !_initialized) {
            _initialized = true;
            _selectedBloodGroup =
                profile.bloodType.isNotEmpty ? profile.bloodType : 'O+';
            _selectedDisabilityType = profile.disabilityType ?? 'None';
            _allergiesController.text = profile.allergies.join(', ');
            _diseasesController.text = profile.chronicDiseases.join(', ');
            _medicationsController.text =
                profile.medications.map((m) => m.name).join(', ');
            _additionalNotesController.text = profile.additionalNotes ?? '';
          }
        });
      }
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: theme.colorScheme.onSurface),
          onPressed: () => context.pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Medical Profile',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: theme.colorScheme.onSurface,
              ),
            ),
            Text(
              'Keep your health information up to date',
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onSurface.withOpacity(0.45),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        titleSpacing: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            // ── Privacy notice ───────────────────────────────────────────
            Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Row(
                children: [
                  Icon(Icons.shield_outlined,
                      size: 16, color: Colors.blue.shade700),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'This data is encrypted and only shared with your assigned responder during an active emergency.',
                      style: TextStyle(
                          fontSize: 11.5,
                          color: Colors.blue.shade700,
                          height: 1.4),
                    ),
                  ),
                ],
              ),
            ),

            // ── Blood Group ──────────────────────────────────────────────
            _buildSectionCard(
              theme: theme,
              isDark: isDark,
              icon: Icons.bloodtype_rounded,
              color: const Color(0xFFD32F2F),
              title: 'Blood Group',
              subtitle: 'Required for emergency transfusion decisions',
              child: DropdownButtonFormField<String>(
                value: _selectedBloodGroup,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.bloodtype_rounded,
                      color: Color(0xFFD32F2F), size: 20),
                  labelText: 'Select blood group',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color:
                            theme.colorScheme.outline.withOpacity(0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: Color(0xFFD32F2F), width: 1.5),
                  ),
                ),
                items: _bloodGroups
                    .map((g) =>
                        DropdownMenuItem(value: g, child: Text(g)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _selectedBloodGroup = v);
                },
              ),
            ),

            // ── Accessibility Need ───────────────────────────────────────
            _buildSectionCard(
              theme: theme,
              isDark: isDark,
              icon: Icons.accessibility_new_rounded,
              color: const Color(0xFF7B1FA2),
              title: 'Accessibility Need',
              subtitle: 'Helps responders prepare the right support approach',
              child: DropdownButtonFormField<String>(
                value: _selectedDisabilityType,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.accessibility_new_rounded,
                      color: Color(0xFF7B1FA2), size: 20),
                  labelText: 'Select disability / accessibility type',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color:
                            theme.colorScheme.outline.withOpacity(0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: Color(0xFF7B1FA2), width: 1.5),
                  ),
                ),
                items: _disabilityTypes
                    .map((d) =>
                        DropdownMenuItem(value: d, child: Text(d)))
                    .toList(),
                onChanged: (v) {
                  if (v != null)
                    setState(() => _selectedDisabilityType = v);
                },
              ),
            ),

            // ── Allergies ────────────────────────────────────────────────
            _buildSectionCard(
              theme: theme,
              isDark: isDark,
              icon: Icons.warning_amber_rounded,
              color: const Color(0xFFE65100),
              title: 'Allergies',
              subtitle: 'Critical — affects which medications can be given',
              child: TextFormField(
                controller: _allergiesController,
                maxLines: 3,
                maxLength: 300,
                decoration: InputDecoration(
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(bottom: 48),
                    child: Icon(Icons.warning_amber_rounded,
                        color: Color(0xFFE65100), size: 20),
                  ),
                  labelText: 'Known allergies',
                  hintText: 'e.g. Penicillin, Peanuts, Latex',
                  helperText: 'Separate multiple entries with commas',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color:
                            theme.colorScheme.outline.withOpacity(0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: Color(0xFFE65100), width: 1.5),
                  ),
                ),
                validator: (v) {
                  if (v != null && v.trim().length > 300)
                    return 'Maximum 300 characters';
                  return null;
                },
              ),
            ),

            // ── Chronic Diseases ─────────────────────────────────────────
            _buildSectionCard(
              theme: theme,
              isDark: isDark,
              icon: Icons.monitor_heart_rounded,
              color: const Color(0xFFC62828),
              title: 'Chronic Diseases',
              subtitle: 'Pre-existing conditions that affect treatment',
              child: TextFormField(
                controller: _diseasesController,
                maxLines: 3,
                maxLength: 300,
                decoration: InputDecoration(
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(bottom: 48),
                    child: Icon(Icons.monitor_heart_rounded,
                        color: Color(0xFFC62828), size: 20),
                  ),
                  labelText: 'Chronic conditions',
                  hintText:
                      'e.g. Diabetes Type 2, Hypertension, Asthma',
                  helperText: 'Separate multiple entries with commas',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color:
                            theme.colorScheme.outline.withOpacity(0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: Color(0xFFC62828), width: 1.5),
                  ),
                ),
                validator: (v) {
                  if (v != null && v.trim().length > 300)
                    return 'Maximum 300 characters';
                  return null;
                },
              ),
            ),

            // ── Current Medications ──────────────────────────────────────
            _buildSectionCard(
              theme: theme,
              isDark: isDark,
              icon: Icons.medication_rounded,
              color: const Color(0xFF0277BD),
              title: 'Current Medications',
              subtitle: 'Include name and dosage — prevents dangerous drug interactions',
              child: TextFormField(
                controller: _medicationsController,
                maxLines: 3,
                maxLength: 500,
                decoration: InputDecoration(
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(bottom: 48),
                    child: Icon(Icons.medication_rounded,
                        color: Color(0xFF0277BD), size: 20),
                  ),
                  labelText: 'Current medications',
                  hintText: 'e.g. Metformin 500mg, Lisinopril 10mg',
                  helperText: 'Separate multiple medications with commas',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color:
                            theme.colorScheme.outline.withOpacity(0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: Color(0xFF0277BD), width: 1.5),
                  ),
                ),
                validator: (v) {
                  if (v != null && v.trim().length > 500)
                    return 'Maximum 500 characters';
                  return null;
                },
              ),
            ),

            // ── Additional Notes ─────────────────────────────────────────
            _buildSectionCard(
              theme: theme,
              isDark: isDark,
              icon: Icons.description_rounded,
              color: const Color(0xFF00695C),
              title: 'Additional Notes',
              subtitle: 'Any other information first responders should know',
              child: TextFormField(
                controller: _additionalNotesController,
                maxLines: 4,
                maxLength: 500,
                decoration: InputDecoration(
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(bottom: 64),
                    child: Icon(Icons.description_rounded,
                        color: Color(0xFF00695C), size: 20),
                  ),
                  labelText: 'Additional medical information',
                  hintText:
                      'e.g. DNR order, previous surgeries, implants, blood pressure notes...',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color:
                            theme.colorScheme.outline.withOpacity(0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: Color(0xFF00695C), width: 1.5),
                  ),
                ),
                validator: (v) {
                  if (v != null && v.trim().length > 500)
                    return 'Maximum 500 characters';
                  return null;
                },
              ),
            ),

            const SizedBox(height: 8),

            // ── Save Button ──────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor:
                      AppColors.primary.withOpacity(0.4),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.save_rounded,
                              size: 20, color: Colors.white),
                          SizedBox(width: 10),
                          Text(
                            'Save Medical Profile',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Section card builder ───────────────────────────────────────────────────
  Widget _buildSectionCard({
    required ThemeData theme,
    required bool isDark,
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.05)
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : theme.colorScheme.outline.withOpacity(0.12),
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                )
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card header strip
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.06),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(
                bottom: BorderSide(color: color.withOpacity(0.12)),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 17),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: color,
                          letterSpacing: 0.1,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 10.5,
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Input field
          Padding(
            padding: const EdgeInsets.all(14),
            child: child,
          ),
        ],
      ),
    );
  }
}
