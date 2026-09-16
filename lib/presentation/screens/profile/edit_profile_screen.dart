import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/design_system/design_system.dart';
import '../../../domain/entities/user.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  // Standard Fields
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _cnicController;
  late TextEditingController _dobController;
  DateTime? _selectedDob;

  // Responder Fields
  late TextEditingController _organizationController;
  late TextEditingController _licenseController;
  late TextEditingController _responderTypeController;
  late TextEditingController _vehicleTypeController;

  final _phoneFormatter = MaskTextInputFormatter(
    mask: '+92-###-#######',
    filter: {"#": RegExp(r'[0-9]')},
    type: MaskAutoCompletionType.lazy,
  );

  bool _isLoading = false;
  bool _isEditing = false;
  File? _selectedImage;

  @override
  void initState() {
    super.initState();
    final user = ref.read(currentUserProvider).value;

    _nameController = TextEditingController(text: user?.fullName ?? '');
    _phoneController = TextEditingController(text: user?.phoneNumber ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
    _cnicController = TextEditingController(text: user?.cnic ?? 'N/A');
    _selectedDob = user?.dateOfBirth;
    _dobController = TextEditingController(
      text: _selectedDob != null
          ? "${_selectedDob!.day}/${_selectedDob!.month}/${_selectedDob!.year}"
          : '',
    );

    _organizationController = TextEditingController(text: user?.organization ?? '');
    _licenseController = TextEditingController(text: user?.licenseNumber ?? '');
    _responderTypeController = TextEditingController(text: user?.responderType ?? '');
    _vehicleTypeController = TextEditingController(text: user?.vehicleType ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _cnicController.dispose();
    _organizationController.dispose();
    _licenseController.dispose();
    _responderTypeController.dispose();
    _vehicleTypeController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  void _toggleEditing() {
    setState(() {
      if (_isEditing) {
        // Reset fields if canceling
        _isEditing = false;
        _selectedImage = null;
        // Re-init controllers
        final u = ref.read(currentUserProvider).value;
        _nameController.text = u?.fullName ?? '';
        _phoneController.text = u?.phoneNumber ?? '';
        _organizationController.text = u?.organization ?? '';
        _responderTypeController.text = u?.responderType ?? '';
        _vehicleTypeController.text = u?.vehicleType ?? '';
      } else {
        _isEditing = true;
      }
    });
  }

  Future<void> _selectDate() async {
    if (!_isEditing) return;

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDob ?? DateTime.now().subtract(const Duration(days: 365 * 18)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedDob = picked;
        _dobController.text = "${picked.day}/${picked.month}/${picked.year}";
      });
    }
  }

  Future<void> _pickImage() async {
    if (!_isEditing) return;

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);

    if (pickedFile != null) {
      setState(() => _selectedImage = File(pickedFile.path));
    }
  }

  Future<void> _handleUpdate() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      // 1. Upload Image if selected
      if (_selectedImage != null) {
        await ref.read(uploadProfileImageProvider(_selectedImage!).future);
      }

      // 2. Update Profile Data
      final user = ref.read(currentUserProvider).value;
      final updateData = {
        'fullName': _nameController.text.trim(),
        'phoneNumber': _phoneController.text.replaceAll('-', '').trim(),
        'dateOfBirth': _selectedDob?.toIso8601String(),
      };

      // Add responder fields if applicable
      if (user?.role == 'RESPONDER') {
        updateData['organization'] = _organizationController.text.trim();
        updateData['responderType'] = _responderTypeController.text.trim();
        updateData['vehicleType'] = _vehicleTypeController.text.trim();
      }

      await ref.read(updateProfileProvider(updateData).future);

      if (mounted) {
        showMfSnackBar(context, 'Profile updated successfully', tone: MfTone.success);
        setState(() {
          _isEditing = false;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        showMfSnackBar(context, 'Failed to update: $e', tone: MfTone.danger);
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).value;
    final bool isResponder = user?.role == 'RESPONDER';

    return MfScaffold(
      title: 'Personal details',
      subtitle: _isEditing ? 'Editing' : null,
      actions: [
        MfIconButton(
          icon: _isEditing ? Icons.close_rounded : Icons.edit_outlined,
          tooltip: _isEditing ? 'Cancel editing' : 'Edit profile',
          onPressed: _isLoading ? null : _toggleEditing,
        ),
      ],
      bottomBar: _isEditing
          ? MfPrimaryButton(
              label: 'Save changes',
              icon: Icons.check_rounded,
              loading: _isLoading,
              onPressed: _handleUpdate,
            )
          : MfSecondaryButton(
              label: 'Edit details',
              icon: Icons.edit_outlined,
              large: true,
              onPressed: _toggleEditing,
            ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(MfSpace.gutter, MfSpace.md, MfSpace.gutter, MfSpace.xl),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildProfileImage(user),
              const SizedBox(height: MfSpace.lg),

              // Basic Info Section
              const MfSectionTitle('Account information'),
              const SizedBox(height: MfSpace.xs),
              _buildTextField(
                label: 'Full name',
                controller: _nameController,
                icon: Icons.person_outline_rounded,
                readOnly: !_isEditing,
                textInputAction: TextInputAction.next,
                validator: (val) => val == null || val.isEmpty ? 'Name is required' : null,
              ),
              const SizedBox(height: MfSpace.md),
              _buildTextField(
                label: 'Phone number',
                controller: _phoneController,
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                readOnly: !_isEditing,
                inputFormatters: [_phoneFormatter],
                validator: (val) => val == null || val.isEmpty ? 'Phone is required' : null,
              ),
              const SizedBox(height: MfSpace.md),
              _buildTextField(
                label: 'Email address',
                controller: _emailController,
                icon: Icons.email_outlined,
                readOnly: true, // Always immutable
                locked: true,
                helper: 'Email cannot be changed',
              ),
              const SizedBox(height: MfSpace.md),
              _buildTextField(
                label: 'CNIC / identity number',
                controller: _cnicController,
                icon: Icons.badge_outlined,
                readOnly: true, // Always immutable
                locked: true,
                helper: 'Identity verified during registration',
              ),
              const SizedBox(height: MfSpace.md),
              _buildTextField(
                label: 'Date of birth',
                controller: _dobController,
                icon: Icons.calendar_today_outlined,
                readOnly: true,
                helper: _isEditing ? 'Tap to choose a date' : null,
                onTap: _isEditing ? _selectDate : null,
              ),

              // Responder Professional Section
              if (isResponder) ...[
                const SizedBox(height: MfSpace.lg),
                const MfSectionTitle('Professional profile'),
                const SizedBox(height: MfSpace.xs),
                _buildTextField(
                  label: 'Organization',
                  controller: _organizationController,
                  icon: Icons.business_outlined,
                  readOnly: !_isEditing,
                ),
                const SizedBox(height: MfSpace.md),
                _buildTextField(
                  label: 'License number',
                  controller: _licenseController,
                  icon: Icons.verified_user_outlined,
                  readOnly: true, // Immutable
                  locked: true,
                  helper: 'Government issued license',
                ),
                const SizedBox(height: MfSpace.md),
                _buildTextField(
                  label: 'Responder type',
                  controller: _responderTypeController,
                  icon: Icons.medical_information_outlined,
                  readOnly: !_isEditing,
                ),
                const SizedBox(height: MfSpace.md),
                _buildTextField(
                  label: 'Vehicle type',
                  controller: _vehicleTypeController,
                  icon: Icons.two_wheeler_rounded,
                  readOnly: !_isEditing,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileImage(User? user) {
    const size = 104.0;
    return Column(
      children: [
        SizedBox(
          width: size,
          height: size,
          child: _selectedImage != null
              ? Semantics(
                  image: true,
                  label: 'Selected profile photo',
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                    ),
                    child: ClipOval(
                      child: Image.file(_selectedImage!, width: size, height: size, fit: BoxFit.cover),
                    ),
                  ),
                )
              : MfAvatar(imageUrl: user?.profileImageUrl, name: user?.fullName, size: size),
        ),
        if (_isEditing) ...[
          const SizedBox(height: MfSpace.sm),
          MfSecondaryButton(
            label: _selectedImage == null ? 'Change photo' : 'Choose another photo',
            icon: Icons.photo_camera_outlined,
            expanded: false,
            onPressed: _isLoading ? null : _pickImage,
          ),
          if (_selectedImage != null)
            Padding(
              padding: const EdgeInsets.only(top: MfSpace.xxs),
              child: Text(
                'New photo will be uploaded when you save',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    bool readOnly = false,
    bool locked = false,
    TextInputType keyboardType = TextInputType.text,
    TextInputAction? textInputAction,
    String? helper,
    VoidCallback? onTap,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    final cs = Theme.of(context).colorScheme;
    final muted = readOnly && onTap == null;
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      validator: validator,
      readOnly: readOnly,
      onTap: onTap,
      inputFormatters: inputFormatters,
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: muted ? cs.onSurfaceVariant : cs.onSurface,
          ),
      decoration: InputDecoration(
        labelText: label,
        helperText: helper,
        helperMaxLines: 2,
        prefixIcon: Icon(icon, color: muted ? cs.onSurfaceVariant : cs.primary),
        suffixIcon: locked
            ? Tooltip(
                message: 'Cannot be changed',
                child: Icon(Icons.lock_outline_rounded, size: 20, color: cs.onSurfaceVariant),
              )
            : null,
        filled: muted ? true : null,
        fillColor: muted ? cs.surfaceContainerHighest.withValues(alpha: 0.5) : null,
      ),
    );
  }
}
