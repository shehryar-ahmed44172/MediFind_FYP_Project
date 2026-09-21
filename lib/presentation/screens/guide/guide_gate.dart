import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/router.dart';
import '../../../services/guide/guide_prefs.dart';
import '../../providers/auth_provider.dart';

/// Opens the welcome tour once, the first time an account reaches a home
/// screen. Mounted above the navigator (like the deaf alert layer) so it
/// works for every role without touching each home screen.
///
/// It never interrupts anything: the tour is only pushed while the user is
/// sitting on a role's home tab, so an SOS, a call or a tracking screen is
/// never covered.
class GuideGate extends ConsumerStatefulWidget {
  final Widget child;
  const GuideGate({super.key, required this.child});

  @override
  ConsumerState<GuideGate> createState() => _GuideGateState();
}

class _GuideGateState extends ConsumerState<GuideGate> {
  static const _homeRoutes = {'/home', '/caregiver', '/responder'};
  String? _checkedUserId;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    if (user != null && user.id != _checkedUserId) {
      _checkedUserId = user.id;
      _maybeShow(user.id);
    }
    return widget.child;
  }

  Future<void> _maybeShow(String userId) async {
    if (await GuidePrefs.hasSeen(userId)) return;
    // Wait for the current frame so the home screen is in place first.
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted || _checkedUserId != userId) return;

    final router = AppRouter.router;
    final location = router.routeInformationProvider.value.uri.path;
    if (!_homeRoutes.contains(location)) return;

    router.push('/welcome-guide');
  }
}
