import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/extensions/extensions.dart';
import '../../../core/utils/utils.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/design_system/design_system.dart';

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
        showMfSnackBar(
          context,
          'Please verify your email before logging in.',
          tone: MfTone.warning,
        );
        context.go('/verify-email', extra: {'email': _emailController.text.trim()});

        // ── Warning: 1–2 attempts remaining ─────────────────────────────────
      } else if (raw.toLowerCase().contains('warning') &&
          raw.toLowerCase().contains('attempt')) {
        _showAttemptsWarningBar(raw);

        // ── Generic invalid credentials ──────────────────────────────────────
      } else {
        showMfSnackBar(
          context,
          raw.contains('credentials')
              ? 'Incorrect email or password. Please try again.'
              : raw,
          tone: MfTone.danger,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Lockout modal ──────────────────────────────────────────────────────────
  void _showLockedModal(String errorMessage) {
    // Extract "X minutes" from the backend message
    final minuteMatch = RegExp(r'(\d+)\s*minute').firstMatch(errorMessage);
    final minutesRemaining =
        minuteMatch != null ? int.tryParse(minuteMatch.group(1) ?? '') : null;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        final text = Theme.of(ctx).textTheme;
        return AlertDialog(
          icon: Icon(Icons.lock_person_rounded, size: 32, color: cs.error),
          title: const Text('Account temporarily locked', textAlign: TextAlign.center),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Your account has been locked due to 5 consecutive failed login attempts.',
                  textAlign: TextAlign.center,
                  style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
                if (minutesRemaining != null) ...[
                  const SizedBox(height: MfSpace.md),
                  MfInfoBanner(
                    icon: Icons.timer_outlined,
                    tone: MfTone.warning,
                    title:
                        'Try again in $minutesRemaining minute${minutesRemaining == 1 ? '' : 's'}',
                  ),
                ],
                const SizedBox(height: MfSpace.md),
                Text(
                  'If you forgot your password, you can reset it now without waiting.',
                  textAlign: TextAlign.center,
                  style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(MfSpace.md, 0, MfSpace.md, MfSpace.md),
          actions: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                MfSecondaryButton(
                  label: 'Reset my password',
                  icon: Icons.lock_reset_rounded,
                  onPressed: () {
                    Navigator.pop(ctx);
                    context.go('/forgot-password');
                  },
                ),
                const SizedBox(height: MfSpace.xs),
                MfPrimaryButton(
                  label: 'I understand',
                  height: MfSize.minTouch,
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  // ── Attempts-remaining warning ─────────────────────────────────────────────
  void _showAttemptsWarningBar(String message) {
    // Extract number from "X attempts remaining"
    final match = RegExp(r'(\d+)\s*attempt').firstMatch(message);
    final remaining = match != null ? int.tryParse(match.group(1) ?? '') : null;

    final isLastAttempt = remaining == 1;

    showMfSnackBar(
      context,
      isLastAttempt
          ? 'Last attempt. Your account will be locked for 30 minutes if you fail again.'
          : 'Incorrect password. $remaining attempts remaining before lockout.',
      tone: isLastAttempt ? MfTone.danger : MfTone.warning,
      duration: const Duration(seconds: 5),
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
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: MfSpace.gutter, vertical: MfSpace.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: _formKey,
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Logo ─────────────────────────────────────────────
                      Center(
                        child: Image.asset(
                          'assets/logos/medifind_logo_full.png',
                          height: 132,
                          fit: BoxFit.contain,
                          semanticLabel: 'MediFind',
                        ),
                      ),
                      const SizedBox(height: MfSpace.lg),
                      Semantics(
                        header: true,
                        child: Text('Welcome back', style: text.headlineSmall),
                      ),
                      const SizedBox(height: MfSpace.xxs),
                      Text(
                        'Log in to continue to MediFind.',
                        style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                      ),
                      const SizedBox(height: MfSpace.lg),

                      const MfSectionTitle('Account details'),
                      const SizedBox(height: MfSpace.xs),

                      // ── Email ────────────────────────────────────────────
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email_outlined),
                          errorMaxLines: 2,
                        ),
                        validator: (value) => StringUtils.validateEmail(value),
                      ),
                      const SizedBox(height: MfSpace.md),

                      // ── Password ─────────────────────────────────────────
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.password],
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        onFieldSubmitted: (_) {
                          if (!_isLoading) _login();
                        },
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          suffixIcon: IconButton(
                            tooltip: _obscurePassword ? 'Show password' : 'Hide password',
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
                      const SizedBox(height: MfSpace.xxs),

                      Align(
                        alignment: Alignment.centerRight,
                        child: MfTextButton(
                          label: 'Forgot password?',
                          onPressed: () => context.go('/forgot-password'),
                        ),
                      ),
                      const SizedBox(height: MfSpace.md),

                      MfPrimaryButton(
                        label: _isLoading ? 'Logging in' : 'Log in',
                        loading: _isLoading,
                        onPressed: _login,
                      ),
                      const SizedBox(height: MfSpace.lg),

                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            "Don't have an account?",
                            style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                          ),
                          MfTextButton(
                            label: 'Register',
                            onPressed: () => context.go('/select-role'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
