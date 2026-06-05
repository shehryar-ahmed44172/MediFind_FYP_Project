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
import '../../../services/location/responder_location_tracker.dart';


class ResponderHomeScreen extends ConsumerStatefulWidget {
  const ResponderHomeScreen({super.key});

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
                  onPressed: () => ref.invalidate(watchActiveEmergenciesProvider),
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
      {'title': 'My Profile',  'icon': Icons.person_rounded,       'color': AppColors.primary,       'route': '/responder/profile'},
      {'title': 'History',     'icon': Icons.history_rounded,       'color': AppColors.secondaryTeal, 'route': '/responder/history'},
      {'title': 'Messages',    'icon': Icons.chat_bubble_rounded,   'color': AppColors.warning,       'route': '/responder/chats'},
      {'title': 'Diagnostics', 'icon': Icons.analytics_rounded,     'color': AppColors.primaryLight,  'route': '/diagnostics'},
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
                   color: (user?.isActive ?? false) ? AppColors.primaryBlue : Colors.grey, // Logo-matched active indicator
                   size: 3.hp),
              SizedBox(width: 4.wp),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text((user?.isActive ?? false) ? 'Ready to Respond' : 'Offline',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 2.2.hp)),
                    const Text('Switch on to receive alerts', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
              Switch.adaptive(
                value: user?.isActive ?? false,
                onChanged: (value) async {
                  setState(() => _isUpdatingStatus = true);
                  await ref.read(setResponderAvailabilityProvider(value).future);
                  if (value) {
                    ref.read(responderLocationTrackerProvider).start();
                  } else {
                    ref.read(responderLocationTrackerProvider).stop();
                  }
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
              'No active emergency requests at this time.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryItemCard extends StatelessWidget {
  final Map<String, dynamic> item;

  const _HistoryItemCard({required this.item});

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
        statusColor = AppColors.primaryBlue; // Logo-matched success
        statusIcon = Icons.check_circle_outline;
        break;
      case 'REJECTED':
        statusColor = AppColors.error; // Error color for rejection
        statusIcon = Icons.cancel_outlined;
        break;
      case 'COMPLETED':
        statusColor = AppColors.primaryBlue; // Logo-matched completion
        statusIcon = Icons.task_alt;
        break;
      default:
        statusColor = AppColors.warning; // Warning for pending
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

  /// Get color based on emergency type (Phase 1: Color-coding)
  Color _getEmergencyColor(String emergencyType) {
    // ── Colors matched to MediFind logo palette ──────────────────────────
    // Primary: #0C637E (Navy-Teal) | Secondary: #2496A7 (Teal) | Accent: #2891C2 (Sky Blue)
    switch (emergencyType.toUpperCase()) {
      case 'CARDIAC':
        return AppColors.primaryNavy; // #0C637E - Most urgent, darkest
      case 'RESPIRATORY':
        return AppColors.primaryTeal; // #2496A7 - Urgent, medium
      case 'STROKE':
        return AppColors.primaryBlue; // #2891C2 - Urgent, lighter blue
      case 'TRAUMA':
        return const Color(0xFF0A5B76); // Darker navy-teal shade - Very urgent
      case 'FALL':
        return const Color(0xFF17A2B8); // Lighter cyan teal - Less urgent
      default:
        return AppColors.primaryNavy; // Fallback to primary
    }
  }

  /// Get emergency icon based on type
  IconData _getEmergencyIcon(String emergencyType) {
    switch (emergencyType.toUpperCase()) {
      case 'CARDIAC':
        return Icons.favorite_rounded;
      case 'RESPIRATORY':
        return Icons.lungs_rounded;
      case 'FALL':
        return Icons.trending_down_rounded;
      case 'TRAUMA':
        return Icons.local_hospital_rounded;
      case 'STROKE':
        return Icons.psychology_rounded;
      default:
        return Icons.emergency_rounded;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final emergencyColor = _getEmergencyColor(request.emergencyType);
    final emergencyIcon = _getEmergencyIcon(request.emergencyType);

    // Fetch patient info (Phase 1: Patient name display)
    final patientAsync = ref.watch(userProfileProvider(request.userId));
    final profileAsync = ref.watch(getMedicalProfileProvider(request.userId));

    return Dismissible(
      key: Key(request.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.error.withOpacity(0.1),
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
      ),
      onDismissed: (_) async {
        final localDs = await ref.read(localDataSourceProvider.future);
        await localDs.deleteEmergency(request.id);

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
          // Phase 1: Color-coded left border
          border: Border(
            left: BorderSide(color: emergencyColor, width: 6),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: InkWell(
            onTap: () => context.go('/responder/request/${request.id}'),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header row with icon and type
                  Row(
                    children: [
                      // Colored icon (Phase 1)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: emergencyColor.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          emergencyIcon,
                          color: emergencyColor,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Type and distance
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              request.emergencyType.replaceAll('_', ' '),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: emergencyColor,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '2.3 km • ${request.expiresAt != null ? "45 sec remaining" : "Incoming"}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Patient info row (Phase 1: Patient name + medical flags)
                  patientAsync.when(
                    data: (patient) => profileAsync.when(
                      data: (profile) {
                        final patientName = patient?.fullName ?? 'Patient';
                        final bloodType = profile?.bloodType ?? 'Unknown';
                        final hasAllergies = profile?.allergies.isNotEmpty ?? false;
                        final allergyDisplay = hasAllergies
                            ? profile!.allergies.first.substring(0, 3)
                            : 'None';

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Patient name
                            Text(
                              patientName,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),

                            // Medical flags row (Phase 1)
                            Row(
                              children: [
                                // Blood type badge
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.error.withOpacity(0.1), // Critical medical info
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '🔴 $bloodType',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.error,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),

                                // Allergy badge (Phase 1)
                                if (hasAllergies)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.warning.withOpacity(0.1), // Warning for allergies
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '⚠️ $allergyDisplay',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.warning,
                                      ),
                                    ),
                                  ),

                                const Spacer(),

                                // DEAF badge (Phase 1: Enhanced)
                                if (request.patientType.toUpperCase() == 'DEAF')
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryBlue.withOpacity(0.1), // Logo-matched accessibility
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      '👁️ DEAF',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primaryBlue,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        );
                      },
                      loading: () => const SizedBox(
                        height: 20,
                        child: LinearProgressIndicator(minVerticalPadding: 0),
                      ),
                      error: (_, __) => Text(
                        patientAsync.valueOrNull?.fullName ?? 'Patient',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ),
                    loading: () => const SizedBox(
                      height: 20,
                      child: LinearProgressIndicator(minVerticalPadding: 0),
                    ),
                    error: (_, __) => const Text(
                      'Patient',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Action buttons row (Phase 1: Quick accept button)
                  Row(
                    children: [
                      // View Details button
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => context.go('/responder/request/${request.id}'),
                          icon: const Icon(Icons.info_outline_rounded, size: 16),
                          label: const Text('Details'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            side: BorderSide(color: emergencyColor),
                            foregroundColor: emergencyColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Quick Accept button (Phase 1)
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => context.go('/responder/request/${request.id}'),
                          icon: const Icon(Icons.check_rounded, size: 18),
                          label: const Text('Accept'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: emergencyColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
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
    );
  }
}
