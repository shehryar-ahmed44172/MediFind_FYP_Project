import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/extensions/extensions.dart';
import '../../../core/utils/utils.dart';
import '../../providers/auth_provider.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String _selectedRole = 'PATIENT';
  String _selectedPatientType = 'NORMAL';
  bool _isLoading = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final params = RegisterParams(
        fullName: _fullNameController.text.trim(),
        email: _emailController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        password: _passwordController.text,
        role: _selectedRole,
      );
      await ref.read(registerProvider(params).future);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Registration successful! Please log in.'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.go('/login');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Registration failed: ${e.toString().replaceAll('Exception:', '').trim()}'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/login'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Join MediFind',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Create your account to get started',
                style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade600),
              ),
              const SizedBox(height: 32),

              // Full Name
              TextFormField(
                controller: _fullNameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: Icon(Icons.person_outlined),
                ),
                validator: (value) => StringUtils.validateName(value),
              ),
              const SizedBox(height: 16),

              // Email
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

              // Phone
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                validator: (value) => StringUtils.validatePhoneNumber(value),
              ),
              const SizedBox(height: 16),

              // Role
              DropdownButtonFormField<String>(
                value: _selectedRole,
                decoration: const InputDecoration(
                  labelText: 'Register As',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                items: const [
                  DropdownMenuItem(value: 'PATIENT', child: Text('Patient')),
                  DropdownMenuItem(value: 'RESPONDER', child: Text('Emergency Responder')),
                  DropdownMenuItem(value: 'CAREGIVER', child: Text('Caregiver')),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _selectedRole = value);
                },
              ),
              const SizedBox(height: 16),

              // Patient Type Selection (only for PATIENT role)
              if (_selectedRole == 'PATIENT') ...[
                Text(
                  'Patient Type',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'This helps MediFind tailor the app for your specific needs.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _PatientTypeChip(
                      label: 'Normal',
                      icon: Icons.person_rounded,
                      color: const Color(0xFF1976D2),
                      selected: _selectedPatientType == 'NORMAL',
                      onTap: () => setState(() => _selectedPatientType = 'NORMAL'),
                    ),
                    const SizedBox(width: 8),
                    _PatientTypeChip(
                      label: 'Deaf',
                      icon: Icons.hearing_disabled_rounded,
                      color: const Color(0xFF00897B),
                      selected: _selectedPatientType == 'DEAF',
                      onTap: () => setState(() => _selectedPatientType = 'DEAF'),
                    ),
                    const SizedBox(width: 8),
                    _PatientTypeChip(
                      label: 'Blind',
                      icon: Icons.visibility_off_rounded,
                      color: const Color(0xFFF57C00),
                      selected: _selectedPatientType == 'BLIND',
                      onTap: () => setState(() => _selectedPatientType = 'BLIND'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _patientTypeColor(_selectedPatientType).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: _patientTypeColor(_selectedPatientType).withOpacity(0.3)),
                  ),
                  child: Text(
                    _getPatientTypeDescription(_selectedPatientType),
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Role description hint
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _getRoleDescription(_selectedRole),
                  style: theme.textTheme.bodySmall,
                ),
              ),
              const SizedBox(height: 16),

              // Password
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
                validator: (value) => StringUtils.validatePassword(value),
              ),
              const SizedBox(height: 16),

              // Confirm Password
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: _obscureConfirmPassword,
                decoration: InputDecoration(
                  labelText: 'Confirm Password',
                  prefixIcon: const Icon(Icons.lock_outlined),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureConfirmPassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined),
                    onPressed: () => setState(
                        () => _obscureConfirmPassword = !_obscureConfirmPassword),
                  ),
                ),
                validator: (value) {
                  if (value.isNullOrEmpty) return 'Confirm password is required';
                  if (value != _passwordController.text)
                    return 'Passwords do not match';
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Register button
              ElevatedButton(
                onPressed: _isLoading ? null : _register,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Create Account',
                        style: TextStyle(fontSize: 16)),
              ),
              const SizedBox(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Already have an account? '),
                  TextButton(
                    onPressed: () => context.go('/login'),
                    child: const Text('Login'),
                  ),
                ],
              ),

              const SizedBox(height: 32),
              // Mock Registration Section (Dev only)
              const Divider(),
              const SizedBox(height: 16),
              Text(
                'Quick Fill (Dev Only)',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleSmall?.copyWith(color: Colors.grey),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _MockFillButton(
                    label: 'Patient',
                    onPressed: () {
                      _fullNameController.text = 'John Doe';
                      _emailController.text = 'john@example.com';
                      _phoneController.text = '+15550001';
                      _passwordController.text = 'Password123!';
                      _confirmPasswordController.text = 'Password123!';
                      setState(() => _selectedRole = 'PATIENT');
                    },
                  ),
                  _MockFillButton(
                    label: 'Responder',
                    onPressed: () {
                      _fullNameController.text = 'Jane Smith';
                      _emailController.text = 'jane@example.com';
                      _phoneController.text = '+15550002';
                      _passwordController.text = 'Password123!';
                      _confirmPasswordController.text = 'Password123!';
                      setState(() => _selectedRole = 'RESPONDER');
                    },
                  ),
                  _MockFillButton(
                    label: 'Caregiver',
                    onPressed: () {
                      _fullNameController.text = 'Mary Doe';
                      _emailController.text = 'mary@example.com';
                      _phoneController.text = '+15550003';
                      _passwordController.text = 'Password123!';
                      _confirmPasswordController.text = 'Password123!';
                      setState(() => _selectedRole = 'CAREGIVER');
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getRoleDescription(String role) {
    switch (role) {
      case 'PATIENT':
        return '👤 Patient: Register to use SOS emergency features and manage your medical profile.';
      case 'RESPONDER':
        return '🚑 Responder: Register to receive and respond to emergency alerts. Requires admin verification.';
      case 'CAREGIVER':
        return '💙 Caregiver: Register to monitor patients you care for during emergencies.';
      default:
        return '';
    }
  }

  String _getPatientTypeDescription(String type) {
    switch (type) {
      case 'DEAF':
        return '🦻 Deaf mode: Enables vibration alerts, text-only interface, predefined emergency messages, and visual-only countdown. No audio required.';
      case 'BLIND':
        return '🦯 Blind mode: Enables voice guidance, large tactile buttons, audio countdown feedback, and automatic voice alerts for your assigned responder.';
      default:
        return '👤 Standard mode: Full access to all features including maps, medical reports, and standard SOS flow.';
    }
  }

  Color _patientTypeColor(String type) {
    switch (type) {
      case 'DEAF':
        return const Color(0xFF00897B);
      case 'BLIND':
        return const Color(0xFFF57C00);
      default:
        return const Color(0xFF1976D2);
    }
  }
}

class _MockFillButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _MockFillButton({
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

// ---------------------------------------------------------------------------
// Patient Type Chip widget (used on Register Screen)
// ---------------------------------------------------------------------------
class _PatientTypeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _PatientTypeChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? color.withOpacity(0.12) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? color : Colors.grey.shade300,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  color: selected ? color : Colors.grey.shade500, size: 22),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  color: selected ? color : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
