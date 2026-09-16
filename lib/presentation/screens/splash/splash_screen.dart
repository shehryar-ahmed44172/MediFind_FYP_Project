import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/design_system/design_system.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();

    // Short, restrained fade-in of the logo and loader.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _visible = true);
    });

    _handleNavigation();
  }

  Future<void> _handleNavigation() async {
    // Wait for splash animation minimum duration
    await Future.delayed(const Duration(milliseconds: 3500));
    
    if (!mounted) return;

    try {
      // Check if user is logged in
      final authState = ref.read(authStateProvider);
      
      if (authState.value == true) {
        // Fetch current user details with a timeout to prevent hanging on splash
        final user = await ref.read(currentUserProvider.future).timeout(
          const Duration(seconds: 10),
          onTimeout: () => null,
        );
        if (!mounted) return;

        if (user != null) {
          // Check if email is verified
          if (!user.isEmailVerified) {
            context.go('/verify-email', extra: {'email': user.email});
            return;
          }

          // Navigate based on role if verified
          if (user.role == 'CAREGIVER') {
            context.go('/caregiver');
          } else if (user.role == 'RESPONDER') {
            context.go('/responder');
          } else {
            context.go('/home');
          }
          return;
        } else {
          // If user is null but authState is true, wipe the stale session directly.
          // We call the repo rather than logoutProvider to avoid any provider caching
          // or lifecycle issues that could silently skip the actual token clearing.
          debugPrint('⚠️ Splash: User profile is null but authState is true. Clearing stale session.');
          try {
            final authRepo = await ref.read(authRepositoryProvider.future);
            await authRepo.logout();
          } catch (_) {}
        }
      }

      // Default fallback to login
      if (mounted) context.go('/login');
    } catch (e) {
      debugPrint('⚠️ Splash: Initial profile fetch failed. Forcing logout to clear stale session.');
      // Clear tokens directly via the repository to guarantee a clean state.
      try {
        final authRepo = await ref.read(authRepositoryProvider.future);
        await authRepo.logout();
      } catch (_) {}
      if (mounted) context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final duration = MfMotion.of(context);

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final logoWidth = math.min(constraints.maxWidth * 0.5, 220.0);
            return AnimatedOpacity(
              opacity: _visible ? 1 : 0,
              duration: duration,
              curve: Curves.easeOut,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: MfSpace.gutter),
                child: Column(
                  children: [
                    const Spacer(flex: 3),
                    Semantics(
                      label: 'MediFind',
                      image: true,
                      child: Image.asset(
                        'assets/logos/medifind_logo_full.png',
                        width: logoWidth,
                        fit: BoxFit.contain,
                        excludeFromSemantics: true,
                      ),
                    ),
                    const Spacer(flex: 2),
                    Semantics(
                      liveRegion: true,
                      label: 'Loading MediFind',
                      child: SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: cs.primary),
                      ),
                    ),
                    const SizedBox(height: MfSpace.md),
                    Text(
                      'Secure. Reliable. Immediate.',
                      textAlign: TextAlign.center,
                      style: text.labelMedium?.copyWith(color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(height: MfSpace.xxl),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
