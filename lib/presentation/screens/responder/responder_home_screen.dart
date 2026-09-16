import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/emergency_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../providers/medical_profile_provider.dart';
import '../../../domain/entities/responder_alert.dart';
import '../../../core/utils/emergency_status.dart';

import '../home/widgets/connectivity_banner.dart';
import '../../widgets/design_system/design_system.dart';
import 'widgets/responder_widgets.dart';
import 'dart:async';
import '../../../services/location/responder_location_tracker.dart';


class ResponderHomeScreen extends ConsumerStatefulWidget {
  const ResponderHomeScreen({super.key});

  @override
  ConsumerState<ResponderHomeScreen> createState() => _ResponderHomeScreenState();
}

class _ResponderHomeScreenState extends ConsumerState<ResponderHomeScreen> {
  /// null  → use server value (no pending change)
  /// true/false → optimistic value while the API call is in-flight
  bool? _optimisticAvailability;
  bool _isUpdatingStatus = false;
  Timer? _pollTimer;

  /// How often the live request list is re-fetched from the server (socket
  /// events refresh it immediately; this catches anything missed).
  static const Duration _pollInterval = Duration(seconds: 12);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Respect the responder's saved availability (GET users/:id returns the
      // responder's `isAvailable` as `isActive`). Never force them online just
      // because they opened the app — only resume location tracking if they
      // are already available.
      final user = await ref.read(currentUserProvider.future);
      if (!mounted) return;
      if (user?.role == 'RESPONDER' && user?.isActive == true) {
        ref.read(responderLocationTrackerProvider).start();
      }
    });

    _pollTimer = Timer.periodic(_pollInterval, (_) {
      if (mounted) ref.invalidate(responderAlertsProvider);
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(responderAlertsProvider);
    ref.invalidate(currentUserProvider);
    try {
      await ref.read(responderAlertsProvider.future);
    } catch (_) {
      // Error state is rendered by the list itself.
    }
  }

  Future<void> _setAvailability(bool value) async {
    if (_isUpdatingStatus) return;
    setState(() {
      _optimisticAvailability = value;
      _isUpdatingStatus = true;
    });
    try {
      // FutureProvider.family caches by argument, so the second call with the
      // same value (e.g. true → false → true) would return the cached resolved
      // Future without hitting the API again. Invalidate first to force a fresh
      // execution every time the user taps the toggle.
      ref.invalidate(setResponderAvailabilityProvider(value));
      await ref.read(setResponderAvailabilityProvider(value).future);
      if (value) {
        ref.read(responderLocationTrackerProvider).start();
      } else {
        ref.read(responderLocationTrackerProvider).stop();
      }
      // Clear optimistic state — server value is now up-to-date
      if (mounted) setState(() { _optimisticAvailability = null; _isUpdatingStatus = false; });
    } catch (e) {
      debugPrint('❌ Failed to update availability: $e');
      // Revert: clear optimistic override so UI snaps back to server state
      if (mounted) {
        setState(() { _optimisticAvailability = null; _isUpdatingStatus = false; });
        showMfSnackBar(
          context,
          'Could not update status. Check your connection and try again.',
          tone: MfTone.danger,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = ref.watch(isConnectedProvider);
    final userAsync = ref.watch(currentUserProvider);
    final alertsAsync = ref.watch(responderAlertsProvider);

    // When connectivity is restored, sync availability state from server
    // so a stale cached value never leaves the toggle stuck.
    ref.listen<bool>(isConnectedProvider, (prev, next) {
      if (prev == false && next == true) {
        ref.invalidate(currentUserProvider);
        ref.invalidate(responderAlertsProvider);
      }
    });

    return Scaffold(
      body: Column(
        children: [
          if (!isConnected) const ConnectivityBanner(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: _buildDashboard(context, userAsync, alertsAsync),
            ),
          ),
        ],
      ),
    );
  }

  /// Visible (non-terminal) alerts: accepted-by-me first, then newest.
  List<ResponderAlert> _visibleAlerts(List<ResponderAlert> alerts) {
    return alerts.where((a) => !EmergencyStatus.isTerminal(a.emergency.status)).toList()
      ..sort((a, b) {
        if (a.isAcceptedByMe != b.isAcceptedByMe) return a.isAcceptedByMe ? -1 : 1;
        final at = a.emergency.createdAt ?? DateTime(2000);
        final bt = b.emergency.createdAt ?? DateTime(2000);
        return bt.compareTo(at);
      });
  }

  Widget _buildDashboard(BuildContext context, AsyncValue userAsync, AsyncValue<List<ResponderAlert>> alertsAsync) {
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final activeAlert = alertsAsync.valueOrNull == null
        ? null
        : _visibleAlerts(alertsAsync.valueOrNull!).where((a) => a.isAcceptedByMe).firstOrNull;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(MfSpace.gutter, MfSpace.md, MfSpace.gutter, MfSpace.xl),
      children: [
        // ── Greeting ─────────────────────────────────────────────────────
        userAsync.when(
          data: (user) => Padding(
            padding: const EdgeInsets.only(bottom: MfSpace.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Responder dashboard', style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                const SizedBox(height: 2),
                Text(
                  'Hello, ${user?.fullName.split(' ')[0] ?? 'Responder'}',
                  style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),

        // ── Availability ────────────────────────────────────────────────
        _buildStatusToggle(context, userAsync, onEmergency: activeAlert != null),

        // ── Active emergency resume banner ─────────────────────────────
        if (activeAlert != null) ...[
          const SizedBox(height: MfSpace.sm),
          MfInfoBanner(
            icon: Icons.two_wheeler_rounded,
            tone: MfTone.primary,
            title: 'Emergency in progress',
            message: '${EmergencyTypes.label(activeAlert.emergency.emergencyType)}'
                '${activeAlert.patientName != null ? ' for ${activeAlert.patientName}' : ''}. Tap to resume.',
            onTap: () => context.push('/responder/active/${activeAlert.id}'),
          ),
        ],

        // ── Incoming requests ───────────────────────────────────────────
        const SizedBox(height: MfSpace.lg),
        Row(
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text('Incoming requests', style: text.titleMedium),
              ),
            ),
            MfIconButton(
              icon: Icons.refresh_rounded,
              tooltip: 'Refresh alerts',
              onPressed: _refresh,
            ),
          ],
        ),
        const SizedBox(height: MfSpace.xs),
        alertsAsync.when(
          skipLoadingOnRefresh: true,
          skipLoadingOnReload: true,
          data: (alerts) {
            final visible = _visibleAlerts(alerts);
            if (visible.isEmpty) {
              return const MfEmptyState(
                compact: true,
                icon: Icons.verified_user_outlined,
                title: 'All clear',
                message: 'No active emergency requests right now. Pull down to refresh.',
              );
            }
            return Column(
              children: [
                for (final alert in visible)
                  _EmergencyRequestCard(key: ValueKey(alert.id), alert: alert),
              ],
            );
          },
          loading: () => MfSkeleton.list(count: 2, itemHeight: 168),
          error: (e, _) => MfErrorState(
            compact: true,
            title: 'Could not load emergency alerts',
            message: '$e',
            onRetry: _refresh,
          ),
        ),

        // ── My rating ───────────────────────────────────────────────────
        const SizedBox(height: MfSpace.md),
        MfSectionTitle(
          'My rating',
          actionLabel: 'Details',
          onAction: () => _showPerformanceSheet(context),
        ),
        _buildRatingCard(context, userAsync),

        // ── Shortcuts ───────────────────────────────────────────────────
        const SizedBox(height: MfSpace.lg),
        const MfSectionTitle('Quick actions'),
        MfQuickActionGrid(
          children: [
            MfIconTile(
              vertical: true,
              icon: Icons.person_outline_rounded,
              label: 'My profile',
              onTap: () => context.go('/responder/profile'),
            ),
            MfIconTile(
              vertical: true,
              icon: Icons.history_rounded,
              label: 'Response history',
              onTap: () => context.go('/responder/history'),
            ),
            MfIconTile(
              vertical: true,
              icon: Icons.star_outline_rounded,
              label: 'My rating',
              subtitle: 'Performance summary',
              onTap: () => _showPerformanceSheet(context),
            ),
            MfIconTile(
              vertical: true,
              icon: Icons.settings_outlined,
              label: 'Settings',
              onTap: () => context.push('/settings'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRatingCard(BuildContext context, AsyncValue userAsync) {
    return userAsync.when(
      loading: () => const MfSkeleton(height: 96, radius: MfRadius.md),
      error: (_, __) => const SizedBox.shrink(),
      data: (user) {
        final rating = (user?.rating as double?) ?? 5.0;
        final total = (user?.totalResponsesHandled as int?) ?? 0;
        final verified = user?.verificationStatus == 'VERIFIED';
        return MfCard(
          onTap: () => _showPerformanceSheet(context),
          semanticLabel: 'My rating ${rating.toStringAsFixed(1)} out of 5, $total responses. Open details.',
          padding: const EdgeInsets.all(MfSpace.sm),
          child: Row(
            children: [
              Expanded(
                child: _InlineStat(
                  icon: Icons.star_rounded,
                  tone: MfTone.warning,
                  value: rating.toStringAsFixed(1),
                  label: 'Rating',
                ),
              ),
              Expanded(
                child: _InlineStat(
                  icon: Icons.task_alt_rounded,
                  tone: MfTone.primary,
                  value: '$total',
                  label: 'Responses',
                ),
              ),
              Expanded(
                child: _InlineStat(
                  icon: verified ? Icons.verified_outlined : Icons.pending_outlined,
                  tone: verified ? MfTone.success : MfTone.warning,
                  value: verified ? 'Yes' : 'Pending',
                  label: 'Verified',
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ],
          ),
        );
      },
    );
  }

  void _showPerformanceSheet(BuildContext context) {
    // Force a fresh fetch from the backend so rating is always up-to-date
    ref.invalidate(currentUserProvider);

    showMfBottomSheet(
      context,
      title: 'My performance',
      builder: (_) => Consumer(
        builder: (ctx, ref, __) {
          final userAsync = ref.watch(currentUserProvider);
          final text = Theme.of(ctx).textTheme;
          final cs = Theme.of(ctx).colorScheme;

          if (userAsync.isLoading) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: MfSpace.xl),
              child: MfLoading(),
            );
          }

          final user   = userAsync.valueOrNull;
          final rating = user?.rating ?? 5.0;
          final total  = user?.totalResponsesHandled ?? 0;
          final type   = user?.responderType ?? 'Responder';
          final org    = user?.organization;

          final fullStars = rating.floor();
          final halfStar  = (rating - fullStars) >= 0.5;

          String performanceLabel;
          MfTone performanceTone;
          if (rating >= 4.5) {
            performanceLabel = 'Excellent';
            performanceTone = MfTone.success;
          } else if (rating >= 4.0) {
            performanceLabel = 'Good';
            performanceTone = MfTone.primary;
          } else if (rating >= 3.5) {
            performanceLabel = 'Average';
            performanceTone = MfTone.warning;
          } else {
            performanceLabel = 'Needs improvement';
            performanceTone = MfTone.danger;
          }
          final starColor = MfColors.tone(ctx, MfTone.warning).solid;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Avatar + name
              MfAvatar(imageUrl: user?.profileImageUrl, name: user?.fullName, size: 64),
              const SizedBox(height: MfSpace.sm),
              Text(user?.fullName ?? 'Responder', style: text.titleMedium, textAlign: TextAlign.center),
              Text(
                org != null ? '$type · $org' : type,
                style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: MfSpace.md),

              // Star row
              Semantics(
                label: 'Rating ${rating.toStringAsFixed(1)} out of 5',
                excludeSemantics: true,
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (i) {
                        if (i < fullStars) {
                          return Icon(Icons.star_rounded, color: starColor, size: 32);
                        } else if (i == fullStars && halfStar) {
                          return Icon(Icons.star_half_rounded, color: starColor, size: 32);
                        } else {
                          return Icon(Icons.star_outline_rounded, color: cs.outline, size: 32);
                        }
                      }),
                    ),
                    const SizedBox(height: MfSpace.xs),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(rating.toStringAsFixed(1), style: text.headlineMedium?.copyWith(fontWeight: FontWeight.w600)),
                        Text(' / 5.0', style: text.bodyLarge?.copyWith(color: cs.onSurfaceVariant)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: MfSpace.xs),
              MfStatusChip(label: performanceLabel, tone: performanceTone),
              const SizedBox(height: MfSpace.md),

              // Stats row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: MfStatTile(
                      icon: Icons.local_hospital_outlined,
                      label: 'Responses',
                      value: '$total',
                    ),
                  ),
                  const SizedBox(width: MfSpace.xs),
                  Expanded(
                    child: MfStatTile(
                      icon: Icons.shield_outlined,
                      tone: user?.isActive == true ? MfTone.success : MfTone.neutral,
                      label: 'Status',
                      value: user?.isActive == true ? 'Active' : 'Offline',
                    ),
                  ),
                  const SizedBox(width: MfSpace.xs),
                  Expanded(
                    child: MfStatTile(
                      icon: Icons.verified_outlined,
                      tone: user?.verificationStatus == 'VERIFIED' ? MfTone.primary : MfTone.warning,
                      label: 'Verified',
                      value: user?.verificationStatus == 'VERIFIED' ? 'Yes' : 'Pending',
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatusToggle(BuildContext context, AsyncValue userAsync, {bool onEmergency = false}) {
    final isConnected = ref.watch(isConnectedProvider);
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return userAsync.when(
      loading: () => const MfSkeleton(height: 96, radius: MfRadius.md),
      error: (_, __) => const SizedBox.shrink(),
      data: (user) {
        // The displayed value: optimistic override (while API in-flight)
        // or the server's confirmed value.
        final serverActive = user?.isActive ?? false;
        final displayActive = _optimisticAvailability ?? serverActive;

        MfTone tone;
        IconData icon;
        String chipLabel;
        String statusLabel;
        String subLabel;
        if (!isConnected) {
          tone = MfTone.warning;
          icon = Icons.wifi_off_rounded;
          chipLabel = displayActive ? 'Online' : 'Offline';
          statusLabel = 'No internet connection';
          subLabel   = 'Toggle unavailable while offline';
        } else if (_isUpdatingStatus) {
          tone = displayActive ? MfTone.success : MfTone.neutral;
          icon = Icons.power_settings_new_rounded;
          chipLabel = 'Updating';
          statusLabel = displayActive ? 'Going online…' : 'Going offline…';
          subLabel   = 'Updating your status…';
        } else if (onEmergency && !displayActive) {
          // Accepting an SOS pauses new alerts; that is not the same as going offline
          tone = MfTone.primary;
          icon = Icons.two_wheeler_rounded;
          chipLabel = 'On emergency';
          statusLabel = 'Responding to an emergency';
          subLabel = 'New alerts are paused until you resolve it';
        } else {
          tone = displayActive ? MfTone.success : MfTone.neutral;
          icon = Icons.power_settings_new_rounded;
          chipLabel = displayActive ? 'Online' : 'Offline';
          statusLabel = displayActive ? 'Ready to respond' : 'You are offline';
          subLabel   = displayActive
              ? 'You will receive nearby emergency alerts'
              : 'Switch on to receive alerts';
        }
        final t = MfColors.tone(context, tone);

        return MfCard(
          tone: tone,
          padding: const EdgeInsets.all(MfSpace.md),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: displayActive && isConnected ? t.solid : cs.surface,
                    borderRadius: MfRadius.smAll,
                    border: Border.all(color: t.border),
                  ),
                  child: Icon(
                    icon,
                    color: displayActive && isConnected ? t.onSolid : t.foreground,
                    size: 26,
                  ),
                ),
                const SizedBox(width: MfSpace.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MfStatusChip(
                        label: chipLabel,
                        tone: tone,
                        icon: displayActive ? Icons.circle : Icons.circle_outlined,
                      ),
                      const SizedBox(height: MfSpace.xxs),
                      Text(statusLabel, style: text.titleMedium),
                      Text(subLabel, style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
                const SizedBox(width: MfSpace.xs),
                // While updating → show a small spinner so the toggle
                // isn't frozen/confusing; once done → restore the switch.
                if (_isUpdatingStatus)
                  SizedBox(
                    width: MfSize.minTouch,
                    height: MfSize.minTouch,
                    child: Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: t.foreground),
                      ),
                    ),
                  )
                else
                  Semantics(
                    label: 'Availability',
                    child: Switch.adaptive(
                      value: displayActive,
                      // Disable entirely when offline so the user gets
                      // a warning card + sub-label instead of a stuck toggle.
                      onChanged: isConnected ? (value) => _setAvailability(value) : null,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Compact stat used in the rating card ─────────────────────────────────────
class _InlineStat extends StatelessWidget {
  final IconData icon;
  final MfTone tone;
  final String value;
  final String label;

  const _InlineStat({
    required this.icon,
    required this.tone,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: MfSpace.xxs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: MfColors.tone(context, tone).foreground),
          const SizedBox(height: MfSpace.xxs),
          Text(value, style: text.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(label, style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _EmergencyRequestCard extends ConsumerStatefulWidget {
  final ResponderAlert alert;
  const _EmergencyRequestCard({super.key, required this.alert});

  @override
  ConsumerState<_EmergencyRequestCard> createState() => _EmergencyRequestCardState();
}

class _EmergencyRequestCardState extends ConsumerState<_EmergencyRequestCard> {
  bool _isAccepting = false;

  static String _timeAgo(DateTime? createdAt) {
    if (createdAt == null) return 'Just now';
    final diff = DateTime.now().difference(createdAt.toLocal());
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    return '${diff.inHours} h ago';
  }

  Future<void> _accept() async {
    final alert = widget.alert;
    final confirmed = await showMfConfirmDialog(
      context,
      title: 'Accept this emergency?',
      message: '${EmergencyTypes.label(alert.emergency.emergencyType)} emergency'
          '${alert.patientName != null ? ' for ${alert.patientName}' : ''}'
          '${alert.distanceKm != null ? ', ${GeoUtils.formatDistance(alert.distanceKm!)} away' : ''}.\n\n'
          'You will be navigated to the patient and marked as busy.',
      confirmLabel: 'Accept',
      cancelLabel: 'Not now',
    );
    if (!confirmed || !mounted) return;

    setState(() => _isAccepting = true);
    try {
      final responderId = await ref.read(currentUserIdProvider.future);
      await ref.read(acceptEmergencyProvider(AcceptRejectParams(
        emergencyId: alert.id,
        responderId: responderId ?? '',
      )).future);
      if (mounted) context.push('/responder/active/${alert.id}');
    } catch (e) {
      if (mounted) {
        showMfSnackBar(context, 'Could not accept: $e', tone: MfTone.danger);
        ref.invalidate(responderAlertsProvider);
      }
    } finally {
      if (mounted) setState(() => _isAccepting = false);
    }
  }

  Future<bool> _confirmReject() {
    return showMfConfirmDialog(
      context,
      title: 'Decline this request?',
      message: 'It will be removed from your list and offered to other responders.',
      confirmLabel: 'Decline',
      cancelLabel: 'Keep',
      destructive: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final alert = widget.alert;
    final request = alert.emergency;
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final acceptedByMe = alert.isAcceptedByMe;

    final profileAsync = ref.watch(getMedicalProfileProvider(request.userId));
    final patientName = alert.patientName ??
        ref.watch(userProfileProvider(request.userId)).valueOrNull?.fullName ??
        'Patient';

    final d = alert.distanceKm;
    final eta = alert.estimatedArrivalMinutes;

    Widget meta(IconData icon, String value) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: cs.onSurfaceVariant),
            const SizedBox(width: MfSpace.xxs),
            Text(value, style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
          ],
        );

    final card = MfCard(
      tone: acceptedByMe ? MfTone.primary : null,
      onTap: () => context.push(
        acceptedByMe ? '/responder/active/${alert.id}' : '/responder/request/${alert.id}',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ResponderTypePictogram(
                type: request.emergencyType,
                tone: acceptedByMe ? MfTone.primary : MfTone.danger,
              ),
              const SizedBox(width: MfSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      patientName,
                      style: text.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      EmergencyTypes.label(request.emergencyType),
                      style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              if (acceptedByMe) ...[
                const SizedBox(width: MfSpace.xs),
                const MfStatusChip(
                  label: 'In progress',
                  tone: MfTone.success,
                  icon: Icons.two_wheeler_rounded,
                ),
              ],
            ],
          ),
          const SizedBox(height: MfSpace.sm),
          Wrap(
            spacing: MfSpace.md,
            runSpacing: MfSpace.xxs,
            children: [
              if (d != null) meta(Icons.near_me_outlined, '${GeoUtils.formatDistance(d)} away'),
              if (eta != null && eta > 0) meta(Icons.schedule_rounded, 'ETA ~$eta min'),
              meta(Icons.access_time_rounded, _timeAgo(request.createdAt)),
            ],
          ),
          profileAsync.when(
            data: (profile) {
              final bloodType = profile?.bloodType;
              final allergies = profile?.allergies ?? const <String>[];
              final isDeaf = (profile?.patientType.toUpperCase() == 'DEAF') ||
                  request.patientType.toUpperCase() == 'DEAF';
              final firstAllergy = allergies.isNotEmpty ? allergies.first.trim() : '';
              final allergyDisplay = firstAllergy.length > 14
                  ? '${firstAllergy.substring(0, 14)}…'
                  : firstAllergy;
              final hasBlood = bloodType != null && bloodType.isNotEmpty;
              if (!hasBlood && allergyDisplay.isEmpty && !isDeaf) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: MfSpace.sm),
                child: Wrap(
                  spacing: MfSpace.xs,
                  runSpacing: MfSpace.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (isDeaf) const ResponderDeafBadge(),
                    if (hasBlood)
                      MfStatusChip(
                        label: 'Blood $bloodType',
                        icon: Icons.bloodtype_outlined,
                        tone: MfTone.neutral,
                      ),
                    if (allergyDisplay.isNotEmpty)
                      MfStatusChip(
                        label: allergies.length > 1
                            ? 'Allergy: $allergyDisplay +${allergies.length - 1}'
                            : 'Allergy: $allergyDisplay',
                        icon: Icons.warning_amber_rounded,
                        tone: MfTone.warning,
                      ),
                  ],
                ),
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.only(top: MfSpace.sm),
              child: LinearProgressIndicator(minHeight: 2),
            ),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(height: MfSpace.md),
          Row(
            children: [
              Expanded(
                child: MfSecondaryButton(
                  label: 'Details',
                  icon: Icons.info_outline_rounded,
                  onPressed: () => context.push('/responder/request/${alert.id}'),
                ),
              ),
              const SizedBox(width: MfSpace.xs),
              Expanded(
                child: MfPrimaryButton(
                  height: MfSize.minTouch,
                  loading: _isAccepting,
                  label: acceptedByMe ? 'Resume' : 'Accept',
                  icon: acceptedByMe ? Icons.navigation_outlined : Icons.check_rounded,
                  onPressed: acceptedByMe
                      ? () => context.push('/responder/active/${alert.id}')
                      : _accept,
                ),
              ),
            ],
          ),
          if (!acceptedByMe) ...[
            const SizedBox(height: MfSpace.xxs),
            Text(
              'Swipe left to decline',
              textAlign: TextAlign.center,
              style: text.labelSmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );

    if (acceptedByMe) {
      return Padding(padding: const EdgeInsets.only(bottom: MfSpace.sm), child: card);
    }

    final danger = MfColors.tone(context, MfTone.danger);
    return Padding(
      padding: const EdgeInsets.only(bottom: MfSpace.sm),
      child: Dismissible(
        key: Key(alert.id),
        direction: DismissDirection.endToStart,
        confirmDismiss: (_) => _confirmReject(),
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: MfSpace.lg),
          decoration: BoxDecoration(
            color: Color.alphaBlend(danger.container, cs.surface),
            borderRadius: MfRadius.mdAll,
            border: Border.all(color: danger.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text('Decline', style: text.titleSmall?.copyWith(color: danger.foreground)),
              const SizedBox(width: MfSpace.xs),
              Icon(Icons.close_rounded, color: danger.foreground),
            ],
          ),
        ),
        onDismissed: (_) async {
          final localDs = await ref.read(localDataSourceProvider.future);
          await localDs.deleteEmergency(alert.id);
          final responderId = await ref.read(currentUserIdProvider.future);
          try {
            await ref.read(rejectEmergencyProvider(
              AcceptRejectParams(emergencyId: alert.id, responderId: responderId ?? ''),
            ).future);
          } catch (e) {
            debugPrint('Failed to reject emergency on backend: $e');
          }
        },
        child: card,
      ),
    );
  }
}
