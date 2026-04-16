import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../widgets/profile/invitations_list_widget.dart';

class UserProfileScreen extends ConsumerWidget {
  const UserProfileScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        centerTitle: true,
      ),
      body: userAsync.when(
        data: (user) {
          if (user == null) return const Center(child: Text('No user profile found'));

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Pending Invitations Widget
              const InvitationsListWidget(),
              
              // Profile Picture
              Center(
                child: Stack(
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: theme.scaffoldBackgroundColor,
                        boxShadow: AppShadows.neumorphicOut,
                      ),
                      child: user.profileImageUrl != null 
                        ? ClipOval(child: Image.network(user.profileImageUrl!, fit: BoxFit.cover))
                        : const Icon(Icons.person, size: 60, color: Colors.grey),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          shape: BoxShape.circle,
                          boxShadow: AppShadows.neumorphicOut,
                        ),
                        padding: const EdgeInsets.all(8),
                        child: const Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // User Info Card
              Container(
                decoration: BoxDecoration(
                  color: theme.scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: AppShadows.neumorphicOut,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _profileTile(Icons.person_outline, 'Full Name', user.fullName),
                      Divider(color: Colors.grey.shade300),
                      _profileTile(Icons.email_outlined, 'Email', user.email),
                      Divider(color: Colors.grey.shade300),
                      _profileTile(Icons.phone_outlined, 'Phone Number', user.phoneNumber),
                      Divider(color: Colors.grey.shade300),
                      _profileTile(Icons.badge_outlined, 'Role', user.role),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Additional Info (Organizations for Responders, etc.)
              if (user.role == 'RESPONDER') 
                Container(
                  decoration: BoxDecoration(
                    color: theme.scaffoldBackgroundColor,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: AppShadows.neumorphicOut,
                  ),
                  margin: const EdgeInsets.only(bottom: 24),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Service Information',
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        _profileTile(Icons.business_outlined, 'Organization', user.organization ?? 'Not Specified'),
                        Divider(color: Colors.grey.shade300),
                        _profileTile(Icons.verified_user_outlined, 'License', user.licenseNumber ?? 'N/A'),
                      ],
                    ),
                  ),
                ),

              // Edit Button
              Container(
                decoration: BoxDecoration(
                  color: theme.scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: AppShadows.neumorphicOut,
                ),
                child: ElevatedButton.icon(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.scaffoldBackgroundColor,
                    foregroundColor: theme.colorScheme.primary,
                    elevation: 0,
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit Profile',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
              const SizedBox(height: 24),
              
              // Logout
              TextButton.icon(
                onPressed: () async {
                  await ref.read(logoutProvider.future);
                  if (context.mounted) context.go('/login');
                },
                icon: const Icon(Icons.logout, color: Colors.red),
                label: const Text('Logout', style: TextStyle(color: Colors.red)),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error loading profile: $e')),
      ),
    );
  }
  }

  Widget _profileTile(IconData icon, String title, String subtitle) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: Colors.grey.shade500),
      title: Text(title,
          style: const TextStyle(fontSize: 12, color: Colors.grey)),
      subtitle: Text(subtitle,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
    );
  }
}
