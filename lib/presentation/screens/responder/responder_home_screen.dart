import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/emergency_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../../domain/entities/emergency.dart';
import 'package:medifind_mobile_application/core/utils/responsive.dart';
import '../../widgets/common/emergency_timer.dart';

import '../home/widgets/connectivity_banner.dart';
import '../../theme/app_theme.dart';
import 'package:medifind_mobile_application/presentation/widgets/common/app_header.dart';
import '../settings/settings_screen.dart';
import '../profile/user_profile_screen.dart';
import '../../../services/location/location_service.dart';
import '../../../services/location/responder_location_tracker.dart';

import '../../providers/navigation_provider.dart';

class ResponderHomeScreen extends ConsumerStatefulWidget {
  const ResponderHomeScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ResponderHomeScreen> createState() => _ResponderHomeScreenState();
}

class _ResponderHomeScreenState extends ConsumerState<ResponderHomeScreen> {
  bool _isUpdatingStatus = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      ref.read(getActiveEmergenciesProvider);
      final user = ref.read(currentUserProvider).valueOrNull;
      if (user?.isActive == true) {
        // Sync availability
        ref.read(setResponderAvailabilityProvider(true));
        
        // Start background location tracking for visibility
        ref.read(responderLocationTrackerProvider).start();
        
        debugPrint('📍 Responder initialized and tracking started');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isConnected = ref.watch(isConnectedProvider);
    final userAsync = ref.watch(currentUserProvider);
    final emergenciesAsync = ref.watch(watchActiveEmergenciesProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            if (!isConnected) const ConnectivityBanner(),
            Expanded(
              child: _buildIncomingRequests(theme, userAsync, emergenciesAsync),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIncomingRequests(ThemeData theme, AsyncValue userAsync, AsyncValue emergenciesAsync) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          userAsync.when(
            data: (user) => Padding(
              padding: EdgeInsets.fromLTRB(24, 24, 24, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Hello,', style: TextStyle(color: Colors.grey, fontSize: 1.8.hp)),
                  Text(user?.fullName.split(' ')[0] ?? 'Responder',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 3.2.hp)),
                ],
              ),
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          
          _buildStatusToggle(theme, userAsync),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: const Text('Quick Actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                  onPressed: () => ref.invalidate(getActiveEmergenciesProvider),
                ),
              ],
            ),
          ),

          emergenciesAsync.when(
            data: (emergencies) => emergencies.isEmpty
                ? _buildEmptyEmergenciesState()
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: emergencies.length,
                    itemBuilder: (ctx, i) => _EmergencyRequestCard(request: emergencies[i]),
                  ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildQuickActionGrid(ThemeData theme) {
    final actions = [
      {'title': 'Emergencies', 'icon': Icons.emergency_rounded, 'color': Colors.red, 'route': '/responder'},
      {'title': 'History', 'icon': Icons.history_rounded, 'color': Colors.indigo, 'route': '/responder/history'},
      {'title': 'Messages', 'icon': Icons.chat_bubble_rounded, 'color': Colors.orange, 'route': null},
      {'title': 'Diagnostics', 'icon': Icons.analytics_rounded, 'color': Colors.blue, 'route': '/diagnostics'},
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
            if (action['route'] != null) {
              context.push(action['route'] as String);
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

  Widget _buildStatusToggle(ThemeData theme, AsyncValue userAsync) {
    return Padding(
      padding: EdgeInsets.all(2.hp),
      child: userAsync.when(
        data: (user) => Container(
          padding: EdgeInsets.symmetric(horizontal: 5.wp, vertical: 2.5.hp),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(28),
            boxShadow: AppShadows.cardShadow,
          ),
          child: Row(
            children: [
              Icon(Icons.power_settings_new_rounded, 
                   color: (user?.isActive ?? false) ? Colors.green : Colors.grey, 
                   size: 3.hp),
              SizedBox(width: 4.wp),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text((user?.isActive ?? false) ? 'Ready to Respond' : 'Offline',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 2.2.hp)),
                    Text('Switch on to receive alerts', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
              Switch.adaptive(
                value: user?.isActive ?? false,
                onChanged: (value) async {
                  setState(() => _isUpdatingStatus = true);
                  await ref.read(setResponderAvailabilityProvider(value).future);
                  if (value) ref.read(responderLocationTrackerProvider).start();
                  else ref.read(responderLocationTrackerProvider).stop();
                  setState(() => _isUpdatingStatus = false);
                },
              ),
            ],
          ),
        ),
        loading: () => const LinearProgressIndicator(),
        error: (_, __) => const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildEmptyEmergenciesState() {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 32),
          Icon(Icons.check_circle_outline_rounded, size: 72, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text('No active emergency requests', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildHistoryTab(ThemeData theme) {
    final historyAsync = ref.watch(getResponderHistoryProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Text('Response History',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                onPressed: () => ref.invalidate(getResponderHistoryProvider),
              ),
            ],
          ),
        ),
        Expanded(
          child: historyAsync.when(
            data: (history) => history.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history_rounded,
                            size: 72, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        const Text('No past records found',
                            style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: history.length,
                    itemBuilder: (ctx, i) {
                      final item = history[i] as Map<String, dynamic>;
                      return _HistoryItemCard(item: item);
                    },
                  ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
        ),
      ],
    );
  }

}

class _HistoryItemCard extends StatelessWidget {
  final Map<String, dynamic> item;

  const _HistoryItemCard({Key? key, required this.item}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = item['status'] as String? ?? 'PENDING';
    final emergency = item['emergency'] as Map<String, dynamic>? ?? {};
    final patient = emergency['patient'] as Map<String, dynamic>? ?? {};
    final type = (emergency['emergencyType'] as String? ?? 'Medical').toUpperCase();
    final date = DateTime.tryParse(item['createdAt']?.toString() ?? '') ?? DateTime.now();

    Color statusColor;
    IconData statusIcon;
    switch (status) {
      case 'ACCEPTED':
      case 'RESPONDER_ASSIGNED':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle_outline;
        break;
      case 'REJECTED':
        statusColor = Colors.red;
        statusIcon = Icons.cancel_outlined;
        break;
      case 'COMPLETED':
        statusColor = Colors.blue;
        statusIcon = Icons.task_alt;
        break;
      default:
        statusColor = Colors.orange;
        statusIcon = Icons.hourglass_empty;
    }

    return InkWell(
      onTap: () => _showHistoryDetails(context),
      borderRadius: BorderRadius.circular(24),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: AppShadows.cardShadow,
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          leading: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(statusIcon, color: statusColor),
          ),
          title: Row(
            children: [
              Text(type.replaceAll('_', ' '),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const Spacer(),
              Text(
                '${date.day}/${date.month} ${date.hour}:${date.minute.toString().padLeft(2, '0')}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text('Patient: ${patient['fullName'] ?? 'Unknown User'}',
                  style: TextStyle(color: Colors.grey.shade700)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showHistoryDetails(BuildContext context) {
    final emergency = item['emergency'] as Map<String, dynamic>? ?? {};
    final patient = emergency['patient'] as Map<String, dynamic>? ?? {};
    final date = DateTime.tryParse(item['createdAt']?.toString() ?? '') ?? DateTime.now();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Response Details', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow(Icons.person_rounded, 'Patient', patient['fullName'] ?? 'Unknown'),
            _buildDetailRow(Icons.emergency_rounded, 'Type', emergency['emergencyType'] ?? 'Medical'),
            _buildDetailRow(Icons.calendar_today_rounded, 'Date', '${date.day}/${date.month}/${date.year}'),
            _buildDetailRow(Icons.info_outline_rounded, 'Status', item['status'] ?? 'N/A'),
            if (item['rejectionReason'] != null)
              _buildDetailRow(Icons.warning_amber_rounded, 'Reason', item['rejectionReason']),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 12),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _EmergencyRequestCard extends ConsumerWidget {
  final Emergency request;
  const _EmergencyRequestCard({required this.request});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    
    return Dismissible(
      key: Key(request.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red.shade100,
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.red),
      ),
      onDismissed: (_) async {
        // First delete locally to remove from UI instantly
        final localDs = await ref.read(localDataSourceProvider.future);
        await localDs.deleteEmergency(request.id);
        
        // Notify backend that responder rejected the request
        final user = ref.read(currentUserProvider).valueOrNull;
        if (user != null) {
          try {
            await ref.read(rejectEmergencyProvider(
              AcceptRejectParams(emergencyId: request.id, responderId: user.id)
            ).future);
            debugPrint('Emergency rejected on backend');
          } catch (e) {
            debugPrint('Failed to reject emergency on backend: $e');
          }
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: AppShadows.cardShadow,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: InkWell(
            onTap: () => context.go('/responder/request/${request.id}'),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.red.shade400, Colors.red.shade700],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.emergency_rounded, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          request.emergencyType.replaceAll('_', ' '),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold, 
                            fontSize: 17,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.location_on_outlined, size: 14, color: Colors.grey.shade600),
                            const SizedBox(width: 4),
                            Text(
                              'Incoming Request',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                            ),
                          ],
                        ),
                        if (request.expiresAt != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.timer_outlined, size: 12, color: Colors.red.shade700),
                                const SizedBox(width: 4),
                                EmergencyTimer(
                                  expiresAt: request.expiresAt!.toIso8601String(),
                                  // We don't have serverTime here easily from the list, 
                                  // but local time is usually fine for a 60s countdown.
                                  style: TextStyle(
                                    color: Colors.red.shade700,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.05),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.chevron_right_rounded, color: AppColors.primary),
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
