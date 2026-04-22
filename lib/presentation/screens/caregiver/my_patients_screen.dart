import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/caregiver_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common/app_header.dart';
import '../../../domain/entities/caregiver_connection.dart';

class MyPatientsScreen extends ConsumerStatefulWidget {
  const MyPatientsScreen({Key? key}) : super(key: key);

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
          AppHeader(greetingOverride: 'Managed Patients'),
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
                error: (err, _) => Center(child: Text('Error: $err')),
              ),
            ),
          ],
        ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/caregiver/link-patient'),
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('Add Patient'),
      ),
    );
  }

  Widget _buildLinksList(List<CaregiverConnection> links, String statusFilter) {
    final filteredLinks = statusFilter == 'ALL' 
        ? links 
        : links.where((l) => l.status == statusFilter).toList();

    if (filteredLinks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline_rounded, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('No patients found', style: TextStyle(color: Colors.grey.shade600)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      itemCount: filteredLinks.length,
      itemBuilder: (context, index) => _PatientManageCard(link: filteredLinks[index]),
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

    Color statusColor = Colors.orange;
    if (isAccepted) statusColor = Colors.green;
    if (isRejected) statusColor = Colors.red;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
              backgroundColor: statusColor.withOpacity(0.1),
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
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isRejected ? 'FAILED' : link.status,
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
            if (!isAccepted)
              IconButton(
                onPressed: () => _showResendConfirm(context, ref),
                icon: Icon(Icons.refresh_rounded, color: AppColors.primary),
                tooltip: 'Resend Invitation',
              ),
          ],
        ),
      ),
    );
  }

  void _showResendConfirm(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Resend Invitation?'),
        content: Text('This will send a new email notification to ${link.patientEmail ?? 'this patient'}.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ref.read(resendInvitationProvider(link.patientId).future);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Invitation resent!'), backgroundColor: Colors.green),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Resend'),
          ),
        ],
      ),
    );
  }
}
