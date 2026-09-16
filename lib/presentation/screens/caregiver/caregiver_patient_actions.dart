import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/chat_provider.dart';
import '../../widgets/design_system/design_system.dart';

/// Shared caregiver → patient actions used by the Patients tab and the
/// My patients screen.

/// Opens (or creates) the 1:1 chat room with [patientId] and pushes `/chat/:roomId`.
Future<void> openCaregiverPatientChat(
  BuildContext context,
  WidgetRef ref, {
  required String patientId,
  String? patientName,
}) async {
  try {
    final room = await ref.read(getChatRoomForUserProvider(patientId).future);
    if (context.mounted) {
      context.push('/chat/${room.id}', extra: patientName ?? 'Patient');
    }
  } catch (e) {
    debugPrint('Caregiver: could not open chat: $e');
    if (context.mounted) {
      showMfSnackBar(context, 'Could not open the chat. Please try again.', tone: MfTone.danger);
    }
  }
}

/// Opens the linked patient's profile.
void openCaregiverPatientProfile(BuildContext context, String patientId) {
  context.push('/caregiver/my-patients/patient-profile/$patientId');
}

/// Status chip for a caregiver link.
Widget caregiverLinkStatusChip({required String linkStatus, required bool sosActive}) {
  if (sosActive) {
    return const MfStatusChip(label: 'SOS active', tone: MfTone.danger, icon: Icons.sos_rounded);
  }
  switch (linkStatus) {
    case 'PENDING':
      return const MfStatusChip(label: 'Pending', tone: MfTone.warning, icon: Icons.schedule_rounded);
    case 'REJECTED':
      return const MfStatusChip(label: 'Declined', tone: MfTone.neutral, icon: Icons.block_rounded);
    default:
      return const MfStatusChip(label: 'Safe', tone: MfTone.success, icon: Icons.verified_user_outlined);
  }
}
