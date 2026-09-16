import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../providers/emergency_provider.dart';
import '../../../services/socket/socket_service.dart';
import '../../../services/notification/medifind_push_service.dart';
import '../../widgets/design_system/design_system.dart';

class DiagnosticsScreen extends ConsumerStatefulWidget {
  const DiagnosticsScreen({super.key});

  @override
  ConsumerState<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends ConsumerState<DiagnosticsScreen> {
  String? _pushStatus;
  bool _isPinging = false;

  @override
  void initState() {
    super.initState();
    _loadPushStatus();
  }

  Future<void> _loadPushStatus() async {
    final status = await MedifindPushService.statusSummary();
    if (mounted) {
      setState(() => _pushStatus = status);
    }
  }

  Future<void> _checkSocketRooms() async {
    setState(() => _isPinging = true);
    try {
      final socket = SocketService.instance;
      // We rely on the 'pong' listener in server.ts to return rooms
      // For now, we'll just check if connected
      if (!socket.isConnected) {
        if (mounted) {
          showMfSnackBar(context, 'Socket not connected', tone: MfTone.danger);
        }
      } else {
        // Send a diagnostic ping
        // Note: We need to listen for 'pong' in SocketService
        // but for now we'll just show status
      }
    } finally {
      if (mounted) setState(() => _isPinging = false);
    }
  }

  Future<void> _clearLocalCache() async {
    final localDs = await ref.read(localDataSourceProvider.future);
    await localDs.clearAllEmergencies();
    if (mounted) {
      showMfSnackBar(context, 'Local emergency cache cleared. Dashboard reset.', tone: MfTone.success);
    }
  }

  Future<void> _cleanAllEmergencies() async {
    final confirmed = await showMfConfirmDialog(
      context,
      title: 'Clean all emergencies?',
      message: 'Cancels every locally cached emergency on the backend and clears the local cache.',
      confirmLabel: 'Clean all',
      destructive: true,
      icon: Icons.cleaning_services_outlined,
    );
    if (!confirmed) return;
    final localDs = await ref.read(localDataSourceProvider.future);
    final emergencies = await localDs.getAllEmergencies();
    int count = 0;
    for (var e in emergencies) {
      try {
        final repo = await ref.read(emergencyRepositoryProvider.future);
        await repo.cancelEmergency(e['id']);
        count++;
      } catch (_) {}
    }
    await localDs.clearAllEmergencies();
    if (mounted) {
      showMfSnackBar(context, 'Cleaned $count emergencies from backend and local cache.');
    }
  }

  Future<void> _setFakeLocation() async {
    await ref.read(pushFakeLocationProvider(0.045).future);
    if (mounted) {
      showMfSnackBar(context, 'Fake location set about 5 km away');
    }
  }

  Future<void> _syncPending() async {
    try {
      await MedifindPushService.syncPending();
      await _loadPushStatus();
      if (mounted) {
        showMfSnackBar(context, 'Missed alerts fetched', tone: MfTone.success);
      }
    } catch (e) {
      if (mounted) {
        showMfSnackBar(context, 'Sync failed: $e', tone: MfTone.danger);
      }
    }
  }

  MfStatusChip _chip(bool ok, String okLabel, String badLabel) => MfStatusChip(
        label: ok ? okLabel : badLabel,
        tone: ok ? MfTone.success : MfTone.danger,
        icon: ok ? Icons.check_circle_outline_rounded : Icons.error_outline_rounded,
      );

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final userAsync = ref.watch(currentUserProvider);
    final isSocketConnected = ref.watch(socketStreamProvider.select((s) => s.valueOrNull?.event == SocketEvent.connectionStatus && s.valueOrNull?.data['status'] == 'connected' || SocketService.instance.isConnected));
    final simulationMode = ref.watch(simulationModeProvider);

    return MfScaffold(
      title: 'Diagnostics',
      subtitle: 'System status and testing tools',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(MfSpace.gutter, MfSpace.md, MfSpace.gutter, MfSpace.xl),
        children: [
          // ── User identity ────────────────────────────────────────────
          const MfSectionTitle('User identity'),
          userAsync.when(
            data: (user) => MfListGroup(
              children: [
                MfKeyValueRow(icon: Icons.fingerprint_rounded, label: 'User ID', value: user?.id ?? 'Unknown'),
                MfKeyValueRow(icon: Icons.person_outline_rounded, label: 'Name', value: user?.fullName ?? 'Unknown'),
                MfKeyValueRow(icon: Icons.badge_outlined, label: 'Role', value: user?.role ?? 'Unknown'),
                MfKeyValueRow(
                  icon: Icons.verified_user_outlined,
                  label: 'Account status',
                  value: user?.isActive == true ? 'Active' : 'Inactive',
                  trailing: _chip(user?.isActive == true, 'Active', 'Inactive'),
                ),
              ],
            ),
            loading: () => MfSkeleton.list(count: 1, itemHeight: 200),
            error: (e, _) => MfCard(
              child: MfErrorState(
                compact: true,
                title: 'Could not load user',
                message: '$e',
                onRetry: () => ref.invalidate(currentUserProvider),
              ),
            ),
          ),
          const SizedBox(height: MfSpace.sm),

          // Reset/Clean Dashboard Buttons (Plan v8)
          MfSecondaryButton(
            label: 'Clear local cache',
            icon: Icons.delete_sweep_outlined,
            tone: MfTone.warning,
            onPressed: _clearLocalCache,
          ),
          const SizedBox(height: MfSpace.xs),
          MfSecondaryButton(
            label: 'Clean all my emergencies (backend + local)',
            icon: Icons.cleaning_services_outlined,
            tone: MfTone.danger,
            onPressed: _cleanAllEmergencies,
          ),

          const SizedBox(height: MfSpace.lg),

          // ── Connection status ────────────────────────────────────────
          const MfSectionTitle('Connection status'),
          MfListGroup(
            children: [
              MfKeyValueRow(
                icon: Icons.hub_outlined,
                label: 'Socket.io',
                value: isSocketConnected ? 'Real-time channel open' : 'Real-time channel closed',
                trailing: _chip(isSocketConnected, 'Connected', 'Disconnected'),
              ),
              Semantics(
                toggled: simulationMode,
                label: 'Simulation mode',
                hint: 'Fake movement for testing',
                excludeSemantics: true,
                onTap: () => ref.read(simulationModeProvider.notifier).state = !simulationMode,
                child: InkWell(
                  onTap: () => ref.read(simulationModeProvider.notifier).state = !simulationMode,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 56),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: MfSpace.md, vertical: MfSpace.xs),
                      child: Row(
                        children: [
                          Icon(Icons.route_outlined, size: 20, color: cs.onSurfaceVariant),
                          const SizedBox(width: MfSpace.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Simulation mode', style: text.titleSmall),
                                Text('Fake movement for testing', style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                              ],
                            ),
                          ),
                          Switch(
                            value: simulationMode,
                            onChanged: (val) => ref.read(simulationModeProvider.notifier).state = val,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(MfSpace.md),
                child: Column(
                  children: [
                    MfPrimaryButton(
                      label: 'Refresh socket status',
                      icon: Icons.refresh_rounded,
                      loading: _isPinging,
                      height: MfSize.minTouch,
                      onPressed: _isPinging ? null : _checkSocketRooms,
                    ),
                    const SizedBox(height: MfSpace.xs),
                    MfSecondaryButton(
                      label: 'Set fake location (5 km away)',
                      icon: Icons.location_on_outlined,
                      onPressed: _setFakeLocation,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: MfSpace.lg),

          // ── Push notifications ───────────────────────────────────────
          const MfSectionTitle('Push notifications'),
          MfListGroup(
            children: [
              MfKeyValueRow(
                icon: Icons.notifications_active_outlined,
                label: 'Delivery',
                value: _pushStatus ?? 'Checking...',
                trailing: _chip(SocketService.instance.isConnected, 'Online', 'Offline'),
              ),
              Padding(
                padding: const EdgeInsets.all(MfSpace.md),
                child: MfPrimaryButton(
                  label: 'Fetch missed alerts',
                  icon: Icons.sync_rounded,
                  height: MfSize.minTouch,
                  onPressed: _syncPending,
                ),
              ),
            ],
          ),

          const SizedBox(height: MfSpace.lg),

          const MfInfoBanner(
            icon: Icons.tips_and_updates_outlined,
            tone: MfTone.neutral,
            title: 'Troubleshooting tips',
            message: '- Ensure you are on the same Wi-Fi as the server (192.168.100.5).\n'
                '- Toggle "Online" status twice to force-sync location.\n'
                '- Check server logs for [Geospatial Search] entries.',
          ),
        ],
      ),
    );
  }
}
