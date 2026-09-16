import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/caregiver_providers.dart';
import '../../theme/app_theme.dart';
import '../../../domain/entities/caregiver_connection.dart';
import '../../providers/chat_provider.dart';

class MyPatientsScreen extends ConsumerStatefulWidget {
  const MyPatientsScreen({super.key});

  @override
  ConsumerState<MyPatientsScreen> createState() => _MyPatientsScreenState();
}

class _MyPatientsScreenState extends ConsumerState<MyPatientsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final linksAsync = ref.watch(allCaregiverLinksProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          const SizedBox(height: 16),
            TabBar(
              controller: _tabController,
              labelColor: AppColors.primary,
              unselectedLabelColor: Colors.grey,
              indicatorColor: AppColors.primary,
              tabs: const [
                Tab(text: 'All'),
                Tab(text: 'Pending'),
                Tab(text: 'Failed'),
              ],
            ),
            Expanded(
              child: linksAsync.when(
                data: (links) {
                  return TabBarView(
                    controller: _tabController,
                    children: [
                      _buildLinksList(links, 'ALL'),
                      _buildLinksList(links, 'PENDING'),
                      _buildLinksList(links, 'REJECTED'),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.cloud_off_rounded, size: 56, color: AppColors.error),
                        const SizedBox(height: 16),
                        const Text('Could not load your patients.', textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => ref.invalidate(allCaregiverLinksProvider),
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Retry'),
                          style: ElevatedButton.styleFrom(minimumSize: const Size(140, 48)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/caregiver/my-patients/link-patient'),
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('Add Patient'),
      ),
    );
  }

  Widget _buildLinksList(List<CaregiverConnection> links, String statusFilter) {
    final filteredLinks = statusFilter == 'ALL' 
        ? links 
        : links.where((l) => l.status == statusFilter).toList();

    Future<void> onRefresh() async {
      try {
        ref.invalidate(allCaregiverLinksProvider);
        await ref.read(allCaregiverLinksProvider.future);
      } catch (_) {}
    }

    if (filteredLinks.isEmpty) {
      final emptyText = switch (statusFilter) {
        'PENDING' => 'No pending invitations',
        'REJECTED' => 'No declined invitations',
        _ => 'No patients yet. Tap "Add Patient" to send an invitation.',
      };
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 32),
          children: [
            const SizedBox(height: 120),
            Icon(Icons.people_outline_rounded, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(emptyText, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade700)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        // Bottom padding keeps the last card clear of the FAB.
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 96),
        itemCount: filteredLinks.length,
        itemBuilder: (context, index) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _PatientManageCard(link: filteredLinks[index]),
        ),
      ),
    );
  }
}

class _PatientManageCard extends ConsumerWidget {
  final CaregiverConnection link;
  const _PatientManageCard({required this.link});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final bool isAccepted = link.status == 'ACCEPTED';
    final bool isRejected = link.status == 'REJECTED';
    final bool isPending = link.status == 'PENDING';

    Color statusColor = AppColors.warning;
    if (isAccepted) statusColor = AppColors.success;
    if (isRejected) statusColor = AppColors.error;

    return InkWell(
      onTap: () => context.push('/caregiver/my-patients/patient-profile/${link.patientId}'),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: AppShadows.neumorphicOut,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: statusColor.withValues(alpha: 0.1),
                child: Icon(Icons.person_rounded, color: statusColor, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      link.patientName ?? link.patientEmail ?? 'Unknown',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isRejected ? 'DECLINED' : isPending ? 'PENDING' : link.status,
                            style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(link.relationship, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                      ],
                    ),
                  ],
                ),
              ),
              if (isAccepted)
                IconButton(
                  onPressed: () async {
                    try {
                      final room = await ref.read(getChatRoomForUserProvider(link.patientId).future);
                      if (context.mounted) {
                        context.push('/chat/${room.id}', extra: link.patientName ?? 'Patient');
                      }
                    } catch (e) {
                      debugPrint('MyPatients: could not open chat: $e');
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Could not open the chat. Please try again.'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.primary),
                  tooltip: 'Chat with Patient',
                ),
              if (isPending || isRejected)
                IconButton(
                  onPressed: () => _showResendConfirm(context, ref),
                  icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
                  tooltip: 'Resend Invitation',
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showResendConfirm(BuildContext context, WidgetRef ref) {
    final messenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Resend Invitation?'),
        content: Text('This will send a new email notification to ${link.patientEmail ?? 'this patient'}.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                await ref.read(resendInvitationProvider(link.patientId).future);
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Invitation resent!'),
                    backgroundColor: AppColors.success,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              } catch (e) {
                debugPrint('MyPatients: resend failed: $e');
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Could not resend the invitation: ${e.toString().replaceAll('Exception:', '').trim()}'),
                    backgroundColor: AppColors.error,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('Resend'),
          ),
        ],
      ),
    );
  }
}
