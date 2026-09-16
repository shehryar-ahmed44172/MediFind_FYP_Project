import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/emergency_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../providers/medical_profile_provider.dart';
import '../../../domain/entities/responder_alert.dart';
import '../../../core/utils/emergency_status.dart';
import 'package:medifind_mobile_application/core/utils/responsive.dart';

import '../home/widgets/connectivity_banner.dart';
import '../../theme/app_theme.dart';
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Could not update status — check your connection and try again.'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            if (!isConnected) const ConnectivityBanner(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                child: _buildIncomingRequests(theme, userAsync, alertsAsync),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIncomingRequests(ThemeData theme, AsyncValue userAsync, AsyncValue<List<ResponderAlert>> alertsAsync) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          userAsync.when(
            data: (user) => Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'RESPONDER DASHBOARD',
                    style: TextStyle(
                      color: AppColors.primaryLight.withOpacity(0.85),
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user?.fullName.split(' ')[0] ?? 'Responder',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w900,
                      fontSize: 32,
                      letterSpacing: -1,
                    ),
                  ),
                ],
              ),
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          
          _buildStatusToggle(theme, userAsync),
          
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Text('Quick Actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          _buildQuickActionGrid(theme),

          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Active Emergency Alerts', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: 'Refresh alerts',
                  onPressed: _refresh,
                ),
              ],
            ),
          ),

          alertsAsync.when(
            skipLoadingOnRefresh: true,
            skipLoadingOnReload: true,
            data: (alerts) {
              final visible = alerts.where((a) => !EmergencyStatus.isTerminal(a.emergency.status)).toList()
                // Accepted-by-me first, then newest.
                ..sort((a, b) {
                  if (a.isAcceptedByMe != b.isAcceptedByMe) return a.isAcceptedByMe ? -1 : 1;
                  final at = a.emergency.createdAt ?? DateTime(2000);
                  final bt = b.emergency.createdAt ?? DateTime(2000);
                  return bt.compareTo(at);
                });
              return visible.isEmpty
                  ? _buildEmptyEmergenciesState()
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: visible.length,
                      itemBuilder: (ctx, i) => _EmergencyRequestCard(
                        key: ValueKey(visible[i].id),
                        alert: visible[i],
                      ),
                    );
            },
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Column(
                children: [
                  Icon(Icons.cloud_off_rounded, size: 40, color: Colors.grey.shade500),
                  const SizedBox(height: 8),
                  Text(
                    'Could not load emergency alerts.\n$e',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry'),
                    style: OutlinedButton.styleFrom(minimumSize: const Size(120, 48)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildQuickActionGrid(ThemeData theme) {
    final actions = [
      {'title': 'My Profile',    'icon': Icons.person_rounded,         'color': AppColors.primary,       'route': '/responder/profile'},
      {'title': 'History',       'icon': Icons.history_rounded,         'color': AppColors.secondaryTeal, 'route': '/responder/history'},
      {'title': 'Settings',      'icon': Icons.settings_rounded,        'color': AppColors.warning,       'route': '/settings'},
      {'title': 'My Rating',     'icon': Icons.star_rounded,            'color': const Color(0xFFF59E0B), 'route': null}, // null = inline bottom sheet
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.4,
      ),
      itemCount: actions.length,
      itemBuilder: (context, index) {
        final action = actions[index];
        final color = action['color'] as Color;
        return InkWell(
          onTap: () {
            final route = action['route'] as String?;
            if (route != null) {
              context.go(route);
            } else {
              // "My Rating" — show performance sheet inline
              _showPerformanceSheet(context);
            }
          },
          borderRadius: BorderRadius.circular(24),
          child: Container(
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(24),
              boxShadow: AppShadows.neumorphicOut,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(action['icon'] as IconData, color: color, size: 28),
                const SizedBox(height: 8),
                Text(action['title'] as String,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showPerformanceSheet(BuildContext context) {
    // Force a fresh fetch from the backend so rating is always up-to-date
    ref.invalidate(currentUserProvider);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Consumer(
        builder: (ctx, ref, __) {
          final userAsync = ref.watch(currentUserProvider);

          // Drag handle is always visible while loading or loaded
          final handle = Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          );

          Widget body;
          if (userAsync.isLoading) {
            body = const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            );
          } else {
            final user   = userAsync.valueOrNull;
            final rating = user?.rating ?? 5.0;
            final total  = user?.totalResponsesHandled ?? 0;
            final type   = user?.responderType ?? 'Responder';
            final org    = user?.organization;

            final fullStars = rating.floor();
            final halfStar  = (rating - fullStars) >= 0.5;

            String performanceLabel;
            Color  performanceColor;
            if (rating >= 4.5) {
              performanceLabel = 'Excellent';
              performanceColor = const Color(0xFF059669);
            } else if (rating >= 4.0) {
              performanceLabel = 'Good';
              performanceColor = const Color(0xFF0C637E);
            } else if (rating >= 3.5) {
              performanceLabel = 'Average';
              performanceColor = const Color(0xFFF59E0B);
            } else {
              performanceLabel = 'Needs Improvement';
              performanceColor = const Color(0xFFDC2626);
            }

            body = Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Avatar + name
                CircleAvatar(
                  radius: 34,
                  backgroundColor: AppColors.primary.withOpacity(0.12),
                  child: Text(
                    user?.fullName.isNotEmpty == true ? user!.fullName[0].toUpperCase() : 'R',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  user?.fullName ?? 'Responder',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                Text(
                  org != null ? '$type · $org' : type,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 24),

                // Star row
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (i) {
                    if (i < fullStars) {
                      return const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 32);
                    } else if (i == fullStars && halfStar) {
                      return const Icon(Icons.star_half_rounded, color: Color(0xFFF59E0B), size: 32);
                    } else {
                      return Icon(Icons.star_outline_rounded, color: Colors.grey.shade300, size: 32);
                    }
                  }),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      rating.toStringAsFixed(1),
                      style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, letterSpacing: -1),
                    ),
                    const Text(' / 5.0', style: TextStyle(fontSize: 16, color: Colors.grey)),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                    color: performanceColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: performanceColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    performanceLabel,
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: performanceColor),
                  ),
                ),
                const SizedBox(height: 24),

                // Stats row
                Row(
                  children: [
                    _StatTile(
                      icon: Icons.local_hospital_rounded,
                      iconColor: AppColors.primary,
                      label: 'Responses',
                      value: '$total',
                    ),
                    const SizedBox(width: 12),
                    _StatTile(
                      icon: Icons.shield_rounded,
                      iconColor: const Color(0xFF059669),
                      label: 'Status',
                      value: user?.isActive == true ? 'Active' : 'Offline',
                      valueColor: user?.isActive == true ? const Color(0xFF059669) : Colors.grey,
                    ),
                    const SizedBox(width: 12),
                    _StatTile(
                      icon: Icons.verified_rounded,
                      iconColor: const Color(0xFF0C637E),
                      label: 'Verified',
                      value: user?.verificationStatus == 'VERIFIED' ? 'Yes' : 'Pending',
                      valueColor: user?.verificationStatus == 'VERIFIED'
                          ? const Color(0xFF0C637E)
                          : const Color(0xFFF59E0B),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            );
          }

          return Container(
            decoration: BoxDecoration(
              color: Theme.of(ctx).cardColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [handle, body],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusToggle(ThemeData theme, AsyncValue userAsync) {
    final isConnected = ref.watch(isConnectedProvider);

    return Padding(
      padding: EdgeInsets.all(2.hp),
      child: userAsync.when(
        loading: () => const LinearProgressIndicator(),
        error: (_, __) => const SizedBox.shrink(),
        data: (user) {
          // The displayed value: optimistic override (while API in-flight)
          // or the server's confirmed value.
          final serverActive = user?.isActive ?? false;
          final displayActive = _optimisticAvailability ?? serverActive;

          Color iconColor;
          String statusLabel;
          String subLabel;
          if (!isConnected) {
            iconColor  = AppColors.warning;
            statusLabel = 'No Internet Connection';
            subLabel   = 'Toggle unavailable while offline';
          } else if (_isUpdatingStatus) {
            iconColor  = displayActive ? AppColors.primaryBlue : Colors.grey;
            statusLabel = displayActive ? 'Going Online…' : 'Going Offline…';
            subLabel   = 'Updating your status…';
          } else {
            iconColor  = displayActive ? AppColors.primaryBlue : Colors.grey;
            statusLabel = displayActive ? 'Ready to Respond' : 'Offline';
            subLabel   = 'Switch on to receive alerts';
          }

          return AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: EdgeInsets.symmetric(horizontal: 5.wp, vertical: 2.5.hp),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(28),
              boxShadow: AppShadows.cardShadow,
              border: Border.all(
                color: !isConnected
                    ? AppColors.warning.withOpacity(0.45)
                    : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.power_settings_new_rounded,
                  color: iconColor,
                  size: 3.hp,
                ),
                SizedBox(width: 4.wp),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(statusLabel,
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 2.2.hp)),
                      Text(subLabel,
                          style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
                // While updating → show a small spinner so the toggle
                // isn't frozen/confusing; once done → restore the switch.
                if (_isUpdatingStatus)
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation(iconColor),
                    ),
                  )
                else
                  Switch.adaptive(
                    value: displayActive,
                    // Disable entirely when offline so the user gets
                    // an amber border + sub-label instead of a stuck toggle.
                    onChanged: isConnected ? (value) => _setAvailability(value) : null,
                    activeColor: AppColors.primaryBlue,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyEmergenciesState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 32),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.verified_user_rounded, size: 52, color: AppColors.primary.withOpacity(0.5)),
            ),
            const SizedBox(height: 20),
            Text(
              'All Clear',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No active emergency requests right now. Pull down to refresh.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Compact stat tile used in the performance bottom sheet ───────────────────
class _StatTile extends StatelessWidget {
  final IconData icon;
  final Color    iconColor;
  final String   label;
  final String   value;
  final Color?   valueColor;

  const _StatTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Icon(icon, color: iconColor, size: 22),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: valueColor ?? Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
            ),
          ],
        ),
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

  /// Colour per emergency type (MediFind logo palette).
  static Color _getEmergencyColor(String emergencyType) {
    switch (EmergencyTypes.normalize(emergencyType)) {
      case EmergencyTypes.cardiac:
        return AppColors.primaryNavy;
      case EmergencyTypes.breathing:
        return AppColors.primaryTeal;
      case EmergencyTypes.stroke:
        return AppColors.primaryBlue;
      case EmergencyTypes.trauma:
        return const Color(0xFF0A5B76);
      case EmergencyTypes.seizure:
        return const Color(0xFF04364E); // deep navy
      case EmergencyTypes.diabetic:
        return const Color(0xFF3D4F5F); // charcoal
      case EmergencyTypes.fall:
        return const Color(0xFF17A2B8);
      default:
        return AppColors.primaryNavy;
    }
  }

  static IconData _getEmergencyIcon(String emergencyType) {
    switch (EmergencyTypes.normalize(emergencyType)) {
      case EmergencyTypes.cardiac:
        return Icons.favorite_rounded;
      case EmergencyTypes.breathing:
        return Icons.air_rounded;
      case EmergencyTypes.fall:
        return Icons.trending_down_rounded;
      case EmergencyTypes.trauma:
        return Icons.local_hospital_rounded;
      case EmergencyTypes.stroke:
        return Icons.psychology_rounded;
      case EmergencyTypes.seizure:
        return Icons.bolt_rounded;
      case EmergencyTypes.diabetic:
        return Icons.bloodtype_rounded;
      default:
        return Icons.emergency_rounded;
    }
  }

  static String _timeAgo(DateTime? createdAt) {
    if (createdAt == null) return 'Just now';
    final diff = DateTime.now().difference(createdAt.toLocal());
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    return '${diff.inHours} h ago';
  }

  String _subtitle() {
    final parts = <String>[];
    final d = widget.alert.distanceKm;
    if (d != null) parts.add('${GeoUtils.formatDistance(d)} away');
    final eta = widget.alert.estimatedArrivalMinutes;
    if (eta != null && eta > 0) parts.add('~$eta min');
    parts.add(_timeAgo(widget.alert.emergency.createdAt));
    return parts.join(' • ');
  }

  Future<void> _accept() async {
    final alert = widget.alert;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Accept this emergency?'),
        content: Text(
          '${EmergencyTypes.label(alert.emergency.emergencyType)} emergency'
          '${alert.patientName != null ? ' for ${alert.patientName}' : ''}'
          '${alert.distanceKm != null ? ', ${GeoUtils.formatDistance(alert.distanceKm!)} away' : ''}.\n\n'
          'You will be navigated to the patient and marked as busy.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Not now')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Accept')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not accept: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
        ref.invalidate(responderAlertsProvider);
      }
    } finally {
      if (mounted) setState(() => _isAccepting = false);
    }
  }

  Future<bool> _confirmReject() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Decline this request?'),
        content: const Text('It will be removed from your list and offered to other responders.'),
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
    return result == true;
  }

  @override
  Widget build(BuildContext context) {
    final alert = widget.alert;
    final request = alert.emergency;
    final theme = Theme.of(context);
    final emergencyColor = _getEmergencyColor(request.emergencyType);
    final emergencyIcon = _getEmergencyIcon(request.emergencyType);
    final acceptedByMe = alert.isAcceptedByMe;

    final profileAsync = ref.watch(getMedicalProfileProvider(request.userId));
    final patientName = alert.patientName ??
        ref.watch(userProfileProvider(request.userId)).valueOrNull?.fullName ??
        'Patient';

    final card = Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppShadows.cardShadow,
      ),
      // Rounded card with a coloured left accent bar. (A non-uniform Border
      // combined with borderRadius throws an assertion, so the accent is a
      // separate strip clipped by ClipRRect.)
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 6, color: emergencyColor),
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => context.push(
                      acceptedByMe ? '/responder/active/${alert.id}' : '/responder/request/${alert.id}',
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: emergencyColor.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(emergencyIcon, color: emergencyColor, size: 26),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      EmergencyTypes.label(request.emergencyType),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: emergencyColor,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _subtitle(),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade700,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (acceptedByMe)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.success.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'IN PROGRESS',
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.success),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            patientName,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
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
                              return Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  if (bloodType != null && bloodType.isNotEmpty)
                                    _Badge(text: 'Blood $bloodType', color: AppColors.error),
                                  if (allergyDisplay.isNotEmpty)
                                    _Badge(
                                      text: allergies.length > 1
                                          ? 'Allergy: $allergyDisplay +${allergies.length - 1}'
                                          : 'Allergy: $allergyDisplay',
                                      color: AppColors.warning,
                                    ),
                                  if (isDeaf) const _Badge(text: 'DEAF — use text', color: AppColors.primaryBlue),
                                ],
                              );
                            },
                            loading: () => const SizedBox(height: 4, child: LinearProgressIndicator()),
                            error: (_, __) => const SizedBox.shrink(),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => context.push('/responder/request/${alert.id}'),
                                  icon: const Icon(Icons.info_outline_rounded, size: 18),
                                  label: const Text('Details'),
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size.fromHeight(48),
                                    side: BorderSide(color: emergencyColor),
                                    foregroundColor: emergencyColor,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _isAccepting
                                      ? null
                                      : acceptedByMe
                                          ? () => context.push('/responder/active/${alert.id}')
                                          : _accept,
                                  icon: _isAccepting
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                        )
                                      : Icon(acceptedByMe ? Icons.navigation_rounded : Icons.check_rounded, size: 18),
                                  label: Text(acceptedByMe ? 'Resume' : 'Accept'),
                                  style: ElevatedButton.styleFrom(
                                    minimumSize: const Size.fromHeight(48),
                                    backgroundColor: emergencyColor,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                              ),
                            ],
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

    if (acceptedByMe) return card;

    return Dismissible(
      key: Key(alert.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmReject(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text('Decline', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w700)),
            SizedBox(width: 8),
            Icon(Icons.close_rounded, color: AppColors.error),
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
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  const _Badge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }
}
