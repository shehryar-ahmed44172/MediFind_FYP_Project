import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
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
    final isDark = theme.brightness == Brightness.dark;
    final settings = ref.watch(accessibilityProvider);
    final isDeafMode = settings.textOnlyMode;
    final userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.symmetric(horizontal: 6.wp, vertical: 2.hp),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildProfessionalHeader(userAsync, theme, isDark),
                        const SizedBox(height: 24),
                        _buildDigitalMedicalID(theme, isDark),
                        const SizedBox(height: 40),
                        _buildAdvancedSOSCenter(theme, isDeafMode, isDark),
                        const SizedBox(height: 48),
                        _buildGlassServiceGrid(theme, isDark),
                        const SizedBox(height: 32),
                        _buildPremiumUpgradeCard(theme, userAsync.valueOrNull),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfessionalHeader(AsyncValue<dynamic> userAsync, ThemeData theme, bool isDark) {
    final textColor = isDark ? Colors.white : theme.colorScheme.onSurface;
    return userAsync.when(
      data: (user) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('MediFind Hub',
                style: TextStyle(
                  color: AppColors.primaryLight.withOpacity(0.85),
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                user?.fullName.split(' ')[0] ?? 'User',
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 32,
                  letterSpacing: -1,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.success.withOpacity(0.5),
                width: 1.5,
              ),
            ),
            child: CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.primary.withOpacity(0.12),
              child: Text(
                user?.fullName.substring(0, 1) ?? 'U',
                style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
      loading: () => const SizedBox(height: 60),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildDigitalMedicalID(ThemeData theme, bool isDark) {
    final userIdAsync = ref.watch(currentUserIdProvider);
    final glassColor1 = isDark ? Colors.white.withOpacity(0.1)  : theme.colorScheme.primary.withOpacity(0.07);
    final glassColor2 = isDark ? Colors.white.withOpacity(0.03) : theme.colorScheme.primary.withOpacity(0.02);
    final borderColor = isDark ? Colors.white.withOpacity(0.1)  : theme.colorScheme.outline.withOpacity(0.2);
    final labelColor  = isDark ? Colors.white70                  : theme.colorScheme.onSurface.withOpacity(0.6);
    final iconColor   = isDark ? Colors.white.withOpacity(0.3)   : theme.colorScheme.onSurface.withOpacity(0.3);

    return userIdAsync.when(
      data: (userId) {
        if (userId == null) return const SizedBox.shrink();
        final profileAsync = ref.watch(getMedicalProfileProvider(userId));

        return profileAsync.when(
          data: (profile) {
            return GestureDetector(
              onTap: () => _showMedicalIDOptions(profile, theme, isDark),
              child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [glassColor1, glassColor2],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: borderColor, width: 1),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withOpacity(0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.health_and_safety_rounded, color: Colors.redAccent, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'DIGITAL MEDICAL ID',
                              style: TextStyle(color: labelColor, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1.5),
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.qr_code_2_rounded, color: iconColor, size: 20),
                              const SizedBox(width: 4),
                              Text('TAP', style: TextStyle(color: iconColor, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1)),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildIDStat('BLOOD', profile?.bloodType ?? '--', Colors.redAccent, labelColor),
                          _buildIDStat('ALLERGIES', (profile?.allergies.isNotEmpty == true) ? 'ACTIVE' : 'NONE', Colors.orangeAccent, labelColor),
                          _buildIDStat('STATUS', 'VERIFIED', Colors.greenAccent, labelColor),
                        ],
                      ),
                    ],
                  ),
                ),
            ); // GestureDetector
          },
          loading: () => const SizedBox(height: 100),
          error: (e, _) => const SizedBox.shrink(),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  /// Shows an action sheet letting the patient choose between editing their
  /// medical profile or displaying the emergency QR code.
  void _showMedicalIDOptions(dynamic profile, ThemeData theme, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // drag handle
            Container(
              width: 36, height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.2) : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              'Medical ID',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              'What would you like to do?',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 20),
            // Edit Medical Profile
            _OptionTile(
              icon: Icons.edit_note_rounded,
              color: AppColors.primary,
              title: 'Edit Medical Profile',
              subtitle: 'Update blood type, allergies, conditions and more',
              onTap: () {
                Navigator.pop(context);
                context.push('/home/medical-profile');
              },
            ),
            const SizedBox(height: 12),
            // Show Emergency QR
            _OptionTile(
              icon: Icons.qr_code_2_rounded,
              color: Colors.deepPurple,
              title: 'Show Emergency QR',
              subtitle: 'Display your medical ID for first responders to scan',
              onTap: () {
                Navigator.pop(context);
                _showMedicalQRSheet(profile, theme, isDark);
              },
            ),
            const SizedBox(height: 16),
            // Privacy note
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.07),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.lock_outline_rounded, size: 14, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your QR is private. Only you can generate it. '
                      'Responders access your data only during an active emergency — all accesses are logged.',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.primary.withOpacity(0.75),
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Shows a QR code bottom-sheet so first responders (or bystanders) can
  /// scan the patient's critical medical info without needing the app.
  void _showMedicalQRSheet(dynamic profile, ThemeData theme, bool isDark) {
    final user = ref.read(currentUserProvider).valueOrNull;
    final name  = user?.fullName ?? 'Unknown';
    final blood = profile?.bloodType ?? 'Unknown';
    final allergies = (profile?.allergies as List?)?.isNotEmpty == true
        ? (profile!.allergies as List).join(', ')
        : 'None';
    final conditions = (profile?.chronicDiseases as List?)?.isNotEmpty == true
        ? (profile!.chronicDiseases as List).join(', ')
        : 'None';
    final isDeaf = profile?.patientType?.toString().toUpperCase() == 'DEAF';

    final qrData = 'MEDIFIND MEDICAL ID\n'
        'Name: $name\n'
        'Blood Type: $blood\n'
        'Allergies: $allergies\n'
        'Conditions: $conditions\n'
        'DEAF/MUTE: ${isDeaf ? "YES" : "NO"}';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // drag handle
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.2) : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Icon(Icons.qr_code_2_rounded, color: AppColors.primary, size: 26),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Emergency Medical ID',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                      Text('Tap to show — anyone can scan',
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withOpacity(0.5))),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // QR Code
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: AppShadows.cardShadow,
              ),
              child: QrImageView(
                data: qrData,
                version: QrVersions.auto,
                size: 210,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            // DEAF badge
            if (isDeaf)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange.withOpacity(0.35)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.hearing_disabled, color: Colors.orange, size: 16),
                    SizedBox(width: 8),
                    Text('DEAF / MUTE status included in QR',
                        style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ),
              ),
            if (!isDeaf) const SizedBox(height: 4),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildIDStat(String label, String value, Color color, Color labelColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: labelColor, fontWeight: FontWeight.w900, fontSize: 9, letterSpacing: 1)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 18),
        ),
      ],
    );
  }

  Widget _buildAdvancedSOSCenter(ThemeData theme, bool isDeaf, bool isDark) {
    final subtitleColor = isDark
        ? Colors.white.withOpacity(0.4)
        : theme.colorScheme.onSurface.withOpacity(0.5);

    return Column(
      children: [
        GestureDetector(
          onTap: () => context.push('/home/emergency'),
          child: SizedBox(
            width: 220,
            height: 220,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Pulse glow layers — fixed container prevents layout shift
                _buildSOSGlow(0, 180, Colors.redAccent.withOpacity(0.12)),
                _buildSOSGlow(0.5, 220, Colors.redAccent.withOpacity(0.06)),

                Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(
                      colors: [Color(0xFFFF5252), Color(0xFF991B1B)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.45),
                        blurRadius: 40,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.emergency_rounded, size: 54, color: Colors.white),
                      SizedBox(height: 4),
                      Text('SOS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 28, letterSpacing: 2)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          isDeaf ? 'TAP TO TRIGGER EMERGENCY' : 'PRESS AND HOLD FOR HELP',
          style: TextStyle(
            color: subtitleColor,
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildSOSGlow(double delay, double size, Color color) {
    return _PulseCircle(delay: delay, size: size, color: color);
  }

  Widget _buildGlassServiceGrid(ThemeData theme, bool isDark) {
    final services = [
      {'title': 'Medical Records', 'icon': Icons.folder_copy_rounded, 'color': Colors.blueAccent,   'route': '/home/medical-reports'},
      {'title': 'Caregivers',      'icon': Icons.people_alt_rounded,  'color': Colors.orangeAccent, 'route': '/home/caregivers'},
      {'title': 'Messages',        'icon': Icons.chat_bubble_rounded,  'color': Colors.purpleAccent, 'route': '/chats'},
      {'title': 'Responders',      'icon': Icons.security_rounded,     'color': Colors.greenAccent,  'route': null},
    ];

    final tileBg     = isDark ? Colors.white.withOpacity(0.05) : theme.colorScheme.surfaceContainer;
    final tileBorder = isDark ? Colors.white.withOpacity(0.08) : theme.colorScheme.outline.withOpacity(0.15);
    final textColor  = isDark ? Colors.white                    : theme.colorScheme.onSurface;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.4,
      ),
      itemCount: services.length,
      itemBuilder: (context, index) {
        final service = services[index];
        final color = service['color'] as Color;
        return Container(
          decoration: BoxDecoration(
            color: tileBg,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: tileBorder),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(24),
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () {
                if (service['route'] != null) {
                  context.go(service['route'] as String);
                } else {
                  _showFeatureComingSoon(context, service['title'] as String);
                }
              },
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(service['icon'] as IconData, color: color, size: 28),
                  const SizedBox(height: 10),
                  Text(
                    service['title'] as String,
                    style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPremiumUpgradeCard(ThemeData theme, dynamic user) {
    if (user?.subscriptionPlan != 'FREE') return const SizedBox.shrink();
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => context.push('/subscription-plans'),
        child: Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              colors: AppColors.medifindGradient,
            ),
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(23),
            ),
            child: Row(
              children: [
                Icon(Icons.auto_awesome_rounded, color: theme.colorScheme.primary),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Upgrade to Premium',
                    style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold),
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded, color: theme.colorScheme.onSurface.withOpacity(0.3), size: 14),
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

// ── Option tile used inside the Medical ID action sheet ──────────────────────
class _OptionTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _OptionTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: color.withOpacity(0.07),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800, color: color)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.55))),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, size: 13, color: color.withOpacity(0.6)),
            ],
          ),
        ),
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
