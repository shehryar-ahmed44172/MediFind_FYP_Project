import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:medifind_mobile_application/core/utils/responsive.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';

class ResetPasswordOtpScreen extends ConsumerStatefulWidget {
  final String email;

  const ResetPasswordOtpScreen({
    super.key,
    required this.email,
  });

  @override
  ConsumerState<ResetPasswordOtpScreen> createState() =>
      _ResetPasswordOtpScreenState();
}

class _ResetPasswordOtpScreenState
    extends ConsumerState<ResetPasswordOtpScreen> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  bool _isResending = false;

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
    for (final c in _controllers) c.dispose();
    for (final n in _focusNodes) n.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  // ── Cooldown timer ─────────────────────────────────────────────────────────
  void _startCooldown() {
    setState(() => _resendCooldown = 60);
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        _resendCooldown--;
        if (_resendCooldown <= 0) t.cancel();
      });
    });
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  String get _currentOtp =>
      _controllers.map((c) => c.text.trim()).join();

  void _clearOtp() {
    for (final c in _controllers) c.clear();
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter all 6 digits of the code.'),
          backgroundColor: Colors.orange.shade700,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      _focusNodes.firstWhere((n) => !n.hasFocus,
          orElse: () => _focusNodes[0]).requestFocus();
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
    setState(() => _isResending = true);

    try {
      await ref.read(forgotPasswordProvider(widget.email).future);
      if (!mounted) return;
      _startCooldown();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('New code sent to ${_maskEmail(widget.email)}'),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceAll('Exception:', '').trim();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              msg.isNotEmpty ? msg : 'Failed to resend. Please try again.'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  // ── OTP box builder ────────────────────────────────────────────────────────
  Widget _buildOtpBox(int index) {
    return AnimatedBuilder(
      animation: _focusNodes[index],
      builder: (context, _) {
        final isFocused = _focusNodes[index].hasFocus;
        final isFilled = _controllers[index].text.isNotEmpty;
        return Container(
          width: 13.wp,
          height: 7.hp,
          decoration: BoxDecoration(
            color: isFilled
                ? Theme.of(context).colorScheme.primary.withOpacity(0.08)
                : Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: AppShadows.cardShadow,
            border: Border.all(
              color: isFocused
                  ? Theme.of(context).colorScheme.primary
                  : isFilled
                      ? Theme.of(context).colorScheme.primary.withOpacity(0.4)
                      : Colors.grey.shade200,
              width: isFocused ? 2.5 : 1.5,
            ),
          ),
          child: TextField(
            controller: _controllers[index],
            focusNode: _focusNodes[index],
            textAlign: TextAlign.center,
            textAlignVertical: TextAlignVertical.center,
            keyboardType: TextInputType.number,
            maxLength: 1,
            style: TextStyle(
              fontSize: 22.sp,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
            decoration: const InputDecoration(
              counterText: '',
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
            onChanged: (value) {
              if (value.isNotEmpty) {
                // Move forward
                if (index < 5) {
                  _focusNodes[index + 1].requestFocus();
                } else {
                  // Last box — dismiss keyboard and auto-continue
                  _focusNodes[index].unfocus();
                  Future.delayed(const Duration(milliseconds: 80),
                      _onContinue);
                }
              } else {
                // Backspace — move backward
                if (index > 0) {
                  _focusNodes[index - 1].requestFocus();
                }
              }
              setState(() {}); // Rebuild border colours
            },
            onTap: () {
              // On tap, clear the current box so user can retype
              _controllers[index].clear();
              setState(() {});
            },
          ),
        );
      },
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Enter Reset Code'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.go('/forgot-password'),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 6.wp, vertical: 2.hp),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: 4.hp),

              // Icon
              Center(
                child: Container(
                  padding: EdgeInsets.all(5.wp),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.mark_email_unread_rounded,
                    size: 18.wp,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),

              SizedBox(height: 3.hp),

              Text(
                'Check Your Email',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),

              SizedBox(height: 1.hp),

              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: TextStyle(
                      fontSize: 14.sp,
                      color: Colors.grey.shade600,
                      height: 1.6),
                  children: [
                    const TextSpan(text: 'We sent a 6-digit code to\n'),
                    TextSpan(
                      text: _maskEmail(widget.email),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const TextSpan(
                        text: '\n\nEnter the code below to continue.'),
                  ],
                ),
              ),

              SizedBox(height: 5.hp),

              // ── 6-box OTP input ─────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(6, _buildOtpBox),
              ),

              SizedBox(height: 1.5.hp),

              // Expire hint
              Center(
                child: Text(
                  'Code expires in 15 minutes',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Colors.grey.shade500,
                  ),
                ),
              ),

              SizedBox(height: 4.hp),

              // ── Continue button ─────────────────────────────────────────
              SizedBox(
                height: 6.5.hp,
                child: ElevatedButton(
                  onPressed: _onContinue,
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Continue',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              SizedBox(height: 3.hp),

              // ── Resend section ──────────────────────────────────────────
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Didn't receive it? ",
                      style: TextStyle(
                          fontSize: 13.sp, color: Colors.grey.shade600),
                    ),
                    _resendCooldown > 0
                        ? Text(
                            'Resend in ${_resendCooldown}s',
                            style: TextStyle(
                                fontSize: 13.sp, color: Colors.grey.shade400),
                          )
                        : GestureDetector(
                            onTap: _isResending ? null : _resendCode,
                            child: _isResending
                                ? SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: theme.colorScheme.primary,
                                    ),
                                  )
                                : Text(
                                    'Resend Code',
                                    style: TextStyle(
                                      fontSize: 13.sp,
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.primary,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                          ),
                  ],
                ),
              ),

              SizedBox(height: 2.hp),

              // ── Wrong email link ────────────────────────────────────────
              Center(
                child: TextButton(
                  onPressed: () => context.go('/forgot-password'),
                  child: Text(
                    'Use a different email address',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
