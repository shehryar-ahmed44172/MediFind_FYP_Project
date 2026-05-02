import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:medifind_mobile_application/core/utils/responsive.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common/app_header.dart';

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
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  bool _isLoading = false;
  bool _isResending = false;

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _showInfoDialog({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String message,
    String buttonLabel = 'OK',
    VoidCallback? onConfirm,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(icon, color: iconColor, size: 28),
            const SizedBox(width: 10),
            Expanded(child: Text(title)),
          ],
        ),
        content: Text(message),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              onConfirm?.call();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: iconColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(buttonLabel),
          ),
        ],
      ),
    );
  }

  void _onVerify() async {
    final otp = _controllers.map((c) => c.text).join();
    if (otp.length < 6) {
      _showInfoDialog(
        icon: Icons.info_outline_rounded,
        iconColor: Colors.orange,
        title: 'Incomplete Code',
        message: 'Please enter the complete 6-digit verification code.',
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ref.read(verifyEmailProvider(VerifyEmailParams(email: widget.email, otp: otp)).future);
      if (mounted) {
        _showInfoDialog(
          icon: Icons.verified_rounded,
          iconColor: Colors.green,
          title: 'Account Verified Successfully',
          message: 'Your account has been verified. You can now use MediFind.',
          buttonLabel: 'Continue',
          onConfirm: () => context.go('/splash'),
        );
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString().replaceAll('Exception:', '').trim();
        _showInfoDialog(
          icon: Icons.error_outline_rounded,
          iconColor: Colors.red,
          title: 'Verification Failed',
          message: msg.isNotEmpty ? msg : 'Invalid or expired code. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onResend() async {
    setState(() => _isResending = true);
    try {
      await ref.read(resendOTPProvider(widget.email).future);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('A new code has been sent to your email.'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString().replaceAll('Exception:', '').trim();
        _showInfoDialog(
          icon: Icons.error_outline_rounded,
          iconColor: Colors.red,
          title: 'Resend Failed',
          message: msg.isNotEmpty ? msg : 'Unable to resend the code. Please wait a moment and try again.',
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: const AppHeader(
        greetingOverride: 'Verify Email',
        canPop: true,
        backPathOverride: '/login',
        showLogout: false,
        showProfile: false,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(3.hp),
        child: Column(
          children: [
            SizedBox(height: 4.hp),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.email_outlined, size: 64, color: theme.primaryColor),
            ),
            SizedBox(height: 4.hp),
            Text(
              'Enter Verification Code',
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 1.hp),
            Text(
              'We have sent a 6-digit code to',
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
            ),
            Text(
              _maskEmail(widget.email),
              style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 6.hp),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(6, (index) => _buildOtpBox(index)),
            ),
            SizedBox(height: 6.hp),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _onVerify,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text('Verify Account', style: TextStyle(fontSize: 1.8.hp, fontWeight: FontWeight.bold)),
              ),
            ),
            SizedBox(height: 3.hp),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("Didn't receive the code? "),
                TextButton(
                  onPressed: _isResending ? null : _onResend,
                  child: _isResending
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text('Resend Code', style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOtpBox(int index) {
    return Container(
      width: 48,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppShadows.cardShadow,
        border: Border.all(
          color: _focusNodes[index].hasFocus ? Theme.of(context).primaryColor : Colors.transparent,
          width: 2,
        ),
      ),
      child: TextField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        textAlign: TextAlign.center,
        textAlignVertical: TextAlignVertical.center, // Center text vertically
        keyboardType: TextInputType.number,
        maxLength: 1,
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        decoration: const InputDecoration(
          counterText: '',
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero, // Remove default padding for better alignment
        ),
        onChanged: (value) {
          if (value.isNotEmpty && index < 5) {
            _focusNodes[index + 1].requestFocus();
          } else if (value.isEmpty && index > 0) {
            _focusNodes[index - 1].requestFocus();
          }
          if (_controllers.every((c) => c.text.isNotEmpty)) {
            _onVerify();
          }
        },
      ),
    );
  }
}
