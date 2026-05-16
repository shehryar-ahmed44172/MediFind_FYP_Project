import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:medifind_mobile_application/core/utils/responsive.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';

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
        _showDialog(
          icon: Icons.warning_amber_rounded,
          iconColor: Colors.orange,
          title: 'Email Not Registered',
          message:
              '"$email" is not linked to any MediFind account.\n\nPlease check the spelling or create a new account.',
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Try Again'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                context.go('/select-role');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryLight,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Register'),
            ),
          ],
        );
      } else {
        _showDialog(
          icon: Icons.error_outline_rounded,
          iconColor: Colors.red,
          title: 'Request Failed',
          message:
              'Could not send the reset code right now.\n\nPlease check your internet connection and try again.',
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('OK'),
            ),
          ],
        );
      }
    }
  }

  void _showDialog({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String message,
    required List<Widget> actions,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(icon, color: iconColor, size: 28),
            const SizedBox(width: 10),
            Expanded(child: Text(title)),
          ],
        ),
        content: Text(message),
        actions: actions,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Forgot Password'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.go('/login'),
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
                SizedBox(height: 5.hp),

                // Icon
                Center(
                  child: Container(
                    padding: EdgeInsets.all(5.wp),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.lock_reset_rounded,
                      size: 18.wp,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),

                SizedBox(height: 3.hp),

                Text(
                  'Reset Your Password',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),

                SizedBox(height: 1.5.hp),

                Text(
                  'Enter the email address linked to your account.\nWe will send a 6-digit code to reset your password.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade600,
                    height: 1.6,
                  ),
                ),

                SizedBox(height: 5.hp),

                // Email field
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.email],
                  onFieldSubmitted: (_) => _sendResetCode(),
                  decoration: InputDecoration(
                    labelText: 'Email Address',
                    hintText: 'you@example.com',
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
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

                SizedBox(height: 3.5.hp),

                // Send button
                SizedBox(
                  height: 6.5.hp,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _sendResetCode,
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'Send Reset Code',
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),

                SizedBox(height: 2.hp),

                // Back to login
                Center(
                  child: TextButton.icon(
                    onPressed: () => context.go('/login'),
                    icon: const Icon(Icons.arrow_back_rounded, size: 16),
                    label: const Text('Back to Login'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey.shade600,
                    ),
                  ),
                ),

                SizedBox(height: 4.hp),

                // Info card
                Container(
                  padding: EdgeInsets.all(3.5.wp),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade100),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded,
                          color: Colors.blue.shade600, size: 20),
                      SizedBox(width: 2.wp),
                      Expanded(
                        child: Text(
                          'A 6-digit code will be sent to your registered email. '
                          'Enter it on the next screen to reset your password. '
                          'The code expires in 15 minutes.',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: Colors.blue.shade700,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
