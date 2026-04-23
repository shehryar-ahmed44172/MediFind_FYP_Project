import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:ui';
import '../../providers/auth_provider.dart';
import '../../providers/medical_profile_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../home/widgets/connectivity_banner.dart';
import '../../theme/app_theme.dart';
import 'package:medifind_mobile_application/services/notification/push_notification_service.dart';
import 'package:medifind_mobile_application/core/utils/responsive.dart';
import 'package:medifind_mobile_application/presentation/services/haptic_feedback_service.dart';
import 'package:medifind_mobile_application/presentation/widgets/common/app_header.dart';
import 'package:medifind_mobile_application/presentation/widgets/emergency/emergency_overlay.dart';
import '../../providers/emergency_provider.dart';
import '../../providers/accessibility_provider.dart';
import 'package:flutter/services.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    // FIX: Run accessibility init once after first frame, NOT inside build().
    // Calling setState-triggering code inside build() causes infinite rebuild loops (blinking).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(currentUserProvider).valueOrNull;
      if (user != null) {
        ref.read(accessibilityProvider.notifier).initializeFromUser(user.patientType, user.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isConnected = ref.watch(isConnectedProvider);

    final settings = ref.watch(accessibilityProvider);
    final isDeafMode = settings.textOnlyMode;

    final userAsync = ref.watch(currentUserProvider);

    // Listen for visual emergency alerts (Deaf/Mute accessibility)
    ref.listen(visualEmergencyAlertProvider, (previous, next) {
      if (next != null) {
        if (settings.vibrationFeedback) HapticFeedbackService.sosPattern();
        EmergencyOverlay.show(
          context,
          title: 'Responder Assigned',
          message: next,
        );
        // Reset the alert state after showing
        ref.read(visualEmergencyAlertProvider.notifier).state = null;
      }
    });

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Visual Accessibility Banner (Immediate feedback for Deaf mode)
            if (isDeafMode)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.amber.shade700,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.visibility, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Visual Accessibility Mode Active',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.go('/home/settings/accessibility'),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 0),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'SETTINGS',
                        style: TextStyle(
                          color: Colors.white,
                          decoration: TextDecoration.underline,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            if (!isConnected) const ConnectivityBanner(),
            
            Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  userAsync.when(
                    data: (user) => Padding(
                      padding: const EdgeInsets.only(bottom: 24, left: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hello,',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: theme.colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                          Text(
                            user?.fullName.split(' ')[0] ?? 'User',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                    loading: () => const SizedBox(height: 60),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                  // profile summary
                  _buildMedicalProfileSnapshot(theme),
                  const SizedBox(height: 32),

                  // main sos btn
                  _buildMassiveSOSButton(theme, isDeafMode),
                  const SizedBox(height: 24),

                  // attach report btn
                  _buildAttachReportOption(theme),
                  const SizedBox(height: 32),

                  // grid for emergency types
                  _buildQuickServices(theme, isDeafMode),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}


  void _showNotifications(BuildContext context, ThemeData theme) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Icon(Icons.notifications_active_outlined, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Text(
                  'Notifications',
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 32),
            Icon(Icons.notifications_off_outlined, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text(
              'No new notifications',
              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildMedicalProfileSnapshot(ThemeData theme) {
    final userIdAsync = ref.watch(currentUserIdProvider);

    return userIdAsync.when(
      data: (userId) {
        if (userId == null) return const SizedBox.shrink();
        final profileAsync = ref.watch(getMedicalProfileProvider(userId));

        return profileAsync.when(
          data: (profile) {
            return Container(
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: AppShadows.neumorphicOut,
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Medical Profile',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      InkWell(
                        onTap: () => context.push('/home/medical-profile'),
                        child: Row(
                          children: [
                            Text(
                              'View all ',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Icon(Icons.arrow_forward_ios_rounded, 
                              size: 14, color: theme.colorScheme.primary),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildProfileStat(theme, 'Blood', profile?.bloodType ?? '--', Icons.bloodtype, Colors.red),
                      Container(width: 1, height: 40, color: Colors.grey.shade200),
                      _buildProfileStat(theme, 'Allergies', 
                        (profile?.allergies.isNotEmpty == true) ? profile!.allergies.first : 'None', 
                        Icons.warning_amber_rounded, Colors.orange),
                      Container(width: 1, height: 40, color: Colors.grey.shade200),
                      _buildProfileStat(theme, 'Meds', 
                        (profile?.medications.isNotEmpty == true) ? '${profile!.medications.length} Active' : 'None', 
                        Icons.medication_liquid_rounded, AppColors.primary),
                    ],
                  ),
                ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => const Text('Tap to refresh profile'),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildProfileStat(ThemeData theme, String title, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          title,
          style: theme.textTheme.bodySmall?.copyWith(
            color: Colors.grey.shade500,
          ),
        ),
      ],
    );
  }

  Widget _buildMassiveSOSButton(ThemeData theme, bool isDeaf) {
    return GestureDetector(
      onLongPressStart: (_) {
        if (isDeaf) HapticFeedbackService.heavy();
      },
      onLongPress: () {
         if (isDeaf) HapticFeedbackService.sosPattern();
         context.go('/home/emergency');
      },
      onTap: () {
        HapticFeedbackService.light();
        context.push('/home/emergency');
      },
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (isDeaf)
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 1.0, end: 1.2),
                duration: const Duration(seconds: 1),
                curve: Curves.easeInOut,
                builder: (context, value, child) {
                  return Container(
                    width: 65.wp * value,
                    height: 65.wp * value,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.red.withOpacity(0.1),
                    ),
                  );
                },
                onEnd: () {}, // Pulse could be repeated with a stateful animation if needed
              ),
            Container(
              width: 65.wp,
              height: 65.wp,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.scaffoldBackgroundColor,
                boxShadow: AppShadows.neumorphicOut,
              ),
              child: Container(
                margin: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFFF4D4D), Color(0xFFD32F2F)],
                  ),
                  boxShadow: AppShadows.sosMassiveGlow,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isDeaf ? Icons.wifi_tethering_rounded : Icons.fingerprint_rounded,
                      size: isDeaf ? 90 : 80,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isDeaf ? 'TAP OR HOLD' : 'PRESS & HOLD',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachReportOption(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppShadows.neumorphicOut,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push('/home/medical-reports'),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.note_add_outlined, color: theme.colorScheme.primary),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Medical Records',
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Attach or view your reports',
                        style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickServices(ThemeData theme, bool isDeaf) {
    final services = [
      {'title': 'My Medical Profile', 'icon': Icons.health_and_safety_outlined, 'color': AppColors.primary, 'route': '/home/medical-profile'},
      {'title': 'Medical Records', 'icon': Icons.assignment_outlined, 'color': AppColors.secondary, 'route': '/home/medical-reports'},
      {'title': 'Connect Caregivers', 'icon': Icons.people_outline_rounded, 'color': AppColors.accent, 'route': '/home/caregivers'},
      {'title': 'Hospitals Nearby', 'icon': Icons.local_hospital_outlined, 'color': Colors.red, 'route': null},
      {'title': 'Emergency Responders', 'icon': Icons.security_outlined, 'color': Colors.indigo, 'route': null},
      {'title': 'Emergency Contacts', 'icon': Icons.contact_phone_outlined, 'color': Colors.orange, 'route': '/home/emergency-contacts'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Quick Services',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed: () {
                HapticFeedbackService.light();
              }, 
              child: const Text('See All', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: isDeaf ? (SizeConfig.screenWidth > 600 ? 1.2 : 0.9) : (SizeConfig.screenWidth > 600 ? 1.4 : 1.1),
          ),
          itemCount: services.length,
          itemBuilder: (context, index) {
            final service = services[index];
            final color = service['color'] as Color;
            return InkWell(
              onTap: () {
                HapticFeedbackService.medium();
                if (service['route'] != null) {
                  context.push(service['route'] as String);
                } else {
                  _showFeatureComingSoon(context, service['title'] as String);
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
                    Container(
                      padding: EdgeInsets.all(isDeaf ? 20 : 16),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        service['icon'] as IconData, 
                        color: color, 
                        size: isDeaf ? 44 : 32,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        service['title'] as String,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: isDeaf ? 14 : 13,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  void _showFeatureComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature feature coming soon!'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.indigo.shade700,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
