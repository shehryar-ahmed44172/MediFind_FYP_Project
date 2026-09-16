import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/design_system/design_system.dart';
import 'widgets/auth_common.dart';

class ResetNewPasswordScreen extends ConsumerStatefulWidget {
  final String email;
  final String otp;

  const ResetNewPasswordScreen({
    super.key,
    required this.email,
    required this.otp,
  });

  @override
  ConsumerState<ResetNewPasswordScreen> createState() => _ResetNewPasswordScreenState();
}

class _ResetNewPasswordScreenState extends ConsumerState<ResetNewPasswordScreen> {
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
          showMfSnackBar(context, 'Session expired. Please start over.', tone: MfTone.warning);
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

  MfTone get _strengthTone {
    switch (_strength) {
      case 1:
        return MfTone.danger;
      case 2:
      case 3:
        return MfTone.warning;
      case 4:
        return MfTone.success;
      default:
        return MfTone.neutral;
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
      await showAuthMessageDialog(
        context,
        icon: Icons.check_circle_outline_rounded,
        tone: MfTone.success,
        title: 'Password reset',
        message: 'Your password has been reset successfully.\n\nPlease log in with your new password.',
        buttonLabel: 'Go to log in',
        onConfirm: () => context.go('/login'),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);

      final msg = e.toString().replaceAll('Exception:', '').trim();
      final isOtpError = msg.toLowerCase().contains('invalid') ||
          msg.toLowerCase().contains('expired') ||
          msg.toLowerCase().contains('code');

      showAuthMessageDialog(
        context,
        icon: isOtpError ? Icons.timer_off_outlined : Icons.error_outline_rounded,
        tone: MfTone.danger,
        title: isOtpError ? 'Code invalid or expired' : 'Reset failed',
        message: msg.isNotEmpty ? msg : 'Something went wrong. Please try again.',
        barrierDismissible: true,
        extraActions: isOtpError
            ? (ctx) => [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      // Go back to OTP screen to enter a fresh code
                      context.go('/reset-password-otp', extra: {'email': widget.email});
                    },
                    child: const Text('Try new code'),
                  ),
                ]
            : null,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final strength = MfColors.tone(context, _strengthTone);

    return MfScaffold(
      title: 'Set new password',
      onBack: () => context.go('/reset-password-otp', extra: {'email': widget.email}),
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
                      const AuthStepIntro(
                        icon: Icons.lock_reset_rounded,
                        title: 'Create a new password',
                        message: 'Your new password must be at least 8 characters.',
                      ),
                      const SizedBox(height: MfSpace.lg),

                      // ── New password ──────────────────────────────────
                      TextFormField(
                        controller: _newPasswordCtrl,
                        obscureText: !_showNew,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.newPassword],
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        decoration: InputDecoration(
                          labelText: 'New password',
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          errorMaxLines: 2,
                          suffixIcon: IconButton(
                            tooltip: _showNew ? 'Hide password' : 'Show password',
                            icon: Icon(_showNew ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                            onPressed: () => setState(() => _showNew = !_showNew),
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
                        const SizedBox(height: MfSpace.xs),
                        Semantics(
                          label: 'Password strength: $_strengthLabel',
                          excludeSemantics: true,
                          child: Row(
                            children: [
                              for (var i = 0; i < 4; i++)
                                Expanded(
                                  child: Container(
                                    height: 4,
                                    margin: EdgeInsets.only(right: i < 3 ? MfSpace.xxs : 0),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(2),
                                      color: i < _strength ? strength.solid : cs.surfaceContainerHighest,
                                    ),
                                  ),
                                ),
                              const SizedBox(width: MfSpace.xs),
                              Text(_strengthLabel, style: text.labelMedium?.copyWith(color: strength.foreground)),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: MfSpace.md),

                      // ── Confirm password ──────────────────────────────
                      TextFormField(
                        controller: _confirmPasswordCtrl,
                        obscureText: !_showConfirm,
                        textInputAction: TextInputAction.done,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        onFieldSubmitted: (_) {
                          if (!_isLoading) _submit();
                        },
                        decoration: InputDecoration(
                          labelText: 'Confirm new password',
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          errorMaxLines: 2,
                          suffixIcon: IconButton(
                            tooltip: _showConfirm ? 'Hide password' : 'Show password',
                            icon: Icon(_showConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                            onPressed: () => setState(() => _showConfirm = !_showConfirm),
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
                      const SizedBox(height: MfSpace.md),

                      // ── Requirements checklist ────────────────────────
                      _buildRequirements(context),
                      const SizedBox(height: MfSpace.lg),

                      MfPrimaryButton(
                        label: _isLoading ? 'Resetting password' : 'Reset password',
                        icon: Icons.check_rounded,
                        loading: _isLoading,
                        onPressed: _submit,
                      ),
                      const SizedBox(height: MfSpace.xs),
                      Center(
                        child: MfTextButton(
                          label: 'Cancel and return to log in',
                          onPressed: () => context.go('/login'),
                        ),
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

  Widget _buildRequirements(BuildContext context) {
    final p = _newPasswordCtrl.text;
    return MfCard(
      padding: const EdgeInsets.all(MfSpace.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Password must have', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: MfSpace.xxs),
          _req(context, 'At least 8 characters', p.length >= 8),
          _req(context, 'One uppercase letter (A-Z)', RegExp(r'[A-Z]').hasMatch(p)),
          _req(context, 'One number (0-9)', RegExp(r'[0-9]').hasMatch(p)),
          _req(context, 'One special character (!@#\$...)', RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(p)),
        ],
      ),
    );
  }

  Widget _req(BuildContext context, String label, bool met) {
    final cs = Theme.of(context).colorScheme;
    final success = MfColors.tone(context, MfTone.success);
    return Semantics(
      label: '$label: ${met ? 'met' : 'not met'}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Icon(
              met ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
              size: 18,
              color: met ? success.solid : cs.onSurfaceVariant,
            ),
            const SizedBox(width: MfSpace.xs),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: met ? success.foreground : cs.onSurfaceVariant,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
