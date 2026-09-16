import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/caregiver_providers.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../widgets/design_system/design_system.dart';
import '../../../domain/entities/caregiver_connection.dart';

/// Patient side: caregivers linked to (or invited by) the current patient.
/// Pushed at `/home/caregivers`.
class ManageCaregiversScreen extends ConsumerStatefulWidget {
  const ManageCaregiversScreen({super.key});

  @override
  ConsumerState<ManageCaregiversScreen> createState() =>
      _ManageCaregiversScreenState();
}

class _ManageCaregiversScreenState extends ConsumerState<ManageCaregiversScreen> {
  final _emailController = TextEditingController();
  final _relationshipController = TextEditingController();
  bool _isInviting = false;
  String? _inviteError;
  StateSetter? _setSheetState;

  @override
  void dispose() {
    _emailController.dispose();
    _relationshipController.dispose();
    super.dispose();
  }

  /// Rebuilds both the screen and the open invite sheet (if any).
  void _update(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
    _setSheetState?.call(() {});
  }

  Future<void> _handleInvite() async {
    final email = _emailController.text.trim();
    final relationship = _relationshipController.text.trim();

    if (email.isEmpty || relationship.isEmpty) {
      _update(() => _inviteError = 'Please fill in all fields');
      return;
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      _update(() => _inviteError = 'Please enter a valid email address');
      return;
    }

    _update(() {
      _isInviting = true;
      _inviteError = null;
    });
    try {
      // Patient inviting a caregiver -> the email belongs to the CAREGIVER.
      await ref.read(sendInvitationProvider({
        'caregiverEmail': email,
        'relationship': relationship,
      }).future);

      if (mounted) {
        Navigator.pop(context);
        _emailController.clear();
        _relationshipController.clear();
        showMfSnackBar(context, 'Invitation sent successfully', tone: MfTone.success);
      }
    } catch (e) {
      if (mounted) {
        _update(() => _inviteError = 'Error: ${e.toString()}');
        showMfSnackBar(context, 'Error: ${e.toString()}', tone: MfTone.danger);
      }
    } finally {
      _update(() => _isInviting = false);
    }
  }

  Future<void> _showAddCaregiverSheet() async {
    _inviteError = null;
    await showMfBottomSheet<void>(
      context,
      title: 'Invite caregiver',
      subtitle: 'Enter the email of the person you want to add as your caregiver. '
          'They will be notified instantly in an emergency.',
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          _setSheetState = setModalState;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: MfSpace.xs),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Email address',
                  hintText: 'e.g. name@example.com',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: MfSpace.md),
              TextField(
                controller: _relationshipController,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _isInviting ? null : _handleInvite(),
                decoration: const InputDecoration(
                  labelText: 'Relationship',
                  hintText: 'e.g. Son, Daughter, Spouse',
                  prefixIcon: Icon(Icons.people_outline_rounded),
                ),
              ),
              if (_inviteError != null) ...[
                const SizedBox(height: MfSpace.sm),
                MfInfoBanner(
                  icon: Icons.error_outline_rounded,
                  title: _inviteError!,
                  tone: MfTone.danger,
                ),
              ],
              const SizedBox(height: MfSpace.lg),
              MfPrimaryButton(
                label: 'Send invitation',
                icon: Icons.send_outlined,
                loading: _isInviting,
                onPressed: _handleInvite,
              ),
              const SizedBox(height: MfSpace.xs),
              MfTextButton(
                label: 'Cancel',
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          );
        },
      ),
    );
    _setSheetState = null;
  }

  Future<void> _handleRemove(CaregiverConnection connection) async {
    final isPending = connection.status.toUpperCase() == 'PENDING';
    final name = connection.caregiverName ?? connection.caregiverEmail ?? 'this caregiver';
    final confirmed = await showMfConfirmDialog(
      context,
      title: isPending ? 'Cancel invitation' : 'Remove caregiver',
      message: isPending
          ? 'Cancel the pending invitation for $name?'
          : 'Are you sure you want to remove $name? They will no longer be notified about your emergencies.',
      cancelLabel: 'Keep',
      confirmLabel: isPending ? 'Cancel invite' : 'Remove',
      destructive: true,
      icon: Icons.person_remove_outlined,
    );
    if (!confirmed) return;

    try {
      // DELETE /api/caregivers/:caregiverId (PATIENT only) expects the
      // caregiver's USER id; the patient is taken from the JWT.
      await ref.read(connectionRepositoryProvider).unlinkCaregiver(connection.caregiverId);
      ref.invalidate(allCaregiverLinksProvider);
      ref.invalidate(caregiverLinksProvider);
      if (!mounted) return;
      showMfSnackBar(context, isPending ? 'Invitation cancelled' : 'Caregiver removed');
    } catch (e) {
      if (!mounted) return;
      showMfSnackBar(context, 'Error: ${e.toString()}', tone: MfTone.danger);
    }
  }

  void _handleInvitationResponse(CaregiverConnection link, bool accept) async {
    try {
      await ref.read(respondToInvitationProvider({
        'invitationId': link.id,
        'accept': accept,
      }).future);
      ref.invalidate(allCaregiverLinksProvider);
      ref.invalidate(caregiverLinksProvider);
      if (mounted) {
        showMfSnackBar(
          context,
          accept ? 'Invitation accepted' : 'Invitation rejected',
          tone: accept ? MfTone.success : MfTone.neutral,
        );
      }
    } catch (e) {
      if (mounted) {
        showMfSnackBar(context, 'Error: ${e.toString()}', tone: MfTone.danger);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final linksAsync = ref.watch(allCaregiverLinksProvider);
    final hasLinks = linksAsync.valueOrNull?.isNotEmpty ?? false;

    return MfScaffold(
      title: 'My caregivers',
      subtitle: 'People notified in an emergency',
      actions: [
        MfIconButton(
          icon: Icons.person_add_alt_outlined,
          tooltip: 'Invite caregiver',
          onPressed: _showAddCaregiverSheet,
        ),
      ],
      bottomBar: hasLinks
          ? MfPrimaryButton(
              label: 'Invite caregiver',
              icon: Icons.person_add_alt_outlined,
              onPressed: _showAddCaregiverSheet,
            )
          : null,
      body: linksAsync.when(
        data: (links) {
          if (links.isEmpty) {
            return RefreshIndicator(
              onRefresh: () => ref.refresh(allCaregiverLinksProvider.future),
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: MfEmptyState(
                      icon: Icons.group_add_outlined,
                      title: 'No caregivers yet',
                      message: 'Add family members or friends to be notified instantly in case of an emergency.',
                      actionLabel: 'Invite caregiver',
                      actionIcon: Icons.person_add_alt_outlined,
                      onAction: _showAddCaregiverSheet,
                    ),
                  ),
                ),
              ),
            );
          }

          final currentUserId = ref.read(currentUserProvider).valueOrNull?.id ?? '';
          return RefreshIndicator(
            onRefresh: () => ref.refresh(allCaregiverLinksProvider.future),
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(MfSpace.gutter, MfSpace.md, MfSpace.gutter, MfSpace.lg),
              itemCount: links.length,
              separatorBuilder: (_, __) => const SizedBox(height: MfSpace.sm),
              itemBuilder: (ctx, i) {
                final link = links[i];
                return _CaregiverCard(
                  link: link,
                  currentUserId: currentUserId,
                  onDelete: () => _handleRemove(link),
                  onAccept: () => _handleInvitationResponse(link, true),
                  onReject: () => _handleInvitationResponse(link, false),
                );
              },
            ),
          );
        },
        loading: () => Padding(
          padding: const EdgeInsets.all(MfSpace.gutter),
          child: MfSkeleton.list(count: 3, itemHeight: 120),
        ),
        error: (e, _) => MfErrorState(
          title: 'Unable to load caregivers',
          message: e.toString(),
          onRetry: () => ref.invalidate(allCaregiverLinksProvider),
        ),
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
    required this.link,
    required this.currentUserId,
    required this.onDelete,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final status = link.status.toUpperCase();
    final isPending = status == 'PENDING';
    final isIncoming = isPending && link.requesterId != currentUserId;

    MfTone tone;
    String statusText;
    IconData statusIcon;
    switch (status) {
      case 'ACCEPTED':
        tone = MfTone.success;
        statusText = 'Active';
        statusIcon = Icons.check_circle_outline_rounded;
        break;
      case 'PENDING':
        tone = MfTone.warning;
        statusText = 'Pending';
        statusIcon = Icons.schedule_rounded;
        break;
      case 'REJECTED':
        tone = MfTone.danger;
        statusText = 'Rejected';
        statusIcon = Icons.block_rounded;
        break;
      default:
        tone = MfTone.neutral;
        statusText = link.status;
        statusIcon = Icons.info_outline_rounded;
    }

    return MfCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MfAvatar(name: link.caregiverName, size: 48),
              const SizedBox(width: MfSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      link.caregiverName ?? 'Unknown caregiver',
                      style: text.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (link.relationship.isNotEmpty)
                      Text(
                        link.relationship,
                        style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    const SizedBox(height: MfSpace.xxs),
                    Row(
                      children: [
                        Icon(Icons.email_outlined, size: 16, color: cs.onSurfaceVariant),
                        const SizedBox(width: MfSpace.xxs),
                        Expanded(
                          child: Text(
                            link.caregiverEmail ?? 'No email',
                            style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: MfSpace.xs),
              MfStatusChip(label: statusText, tone: tone, icon: statusIcon),
            ],
          ),
          if (isIncoming) ...[
            const SizedBox(height: MfSpace.xs),
            Text(
              'Wants to be your caregiver',
              style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: MfSpace.sm),
          const Divider(height: 1),
          const SizedBox(height: MfSpace.xs),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: MfSpace.xs,
            runSpacing: MfSpace.xs,
            children: isIncoming
                ? [
                    MfTextButton(
                      label: 'Reject',
                      icon: Icons.close_rounded,
                      tone: MfTone.danger,
                      onPressed: onReject,
                    ),
                    MfPrimaryButton(
                      label: 'Accept',
                      icon: Icons.check_rounded,
                      tone: MfTone.success,
                      expanded: false,
                      height: MfSize.minTouch,
                      onPressed: onAccept,
                    ),
                  ]
                : [
                    if (status == 'ACCEPTED')
                      Consumer(
                        builder: (context, ref, child) => MfTextButton(
                          label: 'Chat',
                          icon: Icons.chat_bubble_outline_rounded,
                          onPressed: () async {
                            try {
                              final room = await ref.read(getChatRoomForUserProvider(link.caregiverId).future);
                              if (context.mounted) {
                                context.push('/chat/${room.id}', extra: link.caregiverName);
                              }
                            } catch (e) {
                              if (context.mounted) {
                                showMfSnackBar(context, 'Could not open chat: $e', tone: MfTone.danger);
                              }
                            }
                          },
                        ),
                      ),
                    MfTextButton(
                      label: isPending ? 'Cancel invite' : 'Remove',
                      icon: Icons.person_remove_outlined,
                      tone: MfTone.danger,
                      onPressed: onDelete,
                    ),
                  ],
          ),
        ],
      ),
    );
  }
}
