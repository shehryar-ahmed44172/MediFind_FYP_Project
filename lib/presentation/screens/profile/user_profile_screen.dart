import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';

class UserProfileScreen extends ConsumerWidget {
  const UserProfileScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () {},
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
                  child: const Icon(Icons.person, size: 60, color: Colors.grey),
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
                  _profileTile(Icons.person_outline, 'Full Name', 'John Doe'),
                  Divider(color: Colors.grey.shade300),
                  _profileTile(Icons.email_outlined, 'Email', 'john@example.com'),
                  Divider(color: Colors.grey.shade300),
                  _profileTile(Icons.phone_outlined, 'Phone Number', '+1-555-0123'),
                  Divider(color: Colors.grey.shade300),
                  _profileTile(Icons.badge_outlined, 'Role', 'Patient'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Additional Info
          Container(
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: AppShadows.neumorphicOut,
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Additional Information',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _profileTile(Icons.location_city_outlined, 'City', 'New York'),
                  Divider(color: Colors.grey.shade300),
                  _profileTile(Icons.map_outlined, 'State', 'NY'),
                  Divider(color: Colors.grey.shade300),
                  _profileTile(Icons.flag_outlined, 'Country', 'United States'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

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
        ],
      ),
    );
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
