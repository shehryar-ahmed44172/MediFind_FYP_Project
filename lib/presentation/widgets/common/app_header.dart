import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/accessibility_provider.dart';
import '../../providers/notification_provider.dart';
import '../../theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';

class AppHeader extends ConsumerWidget implements PreferredSizeWidget {
  final bool showLogout;
  final bool showProfile;
  final String? greetingOverride;
  final bool centerTitle;
  final bool canPop; // New explicit flag

  const AppHeader({
    Key? key,
    this.showLogout = true,
    this.showProfile = true,
    this.greetingOverride,
    this.centerTitle = false,
    this.canPop = false, // Default to false
  }) : super(key: key);

  @override
  Size get preferredSize => const Size.fromHeight(100); // Standard header height for this design

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
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Row(
            children: [
              // Left: Logo OR Back Button
              if (canPop)
                Container(
                  margin: const EdgeInsets.only(right: 12),
                  child: _buildActionButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    theme: theme,
                    onTap: () {
                      if (Navigator.of(context).canPop()) {
                        Navigator.of(context).pop();
                      } else {
                        context.go(userAsync.valueOrNull?.role == 'CAREGIVER' ? '/caregiver' : '/home');
                      }
                    },
                    size: 18,
                  ),
                )
              else
                Image.asset(
                  'assets/logos/Medifind_New_Logo-removebg-preview.png',
                  height: 55,
                  color: Colors.white,
                  colorBlendMode: BlendMode.srcIn,
                  fit: BoxFit.contain,
                ),
              
              const SizedBox(width: 12),

              // Center/Title Area
              Expanded(
                child: Row(
                  mainAxisAlignment: centerTitle ? MainAxisAlignment.center : MainAxisAlignment.start,
                  children: [
                    if (greetingOverride != null)
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            greetingOverride ?? '',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontSize: 20 * ref.watch(fontSizeMultiplierProvider),
                            ),
                            maxLines: 1,
                          ),
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
                      icon: Icons.chat_bubble_outline_rounded,
                      theme: theme,
                      onTap: () {
                        final user = userAsync.valueOrNull;
                        final role = user?.role ?? 'PATIENT';
                        if (role == 'PATIENT') {
                          context.push('/chats');
                        } else if (role == 'CAREGIVER') {
                          context.push('/caregiver/chats');
                        }
                      },
                      color: Colors.white,
                    ),
                    const SizedBox(width: 8),
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        _buildActionButton(
                          icon: Icons.notifications_none_rounded,
                          theme: theme,
                          onTap: () => _showNotifications(context, ref, theme),
                          color: Colors.white,
                        ),
                        if (ref.watch(unreadNotificationsCountProvider) > 0)
                          Positioned(
                            right: -2,
                            top: -2,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 16,
                                minHeight: 16,
                              ),
                              child: Text(
                                ref.watch(unreadNotificationsCountProvider).toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    ),
                  
                  if (showLogout) ...[
                    const SizedBox(width: 6),
                    _buildActionButton(
                      icon: Icons.logout_rounded,
                      theme: theme,
                      color: Colors.white,
                      onTap: () => _handleLogout(context, ref),
                    ),
                  ],
                  
                  if (showProfile) ...[
                    const SizedBox(width: 8),
                    userAsync.when(
                      data: (user) => GestureDetector(
                        onTap: () => context.push('/profile'),
                        child: _buildAvatar(user?.profileImageUrl, theme),
                      ),
                      loading: () => CircleAvatar(radius: 20, backgroundColor: Colors.white.withOpacity(0.2)),
                      error: (_, __) => const Icon(Icons.account_circle_rounded, color: Colors.white),
                    ),
                  ],

                  // Side Drawer Toggle (Burger)
                  const SizedBox(width: 8),
                  _buildActionButton(
                    icon: Icons.menu_rounded,
                    theme: theme,
                    onTap: () {
                      Scaffold.of(context).openEndDrawer();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(String? imageUrl, ThemeData theme) {
    String? fullImageUrl;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      if (imageUrl.startsWith('http')) {
        fullImageUrl = imageUrl;
      } else {
        // Use socketUrl (which is the root) instead of baseUrl (which has /api/)
        final rootUrl = AppConstants.socketUrl.endsWith('/') 
            ? AppConstants.socketUrl.substring(0, AppConstants.socketUrl.length - 1)
            : AppConstants.socketUrl;
        final cleanPath = imageUrl.startsWith('/') ? imageUrl : '/$imageUrl';
        fullImageUrl = '$rootUrl$cleanPath';
      }
    }

    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
      ),
      child: CircleAvatar(
        radius: 20,
        backgroundColor: Colors.white.withOpacity(0.1),
        backgroundImage: fullImageUrl != null ? NetworkImage(fullImageUrl) : null,
        child: fullImageUrl == null
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
    double size = 22,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color ?? Colors.white, size: size),
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

  void _showNotifications(BuildContext context, WidgetRef ref, ThemeData theme) {
     showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final notificationsAsync = ref.watch(notificationsProvider);
          
          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.7,
            ),
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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
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
                    if (ref.read(unreadNotificationsCountProvider) > 0)
                      TextButton(
                        onPressed: () => ref.read(markAllAsReadProvider),
                        child: const Text('Mark all as read'),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: notificationsAsync.when(
                    data: (notifications) {
                      if (notifications.isEmpty) {
                        return const Center(child: Text('No notifications yet'));
                      }
                      return ListView.builder(
                        itemCount: notifications.length,
                        itemBuilder: (context, index) {
                          final n = notifications[index];
                          if (n == null) return const SizedBox.shrink();
                          final bool isRead = n['isRead'] ?? false;
                          
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(vertical: 8),
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isRead ? Colors.grey.shade100 : AppColors.primary.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isRead ? Icons.notifications_none : Icons.notifications_active,
                                color: isRead ? Colors.grey : AppColors.primary,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              n['title'] ?? 'Notification',
                              style: TextStyle(
                                fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(n['body'] ?? ''),
                            trailing: !isRead 
                              ? IconButton(
                                  icon: const Icon(Icons.check_circle_outline, size: 20),
                                  onPressed: () => ref.read(markAsReadProvider(n['id'])),
                                )
                              : null,
                          );
                        },
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('Error: $e')),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        }
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
