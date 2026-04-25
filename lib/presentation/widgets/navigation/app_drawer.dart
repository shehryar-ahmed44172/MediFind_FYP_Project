import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/constants/app_constants.dart';

class AppDrawer extends ConsumerWidget {
  const AppDrawer({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final userAsync = ref.watch(currentUserProvider);
    final user = userAsync.valueOrNull;

    return Drawer(
      backgroundColor: theme.scaffoldBackgroundColor,
      child: Column(
        children: [
          _buildHeader(context, user, theme),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildMenuItem(
                  context,
                  icon: Icons.dashboard_rounded,
                  title: 'Home',
                  onTap: () {
                    Navigator.pop(context);
                    final role = user?.role ?? 'PATIENT';
                    if (role == 'PATIENT') context.go('/home');
                    else if (role == 'CAREGIVER') context.go('/caregiver');
                    else context.go('/responder');
                  },
                ),
                _buildMenuItem(
                  context,
                  icon: Icons.person_outline_rounded,
                  title: 'My Profile',
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/profile');
                  },
                ),
                if (user?.role == 'PATIENT') ...[
                  _buildMenuItem(
                    context,
                    icon: Icons.content_paste_rounded,
                    title: 'Medical Reports',
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/home/medical-reports');
                    },
                  ),
                  _buildMenuItem(
                    context,
                    icon: Icons.people_outline_rounded,
                    title: 'My Caregivers',
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/home/caregivers');
                    },
                  ),
                ],
                if (user?.role == 'CAREGIVER') ...[
                  _buildMenuItem(
                    context,
                    icon: Icons.people_rounded,
                    title: 'My Patients',
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/caregiver/my-patients');
                    },
                  ),
                  _buildMenuItem(
                    context,
                    icon: Icons.map_outlined,
                    title: 'Patient Tracking',
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/caregiver/maps');
                    },
                  ),
                ],
                _buildMenuItem(
                  context,
                  icon: Icons.history_rounded,
                  title: 'History',
                  onTap: () {
                    final role = user?.role ?? 'PATIENT';
                    Navigator.pop(context);
                    if (role == 'PATIENT') {
                      context.push('/home/medical-reports');
                    } else if (role == 'CAREGIVER') {
                      context.push('/caregiver/history');
                    } else if (role == 'RESPONDER') {
                      context.push('/responder/history');
                    }
                  },
                ),
                if (user?.role == 'PATIENT' || user?.role == 'CAREGIVER')
                  _buildMenuItem(
                    context,
                    icon: Icons.chat_bubble_outline_rounded,
                    title: 'Messages',
                    onTap: () {
                      Navigator.pop(context);
                      final role = user?.role ?? 'PATIENT';
                      if (role == 'PATIENT') {
                        context.push('/chats');
                      } else if (role == 'CAREGIVER') {
                        context.push('/caregiver/chats');
                      }
                    },
                  ),
                const Divider(indent: 20, endIndent: 20),
                _buildMenuItem(
                  context,
                  icon: Icons.settings_outlined,
                  title: 'Settings',
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/settings');
                  },
                ),
              ],
            ),
          ),
          _buildLogoutButton(context, ref, theme),
          SizedBox(height: 2.hp),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, dynamic user, ThemeData theme) {
    String? fullImageUrl;
    if (user?.profileImageUrl != null) {
      final rootUrl = AppConstants.socketUrl.endsWith('/') 
          ? AppConstants.socketUrl.substring(0, AppConstants.socketUrl.length - 1)
          : AppConstants.socketUrl;
      fullImageUrl = '$rootUrl${user.profileImageUrl}';
    }

    return Container(
      padding: EdgeInsets.fromLTRB(20, 6.hp, 20, 3.hp),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: AppColors.medifindGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.white.withOpacity(0.2),
            backgroundImage: fullImageUrl != null ? NetworkImage(fullImageUrl) : null,
            child: fullImageUrl == null 
                ? const Icon(Icons.person_rounded, color: Colors.white, size: 30)
                : null,
          ),
          SizedBox(width: 4.wp),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.fullName ?? 'MediFind User',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  user?.role ?? 'User',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary, size: 24),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
    );
  }

  Widget _buildLogoutButton(BuildContext context, WidgetRef ref, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ListTile(
        leading: const Icon(Icons.logout_rounded, color: Colors.redAccent),
        title: const Text(
          'Logout',
          style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
        ),
        onTap: () => _handleLogout(context, ref),
        tileColor: Colors.red.withOpacity(0.05),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
