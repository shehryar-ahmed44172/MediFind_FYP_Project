import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/extensions/extensions.dart';
import '../../../core/utils/utils.dart';
import '../../../core/utils/responsive.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final params = LoginParams(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      await ref.read(loginProvider(params).future);

      if (!mounted) return;
      final role = await ref.read(currentUserRoleProvider.future);
      if (mounted) _navigateByRole(role);

    } catch (e) {
      if (!mounted) return;
      final raw = e.toString().replaceAll('Exception:', '').trim();

      // ── Account locked ───────────────────────────────────────────────────
      if (raw.toLowerCase().contains('locked') ||
          raw.toLowerCase().contains('temporarily locked')) {
        _showLockedModal(raw);

      // ── Email not verified ───────────────────────────────────────────────
      } else if (raw.toLowerCase().contains('verify your email') ||
                 raw.toLowerCase().contains('email') && raw.toLowerCase().contains('verif')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please verify your email before logging in.'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.go('/verify-email',
            extra: {'email': _emailController.text.trim()});

      // ── Warning: 1–2 attempts remaining ─────────────────────────────────
      } else if (raw.toLowerCase().contains('warning') &&
                 raw.toLowerCase().contains('attempt')) {
        _showAttemptsWarningBar(raw);

      // ── Generic invalid credentials ──────────────────────────────────────
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    raw.contains('credentials')
                        ? 'Incorrect email or password. Please try again.'
                        : raw,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Lockout modal ──────────────────────────────────────────────────────────
  void _showLockedModal(String errorMessage) {
    // Extract "X minutes" from the backend message
    final minuteMatch =
        RegExp(r'(\d+)\s*minute').firstMatch(errorMessage);
    final minutesRemaining =
        minuteMatch != null ? int.tryParse(minuteMatch.group(1) ?? '') : null;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: EdgeInsets.zero,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Red header band ────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 28),
              decoration: const BoxDecoration(
                color: Color(0xFFFFEBEB),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.lock_person_rounded,
                      size: 48,
                      color: Colors.red.shade700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Account Temporarily Locked',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade800,
                    ),
                  ),
                ],
              ),
            ),

            // ── Body ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              child: Column(
                children: [
                  Text(
                    'Your account has been locked due to 5 consecutive failed login attempts.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (minutesRemaining != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 20),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.timer_outlined,
                              color: Colors.orange.shade700, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Try again in $minutesRemaining minute${minutesRemaining == 1 ? '' : 's'}',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  Text(
                    'If you forgot your password, you can reset it now without waiting.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade500,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),

            // ── Actions ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        context.go('/forgot-password');
                      },
                      icon: const Icon(Icons.lock_reset_rounded),
                      label: const Text('Reset My Password'),
                      style: OutlinedButton.styleFrom(
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                        foregroundColor: Colors.white,
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: const Text(
                        'I Understand',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Attempts-remaining warning ─────────────────────────────────────────────
  void _showAttemptsWarningBar(String message) {
    // Extract number from "X attempts remaining"
    final match = RegExp(r'(\d+)\s*attempt').firstMatch(message);
    final remaining = match != null ? int.tryParse(match.group(1) ?? '') : null;

    final isLastAttempt = remaining == 1;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 5),
        backgroundColor:
            isLastAttempt ? Colors.red.shade800 : Colors.orange.shade700,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        content: Row(
          children: [
            Icon(
              isLastAttempt
                  ? Icons.warning_rounded
                  : Icons.info_outline_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isLastAttempt
                    ? '⚠️ Last attempt! Your account will be locked for 30 minutes if you fail again.'
                    : 'Incorrect password. $remaining attempts remaining before lockout.',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // nav by role
  void _navigateByRole(String? role) {
    switch (role?.toUpperCase()) {
      case 'RESPONDER':
        context.go('/responder');
        break;
      case 'CAREGIVER':
        context.go('/caregiver');
        break;
      default:
        context.go('/home'); 
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 6.wp, vertical: 2.hp),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: 6.hp),

                // header
                Semantics(
                  header: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/logos/Medifind_New_Logo-removebg-preview.png',
                        height: 18.hp,
                        fit: BoxFit.contain,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 5.hp),

                // email field
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (value) => StringUtils.validateEmail(value),
                ),
                SizedBox(height: 2.hp),

                // pass field
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (value) {
                    if (value.isNullOrEmpty) return 'Password is required';
                    return null;
                  },
                ),
                SizedBox(height: 1.hp),

                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => context.go('/forgot-password'),
                    child: Text('Forgot Password?', style: TextStyle(fontSize: 1.6.hp)),
                  ),
                ),
                SizedBox(height: 2.hp),

                // login btn with neumorphic effect
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryLight.withOpacity(0.4),
                        blurRadius: 12,
                        offset: const Offset(4, 4),
                      ),
                      const BoxShadow(
                        color: Colors.white,
                        blurRadius: 10,
                        offset: Offset(-4, -4),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 2.hp),
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(
                            'Login',
                            style: TextStyle(
                              fontSize: 1.8.hp,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
                SizedBox(height: 3.hp),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("Don't have an account? ", style: TextStyle(fontSize: 1.6.hp)),
                    TextButton(
                      onPressed: () => context.go('/select-role'),
                      child: Text('Register', style: TextStyle(fontSize: 1.6.hp, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),

              ],
            ),
          ),
        ),
      ),
    );
  }
}
