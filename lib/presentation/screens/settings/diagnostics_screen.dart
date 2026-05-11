import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import '../../providers/auth_provider.dart';
import '../../providers/emergency_provider.dart';
import '../../../services/socket/socket_service.dart';
import '../../../services/notification/push_notification_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common/app_header.dart';
import 'package:go_router/go_router.dart';

class DiagnosticsScreen extends ConsumerStatefulWidget {
  const DiagnosticsScreen({super.key});

  @override
  ConsumerState<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends ConsumerState<DiagnosticsScreen> {
  String? _fcmToken;
  final List<String> _rooms = [];
  bool _isPinging = false;

  @override
  void initState() {
    super.initState();
    _loadFcmToken();
  }

  Future<void> _loadFcmToken() async {
    final token = await PushNotificationService.getToken();
    if (mounted) {
      setState(() => _fcmToken = token);
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Socket not connected!')),
          );
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final userAsync = ref.watch(currentUserProvider);
    final isSocketConnected = ref.watch(socketStreamProvider.select((s) => s.valueOrNull?.event == SocketEvent.connectionStatus && s.valueOrNull?.data['status'] == 'connected' || SocketService.instance.isConnected));

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Column(
        children: [
          const AppHeader(
            greetingOverride: 'Diagnostics',
            showProfile: false,
            canPop: true,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _buildSection(
                  'User Identity',
                  userAsync.when(
                    data: (user) => Column(
                      children: [
                        _buildInfoRow('User ID', user?.id ?? 'Unknown'),
                        _buildInfoRow('Name', user?.fullName ?? 'Unknown'),
                        _buildInfoRow('Role', user?.role ?? 'Unknown'),
                        _buildInfoRow('Active Status', user?.isActive == true ? 'ACTIVE' : 'INACTIVE', color: user?.isActive == true ? Colors.green : Colors.red),
                      ],
                    ),
                    loading: () => const CircularProgressIndicator(),
                    error: (e, _) => Text('Error loading user: $e'),
                  ),
                ),
                
                const SizedBox(height: 12),
                
                // Reset/Clean Dashboard Button (Plan v8)
                Column(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () async {
                        final localDs = await ref.read(localDataSourceProvider.future);
                        await localDs.clearAllEmergencies();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Local emergency cache cleared! Dashboard reset.')),
                          );
                        }
                      },
                      icon: const Icon(Icons.delete_sweep_rounded, color: Colors.orange),
                      label: const Text('Clear Local Cache', style: TextStyle(color: Colors.orange)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.orange),
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: () async {
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
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Cleaned $count emergencies from backend & local cache.')),
                          );
                        }
                      },
                      icon: const Icon(Icons.cleaning_services_rounded),
                      label: const Text('Clean All My Emergencies (Backend + Local)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                _buildSection(
                  'Connection Status',
                  Column(
                    children: [
                      _buildInfoRow(
                        'Socket.io', 
                        isSocketConnected ? 'CONNECTED' : 'DISCONNECTED',
                        color: isSocketConnected ? Colors.green : Colors.red,
                      ),
                      const Divider(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Simulation Mode', style: TextStyle(fontWeight: FontWeight.bold)),
                              Text('Fake movement for testing', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                            ],
                          ),
                          Switch(
                            value: ref.watch(simulationModeProvider),
                            onChanged: (val) => ref.read(simulationModeProvider.notifier).state = val,
                            activeThumbColor: AppColors.primary,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _checkSocketRooms,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Refresh Socket Status'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () async {
                          await ref.read(pushFakeLocationProvider(0.045).future);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Fake location set ~5km away')),
                            );
                          }
                        },
                        icon: const Icon(Icons.location_on_outlined),
                        label: const Text('Set Fake Location (5km away)'),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                _buildSection(
                  'Push Notifications (FCM)',
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow('Token Status', _fcmToken != null ? 'READY' : 'MISSING', color: _fcmToken != null ? Colors.green : Colors.red),
                      if (_fcmToken != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _fcmToken!,
                            style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            OutlinedButton.icon(
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: _fcmToken!));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('FCM Token copied to clipboard')),
                                );
                              },
                              icon: const Icon(Icons.copy_rounded, size: 18),
                              label: const Text('Copy Token'),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed: () async {
                                if (_fcmToken != null) {
                                  try {
                                    await ref.read(updateFcmTokenProvider(_fcmToken!).future);
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('✅ Token synced to backend successfully!')),
                                      );
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('❌ Sync failed: $e')),
                                      );
                                    }
                                  }
                                }
                              },
                              icon: const Icon(Icons.sync_rounded),
                              label: const Text('Sync to Backend'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 40),
                
                Text(
                  'Troubleshooting Tips:',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text('• Ensure you are on the same Wi-Fi as the server (192.168.100.5).\n• Toggle "Online" status twice to force-sync location.\n• Check server logs for [Geospatial Search] entries.', style: TextStyle(fontSize: 13, color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, Widget content) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppShadows.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          content,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Text(
            value, 
            style: TextStyle(
              fontWeight: FontWeight.bold, 
              fontSize: 13,
              color: color,
            )
          ),
        ],
      ),
    );
  }
}
