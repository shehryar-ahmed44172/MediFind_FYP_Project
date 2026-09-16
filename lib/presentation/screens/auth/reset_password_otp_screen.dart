import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/design_system/design_system.dart';
import 'widgets/auth_common.dart';

class ResetPasswordOtpScreen extends ConsumerStatefulWidget {
  final String email;

  const ResetPasswordOtpScreen({
    super.key,
    required this.email,
  });

  @override
  ConsumerState<ResetPasswordOtpScreen> createState() => _ResetPasswordOtpScreenState();
}

class _ResetPasswordOtpScreenState extends ConsumerState<ResetPasswordOtpScreen> {
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  bool _isResending = false;
  String? _codeError;

  // Resend cooldown — 60 s so the user can't spam the API
  int _resendCooldown = 60;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    // Focus the first box immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNodes[0].requestFocus();
    });

    // If no email was passed (shouldn't happen, but guard anyway), go back
    if (widget.email.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/forgot-password');
      });
      return;
    }

    _startCooldown();
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final n in _focusNodes) {
      n.dispose();
    }
    _cooldownTimer?.cancel();
    super.dispose();
  }

  // ── Cooldown timer ─────────────────────────────────────────────────────────
  void _startCooldown() {
    _resendCooldown = 60;
    if (mounted) setState(() {});
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _resendCooldown--;
        if (_resendCooldown <= 0) t.cancel();
      });
    });
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  String get _currentOtp => _controllers.map((c) => c.text.trim()).join();

  void _clearOtp() {
    for (final c in _controllers) {
      c.clear();
    }
    if (mounted) _focusNodes[0].requestFocus();
  }

  String _maskEmail(String email) {
    try {
      final parts = email.split('@');
      if (parts.length != 2) return email;
      final name = parts[0];
      final domain = parts[1];
      if (name.length <= 2) return '${name[0]}***@$domain';
      return '${name[0]}${'*' * (name.length - 2)}${name[name.length - 1]}@$domain';
    } catch (_) {
      return email;
    }
  }

  // ── Actions ────────────────────────────────────────────────────────────────
  void _onContinue() {
    final otp = _currentOtp;
    if (otp.length < 6) {
      setState(() => _codeError = 'Enter all 6 digits of the code.');
      final firstEmpty = _controllers.indexWhere((c) => c.text.isEmpty);
      _focusNodes[firstEmpty < 0 ? 0 : firstEmpty].requestFocus();
      return;
    }

    // Pass email + otp to the next screen
    context.go('/reset-new-password', extra: {
      'email': widget.email,
      'otp': otp,
    });
  }

  Future<void> _resendCode() async {
    if (_resendCooldown > 0 || _isResending) return;

    _clearOtp();
    setState(() {
      _isResending = true;
      _codeError = null;
    });

    try {
      await ref.read(forgotPasswordProvider(widget.email).future);
      if (!mounted) return;
      _startCooldown();
      showMfSnackBar(context, 'New code sent to ${_maskEmail(widget.email)}', tone: MfTone.success);
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceAll('Exception:', '').trim();
      showMfSnackBar(context, msg.isNotEmpty ? msg : 'Failed to resend. Please try again.', tone: MfTone.danger);
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  void _onDigitChanged(int index, String value) {
    if (_codeError != null) setState(() => _codeError = null);
    if (value.isNotEmpty) {
      if (index < 5) {
        _focusNodes[index + 1].requestFocus();
      } else {
        // Last box — dismiss keyboard and auto-continue
        _focusNodes[index].unfocus();
        Future.delayed(const Duration(milliseconds: 80), () {
          if (mounted) _onContinue();
        });
      }
    } else if (index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return MfScaffold(
      title: 'Enter reset code',
      onBack: () => context.go('/forgot-password'),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: MfSpace.gutter, vertical: MfSpace.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AuthStepIntro(
                    icon: Icons.mark_email_unread_outlined,
                    title: 'Check your email',
                    messageWidget: Text.rich(
                      TextSpan(
                        text: 'We sent a 6-digit code to\n',
                        children: [
                          TextSpan(
                            text: _maskEmail(widget.email),
                            style: text.bodyMedium?.copyWith(color: cs.onSurface, fontWeight: FontWeight.w600),
                          ),
                          const TextSpan(text: '\nEnter the code below to continue.'),
                        ],
                      ),
                      textAlign: TextAlign.center,
                      style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ),
                  const SizedBox(height: MfSpace.lg),

                  // ── 6-box OTP input ─────────────────────────────────────
                  AuthOtpRow(
                    controllers: _controllers,
                    focusNodes: _focusNodes,
                    onChanged: _onDigitChanged,
                    // On tap, clear the current box so user can retype
                    onTap: (i) => _controllers[i].clear(),
                  ),
                  const SizedBox(height: MfSpace.sm),
                  if (_codeError != null)
                    Semantics(
                      liveRegion: true,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline_rounded, size: 18, color: cs.error),
                          const SizedBox(width: MfSpace.xxs),
                          Flexible(
                            child: Text(_codeError!, style: text.bodySmall?.copyWith(color: cs.error)),
                          ),
                        ],
                      ),
                    )
                  else
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.schedule_rounded, size: 16, color: cs.onSurfaceVariant),
                        const SizedBox(width: MfSpace.xxs),
                        Text('Code expires in 15 minutes',
                            style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                      ],
                    ),
                  const SizedBox(height: MfSpace.lg),

                  MfPrimaryButton(
                    label: 'Continue',
                    icon: Icons.arrow_forward_rounded,
                    onPressed: _onContinue,
                  ),
                  const SizedBox(height: MfSpace.md),

                  // ── Resend section ──────────────────────────────────────
                  Text(
                    "Didn't receive it?",
                    textAlign: TextAlign.center,
                    style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: MfSpace.xxs),
                  Center(
                    child: MfSecondaryButton(
                      expanded: false,
                      icon: Icons.refresh_rounded,
                      loading: _isResending,
                      label: _resendCooldown > 0
                          ? 'Resend code in ${_resendCooldown}s'
                          : (_isResending ? 'Sending' : 'Resend code'),
                      onPressed: _resendCooldown > 0 ? null : _resendCode,
                    ),
                  ),
                  const SizedBox(height: MfSpace.xs),
                  Center(
                    child: MfTextButton(
                      label: 'Use a different email address',
                      onPressed: () => context.go('/forgot-password'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
