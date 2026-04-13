import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/extensions/extensions.dart';
import '../../../core/utils/utils.dart';
import '../../providers/auth_provider.dart';
import '../../../domain/entities/user.dart';
import '../../theme/app_theme.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  final String role;
  const RegisterScreen({Key? key, required this.role}) : super(key: key);

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  // Common Controllers
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cnicController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Responder specific controllers
  final _organizationController = TextEditingController();
  final _licenseController = TextEditingController();
  String _selectedResponderType = 'EMERGENCY_RESPONDER';
  String _selectedVehicleType = 'AMBULANCE';

  // Document uploads for Responder
  XFile? _cnicFront;
  XFile? _cnicBack;
  XFile? _employeeCardFront;
  XFile? _employeeCardBack;
  final _imagePicker = ImagePicker();

  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String _selectedPatientType = 'NORMAL';
  bool _isLoading = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _cnicController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _organizationController.dispose();
    _licenseController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(String docType) async {
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (picked != null) {
      setState(() {
        switch (docType) {
          case 'CNIC_FRONT':
            _cnicFront = picked;
            break;
          case 'CNIC_BACK':
            _cnicBack = picked;
            break;
          case 'EMP_FRONT':
            _employeeCardFront = picked;
            break;
          case 'EMP_BACK':
            _employeeCardBack = picked;
            break;
        }
      });
    }
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final request = RegisterRequest(
        fullName: _fullNameController.text.trim(),
        email: _emailController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        password: _passwordController.text,
        role: widget.role,
        cnic: _cnicController.text.trim(),
        patientType: widget.role == 'PATIENT' ? _selectedPatientType : null,
        organization:
            widget.role == 'RESPONDER' ? _organizationController.text.trim() : null,
        licenseNumber:
            widget.role == 'RESPONDER' ? _licenseController.text.trim() : null,
        responderType:
            widget.role == 'RESPONDER' ? _selectedResponderType : null,
        vehicleType: widget.role == 'RESPONDER' ? _selectedVehicleType : null,
      );

      await ref.read(registerProvider(request).future);

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
            content: Text(
                'Registration failed: ${e.toString().replaceAll('Exception:', '').trim()}'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Returns a color/icon based on the user's role
  Map<String, dynamic> get _roleTheme {
    switch (widget.role) {
      case 'RESPONDER':
        return {
          'color': const Color(0xFFD32F2F),
          'icon': Icons.local_hospital_rounded,
          'label': 'Emergency Responder',
        };
      case 'CAREGIVER':
        return {
          'color': const Color(0xFF00897B),
          'icon': Icons.favorite_rounded,
          'label': 'Caregiver',
        };
      default:
        return {
          'color': const Color(0xFF0E9AA7), // MediFind primary teal
          'icon': Icons.person_rounded,
          'label': 'Patient',
        };
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final roleColor = _roleTheme['color'] as Color;
    final roleIcon = _roleTheme['icon'] as IconData;
    final roleLabel = _roleTheme['label'] as String;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: size.width * 0.06,
              vertical: 24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Back button
                Align(
                  alignment: Alignment.centerLeft,
                  child: GestureDetector(
                    onTap: () => context.go('/select-role'),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: theme.scaffoldBackgroundColor,
                        shape: BoxShape.circle,
                        boxShadow: AppShadows.neumorphicOut,
                      ),
                      child: Icon(Icons.arrow_back_ios_new_rounded,
                          size: 18, color: roleColor),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Role Badge Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: roleColor.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(roleIcon, color: roleColor, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Create Account',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Registering as: $roleLabel',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: roleColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // ─── Personal Information ───────────────────────────
                _SectionHeader(title: 'Personal Information', color: roleColor),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _fullNameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                  validator: (v) => StringUtils.validateName(v),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email Address',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (v) => StringUtils.validateEmail(v),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  validator: (v) => StringUtils.validatePhoneNumber(v),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _cnicController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'CNIC Number',
                    hintText: 'e.g. 34601-1234567-1',
                    prefixIcon: Icon(Icons.credit_card_outlined),
                  ),
                  validator: (v) => StringUtils.validateCnic(v),
                ),
                const SizedBox(height: 24),

                // ─── Role Specific Fields ───────────────────────────
                if (widget.role == 'PATIENT') ...[
                  _SectionHeader(title: 'Accessibility Mode', color: roleColor),
                  const SizedBox(height: 8),
                  Text(
                    'Select your accessibility needs.',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _PatientTypeChip(
                        label: 'Standard Mode',
                        icon: Icons.person_rounded,
                        color: roleColor,
                        selected: _selectedPatientType == 'NORMAL',
                        onTap: () =>
                            setState(() => _selectedPatientType = 'NORMAL'),
                      ),
                      const SizedBox(width: 12),
                      _PatientTypeChip(
                        label: 'Deaf Mode',
                        icon: Icons.hearing_disabled_rounded,
                        color: const Color(0xFF00897B),
                        selected: _selectedPatientType == 'DEAF',
                        onTap: () =>
                            setState(() => _selectedPatientType = 'DEAF'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],

                if (widget.role == 'RESPONDER') ...[
                  _SectionHeader(
                      title: 'Responder Credentials', color: roleColor),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _organizationController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Organization / Hospital Name',
                      prefixIcon: Icon(Icons.business_rounded),
                    ),
                    validator: (v) =>
                        v.isNullOrEmpty ? 'Required for verification' : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _licenseController,
                    decoration: const InputDecoration(
                      labelText: 'Medical License Number',
                      prefixIcon: Icon(Icons.badge_rounded),
                    ),
                    validator: (v) =>
                        v.isNullOrEmpty ? 'Required for verification' : null,
                  ),
                  const SizedBox(height: 14),

                  // Responder Type is fixed to 'Emergency Responder' as per requirements
                  const SizedBox(height: 14),

                  // Vehicle Type (full width, Motorbike added)
                  DropdownButtonFormField<String>(
                    value: _selectedVehicleType,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Vehicle Type',
                      prefixIcon: Icon(Icons.directions_car_rounded),
                    ),
                    items: const [
                      DropdownMenuItem(
                          value: 'AMBULANCE', child: Text('Ambulance')),
                      DropdownMenuItem(
                          value: 'MOTORBIKE', child: Text('Motorbike')),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => _selectedVehicleType = v);
                      }
                    },
                  ),
                  const SizedBox(height: 24),

                  // ─── Document Uploads ───────────────────────────
                  _SectionHeader(title: 'Identity Documents', color: roleColor),
                  const SizedBox(height: 8),
                  Text(
                    'Upload your CNIC and Employee Card for admin verification.',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 16),

                  // CNIC Row
                  Text(
                    'CNIC',
                    style: theme.textTheme.labelLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _DocumentUploadCard(
                          label: 'Front Side',
                          icon: Icons.credit_card_rounded,
                          color: roleColor,
                          file: _cnicFront,
                          onTap: () => _pickImage('CNIC_FRONT'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _DocumentUploadCard(
                          label: 'Back Side',
                          icon: Icons.credit_card_rounded,
                          color: roleColor,
                          file: _cnicBack,
                          onTap: () => _pickImage('CNIC_BACK'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Employee Card Row
                  Text(
                    'Employee Card',
                    style: theme.textTheme.labelLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _DocumentUploadCard(
                          label: 'Front Side',
                          icon: Icons.badge_rounded,
                          color: roleColor,
                          file: _employeeCardFront,
                          onTap: () => _pickImage('EMP_FRONT'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _DocumentUploadCard(
                          label: 'Back Side',
                          icon: Icons.badge_rounded,
                          color: roleColor,
                          file: _employeeCardBack,
                          onTap: () => _pickImage('EMP_BACK'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],

                // ─── Security ───────────────────────────────────────
                _SectionHeader(title: 'Security', color: roleColor),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (v) => StringUtils.validatePassword(v),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  decoration: InputDecoration(
                    labelText: 'Confirm Password',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureConfirmPassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined),
                      onPressed: () => setState(() =>
                          _obscureConfirmPassword = !_obscureConfirmPassword),
                    ),
                  ),
                  validator: (v) {
                    if (v.isNullOrEmpty) return 'Confirm password is required';
                    if (v != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32),

                // Submit Button
                Container(
                  decoration: BoxDecoration(
                    color: roleColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: roleColor.withOpacity(0.4),
                        blurRadius: 12,
                        offset: const Offset(4, 4),
                      ),
                      const BoxShadow(
                        color: Colors.white,
                        blurRadius: 10,
                        offset: Offset(-4, -4),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _register,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text(
                            'Create Account',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
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
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Helper Widgets ─────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final Color color;
  const _SectionHeader({required this.title, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
            width: 4,
            height: 18,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            )),
        Text(title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                )),
      ],
    );
  }
}

class _DocumentUploadCard extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color color;
  final XFile? file;
  final VoidCallback onTap;

  const _DocumentUploadCard({
    required this.label,
    required this.icon,
    required this.color,
    required this.file,
    required this.onTap,
  });

  @override
  State<_DocumentUploadCard> createState() => _DocumentUploadCardState();
}

class _DocumentUploadCardState extends State<_DocumentUploadCard> {
  Uint8List? _imageBytes;

  @override
  void initState() {
    super.initState();
    if (widget.file != null) _loadBytes();
  }

  @override
  void didUpdateWidget(covariant _DocumentUploadCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.file != oldWidget.file && widget.file != null) {
      _loadBytes();
    }
  }

  Future<void> _loadBytes() async {
    final bytes = await widget.file!.readAsBytes();
    if (mounted) setState(() => _imageBytes = bytes);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasFile = widget.file != null;

    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 130,
        decoration: BoxDecoration(
          color: hasFile
              ? widget.color.withOpacity(0.06)
              : theme.scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: hasFile ? widget.color : Colors.grey.shade400,
            width: hasFile ? 2.0 : 1.5,
            // Simulated dashed look via strokeAlign and style
          ),
        ),
        child: hasFile && _imageBytes != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.memory(_imageBytes!, fit: BoxFit.cover),
                    // Overlay label at bottom
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        color: Colors.black.withOpacity(0.55),
                        child: Text(
                          '✓ ${widget.label}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : hasFile
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: widget.color.withOpacity(0.10),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(widget.icon, color: widget.color, size: 26),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.upload_file_outlined,
                              size: 12, color: widget.color),
                          const SizedBox(width: 4),
                          Text(
                            'Tap to upload',
                            style: TextStyle(
                              color: widget.color,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
      ),
    );
  }
}

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
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: selected ? color.withOpacity(0.12) : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? color : Colors.grey.shade300,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: selected ? color : Colors.grey.shade500, size: 28),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.bold : FontWeight.w500,
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
