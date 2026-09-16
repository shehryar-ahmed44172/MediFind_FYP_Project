import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/emergency_provider.dart';
import 'dart:async';
import '../../../services/audio/voice_alert_service.dart';
import '../../../services/location/location_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/medical_profile_provider.dart';
import '../../providers/accessibility_provider.dart';
import '../../../domain/entities/emergency.dart' as emergency_entity;
import '../../../core/utils/emergency_status.dart';
import '../../widgets/design_system/design_system.dart';
import 'widgets/responder_widgets.dart';

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

  /// ETA derived from the same one-off distance calculation (display only).
  String? _etaText;

  Future<String> _distanceTo(double lat, double lng) {
    return _distanceFuture ??= () async {
      try {
        final position = await LocationService().getCurrentLocation();
        final km = GeoUtils.haversineKm(position.latitude, position.longitude, lat, lng);
        final eta = GeoUtils.etaMinutes(km);
        _etaText = eta == 0 ? 'Arriving' : '~$eta min';
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
        showMfSnackBar(context, 'Could not accept: $e', tone: MfTone.danger);
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
    final confirmed = await showMfConfirmDialog(
      context,
      title: 'Decline this request?',
      message: 'It will be offered to other nearby responders.',
      confirmLabel: 'Decline',
      cancelLabel: 'Keep',
      destructive: true,
    );
    if (!confirmed || !mounted) return;

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

  /// Opens the emergency chat with the patient (same room mechanism as the
  /// active emergency screen). Used by the deaf-patient banner.
  Future<void> _openEmergencyChat(String patientUserId) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const MfLoading(label: 'Opening chat'),
    );
    try {
      final room = await ref.read(chatRepositoryProvider).createOrGetChatRoom(
            patientUserId,
            emergencyId: widget.requestId,
          );
      if (!mounted) return;
      Navigator.pop(context);
      context.push('/chat/${room.id}', extra: 'Patient');
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      showMfSnackBar(context, 'Could not open chat: $e', tone: MfTone.danger);
    }
  }

  @override
  Widget build(BuildContext context) {
    final emergencyAsync = ref.watch(getEmergencyProvider(widget.requestId));

    return MfScaffold(
      title: 'Emergency request',
      fallbackRoute: '/responder',
      body: emergencyAsync.when(
        data: (emergency) => _buildContent(context, emergency as emergency_entity.Emergency?),
        loading: () => const MfLoading(label: 'Loading request'),
        error: (e, _) => MfErrorState(
          title: 'Could not load this emergency',
          message: '$e',
          onRetry: () => ref.invalidate(getEmergencyProvider(widget.requestId)),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, emergency_entity.Emergency? emergency) {
    if (emergency == null) {
      return const MfEmptyState(
        icon: Icons.search_off_rounded,
        title: 'Emergency not found',
        message: 'This request may have been removed.',
      );
    }

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
            emergency: emergency,
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
              emergency: emergency,
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
      loading: () => const MfLoading(label: 'Loading medical profile'),
      error: (e, _) => _buildRequestDetails(
        context: context,
        emergency: emergency,
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

  void _toggleVoiceAlert({
    required String emergencyType,
    required bool isDeaf,
    required String patientName,
    required String bloodGroup,
    required String allergies,
    required String conditions,
    required String distance,
  }) {
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
  }

  Widget _buildRequestDetails({
    required BuildContext context,
    required emergency_entity.Emergency emergency,
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
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final isHigh = priority == 'HIGH';

    final MfTone sourceTone;
    final IconData sourceIcon;
    final String sourceLabel;
    switch (dataSource) {
      case 'snapshot':
        sourceTone = MfTone.info;
        sourceIcon = Icons.save_outlined;
        sourceLabel = 'Pre-captured at SOS time. Valid even if the patient phone is off.';
        break;
      case 'live':
        sourceTone = MfTone.primary;
        sourceIcon = Icons.cloud_done_outlined;
        sourceLabel = 'Live from server';
        break;
      default:
        sourceTone = MfTone.neutral;
        sourceIcon = Icons.cloud_off_outlined;
        sourceLabel = 'Data unavailable';
    }
    final sourceColors = MfColors.tone(context, sourceTone);

    Widget meta(IconData icon, String label, String value) => Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: cs.onSurfaceVariant),
              const SizedBox(width: MfSpace.xs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                    Text(value, style: text.titleSmall),
                  ],
                ),
              ),
            ],
          ),
        );

    final scroll = ListView(
      padding: const EdgeInsets.all(MfSpace.gutter),
      children: [
        // ── Emergency summary ──────────────────────────────────────────
        MfCard(
          tone: isHigh ? MfTone.danger : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (isHigh) ...[
                const Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: MfStatusChip(
                    label: 'High priority escalation',
                    icon: Icons.priority_high_rounded,
                    tone: MfTone.danger,
                    solid: true,
                  ),
                ),
                const SizedBox(height: MfSpace.sm),
              ],
              Row(
                children: [
                  ResponderTypePictogram(type: emergencyType, size: 52, tone: MfTone.danger),
                  const SizedBox(width: MfSpace.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(EmergencyTypes.label(emergencyType), style: text.titleLarge),
                        const SizedBox(height: 2),
                        Text('Emergency type', style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: MfSpace.sm),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: MfStatusChip.emergency(status),
              ),
              const Divider(height: MfSpace.lg),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  meta(Icons.near_me_outlined, 'Distance', distance),
                  const SizedBox(width: MfSpace.xs),
                  meta(Icons.schedule_rounded, 'ETA', _etaText ?? '—'),
                ],
              ),
              const SizedBox(height: MfSpace.sm),
              Row(
                children: [
                  Icon(Icons.location_on_outlined, size: 20, color: cs.onSurfaceVariant),
                  const SizedBox(width: MfSpace.xs),
                  Expanded(
                    child: Text(
                      '${emergency.latitude.toStringAsFixed(5)}, ${emergency.longitude.toStringAsFixed(5)}',
                      style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // ── Deaf patient ──────────────────────────────────────────────
        if (isDeaf) ...[
          const SizedBox(height: MfSpace.sm),
          ResponderDeafCommsCard(
            message: 'Do not call. Use visual cues and text chat.',
            onOpenChat: () => _openEmergencyChat(emergency.userId),
          ),
        ],

        // ── Voice alert (automated analysis) ─────────────────────────
        const SizedBox(height: MfSpace.sm),
        MfSecondaryButton(
          large: true,
          icon: _isPlayingVoice ? Icons.stop_circle_outlined : Icons.volume_up_outlined,
          label: _isPlayingVoice ? 'Stop alert' : 'Play voice alert',
          onPressed: () => _toggleVoiceAlert(
            emergencyType: emergencyType,
            isDeaf: isDeaf,
            patientName: patientName,
            bloodGroup: bloodGroup,
            allergies: allergies,
            conditions: conditions,
            distance: distance,
          ),
        ),

        // ── Medical profile summary ──────────────────────────────────
        const SizedBox(height: MfSpace.lg),
        const MfSectionTitle('Patient medical summary'),
        MfCard(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(MfSpace.md, MfSpace.sm, MfSpace.md, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(sourceIcon, size: 16, color: sourceColors.foreground),
                    const SizedBox(width: MfSpace.xs),
                    Expanded(
                      child: Text(sourceLabel, style: text.labelMedium?.copyWith(color: sourceColors.foreground)),
                    ),
                  ],
                ),
              ),
              MfKeyValueRow(icon: Icons.person_outline_rounded, label: 'Patient', value: patientName),
              const Divider(height: 1, indent: MfSpace.md, endIndent: MfSpace.md),
              MfKeyValueRow(icon: Icons.bloodtype_outlined, label: 'Blood group', value: bloodGroup),
              const Divider(height: 1, indent: MfSpace.md, endIndent: MfSpace.md),
              MfKeyValueRow(icon: Icons.warning_amber_rounded, label: 'Allergies', value: allergies),
              const Divider(height: 1, indent: MfSpace.md, endIndent: MfSpace.md),
              MfKeyValueRow(icon: Icons.medical_information_outlined, label: 'Conditions', value: conditions),
              // Full pre-captured summary when available
              if (voiceSummary != null && voiceSummary.trim().isNotEmpty) ...[
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(MfSpace.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Full captured summary', style: text.labelLarge?.copyWith(color: cs.onSurfaceVariant)),
                      const SizedBox(height: MfSpace.xs),
                      Container(
                        padding: const EdgeInsets.all(MfSpace.sm),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerLow,
                          borderRadius: MfRadius.smAll,
                          border: Border.all(color: cs.outlineVariant),
                        ),
                        child: Text(voiceSummary, style: text.bodyMedium),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        // ── Privacy / audit notice ────────────────────────────────────
        const SizedBox(height: MfSpace.sm),
        const MfInfoBanner(
          icon: Icons.lock_outline_rounded,
          tone: MfTone.neutral,
          title: 'Protected medical data (HIPAA)',
          message: 'This access is logged and limited to active emergency context only. '
              'Do not share or screenshot this information.',
        ),

        if (isClosed || isTaken) ...[
          const SizedBox(height: MfSpace.sm),
          MfInfoBanner(
            icon: isClosed ? Icons.block_rounded : Icons.assignment_turned_in_outlined,
            tone: MfTone.neutral,
            title: isClosed ? 'No longer needs a responder' : 'Already accepted',
            message: isClosed
                ? 'This emergency is ${EmergencyStatus.label(status).toLowerCase()} and no longer needs a responder.'
                : 'This emergency has already been accepted.',
          ),
        ],
        const SizedBox(height: MfSpace.md),
      ],
    );

    Widget? actions;
    if (isClosed || isTaken) {
      if (isTaken) {
        actions = MfSecondaryButton(
          large: true,
          icon: Icons.navigation_outlined,
          label: 'Open if assigned to me',
          onPressed: () => context.go('/responder/active/${widget.requestId}'),
        );
      }
    } else {
      final busy = _isAccepting || _isRejecting;
      actions = Row(
        children: [
          Expanded(
            child: MfSecondaryButton(
              large: true,
              tone: MfTone.danger,
              icon: Icons.close_rounded,
              label: 'Reject',
              loading: _isRejecting,
              onPressed: busy ? null : _reject,
            ),
          ),
          const SizedBox(width: MfSpace.sm),
          Expanded(
            flex: 2,
            child: MfPrimaryButton(
              icon: Icons.check_rounded,
              label: _isAccepting ? 'Preparing navigation…' : 'Accept emergency',
              loading: _isAccepting,
              onPressed: busy ? null : _accept,
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        Expanded(child: scroll),
        if (actions != null) MfBottomActionBar(child: actions),
      ],
    );
  }
}
