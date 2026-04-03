import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/extensions/extensions.dart';
import '../../../core/utils/utils.dart';
import '../../providers/auth_provider.dart';

/// LoginScreen widget handles user authentication.
/// It uses Riverpod for state management and GoRouter for navigation.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  // Controllers for text input fields
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  // Key to manage and validate the form state
  final _formKey = GlobalKey<FormState>();
  
  // UI state variables
  bool _obscurePassword = true; // Toggles password visibility
  bool _isLoading = false;      // Shows loading spinner during API calls

  @override
  void dispose() {
    // Clean up controllers to prevent memory leaks when the screen is closed
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Handles the login process: validation, authentication, and routing
  Future<void> _login() async {
    // Step 1: Validate form fields
    if (!_formKey.currentState!.validate()) return;

    // Step 2: Show loading indicator
    setState(() => _isLoading = true);

    try {
      // Step 3: Prepare login parameters
      final params = LoginParams(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      // Step 4: Call the authentication provider
      await ref.read(loginProvider(params).future);

      if (mounted) {
        // Step 5: Fetch user role and navigate to the correct dashboard
        final role = await ref.read(currentUserRoleProvider.future);
        if (mounted) {
          _navigateByRole(role);
        }
      }
    } catch (e) {
      // Handle authentication errors and show a SnackBar to the user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Login failed: ${e.toString().replaceAll('Exception:', '').trim()}'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      // Hide loading indicator whether login succeeds or fails
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Routes the user to their specific dashboard based on their account type
  void _navigateByRole(String? role) {
    switch (role?.toUpperCase()) {
      case 'RESPONDER':
        context.go('/responder');
        break;
      case 'CAREGIVER':
        context.go('/caregiver');
        break;
      default:
        context.go('/home'); // Default route for Patients
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 60),

                // -----------------------------------------------------------
                // Header Section: Logo & App Title
                // -----------------------------------------------------------
                Icon(Icons.local_hospital_rounded,
                    size: 72, color: theme.colorScheme.primary),
                const SizedBox(height: 16),
                Text(
                  'MediFind',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Emergency Response App',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 48),

                // -----------------------------------------------------------
                // Input Fields Section
                // -----------------------------------------------------------
                // Email Input
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (value) => StringUtils.validateEmail(value),
                ),
                const SizedBox(height: 16),

                // Password Input
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
                const SizedBox(height: 12),

                // Forgot Password Link
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => context.go('/forgot-password'),
                    child: const Text('Forgot Password?'),
                  ),
                ),
                const SizedBox(height: 16),

                // -----------------------------------------------------------
                // Action Buttons Section
                // -----------------------------------------------------------
                // Main Login Button
                ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Login', style: TextStyle(fontSize: 16)),
                ),
                const SizedBox(height: 24),

                // Navigation to Registration
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Don't have an account? "),
                    TextButton(
                      onPressed: () => context.go('/register'),
                      child: const Text('Register'),
                    ),
                  ],
                ),

                const SizedBox(height: 32),
                
                // -----------------------------------------------------------
                // Mock Credentials Section (Development Only)
                // -----------------------------------------------------------
                const Divider(),
                const SizedBox(height: 16),
                Text(
                  'Quick Login (Dev Only)',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleSmall?.copyWith(color: Colors.grey),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _MockLoginButton(
                      label: 'Patient',
                      onPressed: () {
                        _emailController.text = 'patient@example.com';
                        _passwordController.text = 'Password123!';
                      },
                    ),
                    _MockLoginButton(
                      label: 'Responder',
                      onPressed: () {
                        _emailController.text = 'responder@example.com';
                        _passwordController.text = 'Password123!';
                      },
                    ),
                    _MockLoginButton(
                      label: 'Caregiver',
                      onPressed: () {
                        _emailController.text = 'caregiver@example.com';
                        _passwordController.text = 'Password123!';
                      },
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

/// A custom widget used only for quick developer login buttons
class _MockLoginButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _MockLoginButton({
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        textStyle: const TextStyle(fontSize: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(label),
    );
  }
}
