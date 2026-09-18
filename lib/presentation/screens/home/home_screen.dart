import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/emergency_status.dart';
import '../../../services/location/location_service.dart';
import '../../providers/accessibility_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../providers/medical_profile_provider.dart';
import '../../widgets/design_system/design_system.dart';
import '../patient/predefined_messages_screen.dart';

/// GPS readiness for the Home status strip (service on + permission granted).
final _gpsReadyProvider = FutureProvider.autoDispose<bool>((ref) async {
  try {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) return false;
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always || permission == LocationPermission.whileInUse;
  } catch (_) {
    return false;
  }
});

/// The patient's open (non-terminal) emergency, if any.
/// Uses GET emergencies/history (allowed for PATIENT) so the status is fresh.
final _openEmergencyProvider = FutureProvider.autoDispose<_OpenEmergency?>((ref) async {
  final user = await ref.watch(currentUserProvider.future);
  if (user == null || user.role != 'PATIENT') return null;
  final client = ref.read(apiClientProvider);
  final response = await client.dio.get('emergencies/history', queryParameters: {'limit': 5});
  final raw = response.data is Map ? response.data['data'] : null;
  if (raw is! List) return null;
  final open = raw
      .whereType<Map>()
      .map((m) => _OpenEmergency(
            id: (m['id'] ?? '').toString(),
            status: (m['status'] ?? '').toString(),
            type: (m['emergencyType'] ?? 'OTHER').toString(),
            createdAt: DateTime.tryParse((m['createdAt'] ?? '').toString()),
          ))
      .where((e) => e.id.isNotEmpty && !EmergencyStatus.isTerminal(e.status))
      .toList()
    ..sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
  return open.isEmpty ? null : open.first;
});

class _OpenEmergency {
  final String id;
  final String status;
  final String type;
  final DateTime? createdAt;
  const _OpenEmergency({required this.id, required this.status, required this.type, this.createdAt});
}

/// Patient Home (SOS tab).
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with WidgetsBindingObserver {
  GoRouter? _router;
  bool _wasOnHome = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final router = GoRouter.maybeOf(context);
    if (router != null && !identical(router, _router)) {
      _router?.routerDelegate.removeListener(_onRouteChanged);
      _router = router;
      router.routerDelegate.addListener(_onRouteChanged);
    }
  }

  /// Home stays alive in the tab stack — refresh the active-SOS banner and GPS
  /// status whenever the user comes back to it (e.g. after an emergency ends).
  void _onRouteChanged() {
    final router = _router;
    if (router == null || !mounted) return;
    // `last` includes pushed (imperative) routes, unlike `uri`.
    final config = router.routerDelegate.currentConfiguration;
    final onHome = config.isNotEmpty && config.last.matchedLocation == '/home';
    if (onHome && !_wasOnHome) {
      ref.invalidate(_openEmergencyProvider);
      ref.invalidate(_gpsReadyProvider);
    }
    _wasOnHome = onHome;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Run accessibility init once after first frame, NOT inside build().
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(currentUserProvider).valueOrNull;
      if (user != null) {
        ref.read(accessibilityProvider.notifier).initializeFromUser(user.patientType, user.id);
      }
    });
  }

  @override
  void dispose() {
    _router?.routerDelegate.removeListener(_onRouteChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Returning from system settings (GPS toggle) → re-check readiness.
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(_gpsReadyProvider);
      ref.invalidate(_openEmergencyProvider);
    }
  }

  Future<void> _refresh() async {
    final user = ref.read(currentUserProvider).valueOrNull;
    ref.invalidate(_gpsReadyProvider);
    ref.invalidate(_openEmergencyProvider);
    if (user != null) ref.invalidate(getMedicalProfileProvider(user.id));
    await ref.read(_openEmergencyProvider.future).catchError((_) => null);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(accessibilityProvider);
    final user = ref.watch(currentUserProvider).valueOrNull;
    final isDeaf = (user?.patientType ?? '').toUpperCase() == 'DEAF' || settings.textOnlyMode;
    final openEmergency = ref.watch(_openEmergencyProvider).valueOrNull;

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(MfSpace.md, MfSpace.sm, MfSpace.md, MfSpace.xl),
        children: [
          if (openEmergency != null) ...[
            _ActiveEmergencyBanner(emergency: openEmergency),
            const SizedBox(height: MfSpace.md),
          ],
          _StatusStrip(isDeaf: isDeaf, voiceOn: settings.voiceGuidanceEnabled),
          const SizedBox(height: MfSpace.lg),
          Center(
            child: _SosButton(
              isDeaf: isDeaf,
              onTap: () {
                HapticFeedback.heavyImpact();
                context.push('/home/emergency');
              },
            ),
          ),
          const SizedBox(height: MfSpace.sm),
          Text(
            'Press and hold for 2 seconds, choose the emergency type, then you have 60 seconds to cancel before help is alerted. Use Send SOS now if you need help immediately.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: MfSpace.lg),
          if (isDeaf) ...[
            const _DeafTools(),
            const SizedBox(height: MfSpace.lg),
          ] else ...[
            MfInfoBanner(
              icon: settings.voiceGuidanceEnabled ? Icons.record_voice_over_outlined : Icons.voice_over_off_outlined,
              tone: MfTone.info,
              title: settings.voiceGuidanceEnabled ? 'Voice guidance is on' : 'Voice guidance is off',
              message: settings.voiceGuidanceEnabled
                  ? 'MediFind will speak emergency updates, like when a responder is on the way.'
                  : 'Turn it on to hear spoken emergency updates.',
              actionLabel: 'Change in accessibility settings',
              onAction: () => context.push('/accessibility-settings'),
            ),
            const SizedBox(height: MfSpace.lg),
          ],
          const MfSectionTitle('Quick actions'),
          const _QuickActions(),
          const SizedBox(height: MfSpace.lg),
          const MfSectionTitle('Medical ID'),
          const _MedicalIdSummary(),
          const SizedBox(height: MfSpace.lg),
          MfListGroup(
            children: [
              MfIconTile(
                icon: isDeaf ? Icons.hearing_disabled_rounded : Icons.hearing_rounded,
                label: 'Deaf and hearing modes',
                subtitle: 'How MediFind adapts alerts and communication',
                onTap: () => context.push('/home/patient-type-info'),
              ),
              if ((user?.subscriptionPlan ?? 'FREE') == 'FREE')
                MfIconTile(
                  icon: Icons.workspace_premium_outlined,
                  label: 'Upgrade your plan',
                  subtitle: 'More caregivers, reports and priority features',
                  onTap: () => context.push('/subscription-plans'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Active emergency banner ────────────────────────────────────────────────
class _ActiveEmergencyBanner extends StatelessWidget {
  final _OpenEmergency emergency;
  const _ActiveEmergencyBanner({required this.emergency});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final t = MfColors.tone(context, MfTone.danger);
    return MfCard(
      tone: MfTone.danger,
      onTap: () => context.push('/emergency/${emergency.id}/tracking'),
      semanticLabel: 'Emergency in progress: ${EmergencyStatus.label(emergency.status)}. Resume tracking.',
      child: Row(
        children: [
          Icon(Icons.emergency_share_outlined, color: t.foreground, size: 28),
          const SizedBox(width: MfSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Emergency in progress', style: text.titleMedium?.copyWith(color: t.foreground)),
                Text(
                  '${EmergencyTypes.label(emergency.type)} · ${EmergencyStatus.label(emergency.status)}',
                  style: text.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: MfSpace.xs),
          Text('Resume', style: text.labelLarge?.copyWith(color: t.foreground)),
          Icon(Icons.chevron_right_rounded, color: t.foreground),
        ],
      ),
    );
  }
}

// ── Status strip: connectivity · GPS · deaf mode ───────────────────────────
class _StatusStrip extends ConsumerWidget {
  final bool isDeaf;
  final bool voiceOn;
  const _StatusStrip({required this.isDeaf, required this.voiceOn});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(isConnectedProvider);
    final gps = ref.watch(_gpsReadyProvider);

    return Wrap(
      spacing: MfSpace.xs,
      runSpacing: MfSpace.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        MfStatusChip(
          label: online ? 'Online' : 'Offline',
          icon: online ? Icons.wifi_rounded : Icons.wifi_off_rounded,
          tone: online ? MfTone.success : MfTone.warning,
        ),
        gps.when(
          data: (ready) => MfStatusChip(
            label: ready ? 'Location ready' : 'Location off',
            icon: ready ? Icons.my_location_rounded : Icons.location_disabled_rounded,
            tone: ready ? MfTone.success : MfTone.warning,
            tooltip: ready ? null : 'Location off. Open location settings',
            onTap: ready
                ? null
                : () async {
                    final enabled = await LocationService().isLocationServiceEnabled();
                    if (!enabled) {
                      await LocationService().openLocationSettings();
                    } else {
                      final p = await LocationService().requestLocationPermission();
                      if (p == LocationPermission.deniedForever) {
                        await LocationService().openAppSettings();
                      }
                    }
                    ref.invalidate(_gpsReadyProvider);
                  },
          ),
          loading: () => const MfStatusChip(label: 'Checking location', icon: Icons.location_searching_rounded),
          error: (_, __) => const MfStatusChip(
            label: 'Location unknown',
            icon: Icons.location_disabled_rounded,
            tone: MfTone.warning,
          ),
        ),
        if (isDeaf)
          MfStatusChip(
            label: 'Deaf mode ON',
            icon: Icons.hearing_disabled_rounded,
            tone: MfTone.primary,
            solid: true,
            tooltip: 'Deaf mode on. Open accessibility settings',
            onTap: () => context.push('/accessibility-settings'),
          ),
      ],
    );
  }
}

// ── SOS button ──────────────────────────────────────────────────────────────
class _SosButton extends StatefulWidget {
  final bool isDeaf;
  final VoidCallback onTap;
  const _SosButton({required this.isDeaf, required this.onTap});

  @override
  State<_SosButton> createState() => _SosButtonState();
}

class _SosButtonState extends State<_SosButton> with TickerProviderStateMixin {
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2000));

  /// Press-and-hold guard against pocket taps and accidental touches.
  late final AnimationController _hold = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2000),
  )..addStatusListener(_onHoldStatus);

  void _onHoldStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      HapticFeedback.heavyImpact();
      _hold.value = 0;
      widget.onTap();
    }
  }

  void _startHold() {
    HapticFeedback.selectionClick();
    _hold.forward();
  }

  void _releaseHold() {
    if (_hold.isCompleted || _hold.value == 0) return;
    final heldBriefly = _hold.value < 0.25;
    _hold.reverse();
    if (heldBriefly && mounted) {
      showMfSnackBar(context, 'Press and hold the SOS button for 2 seconds to start.', tone: MfTone.info);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MfMotion.reduced(context)) {
      _pulse.stop();
      _pulse.value = 0;
    } else if (!_pulse.isAnimating) {
      _pulse.repeat();
    }
  }

  @override
  void dispose() {
    _hold.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final sos = MfColors.sos(context);
    const size = MfSize.sosButton;
    const ring = 20.0;

    return Semantics(
      button: true,
      label: widget.isDeaf
          ? 'SOS, medical emergency. No voice needed.'
          : 'SOS, medical emergency',
      hint: 'Double tap and hold to start SOS',
      onLongPress: widget.onTap,
      excludeSemantics: true,
      child: SizedBox(
        width: size + ring * 2,
        height: size + ring * 2,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Subtle expanding ring (disabled with reduced motion).
            AnimatedBuilder(
              animation: _pulse,
              builder: (context, _) {
                final v = _pulse.value;
                return Container(
                  width: size + ring * 2 * v,
                  height: size + ring * 2 * v,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: sos.withValues(alpha: 0.35 * (1 - v)), width: 2),
                  ),
                );
              },
            ),
            // Hold progress ring
            IgnorePointer(
              child: SizedBox.square(
                dimension: size + 14,
                child: AnimatedBuilder(
                  animation: _hold,
                  builder: (context, _) => CircularProgressIndicator(
                    value: _hold.value,
                    strokeWidth: 6,
                    color: sos,
                    backgroundColor: Colors.transparent,
                    strokeCap: StrokeCap.round,
                  ),
                ),
              ),
            ),
            Material(
              color: sos,
              shape: CircleBorder(side: BorderSide(color: sos.withValues(alpha: 0.2), width: 6, strokeAlign: 1)),
              elevation: 2,
              shadowColor: sos.withValues(alpha: 0.4),
              clipBehavior: Clip.antiAlias,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (_) => _startHold(),
                onTapUp: (_) => _releaseHold(),
                onTapCancel: _releaseHold,
                child: SizedBox(
                  width: size,
                  height: size,
                  child: Padding(
                    padding: const EdgeInsets.all(MfSpace.lg),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.emergency_rounded, color: cs.onError, size: 44),
                          const SizedBox(height: MfSpace.xxs),
                          Text('SOS', style: text.displaySmall?.copyWith(color: cs.onError, fontWeight: FontWeight.w700, height: 1)),
                          const SizedBox(height: MfSpace.xxs),
                          Text('Hold for 2 seconds', style: text.titleSmall?.copyWith(color: cs.onError)),
                          if (widget.isDeaf)
                            Text(
                              'No voice needed',
                              style: text.bodySmall?.copyWith(color: cs.onError.withValues(alpha: 0.9)),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Deaf tools: show card · quick phrases · alert explainer ────────────────
class _DeafTools extends ConsumerWidget {
  const _DeafTools();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final phrases = ref.watch(predefinedMessagesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MfPrimaryButton(
          label: 'Show to people nearby',
          icon: Icons.co_present_outlined,
          semanticLabel: 'Show to people nearby. Opens a full-screen card saying you are deaf.',
          onPressed: () => context.push('/home/show-card'),
        ),
        const SizedBox(height: MfSpace.lg),
        MfSectionTitle(
          'Quick phrases',
          subtitle: 'Tap a phrase to show it in large text',
          actionLabel: 'Edit',
          onAction: () => context.push('/predefined-messages'),
        ),
        if (phrases.isEmpty)
          Text('No quick phrases yet. Tap Edit to add some.',
              style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant))
        else
          // Wrapped, not a sideways list, so every phrase is fully readable
          Wrap(
            spacing: MfSpace.xs,
            runSpacing: MfSpace.xs,
            children: [
              for (final phrase in phrases.take(_maxHomePhrases))
                ActionChip(
                  avatar: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                  label: Text(phrase, maxLines: 2, overflow: TextOverflow.ellipsis),
                  tooltip: 'Show "$phrase" in large text',
                  materialTapTargetSize: MaterialTapTargetSize.padded,
                  onPressed: () => context.push('/home/show-card', extra: phrase),
                ),
              if (phrases.length > _maxHomePhrases)
                ActionChip(
                  avatar: const Icon(Icons.more_horiz_rounded, size: 18),
                  label: Text('${phrases.length - _maxHomePhrases} more'),
                  tooltip: 'See all quick phrases',
                  materialTapTargetSize: MaterialTapTargetSize.padded,
                  onPressed: () => context.push('/predefined-messages'),
                ),
            ],
          ),
        const SizedBox(height: MfSpace.md),
        const MfInfoBanner(
          icon: Icons.vibration_rounded,
          tone: MfTone.primary,
          title: 'Alerts without sound',
          message: 'Emergency updates arrive as a flashing full-screen message and vibration. '
              'Chat with your responder by text.',
        ),
      ],
    );
  }
}

/// Quick phrases shown on the Deaf home screen; the rest are one tap away.
const int _maxHomePhrases = 4;

// ── Quick actions (2-column, icon + label) ─────────────────────────────────
class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    final items = [
      MfIconTile(
        vertical: true,
        icon: Icons.medical_information_outlined,
        label: 'Medical ID',
        onTap: () => context.go('/medical-id'),
      ),
      MfIconTile(
        vertical: true,
        icon: Icons.contact_phone_outlined,
        label: 'Emergency contacts',
        onTap: () => context.push('/home/emergency-contacts'),
      ),
      MfIconTile(
        vertical: true,
        icon: Icons.groups_outlined,
        label: 'Caregivers',
        onTap: () => context.push('/home/caregivers'),
      ),
      MfIconTile(
        vertical: true,
        icon: Icons.chat_bubble_outline_rounded,
        label: 'Messages',
        onTap: () => context.go('/chats'),
      ),
    ];

    return Column(
      children: [
        for (var row = 0; row < items.length; row += 2) ...[
          if (row > 0) const SizedBox(height: MfSpace.sm),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: items[row]),
                const SizedBox(width: MfSpace.sm),
                Expanded(child: row + 1 < items.length ? items[row + 1] : const SizedBox()),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ── Medical ID summary ─────────────────────────────────────────────────────
class _MedicalIdSummary extends ConsumerWidget {
  const _MedicalIdSummary();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    if (user == null) return const MfSkeleton(height: 96, radius: MfRadius.md);
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return ref.watch(getMedicalProfileProvider(user.id)).when(
          loading: () => const MfSkeleton(height: 96, radius: MfRadius.md),
          error: (_, __) => MfCard(
            child: MfErrorState(
              compact: true,
              message: 'Could not load your medical ID.',
              onRetry: () => ref.invalidate(getMedicalProfileProvider(user.id)),
            ),
          ),
          data: (profile) {
            if (profile == null) {
              return MfCard(
                onTap: () => context.push('/home/medical-profile'),
                child: const _SummaryRow(
                  icon: Icons.add_circle_outline_rounded,
                  title: 'Add your medical information',
                  subtitle: 'Blood group and allergies help responders treat you safely.',
                ),
              );
            }
            final allergies = profile.allergies.where((a) => a.trim().isNotEmpty).toList();
            return MfCard(
              onTap: () => context.go('/medical-id'),
              semanticLabel: 'Medical ID. Blood group ${profile.bloodType.isEmpty ? 'not set' : profile.bloodType}. '
                  'Allergies: ${allergies.isEmpty ? 'none recorded' : allergies.join(', ')}. Open Medical ID.',
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Blood group', style: text.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
                      Text(
                        profile.bloodType.trim().isEmpty ? '--' : profile.bloodType,
                        style: text.headlineSmall?.copyWith(color: cs.error),
                      ),
                    ],
                  ),
                  const SizedBox(width: MfSpace.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Allergies', style: text.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
                        const SizedBox(height: MfSpace.xxs),
                        Text(
                          allergies.isEmpty ? 'None recorded' : allergies.join(', '),
                          style: text.titleSmall,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
                ],
              ),
            );
          },
        );
  }
}

class _SummaryRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _SummaryRow({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, color: MfColors.tone(context, MfTone.primary).foreground),
        const SizedBox(width: MfSpace.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: text.titleSmall),
              Text(subtitle, style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
            ],
          ),
        ),
        Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
      ],
    );
  }
}
