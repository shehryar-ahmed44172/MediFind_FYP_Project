import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/auth_provider.dart';
import '../../providers/accessibility_provider.dart';
import '../../theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';

// ─── Role Theme ───────────────────────────────────────────────────────────────
class _RoleTheme {
  final String label;
  final IconData icon;
  final Color colorA;
  final Color colorB;
  const _RoleTheme(this.label, this.icon, this.colorA, this.colorB);
}

const _kRoleThemes = {
  'PATIENT': _RoleTheme(
    'Patient',
    Icons.favorite_rounded,
    Color(0xFF0E9AA7),
    Color(0xFF0A6B75),
  ),
  'RESPONDER': _RoleTheme(
    'Emergency Responder',
    Icons.emergency_rounded,
    Color(0xFF1B3A6B),
    Color(0xFF2563EB),
  ),
  'CAREGIVER': _RoleTheme(
    'Caregiver',
    Icons.supervisor_account_rounded,
    Color(0xFF5B21B6),
    Color(0xFF7C3AED),
  ),
};

const _kResponderTypeLabels = {
  'PARAMEDIC': 'Paramedic',
  'RESCUE_OFFICER': 'Rescue Officer',
  'EMT': 'Emergency Medical Technician',
  'FIRST_RESPONDER': 'First Responder',
  'VOLUNTEER': 'Volunteer',
};

// ─── Screen ───────────────────────────────────────────────────────────────────
class UserProfileScreen extends ConsumerStatefulWidget {
  final String? userId;
  const UserProfileScreen({super.key, this.userId});

  @override
  ConsumerState<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends ConsumerState<UserProfileScreen> {
  bool _isUploading = false;

  String _resolveImageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    final root = AppConstants.socketUrl.endsWith('/')
        ? AppConstants.socketUrl.substring(0, AppConstants.socketUrl.length - 1)
        : AppConstants.socketUrl;
    return '$root${path.startsWith('/') ? path : '/$path'}';
  }

  Future<void> _pickAndUploadImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ImagePickerSheet(),
    );
    if (source == null || !mounted) return;

    final file = await ImagePicker()
        .pickImage(source: source, imageQuality: 70, maxWidth: 1000);
    if (file == null || !mounted) return;

    setState(() => _isUploading = true);
    try {
      await ref.read(uploadProfileImageProvider(File(file.path)).future);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile picture updated!'),
            backgroundColor: Color(0xFF0E9AA7),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out of MediFind?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(logoutProvider.future);
      if (mounted) context.go('/login');
    }
  }

  Future<void> _confirmDeleteAccount(dynamic user) async {
    // Step 1: Warning dialog
    final proceed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 26),
            SizedBox(width: 8),
            Text('Delete Account', style: TextStyle(color: Colors.red)),
          ],
        ),
        content: const Text(
          'This will permanently delete your account and all associated data including:\n\n'
          '• Medical profile & reports\n'
          '• Emergency history\n'
          '• Caregiver links\n'
          '• All personal data\n\n'
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );

    if (proceed != true || !mounted) return;

    // Step 2: Email confirmation
    final emailController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setState) {
          final matches =
              emailController.text.trim() == (user.email ?? '');
          return AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            title: const Text('Confirm Deletion'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                    'Type your email address to confirm permanent deletion:'),
                const SizedBox(height: 12),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    hintText: user.email ?? 'your@email.com',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor:
                      matches ? Colors.red : Colors.red.withOpacity(0.4),
                ),
                onPressed:
                    matches ? () => Navigator.pop(ctx, true) : null,
                child: const Text('Delete My Account'),
              ),
            ],
          );
        },
      ),
    );

    if (confirmed != true || !mounted) return;

    // Step 3: Execute deletion
    try {
      await ref.read(deleteAccountProvider.future);
      if (mounted) context.go('/login');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete account: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = widget.userId != null
        ? ref.watch(userProfileProvider(widget.userId!))
        : ref.watch(currentUserProvider);
    final settings = ref.watch(accessibilityProvider);
    final isOwn = widget.userId == null;

    return Scaffold(
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Error loading profile: $e',
                textAlign: TextAlign.center),
          ),
        ),
        data: (user) {
          if (user == null) {
            return const Center(child: Text('Profile not found.'));
          }
          final rt = _kRoleThemes[user.role] ?? _kRoleThemes['PATIENT']!;

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ── Gradient header ──────────────────────────────────────────
              _ProfileHeader(
                user: user,
                rt: rt,
                isOwnProfile: isOwn,
                isUploading: _isUploading,
                resolveUrl: _resolveImageUrl,
                onCameraTap: _pickAndUploadImage,
              ),

              // ── Body content ─────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Accessibility notice
                      if (settings.textOnlyMode) ...[
                        _AccessibilityBanner(),
                        const SizedBox(height: 16),
                      ],

                      // Role-specific sections
                      if (user.role == 'RESPONDER') ...[
                        _ResponderStatsRow(user: user),
                        const SizedBox(height: 16),
                        _ResponderCredentials(user: user, rt: rt),
                      ] else if (user.role == 'CAREGIVER') ...[
                        _CaregiverSection(user: user, rt: rt),
                      ] else ...[
                        _PatientSection(user: user, rt: rt),
                      ],

                      const SizedBox(height: 20),

                      // Account info — same for all roles
                      _AccountInfoCard(
                        user: user,
                        fontMultiplier: settings.fontSizeMultiplier,
                      ),

                      if (isOwn) ...[
                        const SizedBox(height: 24),
                        _EditProfileButton(rt: rt),
                        const SizedBox(height: 12),
                        _SignOutButton(onTap: _confirmLogout),
                        const SizedBox(height: 8),
                        _DeleteAccountButton(onTap: () => _confirmDeleteAccount(user)),
                        const SizedBox(height: 8),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─── Gradient Header ──────────────────────────────────────────────────────────
class _ProfileHeader extends StatelessWidget {
  final dynamic user;
  final _RoleTheme rt;
  final bool isOwnProfile;
  final bool isUploading;
  final String Function(String?) resolveUrl;
  final VoidCallback onCameraTap;

  const _ProfileHeader({
    required this.user,
    required this.rt,
    required this.isOwnProfile,
    required this.isUploading,
    required this.resolveUrl,
    required this.onCameraTap,
  });

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 268,
      pinned: true,
      backgroundColor: rt.colorA,
      foregroundColor: Colors.white,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.pin,
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Gradient bg
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [rt.colorA, rt.colorB],
                ),
              ),
            ),
            // Decorative circles
            Positioned(
              right: -50, top: -50,
              child: _Circle(200, Colors.white.withOpacity(0.06)),
            ),
            Positioned(
              left: -30, bottom: 10,
              child: _Circle(130, Colors.white.withOpacity(0.05)),
            ),
            Positioned(
              right: 40, bottom: -20,
              child: _Circle(80, Colors.white.withOpacity(0.04)),
            ),
            // Centre content
            SafeArea(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 16),
                  // Avatar
                  Stack(
                    children: [
                      Container(
                        width: 108,
                        height: 108,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.28),
                              blurRadius: 22,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: isUploading
                              ? Container(
                                  color: rt.colorA.withOpacity(0.5),
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.5,
                                    ),
                                  ),
                                )
                              : _Avatar(
                                  imageUrl: resolveUrl(user.profileImageUrl),
                                  name: user.fullName ?? '',
                                  rt: rt,
                                ),
                        ),
                      ),
                      if (isOwnProfile)
                        Positioned(
                          bottom: 2,
                          right: 2,
                          child: GestureDetector(
                            onTap: onCameraTap,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.camera_alt_rounded,
                                size: 15,
                                color: rt.colorA,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Name
                  Text(
                    user.fullName ?? '',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  // Role badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.4), width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(rt.icon, color: Colors.white, size: 14),
                        const SizedBox(width: 7),
                        Text(
                          rt.label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
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
}

class _Circle extends StatelessWidget {
  final double size;
  final Color color;
  const _Circle(this.size, this.color);
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      );
}

class _Avatar extends StatelessWidget {
  final String imageUrl;
  final String name;
  final _RoleTheme rt;
  const _Avatar(
      {required this.imageUrl, required this.name, required this.rt});
  @override
  Widget build(BuildContext context) {
    if (imageUrl.isNotEmpty) {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _initials(name, rt),
      );
    }
    return _initials(name, rt);
  }

  Widget _initials(String n, _RoleTheme rt) => Container(
        color: rt.colorA.withOpacity(0.35),
        child: Center(
          child: Text(
            n.isNotEmpty ? n[0].toUpperCase() : '?',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 46,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
}

// ─── Accessibility Banner ─────────────────────────────────────────────────────
class _AccessibilityBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: Row(
        children: [
          Icon(Icons.visibility_rounded,
              color: Colors.amber.shade800, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Visual Accessibility Active',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.amber.shade900,
                        fontSize: 13)),
                Text('High-contrast & icon-only interface enabled',
                    style: TextStyle(
                        color: Colors.amber.shade700, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Patient Section ──────────────────────────────────────────────────────────
class _PatientSection extends StatelessWidget {
  final dynamic user;
  final _RoleTheme rt;
  const _PatientSection({required this.user, required this.rt});

  @override
  Widget build(BuildContext context) {
    final isDeaf = user.patientType == 'DEAF';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel('Health Status'),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: isDeaf
                    ? Icons.hearing_disabled_rounded
                    : Icons.health_and_safety_rounded,
                label: 'Patient Mode',
                value: isDeaf ? 'Deaf & Mute' : 'Standard',
                color: isDeaf ? Colors.teal : const Color(0xFF10B981),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.sos_rounded,
                label: 'SOS Status',
                value: 'Ready',
                color: const Color(0xFFEF4444),
              ),
            ),
          ],
        ),
        if (isDeaf) ...[
          const SizedBox(height: 12),
          _InfoBanner(
            icon: Icons.sign_language_rounded,
            title: 'Deaf & Mute Mode Active',
            subtitle:
                'Silent SOS  •  Icon-only UI  •  Haptic + Flash alerts',
            color: Colors.teal,
          ),
        ],
        const SizedBox(height: 20),
        _SectionLabel('Quick Access'),
        const SizedBox(height: 10),
        _QuickAccessCard(links: [
          _QLinkData(Icons.medical_information_rounded,
              'Medical Profile', '/medical-profile', Colors.red.shade400),
          _QLinkData(Icons.contacts_rounded, 'Emergency Contacts',
              '/medical-profile', Colors.orange.shade700),
          _QLinkData(Icons.settings_accessibility_rounded, 'Accessibility',
              '/accessibility-settings', Colors.teal.shade600),
        ]),
      ],
    );
  }
}

// ─── Responder Stats Row ──────────────────────────────────────────────────────
class _ResponderStatsRow extends StatelessWidget {
  final dynamic user;
  const _ResponderStatsRow({required this.user});

  @override
  Widget build(BuildContext context) {
    final isVerified = user.verificationStatus == 'VERIFIED';
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.star_rounded,
            label: 'Rating',
            value: '${(user.rating ?? 5.0).toStringAsFixed(1)}',
            valueSuffix: ' ★',
            color: const Color(0xFFF59E0B),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            icon: Icons.check_circle_rounded,
            label: 'Completed',
            value: '${user.totalResponsesHandled ?? 0}',
            color: const Color(0xFF10B981),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            icon: isVerified
                ? Icons.verified_rounded
                : Icons.pending_rounded,
            label: 'Status',
            value: isVerified ? 'Verified' : 'Pending',
            color: isVerified
                ? const Color(0xFF10B981)
                : const Color(0xFFF59E0B),
          ),
        ),
      ],
    );
  }
}

// ─── Responder Credentials ────────────────────────────────────────────────────
class _ResponderCredentials extends StatelessWidget {
  final dynamic user;
  final _RoleTheme rt;
  const _ResponderCredentials({required this.user, required this.rt});

  @override
  Widget build(BuildContext context) {
    final isVerified = user.verificationStatus == 'VERIFIED';
    final responderTypeLabel = _kResponderTypeLabels[user.responderType] ??
        (user.responderType?.toString().replaceAll('_', ' ') ?? '—');
    final vehicleLabel =
        user.vehicleType?.toString().replaceAll('_', ' ') ?? '—';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel('Professional Credentials'),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: AppShadows.neumorphicOut,
          ),
          child: Column(
            children: [
              _CredRow(
                icon: Icons.badge_rounded,
                label: 'License Number',
                value: user.licenseNumber ?? '—',
                color: rt.colorA,
                isFirst: true,
              ),
              _CredRow(
                icon: Icons.business_rounded,
                label: 'Organization',
                value: user.organization ?? '—',
                color: rt.colorA,
              ),
              _CredRow(
                icon: Icons.medical_services_rounded,
                label: 'Responder Type',
                value: responderTypeLabel,
                color: rt.colorA,
              ),
              _CredRow(
                icon: Icons.airport_shuttle_rounded,
                label: 'Vehicle Type',
                value: vehicleLabel,
                color: rt.colorA,
              ),
              _CredRow(
                icon: isVerified
                    ? Icons.verified_rounded
                    : Icons.pending_rounded,
                label: 'Verification',
                value: isVerified ? 'Verified ✓' : 'Pending Review',
                color: isVerified
                    ? const Color(0xFF10B981)
                    : const Color(0xFFF59E0B),
                valueColor: isVerified
                    ? const Color(0xFF10B981)
                    : const Color(0xFFF59E0B),
                isLast: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _SectionLabel('Quick Access'),
        const SizedBox(height: 10),
        _QuickAccessCard(links: [
          _QLinkData(Icons.history_rounded, 'Response History',
              '/settings', rt.colorA),
          _QLinkData(Icons.tune_rounded, 'Responder Settings',
              '/settings', Colors.grey.shade700),
        ]),
      ],
    );
  }
}

// ─── Caregiver Section ────────────────────────────────────────────────────────
class _CaregiverSection extends StatelessWidget {
  final dynamic user;
  final _RoleTheme rt;
  const _CaregiverSection({required this.user, required this.rt});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel('Monitoring Overview'),
        const SizedBox(height: 10),
        _InfoBanner(
          icon: Icons.monitor_heart_rounded,
          title: 'Active Caregiver',
          subtitle:
              'Monitoring linked patients with real-time SOS alerts',
          color: rt.colorA,
        ),
        const SizedBox(height: 20),
        _SectionLabel('Quick Access'),
        const SizedBox(height: 10),
        _QuickAccessCard(links: [
          _QLinkData(Icons.people_rounded, 'My Patients', '/settings',
              rt.colorA),
          _QLinkData(Icons.person_add_rounded, 'Link New Patient',
              '/settings', const Color(0xFF10B981)),
          _QLinkData(Icons.notifications_active_rounded, 'Alert Settings',
              '/settings', Colors.orange.shade700),
          _QLinkData(Icons.tune_rounded, 'Preferences', '/settings',
              Colors.grey.shade700),
        ]),
      ],
    );
  }
}

// ─── Account Info Card ────────────────────────────────────────────────────────
class _AccountInfoCard extends StatelessWidget {
  final dynamic user;
  final double fontMultiplier;
  const _AccountInfoCard(
      {required this.user, required this.fontMultiplier});

  @override
  Widget build(BuildContext context) {
    final m = fontMultiplier;
    final rows = <_InfoRowData>[
      _InfoRowData(Icons.person_outline_rounded, 'Full Name',
          user.fullName ?? '—'),
      _InfoRowData(
          Icons.email_outlined, 'Email Address', user.email ?? '—'),
      _InfoRowData(Icons.phone_outlined, 'Phone Number',
          user.phoneNumber ?? '—'),
      if (user.cnic != null)
        _InfoRowData(Icons.badge_outlined, 'CNIC / ID', user.cnic!),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel('Account Information'),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: AppShadows.neumorphicOut,
          ),
          child: Column(
            children: rows.asMap().entries.map((e) {
              final i = e.key;
              final row = e.value;
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 14),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(row.icon,
                              color: Colors.grey.shade600,
                              size: 18 * m),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                row.label,
                                style: TextStyle(
                                  fontSize: 11 * m,
                                  color: Colors.grey.shade500,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.4,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                row.value,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14.5 * m,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (i < rows.length - 1)
                    Divider(
                        height: 0,
                        indent: 56,
                        color: Colors.grey.shade100),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

// ─── Edit Profile Button ──────────────────────────────────────────────────────
class _EditProfileButton extends StatelessWidget {
  final _RoleTheme rt;
  const _EditProfileButton({required this.rt});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        onPressed: () => context.push('/edit-profile'),
        icon: const Icon(Icons.edit_rounded, size: 19),
        label: const Text('Edit Profile',
            style:
                TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: rt.colorA,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }
}

// ─── Sign Out Button ──────────────────────────────────────────────────────────
class _SignOutButton extends StatelessWidget {
  final VoidCallback onTap;
  const _SignOutButton({required this.onTap});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.logout_rounded,
            size: 19, color: Colors.red),
        label: const Text('Sign Out',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.red)),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Colors.red, width: 1.5),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }
}

// ─── Shared widgets ───────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Text(
          text.toUpperCase(),
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.9,
            color: Colors.grey.shade500,
          ),
        ),
      );
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? valueSuffix;
  final Color color;
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    this.valueSuffix,
    required this.color,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppShadows.neumorphicOut,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          RichText(
            text: TextSpan(
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color,
                  fontSize: 20),
              children: [
                TextSpan(text: value),
                if (valueSuffix != null)
                  TextSpan(
                      text: valueSuffix,
                      style: const TextStyle(fontSize: 15)),
              ],
            ),
          ),
          const SizedBox(height: 3),
          Text(label,
              style: const TextStyle(
                  fontSize: 11,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  const _InfoBanner(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: color,
                        fontSize: 14)),
                const SizedBox(height: 3),
                Text(subtitle,
                    style: TextStyle(
                        color: color.withOpacity(0.8), fontSize: 12.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QLinkData {
  final IconData icon;
  final String label;
  final String route;
  final Color color;
  const _QLinkData(this.icon, this.label, this.route, this.color);
}

class _QuickAccessCard extends StatelessWidget {
  final List<_QLinkData> links;
  const _QuickAccessCard({required this.links});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppShadows.neumorphicOut,
      ),
      child: Column(
        children: links.asMap().entries.map((e) {
          final i = e.key;
          final link = e.value;
          return Column(
            children: [
              InkWell(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(i == 0 ? 20 : 0),
                  topRight: Radius.circular(i == 0 ? 20 : 0),
                  bottomLeft:
                      Radius.circular(i == links.length - 1 ? 20 : 0),
                  bottomRight:
                      Radius.circular(i == links.length - 1 ? 20 : 0),
                ),
                onTap: () => context.push(link.route),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 15),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: link.color.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child:
                            Icon(link.icon, color: link.color, size: 20),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          link.label,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15),
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded,
                          color: Colors.grey.shade400, size: 22),
                    ],
                  ),
                ),
              ),
              if (i < links.length - 1)
                Divider(
                    height: 0,
                    indent: 56,
                    color: Colors.grey.shade100),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _CredRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final Color? valueColor;
  final bool isFirst;
  final bool isLast;
  const _CredRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.valueColor,
    this.isFirst = false,
    this.isLast = false,
  });
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      value,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: valueColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          Divider(height: 0, indent: 56, color: Colors.grey.shade100),
      ],
    );
  }
}

class _InfoRowData {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRowData(this.icon, this.label, this.value);
}

// ─── Image Source Bottom Sheet ────────────────────────────────────────────────
class _ImagePickerSheet extends StatelessWidget {
  const _ImagePickerSheet();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 20),
          const Text('Update Profile Picture',
              style:
                  TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _PickerOption(
                  Icons.photo_library_outlined,
                  'Gallery',
                  ImageSource.gallery),
              _PickerOption(
                  Icons.camera_alt_outlined,
                  'Camera',
                  ImageSource.camera),
            ],
          ),
        ],
      ),
    );
  }
}

class _PickerOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final ImageSource source;
  const _PickerOption(this.icon, this.label, this.source);
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.pop(context, source),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.primary, size: 30),
            ),
            const SizedBox(height: 10),
            Text(label,
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

// ─── Delete Account Button ────────────────────────────────────────────────────
class _DeleteAccountButton extends StatelessWidget {
  final VoidCallback onTap;
  const _DeleteAccountButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: TextButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.delete_forever_rounded,
            color: Colors.red, size: 18),
        label: const Text(
          'Delete My Account',
          style: TextStyle(
            color: Colors.red,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: Colors.red.withOpacity(0.35), width: 1),
          ),
        ),
      ),
    );
  }
}
