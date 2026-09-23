import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/auth_provider.dart';
import '../../providers/accessibility_provider.dart';
import '../../widgets/design_system/design_system.dart';
import '../../../domain/entities/user.dart';
import '../../../services/location/responder_location_tracker.dart';
import '../../../config/router.dart';
import '../../widgets/responder/responder_rating.dart';

const _kResponderTypeLabels = {
  'PARAMEDIC': 'Paramedic',
  'RESCUE_OFFICER': 'Rescue Officer',
  'EMT': 'Emergency Medical Technician',
  'FIRST_RESPONDER': 'First Responder',
  'VOLUNTEER': 'Volunteer',
};

String _roleLabel(String role) {
  switch (role) {
    case 'RESPONDER':
      return 'Emergency responder';
    case 'CAREGIVER':
      return 'Caregiver';
    default:
      return 'Patient';
  }
}

IconData _roleIcon(String role) {
  switch (role) {
    case 'RESPONDER':
      return Icons.emergency_outlined;
    case 'CAREGIVER':
      return Icons.supervisor_account_outlined;
    default:
      return Icons.favorite_outline_rounded;
  }
}

String _planLabel(String? plan) {
  switch (plan) {
    case 'EXECUTIVE':
      return 'Executive plan';
    case 'PROFESSIONAL':
      return 'Professional plan';
    default:
      return 'Standard plan';
  }
}

bool _isDeafUser(User user) => user.patientType?.toUpperCase() == 'DEAF';

// ─── Screen ───────────────────────────────────────────────────────────────────
/// Own profile (tab root for every role, no header) or a patient's profile
/// viewed by a caregiver (pushed, [userId] set).
class UserProfileScreen extends ConsumerStatefulWidget {
  final String? userId;
  const UserProfileScreen({super.key, this.userId});

  @override
  ConsumerState<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends ConsumerState<UserProfileScreen> {
  bool _isUploading = false;
  bool _isDeleting = false;

  Future<void> _pickAndUploadImage() async {
    final source = await showMfBottomSheet<ImageSource>(
      context,
      title: 'Change profile photo',
      builder: (ctx) => MfListGroup(
        children: [
          MfIconTile(
            icon: Icons.photo_library_outlined,
            label: 'Choose from gallery',
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
          MfIconTile(
            icon: Icons.photo_camera_outlined,
            label: 'Take a photo',
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
        ],
      ),
    );
    if (source == null || !mounted) return;

    final file = await ImagePicker()
        .pickImage(source: source, imageQuality: 70, maxWidth: 1000);
    if (file == null || !mounted) return;

    setState(() => _isUploading = true);
    try {
      await ref.read(uploadProfileImageProvider(File(file.path)).future);
      if (mounted) {
        showMfSnackBar(context, 'Profile photo updated', tone: MfTone.success);
      }
    } catch (e) {
      if (mounted) {
        showMfSnackBar(context, 'Upload failed: $e', tone: MfTone.danger);
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _confirmLogout() async {
    final ok = await showMfConfirmDialog(
      context,
      title: 'Sign out',
      message: 'Are you sure you want to sign out of MediFind?',
      confirmLabel: 'Sign out',
      destructive: true,
      icon: Icons.logout_rounded,
    );

    if (!ok || !mounted) return;

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
        showMfSnackBar(context, 'Sign out failed: $e', tone: MfTone.danger);
      }
    }
  }

  Future<void> _confirmDeleteAccount(User user) async {
    final proceed = await showMfConfirmDialog(
      context,
      title: 'Delete account',
      icon: Icons.warning_amber_rounded,
      destructive: true,
      confirmLabel: 'Continue',
      content: Builder(builder: (ctx) {
        final text = Theme.of(ctx).textTheme;
        const items = [
          'Medical profile and reports',
          'Emergency history',
          'Caregiver links',
          'All personal data',
        ];
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This will permanently delete your account and all associated data, including:',
              style: text.bodyMedium,
            ),
            const SizedBox(height: MfSpace.sm),
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: MfSpace.xxs),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.remove_rounded, size: 18, color: Theme.of(ctx).colorScheme.onSurfaceVariant),
                    const SizedBox(width: MfSpace.xs),
                    Expanded(child: Text(item, style: text.bodyMedium)),
                  ],
                ),
              ),
            const SizedBox(height: MfSpace.sm),
            Text(
              'This action cannot be undone.',
              style: text.bodyMedium?.copyWith(
                color: Theme.of(ctx).colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );
      }),
    );

    if (!proceed || !mounted) return;

    final emailController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final cs = Theme.of(ctx).colorScheme;
          final matches = emailController.text.trim() == user.email;
          return AlertDialog(
            icon: Icon(Icons.delete_forever_outlined, color: cs.error, size: 28),
            title: const Text('Confirm deletion'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Type your email address to confirm permanent deletion.'),
                const SizedBox(height: MfSpace.sm),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: 'Email address',
                    hintText: user.email.isEmpty ? 'your@email.com' : user.email,
                  ),
                  onChanged: (_) => setDialogState(() {}),
                ),
              ],
            ),
            actionsPadding: const EdgeInsets.fromLTRB(MfSpace.md, 0, MfSpace.md, MfSpace.md),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: cs.error,
                  foregroundColor: cs.onError,
                ),
                onPressed: matches ? () => Navigator.pop(ctx, true) : null,
                child: const Text('Delete my account'),
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

      // ── Clear overlay BEFORE navigating ───────────────────────────────
      // The overlay would otherwise persist during the page transition and
      // produce a dark flash.
      setState(() => _isDeleting = false);

      // ── Bypass GoRouter's redirect for this navigation ─────────────────
      AppRouter.skipNextRedirect();
      context.go('/login');
    } catch (e) {
      // Always reset the overlay so it never sticks.
      if (mounted) {
        setState(() => _isDeleting = false);
        showMfSnackBar(context, 'Failed to delete account: $e', tone: MfTone.danger);
      }
    }
  }

  void _retry() {
    if (widget.userId != null) {
      ref.invalidate(userProfileProvider(widget.userId!));
    } else {
      ref.invalidate(currentUserProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = widget.userId != null
        ? ref.watch(userProfileProvider(widget.userId!))
        : ref.watch(currentUserProvider);
    final settings = ref.watch(accessibilityProvider);
    final isOwn = widget.userId == null;

    final body = userAsync.when(
      loading: () => const MfLoading(label: 'Loading profile'),
      error: (e, _) => MfErrorState(
        title: 'Could not load profile',
        message: '$e',
        onRetry: _retry,
      ),
      data: (user) {
        if (user == null) {
          return MfEmptyState(
            icon: Icons.person_off_outlined,
            title: 'Profile not found',
            message: 'This profile is not available right now.',
            actionLabel: 'Try again',
            actionIcon: Icons.refresh_rounded,
            onAction: _retry,
          );
        }
        return isOwn
            ? _buildOwnProfile(context, user, settings.textOnlyMode)
            : _buildViewedProfile(context, user);
      },
    );

    final page = isOwn
        ? Scaffold(body: body)
        : MfScaffold(
            title: 'Patient Profile',
            fallbackRoute: '/caregiver/my-patients',
            body: body,
          );

    return Stack(
      children: [
        page,
        // ── Full-screen deletion overlay ───────────────────────────────────
        if (_isDeleting)
          Positioned.fill(
            child: Semantics(
              liveRegion: true,
              label: 'Deleting account',
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.55),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: Colors.white),
                      const SizedBox(height: MfSpace.md),
                      Material(
                        type: MaterialType.transparency,
                        child: Text(
                          'Deleting account…',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ── Own profile (account hub) ───────────────────────────────────────────────
  Widget _buildOwnProfile(BuildContext context, User user, bool textOnlyMode) {
    final isPatient = user.role != 'RESPONDER' && user.role != 'CAREGIVER';
    final isDeaf = _isDeafUser(user);

    return ListView(
      padding: const EdgeInsets.fromLTRB(MfSpace.gutter, MfSpace.md, MfSpace.gutter, MfSpace.xl),
      children: [
        _IdentityCard(
          user: user,
          isOwnProfile: true,
          isUploading: _isUploading,
          onChangePhoto: _pickAndUploadImage,
        ),

        if (isPatient && (isDeaf || textOnlyMode)) ...[
          const SizedBox(height: MfSpace.md),
          MfInfoBanner(
            icon: Icons.hearing_disabled_rounded,
            title: 'Deaf mode ON',
            message: 'Silent SOS, text-first chat, flashing screen and vibration alerts. '
                'Tap to review accessibility settings.',
            tone: MfTone.primary,
            onTap: () => context.push('/accessibility-settings'),
          ),
        ] else if (textOnlyMode) ...[
          const SizedBox(height: MfSpace.md),
          MfInfoBanner(
            icon: Icons.visibility_outlined,
            title: 'Text-only mode ON',
            message: 'Visual alerts and text-first interface are enabled. Tap to review.',
            tone: MfTone.primary,
            onTap: () => context.push('/accessibility-settings'),
          ),
        ],

        if (user.role == 'RESPONDER')
          ..._responderSections(context, user)
        else if (user.role == 'CAREGIVER')
          ..._caregiverSections(context, user)
        else
          ..._patientSections(context, user),

        const SizedBox(height: MfSpace.lg),
        _AccountInfoSection(user: user),

        const SizedBox(height: MfSpace.lg),
        MfSecondaryButton(
          label: 'Sign out',
          icon: Icons.logout_rounded,
          tone: MfTone.danger,
          large: true,
          onPressed: _confirmLogout,
        ),
        const SizedBox(height: MfSpace.xs),
        Center(
          child: MfTextButton(
            label: 'Delete account',
            icon: Icons.delete_forever_outlined,
            tone: MfTone.danger,
            onPressed: _isDeleting ? null : () => _confirmDeleteAccount(user),
          ),
        ),
      ],
    );
  }

  List<Widget> _patientSections(BuildContext context, User user) {
    final plan = _planLabel(user.subscriptionPlan);
    return [
      const SizedBox(height: MfSpace.lg),
      const MfSectionTitle('Health & safety'),
      MfListGroup(children: [
        MfIconTile(
          icon: Icons.medical_information_outlined,
          label: 'Medical ID',
          subtitle: 'Your health record, blood type and allergies',
          onTap: () => context.go('/medical-id'),
        ),
        MfIconTile(
          icon: Icons.contacts_outlined,
          label: 'Emergency contacts',
          subtitle: 'People to contact in an emergency',
          onTap: () => context.push('/home/emergency-contacts'),
        ),
        MfIconTile(
          icon: Icons.people_outline_rounded,
          label: 'My caregivers',
          subtitle: 'Invite and manage caregivers',
          onTap: () => context.push('/home/caregivers'),
        ),
        MfIconTile(
          icon: Icons.content_paste_rounded,
          label: 'Medical reports',
          subtitle: 'Upload and view report images',
          onTap: () => context.push('/home/medical-reports'),
        ),
      ]),
      const SizedBox(height: MfSpace.lg),
      const MfSectionTitle('Communication & accessibility'),
      MfListGroup(children: [
        MfIconTile(
          icon: Icons.settings_accessibility_rounded,
          label: 'Accessibility settings',
          subtitle: 'Text size, contrast and interface mode',
          onTap: () => context.push('/accessibility-settings'),
        ),
        if (_isDeafUser(user))
          MfIconTile(
            icon: Icons.quickreply_outlined,
            label: 'Quick messages',
            subtitle: 'Pre-written phrases for silent communication',
            onTap: () => context.push('/predefined-messages'),
          ),
        MfIconTile(
          icon: Icons.hearing_disabled_outlined,
          label: 'About deaf & hearing modes',
          subtitle: 'How MediFind adapts to you',
          onTap: () => context.push('/home/patient-type-info'),
        ),
      ]),
      const SizedBox(height: MfSpace.lg),
      const MfSectionTitle('Account'),
      MfListGroup(children: [
        _editProfileTile(context),
        _subscriptionTile(context, plan),
        _settingsTile(context),
      ]),
    ];
  }

  List<Widget> _caregiverSections(BuildContext context, User user) {
    return [
      const SizedBox(height: MfSpace.lg),
      const MfSectionTitle(
        'Patients',
        subtitle: 'Monitoring linked patients with real-time SOS alerts',
      ),
      MfListGroup(children: [
        MfIconTile(
          icon: Icons.people_outline_rounded,
          label: 'My patients',
          subtitle: 'View and manage all linked patients',
          onTap: () => context.push('/caregiver/my-patients'),
        ),
        MfIconTile(
          icon: Icons.person_add_alt_outlined,
          label: 'Link new patient',
          subtitle: 'Connect to a new patient account',
          onTap: () => context.push('/caregiver/my-patients/link-patient'),
        ),
        MfIconTile(
          icon: Icons.map_outlined,
          label: 'Live map',
          subtitle: 'See patients on the live location map',
          onTap: () => context.go('/caregiver/maps'),
        ),
        MfIconTile(
          icon: Icons.history_rounded,
          label: 'Emergency history',
          subtitle: 'Past emergencies and reports',
          onTap: () => context.push('/caregiver/history'),
        ),
        MfIconTile(
          icon: Icons.chat_bubble_outline_rounded,
          label: 'Messages',
          subtitle: 'Conversations with patients and responders',
          onTap: () => context.go('/caregiver/chats'),
        ),
      ]),
      const SizedBox(height: MfSpace.lg),
      const MfSectionTitle('Account'),
      MfListGroup(children: [
        _editProfileTile(context),
        _subscriptionTile(context, _planLabel(user.subscriptionPlan)),
        _accessibilityTile(context),
        _settingsTile(context),
      ]),
    ];
  }

  List<Widget> _responderSections(BuildContext context, User user) {
    return [
      const SizedBox(height: MfSpace.lg),
      const MfSectionTitle('Performance'),
      _ResponderStatsRow(user: user),
      const SizedBox(height: MfSpace.lg),
      const MfSectionTitle('Professional credentials'),
      _ResponderCredentials(user: user),
      const SizedBox(height: MfSpace.lg),
      const MfSectionTitle('Work'),
      MfListGroup(children: [
        MfIconTile(
          icon: Icons.history_rounded,
          label: 'Response history',
          subtitle: 'View past emergency responses',
          onTap: () => context.go('/responder/history'),
        ),
        MfIconTile(
          icon: Icons.tune_rounded,
          label: 'Responder settings',
          subtitle: 'Availability and notifications',
          tone: MfTone.neutral,
          onTap: () => context.push('/settings'),
        ),
      ]),
      const SizedBox(height: MfSpace.lg),
      const MfSectionTitle('Account'),
      MfListGroup(children: [
        _editProfileTile(context),
        _accessibilityTile(context),
        _subscriptionTile(context, _planLabel(user.subscriptionPlan)),
      ]),
    ];
  }

  Widget _editProfileTile(BuildContext context) => MfIconTile(
        icon: Icons.edit_outlined,
        label: 'Edit profile',
        subtitle: 'Name, phone and personal details',
        onTap: () => context.push('/edit-profile'),
      );

  Widget _subscriptionTile(BuildContext context, String plan) => MfIconTile(
        icon: Icons.card_membership_outlined,
        label: 'Subscription',
        subtitle: 'Current: $plan',
        onTap: () => context.push('/subscription-plans'),
      );

  Widget _accessibilityTile(BuildContext context) => MfIconTile(
        icon: Icons.settings_accessibility_rounded,
        label: 'Accessibility',
        subtitle: 'Text size, contrast and interface mode',
        onTap: () => context.push('/accessibility-settings'),
      );

  Widget _settingsTile(BuildContext context) => MfIconTile(
        icon: Icons.settings_outlined,
        label: 'Settings',
        subtitle: 'Notifications, theme and app preferences',
        tone: MfTone.neutral,
        onTap: () => context.push('/settings'),
      );

  // ── Profile viewed by a caregiver ───────────────────────────────────────────
  Widget _buildViewedProfile(BuildContext context, User user) {
    final isDeaf = _isDeafUser(user);
    return ListView(
      padding: const EdgeInsets.fromLTRB(MfSpace.gutter, MfSpace.md, MfSpace.gutter, MfSpace.xl),
      children: [
        _IdentityCard(user: user, isOwnProfile: false, isUploading: false),
        if (user.role == 'RESPONDER') ...[
          const SizedBox(height: MfSpace.lg),
          const MfSectionTitle('Performance'),
          _ResponderStatsRow(user: user),
          const SizedBox(height: MfSpace.lg),
          const MfSectionTitle('Professional credentials'),
          _ResponderCredentials(user: user),
        ] else if (user.role != 'CAREGIVER') ...[
          if (isDeaf) ...[
            const SizedBox(height: MfSpace.md),
            const MfInfoBanner(
              icon: Icons.sign_language_outlined,
              title: 'Communicate by text — cannot receive voice calls',
              message: 'This patient is deaf and uses visual alerts. Use text chat instead of calling.',
              tone: MfTone.primary,
            ),
          ],
          const SizedBox(height: MfSpace.lg),
          const MfSectionTitle('Caregiver actions'),
          MfListGroup(children: [
            MfIconTile(
              icon: Icons.chat_bubble_outline_rounded,
              label: 'Message patient',
              subtitle: 'Open conversation in Messages',
              onTap: () => context.go('/caregiver/chats'),
            ),
            MfIconTile(
              icon: Icons.people_outline_rounded,
              label: 'View in My patients',
              subtitle: 'See full monitoring dashboard',
              onTap: () => context.push('/caregiver/my-patients'),
            ),
            MfIconTile(
              icon: Icons.map_outlined,
              label: 'Live map',
              subtitle: 'View patient on the map',
              onTap: () => context.go('/caregiver/maps'),
            ),
          ]),
        ],
        const SizedBox(height: MfSpace.lg),
        _AccountInfoSection(user: user),
      ],
    );
  }
}

// ─── Identity card ────────────────────────────────────────────────────────────
class _IdentityCard extends StatelessWidget {
  final User user;
  final bool isOwnProfile;
  final bool isUploading;
  final VoidCallback? onChangePhoto;

  const _IdentityCard({
    required this.user,
    required this.isOwnProfile,
    required this.isUploading,
    this.onChangePhoto,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final isPatient = user.role != 'RESPONDER' && user.role != 'CAREGIVER';
    final isDeaf = _isDeafUser(user);
    const avatarSize = 72.0;

    final plan = user.subscriptionPlan;
    final planTone = plan == 'EXECUTIVE' || plan == 'PROFESSIONAL' ? MfTone.primary : MfTone.neutral;
    final planIcon = plan == 'EXECUTIVE'
        ? Icons.workspace_premium_outlined
        : (plan == 'PROFESSIONAL' ? Icons.star_outline_rounded : Icons.card_membership_outlined);

    return MfCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: avatarSize,
                height: avatarSize,
                child: Stack(
                  children: [
                    MfAvatar(imageUrl: user.profileImageUrl, name: user.fullName, size: avatarSize),
                    if (isUploading)
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: cs.surface.withValues(alpha: 0.7),
                          ),
                          child: const Center(
                            child: SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(strokeWidth: 2.5),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: MfSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.fullName.isEmpty ? 'Unnamed user' : user.fullName,
                      style: text.titleLarge,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (user.email.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        user.email,
                        style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: MfSpace.xs),
                    Wrap(
                      spacing: MfSpace.xs,
                      runSpacing: MfSpace.xs,
                      children: [
                        MfStatusChip(
                          label: _roleLabel(user.role),
                          icon: _roleIcon(user.role),
                          tone: MfTone.primary,
                        ),
                        MfStatusChip(
                          label: _planLabel(plan),
                          icon: planIcon,
                          tone: planTone,
                        ),
                        if (isPatient)
                          MfStatusChip(
                            label: isDeaf ? 'Deaf mode' : 'Standard mode',
                            icon: isDeaf ? Icons.hearing_disabled_rounded : Icons.hearing_rounded,
                            tone: MfTone.info,
                          ),
                        if (isPatient)
                          isOwnProfile
                              ? const MfStatusChip(
                                  label: 'SOS ready',
                                  icon: Icons.check_circle_outline_rounded,
                                  tone: MfTone.success,
                                )
                              : const MfStatusChip(
                                  label: 'Monitored',
                                  icon: Icons.shield_outlined,
                                  tone: MfTone.primary,
                                ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (isOwnProfile && onChangePhoto != null) ...[
            const SizedBox(height: MfSpace.md),
            MfSecondaryButton(
              label: isUploading ? 'Uploading photo' : 'Change photo',
              icon: Icons.photo_camera_outlined,
              loading: isUploading,
              onPressed: onChangePhoto,
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Responder stats ──────────────────────────────────────────────────────────
class _ResponderStatsRow extends StatelessWidget {
  final User user;
  const _ResponderStatsRow({required this.user});

  @override
  Widget build(BuildContext context) {
    final isVerified = user.verificationStatus == 'VERIFIED';
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: MfStatTile(
              icon: ResponderRating.hasRatings(user.totalRatings)
                  ? Icons.star_outline_rounded
                  : Icons.fiber_new_rounded,
              label: 'Rating',
              // A responder nobody has rated shows "New", not the 5.0 default.
              value: ResponderRating.label(user.rating, user.totalRatings),
              tone: ResponderRating.hasRatings(user.totalRatings)
                  ? MfTone.warning
                  : MfTone.neutral,
            ),
          ),
          const SizedBox(width: MfSpace.xs),
          Expanded(
            child: MfStatTile(
              icon: Icons.check_circle_outline_rounded,
              label: 'Completed',
              value: '${user.totalResponsesHandled ?? 0}',
              tone: MfTone.success,
            ),
          ),
          const SizedBox(width: MfSpace.xs),
          Expanded(
            child: MfStatTile(
              icon: isVerified ? Icons.verified_outlined : Icons.pending_outlined,
              label: 'Status',
              value: isVerified ? 'Verified' : 'Pending',
              tone: isVerified ? MfTone.success : MfTone.warning,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Responder credentials ────────────────────────────────────────────────────
class _ResponderCredentials extends StatelessWidget {
  final User user;
  const _ResponderCredentials({required this.user});

  @override
  Widget build(BuildContext context) {
    final isVerified = user.verificationStatus == 'VERIFIED';
    final responderTypeLabel = _kResponderTypeLabels[user.responderType] ??
        (user.responderType?.replaceAll('_', ' ') ?? '—');
    final vehicleLabel = user.vehicleType?.replaceAll('_', ' ') ?? '—';

    return MfListGroup(children: [
      MfKeyValueRow(
        icon: Icons.badge_outlined,
        label: 'License number',
        value: user.licenseNumber ?? '—',
      ),
      MfKeyValueRow(
        icon: Icons.business_outlined,
        label: 'Organization',
        value: user.organization ?? '—',
      ),
      MfKeyValueRow(
        icon: Icons.medical_services_outlined,
        label: 'Responder type',
        value: responderTypeLabel,
      ),
      MfKeyValueRow(
        icon: Icons.two_wheeler_rounded,
        label: 'Vehicle type',
        value: vehicleLabel,
      ),
      MfKeyValueRow(
        icon: isVerified ? Icons.verified_outlined : Icons.pending_outlined,
        label: 'Verification',
        value: isVerified ? 'Verified' : 'Pending review',
        trailing: MfStatusChip(
          label: isVerified ? 'Verified' : 'Pending',
          icon: isVerified ? Icons.check_rounded : Icons.schedule_rounded,
          tone: isVerified ? MfTone.success : MfTone.warning,
        ),
      ),
    ]);
  }
}

// ─── Account information ──────────────────────────────────────────────────────
class _AccountInfoSection extends StatelessWidget {
  final User user;
  const _AccountInfoSection({required this.user});

  @override
  Widget build(BuildContext context) {
    String orDash(String? v) => (v == null || v.isEmpty) ? '—' : v;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const MfSectionTitle('Account information'),
        MfListGroup(children: [
          MfKeyValueRow(
            icon: Icons.person_outline_rounded,
            label: 'Full name',
            value: orDash(user.fullName),
          ),
          MfKeyValueRow(
            icon: Icons.email_outlined,
            label: 'Email address',
            value: orDash(user.email),
          ),
          MfKeyValueRow(
            icon: Icons.phone_outlined,
            label: 'Phone number',
            value: orDash(user.phoneNumber),
          ),
          if (user.cnic != null)
            MfKeyValueRow(
              icon: Icons.badge_outlined,
              label: 'CNIC / ID',
              value: user.cnic!,
            ),
        ]),
      ],
    );
  }
}
