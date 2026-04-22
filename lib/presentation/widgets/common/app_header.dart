import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/accessibility_provider.dart';
import '../../theme/app_theme.dart';

class AppHeader extends ConsumerWidget {
  final bool showLogout;
  final bool showProfile;
  final String? greetingOverride;
  final bool centerTitle;

  const AppHeader({
    Key? key,
    this.showLogout = false,
    this.showProfile = true,
    this.greetingOverride,
    this.centerTitle = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final userAsync = ref.watch(currentUserProvider);

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: AppColors.medifindGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Row(
            children: [
              // Left: Back Button OR Logo
              if (greetingOverride != null && context.canPop())
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                  onPressed: () => context.pop(),
                )
              else if (greetingOverride == null)
                Image.asset(
                  'assets/logos/Medifind_New_Logo-removebg-preview.png',
                  height: 48,
                  fit: BoxFit.contain,
                  color: Colors.white,
                  colorBlendMode: BlendMode.srcIn,
                  errorBuilder: (context, error, stackTrace) => 
                    const Icon(Icons.medication_rounded, color: Colors.white, size: 32),
                ),
              
              if (greetingOverride == null)
                const SizedBox(width: 8),

              // Center/Title Area
              Expanded(
                child: Row(
                  mainAxisAlignment: centerTitle ? MainAxisAlignment.center : MainAxisAlignment.start,
                  children: [
                    if (greetingOverride != null)
                      Flexible(
                        child: Text(
                          greetingOverride!,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 18 * ref.watch(fontSizeMultiplierProvider),
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    
                    // Accessibility Badge
                    userAsync.when(
                      data: (user) => user?.patientType == 'DEAF'
                          ? Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.amberAccent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.visibility_rounded, size: 14, color: AppColors.primary),
                            )
                          : const SizedBox.shrink(),
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),

              // Right: Actions
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildActionButton(
                    icon: Icons.notifications_none_rounded,
                    theme: theme,
                    onTap: () => _showNotifications(context, theme),
                    color: Colors.white,
                  ),
                  
                  if (showLogout) ...[
                    const SizedBox(width: 8),
                    _buildActionButton(
                      icon: Icons.logout_rounded,
                      theme: theme,
                      color: Colors.white,
                      onTap: () => _handleLogout(context, ref),
                    ),
                  ],
                  
                  if (showProfile) ...[
                    const SizedBox(width: 12),
                    userAsync.when(
                      data: (user) => GestureDetector(
                        onTap: () => context.push('/profile'),
                        child: _buildAvatar(user?.profileImageUrl, theme),
                      ),
                      loading: () => CircleAvatar(radius: 20, backgroundColor: Colors.white.withOpacity(0.2)),
                      error: (_, __) => const Icon(Icons.account_circle_rounded, color: Colors.white),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(String? imageUrl, ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
      ),
      child: CircleAvatar(
        radius: 20,
        backgroundColor: Colors.white.withOpacity(0.1),
        backgroundImage: imageUrl != null && imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
        child: (imageUrl == null || imageUrl.isEmpty)
            ? const Icon(Icons.person_rounded, color: Colors.white, size: 20)
            : null,
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required ThemeData theme,
    required VoidCallback onTap,
    Color? color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color ?? Colors.white, size: 22),
      ),
    );
  }

  Widget _buildHeaderSkeleton(ThemeData theme) {
    return Row(
      children: [
        CircleAvatar(radius: 26, backgroundColor: Colors.grey.shade200),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(width: 60, height: 12, color: Colors.grey.shade200),
            const SizedBox(height: 8),
            Container(width: 100, height: 20, color: Colors.grey.shade200),
          ],
        ),
      ],

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
                Icon(Icons.notifications_active_outlined, color: AppColors.primary),
                const SizedBox(width: 12),
                Text(
                  'Notifications',
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 32),
            const Text('No new notifications'),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _handleLogout(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Logout'),
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(logoutProvider.future);
              if (context.mounted) {
                context.go('/login');
              }
            },
          ),
        ],
      ),
    );
  }
}
