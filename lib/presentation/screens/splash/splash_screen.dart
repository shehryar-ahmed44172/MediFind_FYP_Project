import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/responsive.dart';
import '../../theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _loaderController;
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _loaderOpacity;

  @override
  void initState() {
    super.initState();
    
    // Logo entrance animation (Scale + Fade)
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _logoScale = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOutBack),
    );

    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: const Interval(0.0, 0.8, curve: Curves.easeIn)),
    );
    
    // Loader fade in animation
    _loaderController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    
    _loaderOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _loaderController, curve: Curves.easeIn),
    );
    
    // Start animations sequence
    _logoController.forward();
    Timer(const Duration(milliseconds: 800), () {
      if (mounted) _loaderController.forward();
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
        }
      }
      
      // Default fallback to login
      context.go('/login');
    } catch (e) {
      // On error, fallback to login
      context.go('/login');
    }
  }

  @override
  void dispose() {
    _logoController.dispose();
    _loaderController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        // Premium subtle gradient background
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white,
              AppColors.primary.withOpacity(0.05),
              Colors.white,
            ],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(flex: 3),
            
            // Animated Logo
            AnimatedBuilder(
              animation: _logoController,
              builder: (context, child) {
                return Opacity(
                  opacity: _logoOpacity.value,
                  child: Transform.scale(
                    scale: _logoScale.value,
                    child: child,
                  ),
                );
              },
              child: Image.asset(
                'assets/logos/Medifind_New_Logo-removebg-preview.png',
                width: 81.wp, 
                fit: BoxFit.fitWidth,
              ),
            ),
            
            const Spacer(flex: 2),
            
            // Fade in Loader and Text
            FadeTransition(
              opacity: _loaderOpacity,
              child: Column(
                children: [
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                      strokeWidth: 2.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'SECURE • RELIABLE • IMMEDIATE',
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 10,
                      color: AppColors.primary.withOpacity(0.6),
                      letterSpacing: 4.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
