import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/caregiver_providers.dart';
import '../../../domain/entities/caregiver_connection.dart';
import '../../theme/app_theme.dart';
import '../../../core/utils/responsive.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import 'package:go_router/go_router.dart';

class ManageCaregiversScreen extends ConsumerStatefulWidget {
  const ManageCaregiversScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ManageCaregiversScreen> createState() =>
      _ManageCaregiversScreenState();
}

class _ManageCaregiversScreenState extends ConsumerState<ManageCaregiversScreen> {
  final _emailController = TextEditingController();
  final _relationshipController = TextEditingController();
  bool _isInviting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _relationshipController.dispose();
    super.dispose();
  }

  Future<void> _handleInvite() async {
    final email = _emailController.text.trim();
    final relationship = _relationshipController.text.trim();

    if (email.isEmpty || relationship.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    setState(() => _isInviting = true);
    try {
      await ref.read(sendInvitationProvider({
        'patientEmail': email,
        'relationship': relationship,
      }).future);
      
      if (mounted) {
        Navigator.pop(context);
        _emailController.clear();
        _relationshipController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invitation sent successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isInviting = false);
    }
  }

  void _showAddCaregiverSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final theme = Theme.of(context);
          return Padding(
            padding: EdgeInsets.fromLTRB(
                24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text('Invite Caregiver',
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                    const Spacer(),
                    IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Enter the email of the person you want to add as your caregiver.',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                const SizedBox(height: 24),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Email Address',
                    hintText: 'e.g. name@example.com',
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _relationshipController,
                  decoration: InputDecoration(
                    labelText: 'Relationship',
                    hintText: 'e.g. Son, Daughter, Spouse',
                    prefixIcon: const Icon(Icons.people_outline),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isInviting ? null : _handleInvite,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: _isInviting 
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Send Invitation', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _handleRemove(CaregiverConnection connection) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Caregiver'),
        content: Text('Are you sure you want to remove ${connection.caregiverName ?? "this caregiver"}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(connectionRepositoryProvider).unlinkCaregiver(connection.caregiverId);
                ref.invalidate(allCaregiverLinksProvider);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Caregiver removed')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _handleInvitationResponse(CaregiverConnection link, bool accept) async {
    try {
      await ref.read(respondToInvitationProvider({
        'invitationId': link.id,
        'accept': accept,
      }).future);
      ref.invalidate(allCaregiverLinksProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(accept ? 'Invitation accepted' : 'Invitation rejected'),
            backgroundColor: accept ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final linksAsync = ref.watch(allCaregiverLinksProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddCaregiverSheet,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Caregiver', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: linksAsync.when(
        data: (links) {
          if (links.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.05),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.group_add_outlined, size: 80, color: Colors.blue.shade300),
                  ),
                  const SizedBox(height: 24),
                  const Text('No Caregivers Yet',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      'Add family members or friends to be notified instantly in case of an emergency.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => ref.refresh(allCaregiverLinksProvider.future),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              itemCount: links.length,
              itemBuilder: (ctx, i) {
                final link = links[i];
                return _CaregiverCard(
                  link: link,
                  currentUserId: ref.read(currentUserProvider).valueOrNull?.id ?? '',
                  onDelete: () => _handleRemove(link),
                  onAccept: () => _handleInvitationResponse(link, true),
                  onReject: () => _handleInvitationResponse(link, false),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: ${e.toString()}')),
      ),
    );
  }
}

class _CaregiverCard extends StatelessWidget {
  final CaregiverConnection link;
  final String currentUserId;
  final VoidCallback onDelete;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _CaregiverCard({
    Key? key,
    required this.link,
    required this.currentUserId,
    required this.onDelete,
    required this.onAccept,
    required this.onReject,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    String statusText;

    switch (link.status.toUpperCase()) {
      case 'ACCEPTED':
        statusColor = Colors.green;
        statusText = 'Connected';
        break;
      case 'PENDING':
        statusColor = Colors.orange;
        statusText = 'Pending Approval';
        break;
      case 'REJECTED':
        statusColor = Colors.red;
        statusText = 'Rejected';
        break;
      default:
        statusColor = Colors.grey;
        statusText = link.status;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: statusColor.withOpacity(0.1),
                    child: Text(
                      (link.caregiverName ?? '?')[0].toUpperCase(),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          link.caregiverName ?? 'Unknown Caregiver',
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          link.relationship,
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(height: 1),
              ),
              Row(
                children: [
                  Icon(Icons.email_outlined, size: 14, color: Colors.grey.shade400),
                  const SizedBox(width: 6),
                  Text(link.caregiverEmail ?? 'No email',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                  const Spacer(),
                  if (link.status.toUpperCase() == 'PENDING' && link.requesterId != currentUserId) ...[
                    TextButton(
                      onPressed: onReject,
                      child: const Text('Reject', style: TextStyle(color: Colors.red, fontSize: 13)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: onAccept,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        minimumSize: const Size(0, 32),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Accept', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    ),
                  ] else ...[
                    if (link.status.toUpperCase() == 'ACCEPTED')
                      Consumer(
                        builder: (context, ref, child) => TextButton.icon(
                          onPressed: () async {
                            final room = await ref.read(getChatRoomForUserProvider(link.caregiverId).future);
                            if (context.mounted) {
                              context.push('/chat/${room.id}', extra: link.caregiverName);
                            }
                          },
                          icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16, color: AppColors.primary),
                          label: const Text('Chat', style: TextStyle(color: AppColors.primary, fontSize: 13)),
                        ),
                      ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: onDelete,
                      icon: const Icon(Icons.person_remove_outlined, size: 16, color: Colors.red),
                      label: const Text('Remove', style: TextStyle(color: Colors.red, fontSize: 13)),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
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
}
