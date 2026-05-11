import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/auth_provider.dart';
import '../../providers/accessibility_provider.dart';
import '../../theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../services/location/responder_location_tracker.dart';
import '../../../config/router.dart';

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
  bool _isDeleting = false;

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

    if (ok != true || !mounted) return;

    try {
      // 1. Clear tokens from Hive + API client + socket.
      final authRepo = await ref.read(authRepositoryProvider.future);
      await authRepo.logout();

      // 2. ── CRITICAL: set authState to data(false) SYNCHRONOUSLY ────────────
      //    Riverpod's ref.invalidate() is deferred — the new notifier's async
      //    _initializeAuth() may not complete before the router's redirect fires.
      //    forceLoggedOut() sets the state immediately so that EVERY subsequent
      //    redirect evaluation (including ones triggered by GoRouterRefreshStream)
      //    sees data(false) and never sends the user back to /splash or /home.
      ref.read(authStateProvider.notifier).forceLoggedOut();

      // 3. Invalidate derived providers so they re-read from cleared storage.
      ref.invalidate(currentUserIdProvider);
      ref.invalidate(currentUserRoleProvider);
      ref.invalidate(currentUserProvider);
      ref.invalidate(responderLocationTrackerProvider);

      if (!mounted) return;

      // 4. Belt-and-suspenders: skip one redirect evaluation in case the router
      //    fires before the data(false) state propagates to its listener.
      AppRouter.skipNextRedirect();
      context.go('/login');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sign out failed: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _confirmDeleteAccount(dynamic user) async {
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

    final emailController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setState) {
          final matches = emailController.text.trim() == (user.email ?? '');
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
                onPressed: matches ? () => Navigator.pop(ctx, true) : null,
                child: const Text('Delete My Account'),
              ),
            ],
          );
        },
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isDeleting = true);

    try {
      // Get the repo directly — avoids FutureProvider mid-flight abandonment issues
      final authRepo = await ref.read(authRepositoryProvider.future);

      // Make the DELETE /api/users/me request and clear local session data
      await authRepo.deleteAccount();

      // Synchronously mark the session as ended — same reasoning as logout.
      ref.read(authStateProvider.notifier).forceLoggedOut();

      // Invalidate derived providers so they re-read from cleared storage.
      ref.invalidate(currentUserIdProvider);
      ref.invalidate(currentUserRoleProvider);
      ref.invalidate(currentUserProvider);
      ref.invalidate(responderLocationTrackerProvider);

      if (!mounted) return;

      // ── Bypass GoRouter's redirect for this navigation ─────────────────
      // Without this, the redirect reads authStateProvider which may still
      // hold data(true) (stale) and intercepts context.go('/login') by
      // returning '/splash', which causes the black-screen bug.
      // skipNextRedirect() makes the next redirect evaluation return null
      // unconditionally (one-shot flag, clears itself immediately).
      AppRouter.skipNextRedirect();
      context.go('/login');
    } catch (e) {
      // Always reset the overlay, even if the widget is still mounted.
      // Without this guard the dark overlay would stick forever.
      if (mounted) {
        setState(() => _isDeleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete account: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
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

    return Stack(
      children: [
        Scaffold(
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

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Gradient identity card ──────────────────────────────
                _ProfileCard(
                  user: user,
                  rt: rt,
                  isOwnProfile: isOwn,
                  isUploading: _isUploading,
                  resolveUrl: _resolveImageUrl,
                  onCameraTap: _pickAndUploadImage,
                ),

                // ── Body content ────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                        _DeleteAccountButton(
                            onTap: _isDeleting ? null : () => _confirmDeleteAccount(user)),
                        const SizedBox(height: 8),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ),
        // ── Full-screen deletion overlay ───────────────────────────────────
        if (_isDeleting)
          Container(
            color: Colors.black.withOpacity(0.55),
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 20),
                  Text(
                    'Deleting account…',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ─── Profile Identity Card ────────────────────────────────────────────────────
// A contained gradient card — no full-screen banner, no conflict with AppHeader.
class _ProfileCard extends StatelessWidget {
  final dynamic user;
  final _RoleTheme rt;
  final bool isOwnProfile;
  final bool isUploading;
  final String Function(String?) resolveUrl;
  final VoidCallback onCameraTap;

  const _ProfileCard({
    required this.user,
    required this.rt,
    required this.isOwnProfile,
    required this.isUploading,
    required this.resolveUrl,
    required this.onCameraTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [rt.colorA, rt.colorB],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: rt.colorA.withOpacity(0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          // ── Avatar ────────────────────────────────────────────────
          Stack(
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: Colors.white.withOpacity(0.85), width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
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
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: onCameraTap,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Icon(Icons.camera_alt_rounded,
                          size: 13, color: rt.colorA),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),

          // ── Name + role ────────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.fullName ?? '',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.1,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
                const SizedBox(height: 10),
                // Role badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                    border:
                        Border.all(color: Colors.white.withOpacity(0.35)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(rt.icon, color: Colors.white, size: 12),
                      const SizedBox(width: 5),
                      Text(
                        rt.label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
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
    );
  }
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
        errorBuilder: (_, __, ___) => _initials(),
      );
    }
    return _initials();
  }

  Widget _initials() => Container(
        color: rt.colorA.withOpacity(0.35),
        child: Center(
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 38,
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
              child: _StatusBadge(
                icon: isDeaf
                    ? Icons.hearing_disabled_rounded
                    : Icons.hearing_rounded,
                label: isDeaf ? 'Deaf & Mute' : 'Standard Mode',
                color: isDeaf ? Colors.teal : const Color(0xFF10B981),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatusBadge(
                icon: Icons.sos_rounded,
                label: 'SOS Ready',
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
          _QLinkData(
            Icons.medical_information_rounded,
            'Medical Profile',
            'View your full health record',
            '/home/medical-profile',
            Colors.red.shade400,
          ),
          _QLinkData(
            Icons.contacts_rounded,
            'Emergency Contacts',
            'Manage people to contact in emergencies',
            '/home/emergency-contacts',
            Colors.orange.shade700,
          ),
          _QLinkData(
            Icons.settings_accessibility_rounded,
            'Accessibility',
            'Font size, contrast & interface mode',
            '/home/accessibility-settings',
            Colors.teal.shade600,
          ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel('Performance'),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _MiniStatCard(
                icon: Icons.star_rounded,
                label: 'Rating',
                value: (user.rating ?? 5.0).toStringAsFixed(1),
                color: const Color(0xFFF59E0B),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MiniStatCard(
                icon: Icons.check_circle_rounded,
                label: 'Completed',
                value: '${user.totalResponsesHandled ?? 0}',
                color: const Color(0xFF10B981),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MiniStatCard(
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
        const SizedBox(height: 16),
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
              'View past emergency responses', '/settings', rt.colorA),
          _QLinkData(Icons.tune_rounded, 'Responder Settings',
              'Availability and notifications', '/settings',
              Colors.grey.shade700),
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
          _QLinkData(Icons.people_rounded, 'My Patients',
              'View all linked patients', '/settings', rt.colorA),
          _QLinkData(Icons.person_add_rounded, 'Link New Patient',
              'Connect to a new patient account', '/settings',
              const Color(0xFF10B981)),
          _QLinkData(Icons.notifications_active_rounded, 'Alert Settings',
              'Configure SOS notifications', '/settings',
              Colors.orange.shade700),
          _QLinkData(Icons.tune_rounded, 'Preferences',
              'Interface and monitoring settings', '/settings',
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
                              color: Colors.grey.shade500,
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
                                  letterSpacing: 0.3,
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
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
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
        icon: const Icon(Icons.logout_rounded, size: 19, color: Colors.red),
        label: const Text('Sign Out',
            style: TextStyle(
                fontSize: 15,
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

// ─── Delete Account Button ────────────────────────────────────────────────────
class _DeleteAccountButton extends StatelessWidget {
  final VoidCallback? onTap;
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
            side: BorderSide(color: Colors.red.withOpacity(0.3), width: 1),
          ),
        ),
      ),
    );
  }
}

// ─── Shared Widgets ───────────────────────────────────────────────────────────

/// Section label with a coloured left accent bar.
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}

/// Compact horizontal status badge used for patient health status.
class _StatusBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _StatusBadge(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.22)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Mini stat card for responders.
class _MiniStatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _MiniStatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppShadows.neumorphicOut,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10.5,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
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
        border: Border.all(color: color.withOpacity(0.22)),
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
  final String subtitle;
  final String route;
  final Color color;
  const _QLinkData(
      this.icon, this.label, this.subtitle, this.route, this.color);
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: Colors.transparent,
          child: Column(
            children: links.asMap().entries.map((e) {
              final i = e.key;
              final link = e.value;
              return Column(
                children: [
                  InkWell(
                    onTap: () => context.push(link.route),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 13),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              color: link.color.withOpacity(0.10),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(link.icon,
                                color: link.color, size: 20),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  link.label,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  link.subtitle,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
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
        ),
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
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
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
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      value,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14.5,
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
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _PickerOption(
                  Icons.photo_library_outlined, 'Gallery', ImageSource.gallery),
              _PickerOption(
                  Icons.camera_alt_outlined, 'Camera', ImageSource.camera),
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
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
