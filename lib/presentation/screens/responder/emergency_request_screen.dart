import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/emergency_provider.dart';
import '../../theme/app_theme.dart';
import 'dart:async';
import '../../../services/audio/voice_alert_service.dart';
import '../../../services/location/location_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/medical_profile_provider.dart';
import '../../providers/accessibility_provider.dart';
import '../../../domain/entities/emergency.dart' as emergency_entity;
import '../../../core/utils/emergency_status.dart';

class EmergencyRequestScreen extends ConsumerStatefulWidget {
  final String requestId;
  const EmergencyRequestScreen({super.key, required this.requestId});

  @override
  ConsumerState<EmergencyRequestScreen> createState() =>
      _EmergencyRequestScreenState();
}

class _EmergencyRequestScreenState
    extends ConsumerState<EmergencyRequestScreen> {
  bool _isAccepting = false;
  bool _isRejecting = false;
  bool _isPlayingVoice = false;

  /// Distance from the responder, computed ONCE (not on every rebuild).
  Future<String>? _distanceFuture;

  Future<String> _distanceTo(double lat, double lng) {
    return _distanceFuture ??= () async {
      try {
        final position = await LocationService().getCurrentLocation();
        final km = GeoUtils.haversineKm(position.latitude, position.longitude, lat, lng);
        return '${GeoUtils.formatDistance(km)} away';
      } catch (_) {
        return 'Distance unavailable';
      }
    }();
  }

  Future<void> _accept() async {
    setState(() => _isAccepting = true);
    
    try {
      final responderId = await ref.read(currentUserIdProvider.future) ?? '';

      // Get the emergency data to find the userId
      final emergency = await ref.read(getEmergencyProvider(widget.requestId).future);

      await ref.read(acceptEmergencyProvider(AcceptRejectParams(
        emergencyId: widget.requestId,
        responderId: responderId,
      )).future);
      
      final voiceEnabled = ref.read(accessibilityProvider).voiceGuidanceEnabled;

      if (voiceEnabled) {
        VoiceAlertService().speakMessage("Emergency accepted. Preparing automated analysis.");
      }

      // Check if patient is deaf and play situational report
      final profile = await ref.read(getMedicalProfileProvider(emergency.userId).future);

      if (voiceEnabled &&
          profile != null &&
          (profile.patientType.toUpperCase() == 'DEAF' ||
              emergency.patientType.toUpperCase() == 'DEAF')) {
        await VoiceAlertService().speakAutomatedEmergencyReport(
          emergency: emergency,
          medical: profile,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not accept: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
        ref.invalidate(getEmergencyProvider(widget.requestId));
        setState(() => _isAccepting = false);
      }
      return;
    }
    
    // Navigate immediately to active emergency screen
    if (mounted) {
      context.go('/responder/active/${widget.requestId}');
    }
  }

  Future<void> _reject() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Decline this request?'),
        content: const Text('It will be offered to other nearby responders.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Decline'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isRejecting = true);
    try {
      final responderId = await ref.read(currentUserIdProvider.future) ?? '';
      await ref.read(rejectEmergencyProvider(AcceptRejectParams(
        emergencyId: widget.requestId,
        responderId: responderId,
      )).future);
    } catch (e) {
      debugPrint('Reject error: $e');
    }

    if (mounted) {
      context.go('/responder');
    }
  }

  @override
  Widget build(BuildContext context) {
    final emergencyAsync = ref.watch(getEmergencyProvider(widget.requestId));
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Emergency Request'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          tooltip: 'Back',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/responder');
            }
          },
        ),
      ),
      body: emergencyAsync.when(
        data: (emergency) => _buildContent(context, theme, emergency as emergency_entity.Emergency?),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
                const SizedBox(height: 12),
                Text('Could not load this emergency.\n$e', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => ref.invalidate(getEmergencyProvider(widget.requestId)),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, ThemeData theme, emergency_entity.Emergency? emergency) {
    if (emergency == null) return const Center(child: Text('Emergency not found'));

    final distanceFuture = _distanceTo(emergency.latitude, emergency.longitude);
    final priority = emergency.priority.toUpperCase() == 'HIGH' ? 'HIGH' : 'NORMAL';

    // If the server pre-captured a voiceSummary at SOS time, use it as the
    // primary source. This works even when the patient's phone is off.
    final hasCapturedSummary = emergency.voiceSummary != null &&
        emergency.voiceSummary!.trim().isNotEmpty;

    if (hasCapturedSummary) {
      // Fast path: show pre-captured snapshot immediately — no extra API call needed.
      final patientAsync = ref.watch(userProfileProvider(emergency.userId));
      final patientName = patientAsync.when(
        data: (u) => u?.fullName ?? 'Patient',
        loading: () => 'Loading...',
        error: (_, __) => 'Patient',
      );
      return FutureBuilder<String>(
        future: distanceFuture,
        builder: (context, distanceSnapshot) {
          return _buildRequestDetails(
            context: context,
            theme: theme,
            emergencyType: emergency.emergencyType,
            patientName: patientName,
            distance: distanceSnapshot.data ?? 'Calculating...',
            bloodGroup: _extractFromSummary(emergency.voiceSummary!, 'Blood Type') ?? 'See summary below',
            allergies: _extractFromSummary(emergency.voiceSummary!, 'Allergies') ?? 'See summary below',
            conditions: _extractFromSummary(emergency.voiceSummary!, 'Conditions') ?? 'See summary below',
            priority: priority,
            isDeaf: emergency.patientType.toUpperCase() == 'DEAF',
            voiceSummary: emergency.voiceSummary,
            dataSource: 'snapshot',
            status: emergency.status,
          );
        },
      );
    }

    // Fallback: fetch live medical profile from server (requires active connection).
    // Medical data is on the SERVER — this works regardless of patient's phone state.
    final profileAsync = ref.watch(getMedicalProfileProvider(emergency.userId));
    return profileAsync.when(
      data: (profile) {
        final patientAsync = ref.watch(userProfileProvider(emergency.userId));
        final patientName = patientAsync.when(
          data: (u) => u?.fullName ?? 'Patient',
          loading: () => '...',
          error: (_, __) => 'Patient',
        );
        return FutureBuilder<String>(
          future: distanceFuture,
          builder: (context, distanceSnapshot) {
            return _buildRequestDetails(
              context: context,
              theme: theme,
              emergencyType: emergency.emergencyType,
              patientName: patientName,
              distance: distanceSnapshot.data ?? 'Calculating...',
              bloodGroup: profile?.bloodType ?? 'Not recorded',
              allergies: (profile?.allergies.isNotEmpty == true) ? profile!.allergies.join(', ') : 'None listed',
              conditions: (profile?.chronicDiseases.isNotEmpty == true) ? profile!.chronicDiseases.join(', ') : 'No chronic conditions',
              priority: priority,
              isDeaf: (profile?.patientType.toUpperCase() == 'DEAF' || emergency.patientType.toUpperCase() == 'DEAF'),
              dataSource: 'live',
              status: emergency.status,
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _buildRequestDetails(
        context: context,
        theme: theme,
        emergencyType: emergency.emergencyType,
        patientName: 'Patient',
        distance: 'Unable to calculate',
        bloodGroup: 'Unavailable',
        allergies: 'Unavailable',
        conditions: 'Unavailable',
        dataSource: 'unavailable',
        status: emergency.status,
      ),
    );
  }

  /// Extracts a labelled value from the pre-captured voiceSummary text.
  /// e.g. "Blood Type: O+" → "O+"
  String? _extractFromSummary(String summary, String label) {
    final lines = summary.split('\n');
    for (final line in lines) {
      if (line.toLowerCase().startsWith(label.toLowerCase())) {
        final parts = line.split(':');
        if (parts.length > 1) return parts.sublist(1).join(':').trim();
      }
    }
    return null;
  }

  Widget _buildRequestDetails({
    required BuildContext context,
    required ThemeData theme,
    required String emergencyType,
    required String patientName,
    required String distance,
    required String bloodGroup,
    required String allergies,
    required String conditions,
    String priority = 'NORMAL',
    bool isDeaf = false,
    String? voiceSummary,
    String dataSource = 'live',
    String status = 'ACTIVE',
  }) {
    final isClosed = EmergencyStatus.isTerminal(status);
    final isTaken = EmergencyStatus.isAssigned(status);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Emergency Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: priority == 'HIGH'
                    ? [const Color(0xFFb71c1c), const Color(0xFFd32f2f)]
                    : [const Color(0xFFF57C00), const Color(0xFFFFB74D)],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                if (priority == 'HIGH')
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text('HIGH PRIORITY ESCALATION',
                        style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                const Icon(Icons.emergency_rounded,
                    color: Colors.white, size: 48),
                const SizedBox(height: 8),
                Text(
                  EmergencyTypes.label(emergencyType),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(distance,
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 15)),
              ],
            ),
          ),
          if (isDeaf) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.primaryNavy, // Logo-matched accessibility alert
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.hearing_disabled, color: Colors.white),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'ACCESSIBILITY ALERT: DEAF PATIENT',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),

          // Voice Alert Button
          OutlinedButton.icon(
            onPressed: () {
              final isCurrentlyPlaying = _isPlayingVoice;
              setState(() => _isPlayingVoice = !isCurrentlyPlaying);
              
              if (isCurrentlyPlaying) {
                 VoiceAlertService().stop();
              } else {
                 final message = "Emergency Alert: ${emergencyType.replaceAll('_', ' ')}. "
                     "${isDeaf ? 'Attention: This is a Deaf Patient. Use visual cues and text chat. ' : ''}"
                     "Patient: $patientName. "
                     "Blood Group: $bloodGroup. "
                     "Allergies: $allergies. "
                     "Conditions: $conditions. "
                     "Distance: $distance.";
                 VoiceAlertService().speakMessage(message);
              }
            },
            icon: Icon(_isPlayingVoice
                ? Icons.stop_circle_outlined
                : Icons.volume_up_outlined),
            label: Text(_isPlayingVoice ? 'Stop Alert' : 'Play Voice Alert'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 16),

          // ── Privacy / audit notice ────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.warning.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.lock_outline_rounded, size: 15, color: AppColors.warning),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'HIPAA-Protected Medical Data',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.warning,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'This access is logged and limited to active emergency context only. '
                        'Do not share or screenshot this information.',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: AppColors.warning,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Data source badge ─────────────────────────────────────────
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: dataSource == 'snapshot'
                      ? AppColors.primaryBlue.withOpacity(0.1) // Logo-matched light blue
                      : dataSource == 'live'
                          ? AppColors.primaryTeal.withOpacity(0.1) // Logo-matched light teal
                          : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: dataSource == 'snapshot'
                        ? AppColors.primaryBlue.withOpacity(0.4)
                        : dataSource == 'live'
                            ? AppColors.primaryTeal.withOpacity(0.4)
                            : Colors.grey.shade300,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      dataSource == 'snapshot'
                          ? Icons.save_outlined
                          : dataSource == 'live'
                              ? Icons.cloud_done_outlined
                              : Icons.cloud_off_outlined,
                      size: 12,
                      color: dataSource == 'snapshot'
                          ? AppColors.primaryBlue // Logo-matched
                          : dataSource == 'live'
                              ? AppColors.primaryTeal // Logo-matched
                              : Colors.grey.shade600,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      dataSource == 'snapshot'
                          ? 'Pre-captured at SOS time — valid even if patient phone is off'
                          : dataSource == 'live'
                              ? 'Live from server'
                              : 'Data unavailable',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: dataSource == 'snapshot'
                            ? AppColors.primaryBlue // Logo-matched
                            : dataSource == 'live'
                                ? AppColors.primaryTeal // Logo-matched
                                : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Medical Profile Summary ───────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: AppShadows.neumorphicOut,
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.medical_information_outlined,
                          color: AppColors.primary),
                      SizedBox(width: 8),
                      Text('Patient Medical Summary',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                  const Divider(),
                  _InfoRow(label: 'Patient', value: patientName),
                  _InfoRow(label: 'Blood Group', value: bloodGroup),
                  _InfoRow(label: 'Allergies', value: allergies),
                  _InfoRow(label: 'Conditions', value: conditions),
                  // Full pre-captured summary when available
                  if (voiceSummary != null && voiceSummary.trim().isNotEmpty) ...[
                    const Divider(),
                    const Text(
                      'Full Captured Summary',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue.withOpacity(0.1), // Logo-matched light blue
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.primaryBlue.withOpacity(0.3)),
                      ),
                      child: Text(
                        voiceSummary,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.6,
                          color: AppColors.primaryBlue.withOpacity(0.9),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          if (isClosed || isTaken) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  Icon(isClosed ? Icons.block_rounded : Icons.assignment_turned_in_rounded, color: Colors.grey.shade700),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isClosed
                          ? 'This emergency is ${EmergencyStatus.label(status).toLowerCase()} and no longer needs a responder.'
                          : 'This emergency has already been accepted.',
                      style: TextStyle(color: Colors.grey.shade800, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (isTaken)
              SizedBox(
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: () => context.go('/responder/active/${widget.requestId}'),
                  icon: const Icon(Icons.navigation_rounded),
                  label: const Text('Open if assigned to me'),
                ),
              ),
          ] else
          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: (_isAccepting || _isRejecting) ? null : _reject,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: AppColors.error),
                    foregroundColor: AppColors.error,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isRejecting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.error),
                        )
                      : const Text('Reject', style: TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: (_isAccepting || _isRejecting) ? null : _accept,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue, // Logo-matched primary action
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isAccepting
                      ? const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white)),
                            SizedBox(height: 8),
                            Text('Preparing Navigation...',
                                style: TextStyle(
                                    color: Colors.white, fontSize: 12)),
                          ],
                        )
                      : const Text('Accept Emergency',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: const TextStyle(
                    color: Colors.grey, fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
