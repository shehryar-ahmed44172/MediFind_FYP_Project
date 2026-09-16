import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/design_system/design_system.dart';
import 'widgets/auth_common.dart';

class EmailVerificationScreen extends ConsumerStatefulWidget {
  final String email;

  const EmailVerificationScreen({
    super.key,
    required this.email,
  });

  @override
  ConsumerState<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends ConsumerState<EmailVerificationScreen> {
  static const _cooldownSeconds = 60;

  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  bool _isLoading = false;
  bool _isResending = false;

  /// Inline error under the code boxes (wrong / expired code).
  String? _codeError;

  int _resendCooldown = 0;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNodes[0].requestFocus();
    });
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _resendCooldown = _cooldownSeconds);
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

  void _clearCode() {
    for (final c in _controllers) {
      c.clear();
    }
    _focusNodes[0].requestFocus();
  }

  Future<void> _onVerify() async {
    if (_isLoading) return;
    final otp = _controllers.map((c) => c.text).join();
    if (otp.length < 6) {
      setState(() => _codeError = 'Enter all 6 digits of the verification code.');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _codeError = null;
    });
    try {
      await ref.read(verifyEmailProvider(VerifyEmailParams(email: widget.email, otp: otp)).future);
      if (mounted) {
        await showAuthMessageDialog(
          context,
          icon: Icons.verified_outlined,
          tone: MfTone.success,
          title: 'Account verified',
          message: 'Your account has been verified. You can now use MediFind.',
          buttonLabel: 'Continue',
          onConfirm: () => context.go('/splash'),
        );
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString().replaceAll('Exception:', '').trim();
        setState(() => _codeError = msg.isNotEmpty ? msg : 'Invalid or expired code. Please try again.');
        _clearCode();
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _onResend() async {
    if (_resendCooldown > 0 || _isResending) return;
    setState(() => _isResending = true);
    try {
      await ref.read(resendOTPProvider(widget.email).future);
      if (mounted) {
        _startCooldown();
        setState(() => _codeError = null);
        _clearCode();
        showMfSnackBar(context, 'A new code has been sent to your email.', tone: MfTone.success);
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString().replaceAll('Exception:', '').trim();
        showMfSnackBar(
          context,
          msg.isNotEmpty ? msg : 'Unable to resend the code. Please wait a moment and try again.',
          tone: MfTone.danger,
        );
      }
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  String _maskEmail(String email) {
    try {
      final parts = email.split('@');
      if (parts.length != 2) return email;
      final username = parts[0];
      final domain = parts[1];
      if (username.length <= 2) return '${username[0]}***@$domain';
      return '${username[0]}${'*' * (username.length - 2)}${username[username.length - 1]}@$domain';
    } catch (e) {
      return email;
    }
  }

  void _onDigitChanged(int index, String value) {
    if (_codeError != null) setState(() => _codeError = null);
    if (value.isNotEmpty && index < 5) {
      _focusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
    if (_controllers.every((c) => c.text.isNotEmpty)) {
      _onVerify();
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return MfScaffold(
      title: 'Verify email',
      onBack: () {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        } else {
          context.go('/login');
        }
      },
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
                    title: 'Enter verification code',
                    messageWidget: Text.rich(
                      TextSpan(
                        text: 'We sent a 6-digit code to\n',
                        children: [
                          TextSpan(
                            text: _maskEmail(widget.email),
                            style: text.bodyMedium?.copyWith(color: cs.onSurface, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                      style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ),
                  const SizedBox(height: MfSpace.lg),
                  AuthOtpRow(
                    controllers: _controllers,
                    focusNodes: _focusNodes,
                    onChanged: _onDigitChanged,
                  ),
                  if (_codeError != null) ...[
                    const SizedBox(height: MfSpace.sm),
                    Semantics(
                      liveRegion: true,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline_rounded, size: 18, color: cs.error),
                          const SizedBox(width: MfSpace.xxs),
                          Flexible(
                            child: Text(
                              _codeError!,
                              textAlign: TextAlign.center,
                              style: text.bodySmall?.copyWith(color: cs.error),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: MfSpace.lg),
                  MfPrimaryButton(
                    label: _isLoading ? 'Verifying' : 'Verify account',
                    icon: Icons.verified_user_outlined,
                    loading: _isLoading,
                    onPressed: _onVerify,
                  ),
                  const SizedBox(height: MfSpace.md),
                  Text(
                    "Didn't receive the code?",
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
                      onPressed: _resendCooldown > 0 ? null : _onResend,
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
