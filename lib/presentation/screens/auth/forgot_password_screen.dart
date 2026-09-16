import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/design_system/design_system.dart';
import 'widgets/auth_common.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetCode() async {
    // Dismiss keyboard
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();

    setState(() => _isLoading = true);

    try {
      // autoDispose provider — each call is a fresh API request, no caching
      await ref.read(forgotPasswordProvider(email).future);

      // Success: navigate to the OTP entry screen
      if (mounted) {
        context.go('/reset-password-otp', extra: {'email': email});
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);

      final errorStr = e.toString();
      final isNotFound = errorStr.contains('not registered') ||
          errorStr.contains('not found') ||
          errorStr.contains('404');

      if (isNotFound) {
        showAuthMessageDialog(
          context,
          icon: Icons.warning_amber_rounded,
          tone: MfTone.warning,
          title: 'Email not registered',
          message:
              '"$email" is not linked to any MediFind account.\n\nPlease check the spelling or create a new account.',
          buttonLabel: 'Register',
          barrierDismissible: true,
          onConfirm: () => context.go('/select-role'),
          extraActions: (ctx) => [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Try again'),
            ),
          ],
        );
      } else {
        showAuthMessageDialog(
          context,
          icon: Icons.error_outline_rounded,
          tone: MfTone.danger,
          title: 'Request failed',
          message:
              'Could not send the reset code right now.\n\nPlease check your internet connection and try again.',
          barrierDismissible: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return MfScaffold(
      title: 'Forgot password',
      onBack: () => context.go('/login'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(MfSpace.gutter, MfSpace.lg, MfSpace.gutter, MfSpace.lg),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const AuthStepIntro(
                  icon: Icons.lock_reset_rounded,
                  title: 'Reset your password',
                  message:
                      'Enter the email address linked to your account. We will send a 6-digit code to reset your password.',
                ),
                const SizedBox(height: MfSpace.xl),

                // Email field
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.email],
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  onFieldSubmitted: (_) {
                    if (!_isLoading) _sendResetCode();
                  },
                  decoration: const InputDecoration(
                    labelText: 'Email address',
                    hintText: 'you@example.com',
                    prefixIcon: Icon(Icons.email_outlined),
                    errorMaxLines: 2,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your email address';
                    }
                    final trimmed = value.trim();
                    if (!trimmed.contains('@') || !trimmed.contains('.')) {
                      return 'Please enter a valid email address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: MfSpace.lg),

                MfPrimaryButton(
                  label: 'Send reset code',
                  icon: Icons.send_rounded,
                  loading: _isLoading,
                  onPressed: _sendResetCode,
                ),
                const SizedBox(height: MfSpace.xs),

                // Back to login
                Center(
                  child: TextButton.icon(
                    onPressed: () => context.go('/login'),
                    icon: const Icon(Icons.arrow_back_rounded, size: 18),
                    label: const Text('Back to login'),
                    style: TextButton.styleFrom(
                      foregroundColor: cs.onSurfaceVariant,
                      minimumSize: const Size(MfSize.minTouch, MfSize.minTouch),
                    ),
                  ),
                ),
                const SizedBox(height: MfSpace.lg),

                // Info
                const MfInfoBanner(
                  icon: Icons.info_outline_rounded,
                  tone: MfTone.info,
                  title: 'How it works',
                  message: 'A 6-digit code will be sent to your registered email. '
                      'Enter it on the next screen to reset your password. '
                      'The code expires in 15 minutes.',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
