import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../domain/entities/chat_message.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../widgets/design_system/design_system.dart';

/// True when the room belongs to an emergency (patient ↔ responder).
bool chatRoomIsEmergency(ChatRoom room) =>
    room.emergencyId != null || room.responderId != null || (room.roomType ?? '').toUpperCase().contains('EMERGENCY');

/// The other participant of [room] as seen by a user with [role].
///
/// Patients see their caregiver or, in emergency rooms, the responder.
/// Caregivers and responders see the patient.
Map<String, dynamic>? chatRoomOtherUser(ChatRoom room, String? role) {
  switch ((role ?? '').toUpperCase()) {
    case 'PATIENT':
      return room.responder ?? room.caregiver;
    default:
      return room.patient;
  }
}

/// Display name for the other participant, never a bare "User".
String chatRoomDisplayName(ChatRoom room, String? role) {
  final name = (chatRoomOtherUser(room, role)?['fullName'] as String?)?.trim();
  if (name != null && name.isNotEmpty) return name;
  final isPatient = (role ?? '').toUpperCase() == 'PATIENT';
  if (chatRoomIsEmergency(room)) return isPatient ? 'Responder' : 'Patient';
  return isPatient ? 'Caregiver' : 'Patient';
}

String _lastMessagePreview(ChatMessage? m) {
  if (m == null) return 'No messages yet';
  switch (m.messageType) {
    case MessageType.IMAGE:
      return 'Photo';
    case MessageType.AUDIO:
    case MessageType.VOICE_ALERT:
      return 'Voice message';
    case MessageType.DOCUMENT:
      return 'Document: ${m.content}';
    case MessageType.TEXT:
      return m.content.contains('google.com/maps') ? 'Shared location' : m.content;
  }
}

String _formatRoomTime(DateTime time) {
  final local = time.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(local.year, local.month, local.day);
  if (day == today) return DateFormat('h:mm a').format(local);
  if (today.difference(day).inDays == 1) return 'Yesterday';
  if (today.difference(day).inDays < 7) return DateFormat('EEE').format(local);
  return DateFormat('d MMM').format(local);
}

class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomsAsync = ref.watch(chatRoomsProvider);
    final role = ref.watch(currentUserProvider).valueOrNull?.role;

    return roomsAsync.when(
      data: (rooms) => RefreshIndicator(
        onRefresh: () => ref.refresh(chatRoomsProvider.future),
        child: rooms.isEmpty
            ? LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  // Scrollable so pull-to-refresh works on the empty state.
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: const MfEmptyState(
                      icon: Icons.forum_outlined,
                      title: 'No conversations yet',
                      message: 'Chats with linked caregivers, patients and emergency responders will appear here.',
                    ),
                  ),
                ),
              )
            : ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(MfSpace.gutter, MfSpace.md, MfSpace.gutter, MfSpace.xl),
                itemCount: rooms.length,
                separatorBuilder: (_, __) => const SizedBox(height: MfSpace.xs),
                itemBuilder: (context, index) {
                  final room = rooms[index];
                  final other = chatRoomOtherUser(room, role);
                  final name = chatRoomDisplayName(room, role);
                  final lastMessage = room.messages?.isNotEmpty == true ? room.messages!.first : null;
                  return _ChatRoomTile(
                    name: name,
                    imageUrl: other?['profileImageUrl'] as String?,
                    preview: _lastMessagePreview(lastMessage),
                    time: lastMessage?.createdAt ?? room.updatedAt,
                    isEmergency: chatRoomIsEmergency(room),
                    onTap: () => context.push('/chat/${room.id}', extra: name),
                  );
                },
              ),
      ),
      loading: () => Padding(
        padding: const EdgeInsets.all(MfSpace.gutter),
        child: MfSkeleton.list(count: 5, itemHeight: 72),
      ),
      error: (e, _) => MfErrorState(
        title: 'Could not load conversations',
        message: 'Check your connection and try again.',
        onRetry: () => ref.invalidate(chatRoomsProvider),
      ),
    );
  }
}

class _ChatRoomTile extends StatelessWidget {
  final String name;
  final String? imageUrl;
  final String preview;
  final DateTime time;
  final bool isEmergency;
  final VoidCallback onTap;

  const _ChatRoomTile({
    required this.name,
    required this.imageUrl,
    required this.preview,
    required this.time,
    required this.isEmergency,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final timeLabel = _formatRoomTime(time);
    return MfCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: MfSpace.sm, vertical: MfSpace.sm),
      semanticLabel: '${isEmergency ? 'Emergency chat with' : 'Chat with'} $name. Last message: $preview. $timeLabel',
      child: ExcludeSemantics(
        child: Row(
          children: [
            MfAvatar(imageUrl: imageUrl, name: name, size: 48),
            const SizedBox(width: MfSpace.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(name, style: text.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      const SizedBox(width: MfSpace.xs),
                      Text(timeLabel, style: text.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  if (isEmergency) ...[
                    const SizedBox(height: MfSpace.xxs),
                    const MfStatusChip(
                      label: 'Emergency',
                      icon: Icons.emergency_outlined,
                      tone: MfTone.primary,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: MfSpace.xxs),
            Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
