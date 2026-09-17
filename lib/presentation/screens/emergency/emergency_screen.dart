import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../services/location/location_service.dart';
import '../../../core/utils/emergency_status.dart';
import '../../../core/utils/exceptions.dart';
import '../../providers/connectivity_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/accessibility_provider.dart';
import '../../widgets/design_system/design_system.dart';
import '../../widgets/map/map_warmup.dart';

class EmergencyScreen extends ConsumerStatefulWidget {
  const EmergencyScreen({super.key});

  @override
  ConsumerState<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends ConsumerState<EmergencyScreen> {
  String _selectedEmergencyType = EmergencyTypes.cardiac;
  final _additionalInfoController = TextEditingController();
  final _symptomsController = TextEditingController();
  bool _isFetchingLocation = false;
  bool _isClassifying = false;
  bool? _showTextClassifier; // null = default (open for deaf / text-only patients)
  Map<String, dynamic>? _aiResult;
  final FocusNode _otherFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Get the location and the map ready while the patient picks a type,
    // so Send SOS opens the countdown without waiting.
    LocationService().prewarm();
    Future.delayed(const Duration(milliseconds: 450), () {
      if (mounted) MapWarmup.run();
    });
  }

  // Values match the backend's specialist routing (SPECIALIST_MAP) + FALL/OTHER.
  static const List<Map<String, dynamic>> _emergencyTypes = [
    {'value': EmergencyTypes.cardiac, 'icon': Icons.favorite_outline_rounded},
    {'value': EmergencyTypes.stroke, 'icon': Icons.psychology_outlined},
    {'value': EmergencyTypes.breathing, 'icon': Icons.air_rounded},
    {'value': EmergencyTypes.trauma, 'icon': Icons.personal_injury_outlined},
    {'value': EmergencyTypes.fall, 'icon': Icons.accessibility_new_rounded},
    {'value': EmergencyTypes.seizure, 'icon': Icons.bolt_rounded},
    {'value': EmergencyTypes.diabetic, 'icon': Icons.bloodtype_outlined},
    {'value': EmergencyTypes.other, 'icon': Icons.medical_services_outlined},
  ];

  @override
  void dispose() {
    _additionalInfoController.dispose();
    _symptomsController.dispose();
    _otherFocusNode.dispose();
    super.dispose();
  }

  Future<void> _classifySymptoms() async {
    final symptoms = _symptomsController.text.trim();
    if (symptoms.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _isClassifying = true;
      _aiResult = null;
    });
    try {
      final apiClient = ref.read(apiClientProvider);
      final result = await apiClient.classifyEmergencySymptoms(symptoms);
      final type = result['emergencyType'] as String?;
      final confidence = (result['confidence'] as num?)?.toDouble() ?? 0;
      if (type == null || confidence <= 0) {
        throw StateError('classification unavailable');
      }
      if (mounted) {
        final knownValues = _emergencyTypes.map((e) => e['value'] as String).toSet();
        // Map classifier output to the screen's type list (best-effort)
        final mapped = knownValues.contains(type) ? type : _mapClassifierType(type);
        final reasoning = result['reasoning'] as String?;
        setState(() {
          _aiResult = {'type': mapped, 'confidence': confidence, 'reasoning': reasoning ?? ''};
          _selectedEmergencyType = mapped;
          if (mapped == EmergencyTypes.other && reasoning != null && reasoning.isNotEmpty) {
            _additionalInfoController.text = reasoning;
          }
        });
        HapticFeedback.mediumImpact();
        showMfSnackBar(
          context,
          'AI suggested: ${EmergencyTypes.label(mapped)}',
          tone: MfTone.success,
          duration: const Duration(seconds: 3),
        );
      }
    } catch (_) {
      if (mounted) {
        showMfSnackBar(context, 'AI classification unavailable. Please select the type manually.', tone: MfTone.warning);
      }
    } finally {
      if (mounted) setState(() => _isClassifying = false);
    }
  }

  String _mapClassifierType(String raw) {
    final normalized = EmergencyTypes.normalize(raw);
    return EmergencyTypes.all.contains(normalized) ? normalized : EmergencyTypes.other;
  }

  Future<void> _triggerSOS() async {
    final isConnected = ref.read(isConnectedProvider);

    if (!isConnected) {
      _showOfflineFallbackDialog();
      return;
    }

    setState(() => _isFetchingLocation = true);
    HapticFeedback.heavyImpact();

    try {
      final locationService = LocationService();
      final locationEnabled = await locationService.isLocationServiceEnabled();

      if (!locationEnabled) {
        if (mounted) {
          _showGpsDisabledDialog();
        }
        return;
      }

      // Real GPS fix or last known position only — never fake coordinates.
      // A fix from the last 2 minutes opens the countdown at once; the countdown
      // refines it before anything is sent.
      final recent = await locationService.recentPosition();
      final position = recent ?? await locationService.getCurrentLocation();

      if (mounted) {
        context.push('/home/sos-countdown', extra: {
          'emergencyType': _selectedEmergencyType,
          'latitude': position.latitude,
          'longitude': position.longitude,
          'isMocked': position.isMocked,
          'refineLocation': recent != null,
          'additionalInfo': _additionalInfoController.text.trim().isNotEmpty
              ? _additionalInfoController.text.trim()
              : null,
        });
      }
    } on LocationException catch (e) {
      if (mounted) _showLocationUnavailableDialog(e);
    } catch (_) {
      if (mounted) {
        _showLocationUnavailableDialog(
          LocationException(message: LocationService.unavailableMessage),
        );
      }
    } finally {
      if (mounted) setState(() => _isFetchingLocation = false);
    }
  }

  ButtonStyle _dangerFilled(BuildContext ctx) {
    final cs = Theme.of(ctx).colorScheme;
    return FilledButton.styleFrom(backgroundColor: cs.error, foregroundColor: cs.onError);
  }

  void _showOfflineFallbackDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.wifi_off_rounded, color: Theme.of(ctx).colorScheme.error, size: 28),
        title: const Text('No internet connection'),
        content: const Text(
          'You are offline. To get emergency help, you can call or SMS the emergency number.',
        ),
        actionsOverflowButtonSpacing: MfSpace.xs,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.sms_outlined),
            label: const Text('Send SMS'),
            onPressed: () {
              Navigator.pop(ctx);
              _launchEmergencyUri('sms:1122');
            },
          ),
          FilledButton.icon(
            style: _dangerFilled(ctx),
            icon: const Icon(Icons.phone_rounded),
            label: const Text('Call 1122'),
            onPressed: () {
              Navigator.pop(ctx);
              _launchEmergencyUri('tel:1122');
            },
          ),
        ],
      ),
    );
  }

  Future<void> _launchEmergencyUri(String uri) async {
    try {
      final ok = await launchUrl(Uri.parse(uri));
      if (!ok) throw Exception('launch failed');
    } catch (_) {
      if (mounted) {
        showMfSnackBar(context, 'Could not open the dialer. Please dial 1122 manually.', tone: MfTone.danger);
      }
    }
  }

  /// Location could not be determined: explain clearly and offer 1122.
  void _showLocationUnavailableDialog(LocationException e) {
    final permanentlyDenied = e.code == 'PERMISSION_PERMANENTLY_DENIED';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.location_off_outlined, color: Theme.of(ctx).colorScheme.error, size: 28),
        title: const Text('Location unavailable'),
        content: SingleChildScrollView(
          child: Text(
            '${e.message}\n\nAn SOS can only be sent with your real location. '
            'If this is urgent, call 1122 now.',
          ),
        ),
        actionsOverflowButtonSpacing: MfSpace.xs,
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              if (permanentlyDenied) {
                await LocationService().openAppSettings();
              } else {
                await LocationService().openLocationSettings();
              }
            },
            child: Text(permanentlyDenied ? 'App settings' : 'GPS settings'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _triggerSOS();
            },
            child: const Text('Try again'),
          ),
          FilledButton.icon(
            style: _dangerFilled(ctx),
            icon: const Icon(Icons.phone_rounded),
            label: const Text('Call 1122'),
            onPressed: () {
              Navigator.pop(ctx);
              _launchEmergencyUri('tel:1122');
            },
          ),
        ],
      ),
    );
  }

  void _showGpsDisabledDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.location_off_outlined, color: MfColors.tone(ctx, MfTone.warning).foreground, size: 28),
        title: const Text('GPS is turned off'),
        content: const Text(
          'Location services are off. Turn on GPS so responders can find you, '
          'or call 1122 if this is urgent.',
        ),
        actionsOverflowButtonSpacing: MfSpace.xs,
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await LocationService().openLocationSettings();
            },
            child: const Text('Open settings'),
          ),
          FilledButton.icon(
            style: _dangerFilled(ctx),
            icon: const Icon(Icons.phone_rounded),
            label: const Text('Call 1122'),
            onPressed: () {
              Navigator.pop(ctx);
              _launchEmergencyUri('tel:1122');
            },
          ),
        ],
      ),
    );
  }

  void _selectType(String value) {
    HapticFeedback.lightImpact();
    setState(() => _selectedEmergencyType = value);
    if (value == EmergencyTypes.other) _otherFocusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final isConnected = ref.watch(isConnectedProvider);
    final user = ref.watch(currentUserProvider).valueOrNull;
    final settings = ref.watch(accessibilityProvider);
    final isDeafPatient = (user?.patientType?.toUpperCase() == 'DEAF') || settings.textOnlyMode;
    final isOther = _selectedEmergencyType == EmergencyTypes.other;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        context.go('/home');
      },
      child: MfScaffold(
        title: 'Emergency alert',
        subtitle: 'Choose what is happening',
        onBack: () => context.go('/home'),
        bottomBar: MfPrimaryButton(
          label: _isFetchingLocation ? 'Detecting location…' : 'Send SOS',
          icon: Icons.sos_rounded,
          tone: MfTone.danger,
          loading: _isFetchingLocation,
          semanticLabel: _isFetchingLocation ? 'Detecting your location' : 'Send SOS emergency alert',
          onPressed: _isFetchingLocation ? null : _triggerSOS,
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(MfSpace.gutter, MfSpace.md, MfSpace.gutter, MfSpace.lg),
          children: [
            if (!isConnected) ...[
              const MfInfoBanner(
                icon: Icons.wifi_off_rounded,
                tone: MfTone.warning,
                title: 'You are offline',
                message: 'Send SOS will offer to call or SMS 1122 instead.',
              ),
              const SizedBox(height: MfSpace.md),
            ],

            // AI symptom check (Gemini): describe in words, AI picks the emergency type.
            _buildTextClassifierCard(context, expandedByDefault: isDeafPatient),
            const SizedBox(height: MfSpace.lg),

            const MfSectionTitle('What is happening?', subtitle: 'Tap the closest match'),
            const SizedBox(height: MfSpace.xs),
            _buildTypeGrid(),

            const SizedBox(height: MfSpace.lg),
            const MfSectionTitle('Additional details'),
            const SizedBox(height: MfSpace.xs),
            TextFormField(
              controller: _additionalInfoController,
              focusNode: _otherFocusNode,
              maxLines: isOther ? 4 : 3,
              minLines: 2,
              style: text.bodyLarge,
              decoration: InputDecoration(
                labelText: isOther ? 'Describe your emergency *' : 'Additional details (optional)',
                hintText: isOther
                    ? 'e.g. unconscious, severe bleeding'
                    : 'e.g. exact floor, symptoms, landmarks',
                alignLabelWithHint: true,
                enabledBorder: isOther
                    ? OutlineInputBorder(
                        borderRadius: MfRadius.mdAll,
                        borderSide: BorderSide(color: cs.error, width: 1.5),
                      )
                    : null,
                labelStyle: isOther ? text.bodyLarge?.copyWith(color: cs.error) : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeGrid() {
    final rows = <Widget>[];
    for (var i = 0; i < _emergencyTypes.length; i += 2) {
      final left = _emergencyTypes[i];
      final right = i + 1 < _emergencyTypes.length ? _emergencyTypes[i + 1] : null;
      rows.add(
        Padding(
          padding: EdgeInsets.only(bottom: i + 2 < _emergencyTypes.length ? MfSpace.sm : 0),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _tileFor(left)),
                const SizedBox(width: MfSpace.sm),
                Expanded(child: right == null ? const SizedBox.shrink() : _tileFor(right)),
              ],
            ),
          ),
        ),
      );
    }
    return Column(children: rows);
  }

  Widget _tileFor(Map<String, dynamic> type) {
    final value = type['value'] as String;
    return _EmergencyTypeTile(
      icon: type['icon'] as IconData,
      label: EmergencyTypes.label(value),
      selected: _selectedEmergencyType == value,
      onTap: () => _selectType(value),
    );
  }

  Widget _buildTextClassifierCard(BuildContext context, {required bool expandedByDefault}) {
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final expanded = _showTextClassifier ?? expandedByDefault;
    final result = _aiResult;
    return MfCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MfIconTile(
            icon: Icons.auto_awesome_outlined,
            label: 'AI symptom check',
            subtitle: 'Describe what is happening in your own words. AI suggests the emergency type.',
            showChevron: false,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const MfStatusChip(label: 'AI', tone: MfTone.primary),
                const SizedBox(width: MfSpace.xs),
                Icon(expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: cs.onSurfaceVariant),
              ],
            ),
            onTap: () => setState(() => _showTextClassifier = !expanded),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(MfSpace.md, 0, MfSpace.md, MfSpace.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _symptomsController,
                    maxLines: 3,
                    minLines: 2,
                    style: text.bodyLarge,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'What do you feel?',
                      hintText: 'e.g. sudden chest pain spreading to my left arm',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: MfSpace.sm),
                  MfSecondaryButton(
                    label: _isClassifying ? 'Checking symptoms…' : 'Suggest emergency type',
                    icon: Icons.auto_awesome_outlined,
                    loading: _isClassifying,
                    onPressed: _isClassifying ? null : _classifySymptoms,
                  ),
                  if (result != null) ...[
                    const SizedBox(height: MfSpace.sm),
                    MfInfoBanner(
                      icon: Icons.auto_awesome_outlined,
                      tone: MfTone.success,
                      title: 'AI suggests: ${EmergencyTypes.label(result['type'] as String)} '
                          '(${((result['confidence'] as double) * 100).round()}% sure)',
                      message: [
                        if ((result['reasoning'] as String).isNotEmpty) result['reasoning'] as String,
                        'Selected below. You can change it before sending.',
                      ].join('\n'),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Selectable pictogram tile: icon + always-visible label, min 96dp tall.
class _EmergencyTypeTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _EmergencyTypeTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final danger = MfColors.tone(context, MfTone.danger);
    final hc = MfColors.isHighContrast(context);

    final shape = RoundedRectangleBorder(
      borderRadius: MfRadius.mdAll,
      side: BorderSide(
        color: selected ? danger.solid : cs.outlineVariant,
        width: selected ? 2 : (hc ? 2 : 1),
      ),
    );

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: selected ? Color.alphaBlend(danger.container, cs.surface) : cs.surface,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          customBorder: shape,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 96),
            child: Padding(
              padding: const EdgeInsets.all(MfSpace.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: selected ? danger.solid : danger.container,
                          borderRadius: MfRadius.smAll,
                        ),
                        child: Icon(icon, size: 24, color: selected ? danger.onSolid : danger.foreground),
                      ),
                      const Spacer(),
                      if (selected) Icon(Icons.check_circle_rounded, color: danger.solid, size: 22),
                    ],
                  ),
                  const SizedBox(height: MfSpace.sm),
                  Text(
                    label,
                    style: text.titleSmall?.copyWith(
                      color: cs.onSurface,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
