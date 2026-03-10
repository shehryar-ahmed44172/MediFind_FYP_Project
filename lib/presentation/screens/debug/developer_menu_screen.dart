import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class DeveloperMenuScreen extends StatelessWidget {
  const DeveloperMenuScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MediFind Developer Menu'),
        backgroundColor: Colors.redAccent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Use this menu to preview app layouts without a backend.',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
            ),
          ),
          const Divider(),
          _SectionHeader('Authentication'),
          _MenuTile(title: 'Login Screen', route: '/login'),
          _MenuTile(title: 'Register Screen', route: '/register'),
          _MenuTile(title: 'Forgot Password', route: '/forgot-password'),

          _SectionHeader('Patient / User'),
          _MenuTile(title: 'Home Screen (SOS)', route: '/home'),
          _MenuTile(title: 'Emergency Selection', route: '/home/emergency'),
          _MenuTile(title: 'Medical Profile', route: '/home/medical-profile'),
          _MenuTile(title: 'Edit Medical Profile', route: '/home/medical-profile/edit'),
          _MenuTile(title: 'Medical Reports', route: '/home/medical-reports'),
          _MenuTile(title: 'User Profile', route: '/home/profile'),
          _MenuTile(title: 'Manage Caregivers', route: '/home/caregivers'),
          _MenuTile(title: 'Accessibility Settings', route: '/home/settings/accessibility'),
          _MenuTile(title: 'Patient Type Info (Normal)', route: '/home/patient-type-info'),

          _SectionHeader('Responder'),
          _MenuTile(title: 'Responder Home', route: '/responder'),
          _MenuTile(title: 'Active Emergency', route: '/responder/active'),

          _SectionHeader('Caregiver'),
          _MenuTile(title: 'Caregiver Dashboard', route: '/caregiver'),

          const SizedBox(height: 32),
          const Center(
            child: Text(
              'Note: Some screens (like tracking) require dynamic IDs and may show error states without data.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.redAccent),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final String title;
  final String route;
  const _MenuTile({required this.title, required this.route});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push(route),
    );
  }
}
