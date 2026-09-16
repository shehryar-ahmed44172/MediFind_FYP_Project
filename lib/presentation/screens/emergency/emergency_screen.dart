import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../services/location/location_service.dart';
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
  String _selectedEmergencyType = 'CARDIAC';
  final _additionalInfoController = TextEditingController();
  final _symptomsController = TextEditingController();
  bool _isFetchingLocation = false;
  bool _isClassifying = false;
  final FocusNode _otherFocusNode = FocusNode();

  static const List<Map<String, dynamic>> _emergencyTypes = [
    {'value': 'CARDIAC', 'label': 'Cardiac Emergency', 'icon': Icons.favorite_rounded},
    {'value': 'BREATHING', 'label': 'Breathing Issue', 'icon': Icons.wind_power_rounded},
    {'value': 'TRAUMA', 'label': 'Injury / Trauma', 'icon': Icons.personal_injury_outlined},
    {'value': 'FALL', 'label': 'Fall / Mobility', 'icon': Icons.accessibility_new_outlined},
    {'value': 'STROKE', 'label': 'Stroke', 'icon': Icons.psychology_outlined},
    {'value': 'OTHER', 'label': 'Other Emergency', 'icon': Icons.emergency_outlined},
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
          if (mapped == 'OTHER' && reasoning != null && reasoning.isNotEmpty) {
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
    const mapping = {
      'CHEST_PAIN': 'CARDIAC',
      'SHORTNESS_OF_BREATH': 'BREATHING',
      'SEIZURE': 'OTHER',
      'STROKE': 'STROKE',
      'DIABETIC': 'OTHER',
      'CARDIAC': 'CARDIAC',
      'TRAUMA': 'TRAUMA',
    };
    return mapping[raw] ?? 'OTHER';
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Location error: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
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
            onPressed: () async {
              Navigator.pop(ctx);
              final uri = Uri.parse('smsto:1122');
              if (await canLaunchUrl(uri)) await launchUrl(uri);
            },
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            icon: const Icon(Icons.phone, color: Colors.white),
            label: const Text('Call 1122', style: TextStyle(color: Colors.white)),
            onPressed: () async {
              Navigator.pop(ctx);
              final uri = Uri.parse('tel:1122');
              if (await canLaunchUrl(uri)) await launchUrl(uri);
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
          'Location services are disabled. Please enable GPS to use SOS.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await LocationService().openLocationSettings();
            },
            child: const Text('Open Settings'),
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
                          'Offline — SOS will fall back to SMS/Call.',
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
                          return GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              setState(() => _selectedEmergencyType = type['value'] as String);
                              if (type['value'] == 'OTHER') _otherFocusNode.requestFocus();
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
                        maxLines: _selectedEmergencyType == 'OTHER' ? 4 : 3,
                        style: TextStyle(
                          fontSize: 14,
                          color: theme.colorScheme.onSurface,
                        ),
                        decoration: InputDecoration(
                          labelText: _selectedEmergencyType == 'OTHER'
                              ? 'Describe your emergency *'
                              : 'Additional details (optional)',
                          hintText: _selectedEmergencyType == 'OTHER'
                              ? 'e.g. unconscious, severe bleeding...'
                              : 'e.g. exact floor, symptoms, landmarks...',
                          alignLabelWithHint: true,
                          filled: true,
                          fillColor: _selectedEmergencyType == 'OTHER'
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
                              color: _selectedEmergencyType == 'OTHER'
                                  ? const Color(0xFFD32F2F)
                                  : theme.colorScheme.outline.withOpacity(0.2),
                              width: _selectedEmergencyType == 'OTHER' ? 2 : 1,
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
                            color: _selectedEmergencyType == 'OTHER'
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
