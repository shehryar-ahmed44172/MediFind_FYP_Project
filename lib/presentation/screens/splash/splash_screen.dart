import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';

/// Continues the native Android splash without a jump: same white background
/// and the same mark in the exact centre of the screen. The mark then shrinks
/// while the wordmark and tagline fade in below it — and because mark and text
/// are one centred column, the group stays centred on the screen the whole
/// time. The session check runs at the same time, so the splash only stays as
/// long as it has to.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> with SingleTickerProviderStateMixin {
  /// Size of the Android 12+ splash icon box; the native splash draws the mark at this size.
  static const double _nativeIconBox = 288;
  static const double _settledBox = 200;
  static const Color _navy = Color(0xFF04364E);
  static const Color _teal = Color(0xFF2496A7);

  late final AnimationController _intro = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  late final Animation<double> _settle = CurvedAnimation(parent: _intro, curve: const Interval(0, 0.7, curve: Curves.easeOutCubic));
  late final Animation<double> _reveal = CurvedAnimation(parent: _intro, curve: const Interval(0.35, 1, curve: Curves.easeOut));
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (MediaQuery.of(context).disableAnimations) {
        _intro.value = 1;
      } else {
        _intro.forward();
      }
    });
    _start();
  }

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    // Resolve where to go while the intro plays; show the splash at least ~1.2 s
    final results = await Future.wait<Object?>([
      _resolveDestination(),
      Future<void>.delayed(const Duration(milliseconds: 1200)),
    ]);
    if (!mounted) return;
    final destination = results.first! as ({String path, Object? extra});
    setState(() => _leaving = true);
    await Future<void>.delayed(const Duration(milliseconds: 180));
    if (mounted) context.go(destination.path, extra: destination.extra);
  }

  /// Waits until the stored session has been read (the auth state stops loading).
  Future<bool> _loggedIn() {
    final current = ref.read(authStateProvider);
    if (!current.isLoading) return Future.value(current.value == true);
    final done = Completer<bool>();
    final sub = ref.listenManual<AsyncValue<bool>>(authStateProvider, (_, next) {
      if (!next.isLoading && !done.isCompleted) done.complete(next.value == true);
    });
    return done.future.timeout(const Duration(seconds: 5), onTimeout: () => false).whenComplete(sub.close);
  }

  Future<({String path, Object? extra})> _resolveDestination() async {
    try {
      if (await _loggedIn()) {
        // Fetch current user details with a timeout to prevent hanging on splash
        final user = await ref.read(currentUserProvider.future).timeout(const Duration(seconds: 10), onTimeout: () => null);
        if (user != null) {
          if (!user.isEmailVerified) return (path: '/verify-email', extra: {'email': user.email});
          if (user.role == 'CAREGIVER') return (path: '/caregiver', extra: null);
          if (user.role == 'RESPONDER') return (path: '/responder', extra: null);
          return (path: '/home', extra: null);
        }
        // Logged in but no profile: the session is stale, clear it directly.
        debugPrint('⚠️ Splash: User profile is null but authState is true. Clearing stale session.');
        await _clearSession();
      }
    } catch (e) {
      debugPrint('⚠️ Splash: Initial profile fetch failed. Forcing logout to clear stale session.');
      await _clearSession();
    }
    return (path: '/login', extra: null);
  }

  Future<void> _clearSession() async {
    try {
      final authRepo = await ref.read(authRepositoryProvider.future);
      await authRepo.logout();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.3);

    // Brand splash: always white with dark status bar icons, like the native splash
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent, systemNavigationBarColor: Colors.white),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: AnimatedOpacity(
          opacity: _leaving ? 0 : 1,
          duration: const Duration(milliseconds: 180),
          child: AnimatedBuilder(
            animation: _intro,
            builder: (context, _) {
              // Mark: starts at the size the native splash drew it, then shrinks.
              final box = _nativeIconBox - (_nativeIconBox - _settledBox) * _settle.value;
              return Stack(
                children: [
                  // Mark + wordmark as ONE centred column, so the group never
                  // drifts off centre while the text appears.
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: box,
                            height: box,
                            child: Semantics(
                              label: 'MediFind',
                              image: true,
                              child: Image.asset('assets/logos/medifind_splash_mark.png', excludeFromSemantics: true),
                            ),
                          ),
                          // Grows with the reveal so the column stays balanced
                          ClipRect(
                            child: Align(
                              alignment: Alignment.topCenter,
                              heightFactor: _reveal.value,
                              child: Opacity(
                                opacity: _reveal.value,
                                child: Column(
                                  children: [
                                    Text.rich(
                                      const TextSpan(children: [
                                        TextSpan(text: 'MEDI', style: TextStyle(color: _teal)),
                                        TextSpan(text: 'FIND', style: TextStyle(color: _navy)),
                                      ]),
                                      textScaler: TextScaler.linear(textScale),
                                      style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: 2),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Emergency help, without hearing or speaking',
                                      textAlign: TextAlign.center,
                                      textScaler: TextScaler.linear(textScale),
                                      style: TextStyle(fontSize: 14, color: _navy.withValues(alpha: 0.65), fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Slim progress bar near the bottom
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: MediaQuery.paddingOf(context).bottom + 56,
                    child: Opacity(
                      opacity: _reveal.value,
                      child: Center(
                        child: Semantics(
                          liveRegion: true,
                          label: 'Loading MediFind',
                          child: SizedBox(
                            width: 96,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: LinearProgressIndicator(
                                minHeight: 3,
                                color: _teal,
                                backgroundColor: _teal.withValues(alpha: 0.15),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
