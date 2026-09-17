import 'package:flutter/material.dart';

import '../../../services/call/call_service.dart';
import '../design_system/design_system.dart';

/// Starts an in-app call and tells the user when it cannot start
/// (not allowed, other person busy, offline, permission denied).
Future<void> startInAppCall(BuildContext context, CallPeer peer, CallMedia media) async {
  final error = await CallService.instance.startCall(peer, media);
  if (error != null && context.mounted) {
    showMfSnackBar(context, error, tone: MfTone.danger);
  }
}
