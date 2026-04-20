import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/medical_profile_provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common/app_header.dart';

class MedicalProfileScreen extends ConsumerWidget {
  const MedicalProfileScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserId = ref.watch(currentUserIdProvider);
    return currentUserId.when(
      data: (userId) => _buildProfileContent(context, ref, userId ?? ''),
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
    );
  }

  Widget _buildProfileContent(BuildContext context, WidgetRef ref, String userId) {
    final profileAsync = ref.watch(getMedicalProfileProvider(userId));
    return Scaffold(
      body: Column(
        children: [
          const AppHeader(greetingOverride: 'Medical Profile'),
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
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade700,
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
                error: (e, _) => Center(child: Text('Error loading profile: $e')),
              ),
            ),
          ],
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
