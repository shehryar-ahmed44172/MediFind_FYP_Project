import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/medical_profile_provider.dart';
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
    final settings = ref.watch(accessibilityProvider);
    final isDeafMode = settings.textOnlyMode;
    final userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
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
                    _buildPremiumCard(theme, userAsync.valueOrNull),
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
    return Padding(
      padding: EdgeInsets.fromLTRB(5.wp, 10, 5.wp, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade800, Colors.blue.shade600],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.accessibility_new_rounded, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Accessibility Active', 
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  Text('Optimized for Deaf communication', 
                    style: TextStyle(color: Colors.white70, fontSize: 11)),
                ],
              ),
            ),
            Icon(Icons.info_outline_rounded, color: Colors.white.withOpacity(0.6), size: 20),
          ],
        ),
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
            Row(
              children: [
                Text(user?.fullName.split(' ')[0] ?? 'User',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 3.2.hp)),
                if (ref.watch(accessibilityProvider).textOnlyMode) ...[
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.accessibility_new_rounded, size: 14, color: Colors.blue.shade700),
                        const SizedBox(width: 4),
                        Text('DEAF MODE', style: TextStyle(color: Colors.blue.shade700, fontSize: 10, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
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
    // push: true = nested sub-screen (back button returns here)
    // push: false/absent = tab switch (context.go)
    final actions = [
      {'title': 'Medical Records', 'icon': Icons.assignment_rounded, 'color': AppColors.primary, 'route': '/home/medical-reports', 'push': false},
      {'title': 'My Caregivers', 'icon': Icons.people_alt_rounded, 'color': AppColors.secondary, 'route': '/home/caregivers', 'push': false},
      {'title': 'Messages', 'icon': Icons.chat_bubble_rounded, 'color': Colors.blue, 'route': '/chats', 'push': false},
      {'title': 'Emergency Contacts', 'icon': Icons.contact_phone_rounded, 'color': Colors.orange, 'route': '/home/emergency-contacts', 'push': true},
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
              final shouldPush = action['push'] == true;
              if (shouldPush) {
                context.push(route);
              } else {
                context.go(route);
              }
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
                        onTap: () => context.push('/home/medical-profile'),
                        child: Row(
                          children: [
                            Text(
                              'View Profile',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 4),
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
        context.push('/home/emergency');
      },
      onTap: () {
        HapticFeedbackService.light();
        context.push('/home/emergency');
      },
      child: Center(
        child: SizedBox(
          width: 75.wp,
          height: 75.wp,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Animated Outer Ripples (Wrapped in RepaintBoundary for performance)
              RepaintBoundary(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    _PulseCircle(delay: 0, size: 75.wp, color: Colors.red.withOpacity(0.1)),
                    _PulseCircle(delay: 1, size: 75.wp, color: Colors.red.withOpacity(0.05)),
                  ],
                ),
              ),
              
              // Main Button Container
              Container(
                width: 62.wp,
                height: 62.wp,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.scaffoldBackgroundColor,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(theme.brightness == Brightness.dark ? 0.4 : 0.1),
                      blurRadius: 30,
                      offset: const Offset(0, 15),
                    ),
                  ],
                ),
                child: Container(
                  margin: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFFF5252), Color(0xFFD32F2F)],
                    ),
                    boxShadow: AppShadows.sosMassiveGlow,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.emergency_rounded,
                        size: 80,
                        color: Colors.white,
                      ),
                      const Text(
                        'SOS',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 26,
                          letterSpacing: 4,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withOpacity(0.3)),
                        ),
                        child: Text(
                          isDeaf ? 'TAP FOR EMERGENCY' : 'PRESS & HOLD',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 10,
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
      {'title': 'My Medical Profile', 'icon': Icons.health_and_safety_outlined, 'color': AppColors.primary, 'route': '/home/medical-profile', 'push': true},
      {'title': 'Medical Records', 'icon': Icons.assignment_outlined, 'color': AppColors.secondary, 'route': '/home/medical-reports', 'push': false},
      {'title': 'Connect Caregivers', 'icon': Icons.people_outline_rounded, 'color': AppColors.accent, 'route': '/home/caregivers', 'push': false},
      {'title': 'Hospitals Nearby', 'icon': Icons.local_hospital_outlined, 'color': Colors.red, 'route': null, 'push': false},
      {'title': 'Emergency Responders', 'icon': Icons.security_outlined, 'color': Colors.indigo, 'route': null, 'push': false},
      {'title': 'Emergency Contacts', 'icon': Icons.contact_phone_outlined, 'color': Colors.orange, 'route': '/home/emergency-contacts', 'push': true},
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
                  final shouldPush = service['push'] == true;
                  if (shouldPush) {
                    context.push(route);
                  } else {
                    context.go(route);
                  }
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

  Widget _buildPremiumCard(ThemeData theme, dynamic user) {
    // Only show for Free users
    if (user?.subscriptionPlan != 'FREE') return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0C637E), Color(0xFF2496A7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0C637E).withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push('/subscription-plans'),
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Unlock MediFind Premium',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Get live tracking & priority dispatch',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded, color: Colors.white.withOpacity(0.7), size: 14),
              ],
            ),
          ),
        ),
      ),
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

class _PulseCircle extends StatefulWidget {
  final double delay;
  final double size;
  final Color color;

  const _PulseCircle({required this.delay, required this.size, required this.color});

  @override
  State<_PulseCircle> createState() => _PulseCircleState();
}

class _PulseCircleState extends State<_PulseCircle> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    Future.delayed(Duration(milliseconds: (widget.delay * 1000).toInt()), () {
      if (mounted) _controller.repeat();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.size * _controller.value,
          height: widget.size * _controller.value,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color.withOpacity(widget.color.opacity * (1 - _controller.value)),
          ),
        );
      },
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
      {'title': 'My Medical Profile', 'icon': Icons.health_and_safety_outlined, 'color': AppColors.primary, 'route': '/home/medical-profile', 'push': true},
      {'title': 'Medical Records', 'icon': Icons.assignment_outlined, 'color': AppColors.secondary, 'route': '/home/medical-reports', 'push': false},
      {'title': 'Connect Caregivers', 'icon': Icons.people_outline_rounded, 'color': AppColors.accent, 'route': '/home/caregivers', 'push': false},
      {'title': 'Hospitals Nearby', 'icon': Icons.local_hospital_outlined, 'color': Colors.red, 'route': null, 'push': false},
      {'title': 'Emergency Responders', 'icon': Icons.security_outlined, 'color': Colors.indigo, 'route': null, 'push': false},
      {'title': 'Emergency Contacts', 'icon': Icons.contact_phone_outlined, 'color': Colors.orange, 'route': '/home/emergency-contacts', 'push': true},
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
                  final shouldPush = service['push'] == true;
                  if (shouldPush) {
                    context.push(route);
                  } else {
                    context.go(route);
                  }
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

  Widget _buildPremiumCard(ThemeData theme, dynamic user) {
    // Only show for Free users
    if (user?.subscriptionPlan != 'FREE') return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0C637E), Color(0xFF2496A7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0C637E).withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push('/subscription-plans'),
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Unlock MediFind Premium',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Get live tracking & priority dispatch',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded, color: Colors.white.withOpacity(0.7), size: 14),
              ],
            ),
          ),
        ),
      ),
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
