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
import '../../theme/app_theme.dart';

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
  final FocusNode _otherFocusNode = FocusNode();

  // Values match the backend's specialist routing (SPECIALIST_MAP) + FALL/OTHER.
  static const List<Map<String, dynamic>> _emergencyTypes = [
    {'value': EmergencyTypes.cardiac, 'label': 'Cardiac / Chest Pain', 'icon': Icons.favorite_rounded},
    {'value': EmergencyTypes.breathing, 'label': 'Breathing', 'icon': Icons.air_rounded},
    {'value': EmergencyTypes.stroke, 'label': 'Stroke', 'icon': Icons.psychology_outlined},
    {'value': EmergencyTypes.trauma, 'label': 'Injury / Trauma', 'icon': Icons.personal_injury_outlined},
    {'value': EmergencyTypes.fall, 'label': 'Fall', 'icon': Icons.accessibility_new_outlined},
    {'value': EmergencyTypes.seizure, 'label': 'Seizure', 'icon': Icons.bolt_rounded},
    {'value': EmergencyTypes.diabetic, 'label': 'Diabetic', 'icon': Icons.bloodtype_outlined},
    {'value': EmergencyTypes.other, 'label': 'Other', 'icon': Icons.emergency_outlined},
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
    setState(() => _isClassifying = true);
    try {
      final apiClient = ref.read(apiClientProvider);
      final result = await apiClient.classifyEmergencySymptoms(symptoms);
      final type = result['emergencyType'] as String?;
      if (type != null && mounted) {
        final knownValues = _emergencyTypes.map((e) => e['value'] as String).toSet();
        // Map classifier output to the screen's type list (best-effort)
        final mapped = knownValues.contains(type) ? type : _mapClassifierType(type);
        final reasoning = result['reasoning'] as String?;
        setState(() {
          _selectedEmergencyType = mapped;
          if (mapped == EmergencyTypes.other && reasoning != null && reasoning.isNotEmpty) {
            _additionalInfoController.text = reasoning;
          }
        });
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(children: [
              const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text('AI suggested: ${_emergencyTypes.firstWhere((e) => e['value'] == mapped, orElse: () => {'label': mapped})['label']}')),
            ]),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('AI classification unavailable — please select manually.'), behavior: SnackBarBehavior.floating),
        );
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
      final position = await locationService.getCurrentLocation();

      if (mounted) {
        context.push('/home/sos-countdown', extra: {
          'emergencyType': _selectedEmergencyType,
          'latitude': position.latitude,
          'longitude': position.longitude,
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

  void _showOfflineFallbackDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.signal_wifi_off, color: AppColors.error),
            const SizedBox(width: 8),
            const Text('No Internet Connection'),
          ],
        ),
        content: const Text(
          'You are offline. To get emergency help, you can call or SMS the emergency number.',
        ),
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
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            icon: const Icon(Icons.phone, color: Colors.white),
            label: const Text('Call 1122', style: TextStyle(color: Colors.white)),
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the dialer. Please dial 1122 manually.')),
        );
      }
    }
  }

  /// Location could not be determined: explain clearly and offer 1122.
  void _showLocationUnavailableDialog(LocationException e) {
    final permanentlyDenied = e.code == 'PERMISSION_PERMANENTLY_DENIED';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.location_off_rounded, color: AppColors.error),
            const SizedBox(width: 8),
            const Expanded(child: Text('Location unavailable')),
          ],
        ),
        content: Text(
          '${e.message}\n\nAn SOS can only be sent with your real location. '
          'If this is urgent, call 1122 now.',
        ),
        actionsOverflowButtonSpacing: 8,
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
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            icon: const Icon(Icons.phone),
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
        title: Row(
          children: [
            Icon(Icons.location_off, color: AppColors.warning),
            const SizedBox(width: 8),
            const Text('GPS Disabled'),
          ],
        ),
        content: const Text(
          'Location services are off. Turn on GPS so responders can find you, '
          'or call 1122 if this is urgent.',
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await LocationService().openLocationSettings();
            },
            child: const Text('Open Settings'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            icon: const Icon(Icons.phone),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isConnected = ref.watch(isConnectedProvider);
    final user = ref.watch(currentUserProvider).valueOrNull;
    final settings = ref.watch(accessibilityProvider);
    final isDeafPatient = (user?.patientType?.toUpperCase() == 'DEAF') || settings.textOnlyMode;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        context.go('/home');
      },
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: theme.colorScheme.onSurface),
            tooltip: 'Back',
            onPressed: () => context.go('/home'),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Emergency Alert',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              Text(
                'Select type and confirm',
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
        body: SafeArea(
          child: Column(
            children: [
              // ── Offline banner ─────────────────────────────────────────
              if (!isConnected)
                Container(
                  margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.warning.withOpacity(0.4)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.signal_wifi_off, color: AppColors.warning, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Offline — the alert button will offer Call / SMS 1122.',
                          style: TextStyle(fontSize: 12, color: AppColors.warning, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),

              // ── Scrollable content ──────────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Deaf patient: AI symptom classifier ────────────────
                      if (isDeafPatient) ...[
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.07),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.primary.withOpacity(0.25)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.auto_awesome_rounded, color: AppColors.primary, size: 16),
                                  const SizedBox(width: 6),
                                  Text(
                                    'AI Symptom Classifier',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.primary,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _symptomsController,
                                maxLines: 2,
                                style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface),
                                decoration: InputDecoration(
                                  hintText: 'Type what you feel (e.g. chest pain, difficulty breathing)...',
                                  hintStyle: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withOpacity(0.4)),
                                  filled: true,
                                  fillColor: theme.colorScheme.surface,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: _isClassifying ? null : _classifySymptoms,
                                  icon: _isClassifying
                                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                      : const Icon(Icons.auto_awesome_rounded, size: 16),
                                  label: Text(_isClassifying ? 'Classifying...' : 'AI Suggest Emergency Type'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Section label
                      Text(
                        'What is happening?',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.onSurface.withOpacity(0.55),
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Emergency type grid
                      GridView.count(
                        crossAxisCount: 3,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.9,
                        children: _emergencyTypes.map((type) {
                          final isSelected = _selectedEmergencyType == type['value'];
                          return Semantics(
                            button: true,
                            selected: isSelected,
                            label: type['label'] as String,
                            child: GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              setState(() => _selectedEmergencyType = type['value'] as String);
                              if (type['value'] == EmergencyTypes.other) _otherFocusNode.requestFocus();
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(18),
                                color: isSelected
                                    ? const Color(0xFFD32F2F)
                                    : theme.colorScheme.surfaceContainer,
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFFD32F2F)
                                      : theme.colorScheme.outline.withOpacity(0.15),
                                  width: isSelected ? 2 : 1,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: const Color(0xFFD32F2F).withOpacity(0.30),
                                          blurRadius: 12,
                                          offset: const Offset(0, 6),
                                        )
                                      ]
                                    : [],
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isSelected
                                          ? Colors.white.withOpacity(0.2)
                                          : const Color(0xFFD32F2F).withOpacity(0.09),
                                    ),
                                    child: Icon(
                                      type['icon'] as IconData,
                                      color: isSelected ? Colors.white : const Color(0xFFD32F2F),
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                    child: Text(
                                      type['label'] as String,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: isSelected ? Colors.white : theme.colorScheme.onSurface,
                                        height: 1.3,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 24),
                      Text(
                        'Additional details',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.onSurface.withOpacity(0.55),
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Notes field
                      TextFormField(
                        controller: _additionalInfoController,
                        focusNode: _otherFocusNode,
                        maxLines: _selectedEmergencyType == EmergencyTypes.other ? 4 : 3,
                        style: TextStyle(
                          fontSize: 14,
                          color: theme.colorScheme.onSurface,
                        ),
                        decoration: InputDecoration(
                          labelText: _selectedEmergencyType == EmergencyTypes.other
                              ? 'Describe your emergency *'
                              : 'Additional details (optional)',
                          hintText: _selectedEmergencyType == EmergencyTypes.other
                              ? 'e.g. unconscious, severe bleeding...'
                              : 'e.g. exact floor, symptoms, landmarks...',
                          alignLabelWithHint: true,
                          filled: true,
                          fillColor: _selectedEmergencyType == EmergencyTypes.other
                              ? const Color(0xFFD32F2F).withOpacity(0.04)
                              : theme.colorScheme.surfaceContainer,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: theme.colorScheme.outline.withOpacity(0.2),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: _selectedEmergencyType == EmergencyTypes.other
                                  ? const Color(0xFFD32F2F)
                                  : theme.colorScheme.outline.withOpacity(0.2),
                              width: _selectedEmergencyType == EmergencyTypes.other ? 2 : 1,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Color(0xFFD32F2F),
                              width: 2,
                            ),
                          ),
                          labelStyle: TextStyle(
                            color: _selectedEmergencyType == EmergencyTypes.other
                                ? const Color(0xFFD32F2F)
                                : theme.colorScheme.onSurface.withOpacity(0.55),
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                          hintStyle: TextStyle(
                            color: theme.colorScheme.onSurface.withOpacity(0.35),
                            fontSize: 13,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),

              // ── Sticky bottom action bar ────────────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                decoration: BoxDecoration(
                  color: theme.scaffoldBackgroundColor,
                  border: Border(
                    top: BorderSide(
                      color: theme.colorScheme.outline.withOpacity(0.12),
                    ),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: SizedBox(
                    width: double.infinity,
                    height: 58,
                    child: ElevatedButton(
                      onPressed: _isFetchingLocation ? null : _triggerSOS,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD32F2F),
                        disabledBackgroundColor: const Color(0xFFD32F2F).withOpacity(0.3),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        elevation: 0,
                      ),
                      child: _isFetchingLocation
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                ),
                                SizedBox(width: 12),
                                Text(
                                  'Detecting Location…',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.emergency_rounded, size: 22, color: Colors.white),
                                SizedBox(width: 10),
                                Text(
                                  'SEND EMERGENCY ALERT',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.0,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
