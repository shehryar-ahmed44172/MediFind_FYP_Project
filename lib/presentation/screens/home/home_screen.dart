import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/medical_profile_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../home/widgets/connectivity_banner.dart';
import '../../theme/app_theme.dart';
import 'package:medifind_mobile_application/core/utils/responsive.dart';
import 'package:medifind_mobile_application/presentation/services/haptic_feedback_service.dart';
import '../../providers/accessibility_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final int _currentIndex = 0;

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

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            if (isDeafMode) _buildAccessibilityBanner(context),
            if (!isConnected) const ConnectivityBanner(),
            
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 5.wp, vertical: 2.hp),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildWelcomeHeader(userAsync, theme),
                    _buildMedicalProfileSnapshot(theme),
                    const SizedBox(height: 24),
                    _buildMassiveSOSButton(theme, isDeafMode),
                    const SizedBox(height: 32),
                    _buildSectionHeader(theme, 'Quick Actions'),
                    const SizedBox(height: 16),
                    _buildQuickActionGrid(theme),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccessibilityBanner(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(color: Colors.amber.shade700),
      child: const Row(
        children: [
          Icon(Icons.visibility, color: Colors.white, size: 18),
          SizedBox(width: 8),
          Text('Visual Accessibility Mode Active', 
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildWelcomeHeader(AsyncValue<dynamic> userAsync, ThemeData theme) {
    return userAsync.when(
      data: (user) => Padding(
        padding: EdgeInsets.only(bottom: 3.hp, left: 1.wp),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Hello,', style: TextStyle(color: Colors.grey, fontSize: 1.8.hp)),
            Text(user?.fullName.split(' ')[0] ?? 'User',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 3.2.hp)),
          ],
        ),
      ),
      loading: () => const SizedBox(height: 60),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title) {
    return Text(
      title,
      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
    );
  }

  Widget _buildQuickActionGrid(ThemeData theme) {
    final actions = [
      {'title': 'Medical Records', 'icon': Icons.assignment_rounded, 'color': AppColors.primary, 'route': '/home/medical-reports'},
      {'title': 'My Caregivers', 'icon': Icons.people_alt_rounded, 'color': AppColors.secondary, 'route': '/home/caregivers'},
      {'title': 'Messages', 'icon': Icons.chat_bubble_rounded, 'color': Colors.blue, 'route': '/chats'},
      {'title': 'Emergency Contacts', 'icon': Icons.contact_phone_rounded, 'color': Colors.orange, 'route': '/home/emergency-contacts'},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.3,
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
              _showFeatureComingSoon(context, action['title'] as String);
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
                Icon(action['icon'] as IconData, color: color, size: 32),
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
                        onTap: () => context.go('/home/medical-profile'),
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
        context.go('/home/emergency');
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
          onTap: () => context.go('/home/medical-reports'),
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
                final route = service['route'] as String?;
                if (route != null) {
                  context.go(route);
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
