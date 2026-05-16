import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:medifind_mobile_application/core/utils/responsive.dart';
import '../../providers/auth_provider.dart';

class ResetNewPasswordScreen extends ConsumerStatefulWidget {
  final String email;
  final String otp;

  const ResetNewPasswordScreen({
    super.key,
    required this.email,
    required this.otp,
  });

  @override
  ConsumerState<ResetNewPasswordScreen> createState() =>
      _ResetNewPasswordScreenState();
}

class _ResetNewPasswordScreenState
    extends ConsumerState<ResetNewPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _newPasswordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  bool _isLoading = false;
  bool _showNew = false;
  bool _showConfirm = false;
  int _strength = 0; // 0-4

  @override
  void initState() {
    super.initState();

    // Guard: if email or OTP is missing, go back to start
    if (widget.email.isEmpty || widget.otp.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Session expired. Please start over.'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
            ),
          );
          context.go('/forgot-password');
        }
      });
    }

    _newPasswordCtrl.addListener(_updateStrength);
  }

  @override
  void dispose() {
    _newPasswordCtrl.removeListener(_updateStrength);
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  void _updateStrength() {
    final p = _newPasswordCtrl.text;
    int s = 0;
    if (p.length >= 8) s++;
    if (RegExp(r'[A-Z]').hasMatch(p)) s++;
    if (RegExp(r'[0-9]').hasMatch(p)) s++;
    if (RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(p)) s++;
    setState(() => _strength = s);
  }

  Color get _strengthColor {
    switch (_strength) {
      case 1:
        return Colors.red;
      case 2:
        return Colors.orange;
      case 3:
        return Colors.yellow.shade700;
      case 4:
        return Colors.green;
      default:
        return Colors.grey.shade300;
    }
  }

  String get _strengthLabel {
    switch (_strength) {
      case 1:
        return 'Weak';
      case 2:
        return 'Fair';
      case 3:
        return 'Good';
      case 4:
        return 'Strong';
      default:
        return '';
    }
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await ref.read(
        resetPasswordProvider(
          ResetPasswordParams(
            email: widget.email,
            otp: widget.otp,
            newPassword: _newPasswordCtrl.text,
          ),
        ).future,
      );

      if (!mounted) return;

      // ── Success ──────────────────────────────────────────────────────────
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.green, size: 32),
              SizedBox(width: 10),
              Expanded(child: Text('Password Reset!')),
            ],
          ),
          content: const Text(
            'Your password has been reset successfully.\n\n'
            'Please log in with your new password.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                context.go('/login');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Go to Login'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);

      final msg = e.toString().replaceAll('Exception:', '').trim();
      final isOtpError = msg.toLowerCase().contains('invalid') ||
          msg.toLowerCase().contains('expired') ||
          msg.toLowerCase().contains('code');

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(
                isOtpError
                    ? Icons.timer_off_rounded
                    : Icons.error_outline_rounded,
                color: Colors.red,
                size: 28,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                    isOtpError ? 'Code Invalid or Expired' : 'Reset Failed'),
              ),
            ],
          ),
          content: Text(
            msg.isNotEmpty
                ? msg
                : 'Something went wrong. Please try again.',
          ),
          actions: [
            if (isOtpError)
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  // Go back to OTP screen to enter a fresh code
                  context.go('/reset-password-otp',
                      extra: {'email': widget.email});
                },
                child: const Text('Try New Code'),
              ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Set New Password'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.go('/reset-password-otp',
              extra: {'email': widget.email}),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 6.wp, vertical: 2.hp),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: 4.hp),

                // Icon
                Center(
                  child: Container(
                    padding: EdgeInsets.all(5.wp),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.lock_open_rounded,
                      size: 18.wp,
                      color: Colors.green.shade600,
                    ),
                  ),
                ),

                SizedBox(height: 3.hp),

                Text(
                  'Create New Password',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),

                SizedBox(height: 1.hp),

                Text(
                  'Your new password must be at least 8 characters.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade600, height: 1.5),
                ),

                SizedBox(height: 4.hp),

                // ── New password ────────────────────────────────────────
                TextFormField(
                  controller: _newPasswordCtrl,
                  obscureText: !_showNew,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'New Password',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      icon: Icon(_showNew
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined),
                      onPressed: () =>
                          setState(() => _showNew = !_showNew),
                    ),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide:
                          BorderSide(color: Colors.grey.shade300, width: 1.5),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                          color: theme.colorScheme.primary, width: 2),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Password is required';
                    if (v.length < 8) {
                      return 'Password must be at least 8 characters';
                    }
                    return null;
                  },
                ),

                // Strength bar
                if (_newPasswordCtrl.text.isNotEmpty) ...[
                  SizedBox(height: 1.hp),
                  Row(
                    children: [
                      ...List.generate(4, (i) => Expanded(
                        child: Container(
                          height: 4,
                          margin:
                              EdgeInsets.only(right: i < 3 ? 1.5.wp : 0),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            color: i < _strength
                                ? _strengthColor
                                : Colors.grey.shade200,
                          ),
                        ),
                      )),
                      SizedBox(width: 2.wp),
                      Text(
                        _strengthLabel,
                        style: TextStyle(
                          fontSize: 11.sp,
                          color: _strengthColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],

                SizedBox(height: 2.5.hp),

                // ── Confirm password ────────────────────────────────────
                TextFormField(
                  controller: _confirmPasswordCtrl,
                  obscureText: !_showConfirm,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    labelText: 'Confirm New Password',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      icon: Icon(_showConfirm
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined),
                      onPressed: () =>
                          setState(() => _showConfirm = !_showConfirm),
                    ),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide:
                          BorderSide(color: Colors.grey.shade300, width: 1.5),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                          color: theme.colorScheme.primary, width: 2),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return 'Please confirm your password';
                    }
                    if (v != _newPasswordCtrl.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),

                SizedBox(height: 3.hp),

                // ── Requirements checklist ──────────────────────────────
                _buildRequirements(),

                SizedBox(height: 4.hp),

                // ── Submit button ───────────────────────────────────────
                SizedBox(
                  height: 6.5.hp,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.green.shade200,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5, color: Colors.white),
                          )
                        : Text(
                            'Reset Password',
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),

                SizedBox(height: 2.hp),

                Center(
                  child: TextButton(
                    onPressed: () => context.go('/login'),
                    child: Text(
                      'Cancel — Back to Login',
                      style: TextStyle(
                          fontSize: 13.sp, color: Colors.grey.shade500),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRequirements() {
    final p = _newPasswordCtrl.text;
    return Container(
      padding: EdgeInsets.all(3.wp),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Password must have:',
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          SizedBox(height: 1.hp),
          _req('At least 8 characters', p.length >= 8),
          _req('One uppercase letter (A–Z)',
              RegExp(r'[A-Z]').hasMatch(p)),
          _req('One number (0–9)', RegExp(r'[0-9]').hasMatch(p)),
          _req('One special character (!@#\$…)',
              RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(p)),
        ],
      ),
    );
  }

  Widget _req(String label, bool met) => Padding(
        padding: EdgeInsets.symmetric(vertical: 0.3.hp),
        child: Row(
          children: [
            Icon(
              met
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 16,
              color: met ? Colors.green : Colors.grey.shade400,
            ),
            SizedBox(width: 2.wp),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.sp,
                color: met ? Colors.green.shade700 : Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
}
