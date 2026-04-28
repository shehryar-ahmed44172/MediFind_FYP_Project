import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/medical_profile_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/accessibility_provider.dart';
import '../../theme/app_theme.dart';

class MedicalProfileScreen extends ConsumerWidget {
  const MedicalProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserId = ref.watch(currentUserIdProvider);
    final settings = ref.watch(accessibilityProvider);
    final m = settings.fontSizeMultiplier;
    
    return currentUserId.when(
      data: (userId) => _buildProfileContent(context, ref, userId ?? '', settings, m),
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
    );
  }

  Widget _buildProfileContent(BuildContext context, WidgetRef ref, String userId, AccessibilitySettings settings, double m) {
    final profileAsync = ref.watch(getMedicalProfileProvider(userId));
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: profileAsync.when(
        data: (profile) {
          if (profile == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.medical_information_outlined,
                      size: 72, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('No medical profile found',
                      style: TextStyle(color: Colors.grey, fontSize: 16)),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Create Medical Profile'),
                    onPressed: () => context.go('/home/medical-profile/edit'),
                  ),
                ],
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _SectionCard(
                title: 'Blood Group',
                icon: Icons.bloodtype_outlined,
                iconColor: Colors.red,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text(
                    profile.bloodType.isNotEmpty ? profile.bloodType : 'Not set',
                    style: TextStyle(
                      fontSize: 28 * m,
                      fontWeight: FontWeight.bold,
                      color: settings.highContrast ? Colors.black : Colors.red.shade700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              _SectionCard(
                title: 'Disability Type',
                icon: Icons.accessibility_new_outlined,
                iconColor: Colors.purple,
                child: Text(
                  profile.disabilityType?.isNotEmpty == true
                      ? profile.disabilityType!
                      : 'None specified',
                  style: const TextStyle(fontSize: 15),
                ),
              ),
              const SizedBox(height: 16),

              _ChipListSection(
                title: 'Allergies',
                icon: Icons.warning_amber_outlined,
                iconColor: Colors.orange,
                items: profile.allergies,
                color: Colors.orange,
              ),
              const SizedBox(height: 16),

              _ChipListSection(
                title: 'Chronic Diseases',
                icon: Icons.healing_outlined,
                iconColor: Colors.pink,
                items: profile.chronicDiseases,
                color: Colors.pink,
              ),
              const SizedBox(height: 16),

              _SectionCard(
                title: 'Current Medications',
                icon: Icons.medication_outlined,
                iconColor: AppColors.primary,
                child: profile.medications.isEmpty
                    ? const Text('None', style: TextStyle(color: Colors.grey))
                    : Column(
                        children: profile.medications
                            .map((m) => ListTile(
                                  dense: true,
                                  leading: const Icon(Icons.circle, size: 8),
                                  title: Text(m.name),
                                  contentPadding: EdgeInsets.zero,
                                ))
                            .toList(),
                      ),
              ),
              const SizedBox(height: 16),

              _SectionCard(
                title: 'Emergency Contacts',
                icon: Icons.contact_phone_outlined,
                iconColor: Colors.orange,
                child: profile.emergencyContacts.isEmpty
                    ? const Text('None', style: TextStyle(color: Colors.grey))
                    : Column(
                        children: profile.emergencyContacts
                            .map((c) => ListTile(
                                  dense: true,
                                  leading: const Icon(Icons.person, size: 20, color: Colors.orange),
                                  title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text('${c.relationship} • ${c.phoneNumber}'),
                                  contentPadding: EdgeInsets.zero,
                                ))
                            .toList(),
                      ),
              ),
              const SizedBox(height: 24),

              // Medical Reports CTA
              OutlinedButton.icon(
                onPressed: () => context.go('/home/medical-reports'),
                icon: const Icon(Icons.description_outlined),
                label: const Text('View Medical Reports'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => context.go('/home/medical-profile/edit'),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit Medical Profile'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          );
        },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => _ErrorView(
                  message: e.toString(),
                  onRetry: () => ref.invalidate(getMedicalProfileProvider(userId)),
                ),
              ),
            ),
          ],
        ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
          borderRadius: BorderRadius.circular(32),
          boxShadow: AppShadows.neumorphicOut,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.2),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Icon(
                Icons.wifi_off_rounded,
                size: 48,
                color: Colors.red.shade700,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Connection Issue',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message.contains('timeout') 
                  ? 'The server is taking too long to respond. Please check your internet.' 
                  : 'We encountered an error while loading your profile. Please try again.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 8,
                shadowColor: AppColors.primary.withOpacity(0.4),
              ),
              child: const Text(
                'TRY AGAIN',
                style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Go Back',
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final Widget child;
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppShadows.neumorphicOut,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: iconColor, size: 20),
                const SizedBox(width: 8),
                Text(title,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _ChipListSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final List<String> items;
  final Color color;
  const _ChipListSection({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.items,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: title,
      icon: icon,
      iconColor: iconColor,
      child: items.isEmpty
          ? const Text('None', style: TextStyle(color: Colors.grey))
          : Wrap(
              spacing: 8,
              runSpacing: 4,
              children: items
                  .map((item) => Chip(
                        label: Text(item),
                        backgroundColor: color.withOpacity(0.1),
                        labelStyle: TextStyle(color: color.withOpacity(0.8)),
                        side: BorderSide(color: color.withOpacity(0.3)),
                      ))
                  .toList(),
            ),
    );
  }
}
