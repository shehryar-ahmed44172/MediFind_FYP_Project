import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/medical_profile_provider.dart';
import '../../widgets/design_system/design_system.dart';

class EditMedicalProfileScreen extends ConsumerStatefulWidget {
  const EditMedicalProfileScreen({super.key});

  @override
  ConsumerState<EditMedicalProfileScreen> createState() => _EditMedicalProfileScreenState();
}

class _EditMedicalProfileScreenState extends ConsumerState<EditMedicalProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  // Input controllers for the chip / list editors (pending, not-yet-added text).
  final _allergiesController = TextEditingController();
  final _diseasesController = TextEditingController();
  final _medicationsController = TextEditingController();
  final _additionalNotesController = TextEditingController();

  final List<String> _allergies = [];
  final List<String> _diseases = [];
  final List<String> _medications = [];

  String _selectedBloodGroup = 'O+';
  String _selectedDisabilityType = 'None';
  bool _isLoading = false;
  bool _initialized = false;

  static const List<String> _bloodGroups = ['O+', 'O-', 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'Unknown'];

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

  /// Moves any typed-but-not-added text into the matching list so nothing
  /// the user typed is lost on save.
  void _commitPending() {
    _addFrom(_allergiesController, _allergies);
    _addFrom(_diseasesController, _diseases);
    _addFrom(_medicationsController, _medications);
  }

  void _addFrom(TextEditingController controller, List<String> target) {
    final items = _parseList(controller.text);
    if (items.isEmpty) return;
    setState(() {
      for (final item in items) {
        if (!target.any((t) => t.toLowerCase() == item.toLowerCase())) {
          target.add(item);
        }
      }
      controller.clear();
    });
  }

  void _removeFrom(List<String> target, String item) {
    setState(() => target.remove(item));
  }

  Future<void> _save() async {
    _commitPending();
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final userId = await ref.read(currentUserIdProvider.future);
      if (userId == null) throw Exception('Not logged in');

      final params = UpdateMedicalProfileParams(
        userId: userId,
        bloodType: _selectedBloodGroup,
        disabilityType: _selectedDisabilityType == 'None' ? null : _selectedDisabilityType,
        allergies: List<String>.from(_allergies),
        chronicDiseases: List<String>.from(_diseases),
        medications: List<String>.from(_medications),
        additionalNotes: _additionalNotesController.text.trim(),
      );

      await ref.read(updateMedicalProfileProvider(params).future);

      if (mounted) {
        showMfSnackBar(context, 'Medical profile updated', tone: MfTone.success);
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            icon: Icon(Icons.error_outline_rounded, color: MfColors.sos(ctx), size: 28),
            title: const Text('Save failed'),
            content: const Text(
              'Unable to save your medical profile. Please check your internet connection and try again.',
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
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
    return input.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
  }

  /// Same limit the backend-facing comma separated text had before.
  String? _maxLength(List<String> items, TextEditingController pending, int max) {
    final all = [...items, ..._parseList(pending.text)];
    if (all.join(', ').length > max) return 'Maximum $max characters';
    return null;
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
            _selectedBloodGroup = profile.bloodType.isNotEmpty ? profile.bloodType : 'O+';
            _selectedDisabilityType = profile.disabilityType ?? 'None';
            _allergies
              ..clear()
              ..addAll(profile.allergies);
            _diseases
              ..clear()
              ..addAll(profile.chronicDiseases);
            _medications
              ..clear()
              ..addAll(profile.medications.map((m) => m.name));
            _additionalNotesController.text = profile.additionalNotes ?? '';
          }
        });
      }
    }

    final bloodGroups = [
      ..._bloodGroups,
      if (!_bloodGroups.contains(_selectedBloodGroup)) _selectedBloodGroup,
    ];
    final disabilityTypes = [
      ..._disabilityTypes,
      if (!_disabilityTypes.contains(_selectedDisabilityType)) _selectedDisabilityType,
    ];

    return MfScaffold(
      title: 'Edit medical profile',
      subtitle: 'Keep your health information up to date',
      bottomBar: MfPrimaryButton(
        label: 'Save medical profile',
        icon: Icons.save_outlined,
        loading: _isLoading,
        onPressed: _save,
      ),
      body: Form(
        key: _formKey,
        // Column (not a lazy ListView) so every field's validator runs on save.
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(MfSpace.gutter, MfSpace.md, MfSpace.gutter, MfSpace.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const MfInfoBanner(
                icon: Icons.shield_outlined,
                tone: MfTone.primary,
                title: 'Private and encrypted',
                message:
                    'This data is encrypted and only shared with your assigned responder during an active emergency.',
              ),
              const SizedBox(height: MfSpace.lg),

              // ── Critical information ─────────────────────────────────────
              const MfSectionTitle(
                'Blood group',
                subtitle: 'Required for emergency transfusion decisions',
              ),
              const SizedBox(height: MfSpace.xs),
              Semantics(
                label: 'Blood group',
                container: true,
                child: Wrap(
                  spacing: MfSpace.xs,
                  runSpacing: MfSpace.xs,
                  children: [
                    for (final g in bloodGroups)
                      ChoiceChip(
                        label: Text(g),
                        selected: _selectedBloodGroup == g,
                        materialTapTargetSize: MaterialTapTargetSize.padded,
                        onSelected: (_) => setState(() => _selectedBloodGroup = g),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: MfSpace.lg),

              const MfSectionTitle(
                'Allergies',
                subtitle: 'Critical: affects which medications can be given',
              ),
              const SizedBox(height: MfSpace.xs),
              _ChipListEditor(
                controller: _allergiesController,
                items: _allergies,
                label: 'Add an allergy',
                hint: 'e.g. Penicillin, Peanuts, Latex',
                addTooltip: 'Add allergy',
                itemNoun: 'allergy',
                tone: MfTone.danger,
                onAdd: () => _addFrom(_allergiesController, _allergies),
                onRemove: (item) => _removeFrom(_allergies, item),
                validator: (_) => _maxLength(_allergies, _allergiesController, 300),
              ),
              const SizedBox(height: MfSpace.lg),

              // ── Conditions & medications ─────────────────────────────────
              const MfSectionTitle(
                'Chronic conditions',
                subtitle: 'Pre-existing conditions that affect treatment',
              ),
              const SizedBox(height: MfSpace.xs),
              _ChipListEditor(
                controller: _diseasesController,
                items: _diseases,
                label: 'Add a condition',
                hint: 'e.g. Diabetes Type 2, Hypertension, Asthma',
                addTooltip: 'Add condition',
                itemNoun: 'condition',
                tone: MfTone.warning,
                onAdd: () => _addFrom(_diseasesController, _diseases),
                onRemove: (item) => _removeFrom(_diseases, item),
                validator: (_) => _maxLength(_diseases, _diseasesController, 300),
              ),
              const SizedBox(height: MfSpace.lg),

              const MfSectionTitle(
                'Current medications',
                subtitle: 'Include name and dosage to prevent dangerous drug interactions',
              ),
              const SizedBox(height: MfSpace.xs),
              _ChipListEditor(
                controller: _medicationsController,
                items: _medications,
                label: 'Add a medication',
                hint: 'e.g. Metformin 500mg',
                addTooltip: 'Add medication',
                itemNoun: 'medication',
                asList: true,
                onAdd: () => _addFrom(_medicationsController, _medications),
                onRemove: (item) => _removeFrom(_medications, item),
                validator: (_) => _maxLength(_medications, _medicationsController, 500),
              ),
              const SizedBox(height: MfSpace.lg),

              // ── Accessibility ────────────────────────────────────────────
              const MfSectionTitle(
                'Accessibility need',
                subtitle: 'Helps responders prepare the right support approach',
              ),
              const SizedBox(height: MfSpace.xs),
              DropdownButtonFormField<String>(
                key: ValueKey('disability-$_initialized'),
                initialValue: _selectedDisabilityType,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Disability / accessibility type',
                  prefixIcon: Icon(Icons.accessibility_new_rounded),
                ),
                items: disabilityTypes.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _selectedDisabilityType = v);
                },
              ),
              const SizedBox(height: MfSpace.lg),

              // ── Notes ────────────────────────────────────────────────────
              const MfSectionTitle(
                'Additional notes',
                subtitle: 'Any other information first responders should know',
              ),
              const SizedBox(height: MfSpace.xs),
              TextFormField(
                controller: _additionalNotesController,
                maxLines: 4,
                maxLength: 500,
                decoration: const InputDecoration(
                  labelText: 'Additional medical information',
                  hintText: 'e.g. DNR order, previous surgeries, implants, blood pressure notes',
                  alignLabelWithHint: true,
                ),
                validator: (v) {
                  if (v != null && v.trim().length > 500) {
                    return 'Maximum 500 characters';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Text input + add button with removable chips (or rows when [asList]).
class _ChipListEditor extends StatelessWidget {
  final TextEditingController controller;
  final List<String> items;
  final String label;
  final String hint;
  final String addTooltip;
  final String itemNoun;
  final MfTone tone;
  final bool asList;
  final VoidCallback onAdd;
  final ValueChanged<String> onRemove;
  final FormFieldValidator<String> validator;

  const _ChipListEditor({
    required this.controller,
    required this.items,
    required this.label,
    required this.hint,
    required this.addTooltip,
    required this.itemNoun,
    required this.onAdd,
    required this.onRemove,
    required this.validator,
    this.tone = MfTone.primary,
    this.asList = false,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final t = MfColors.tone(context, tone);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: controller,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => onAdd(),
          validator: validator,
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            helperText: 'Tap add, or separate several entries with commas',
            suffixIcon: MfIconButton(
              icon: Icons.add_circle_outline_rounded,
              tooltip: addTooltip,
              color: cs.primary,
              onPressed: onAdd,
            ),
          ),
        ),
        const SizedBox(height: MfSpace.xs),
        if (items.isEmpty)
          Text('None added', style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant))
        else if (asList)
          MfListGroup(
            children: [
              for (final item in items)
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: MfSize.minTouch),
                  child: Padding(
                    padding: const EdgeInsets.only(left: MfSpace.md, right: MfSpace.xxs),
                    child: Row(
                      children: [
                        Icon(Icons.medication_outlined, size: 20, color: cs.onSurfaceVariant),
                        const SizedBox(width: MfSpace.sm),
                        Expanded(child: Text(item, style: text.bodyLarge)),
                        MfIconButton(
                          icon: Icons.close_rounded,
                          tooltip: 'Remove $itemNoun $item',
                          onPressed: () => onRemove(item),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          )
        else
          Wrap(
            spacing: MfSpace.xs,
            runSpacing: 0,
            children: [
              for (final item in items)
                InputChip(
                  label: Text(item),
                  labelStyle: text.labelLarge?.copyWith(color: t.foreground),
                  backgroundColor: Color.alphaBlend(t.container, cs.surface),
                  side: BorderSide(color: t.border),
                  deleteIconColor: t.foreground,
                  deleteButtonTooltipMessage: 'Remove $itemNoun $item',
                  materialTapTargetSize: MaterialTapTargetSize.padded,
                  onDeleted: () => onRemove(item),
                ),
            ],
          ),
      ],
    );
  }
}
