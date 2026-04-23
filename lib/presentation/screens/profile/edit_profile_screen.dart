import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../../domain/entities/user.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({Key? key}) : super(key: key);

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
  
  // Responder Fields
  late TextEditingController _organizationController;
  late TextEditingController _licenseController;
  late TextEditingController _responderTypeController;
  late TextEditingController _vehicleTypeController;
  
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
    super.dispose();
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
        'phoneNumber': _phoneController.text.trim(),
      };

      // Add responder fields if applicable
      if (user?.role == 'RESPONDER') {
        updateData['organization'] = _organizationController.text.trim();
        updateData['responderType'] = _responderTypeController.text.trim();
        updateData['vehicleType'] = _vehicleTypeController.text.trim();
      }

      await ref.read(updateProfileProvider(updateData).future);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() {
          _isEditing = false;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider).value;
    final bool isResponder = user?.role == 'RESPONDER';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Personal Details'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.close_rounded : Icons.edit_note_rounded),
            onPressed: () => setState(() {
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
            }),
            tooltip: _isEditing ? 'Cancel' : 'Edit Profile',
          ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  // Profile Picture Section
                  _buildProfileImage(user),
                  const SizedBox(height: 32),

                  // Basic Info Section
                  _buildSectionHeader('Account Information'),
                  const SizedBox(height: 16),
                  _buildTextField(
                    label: 'Full Name',
                    controller: _nameController,
                    icon: Icons.person_outline,
                    readOnly: !_isEditing,
                    validator: (val) => val == null || val.isEmpty ? 'Name is required' : null,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    label: 'Phone Number',
                    controller: _phoneController,
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    readOnly: !_isEditing,
                    validator: (val) => val == null || val.isEmpty ? 'Phone is required' : null,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    label: 'Email Address',
                    controller: _emailController,
                    icon: Icons.email_outlined,
                    readOnly: true, // Always immutable
                    subtitle: 'Email cannot be changed',
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    label: 'CNIC / Identity Number',
                    controller: _cnicController,
                    icon: Icons.badge_outlined,
                    readOnly: true, // Always immutable
                    subtitle: 'Identity verified during registration',
                  ),
                  
                  // Responder Professional Section
                  if (isResponder) ...[
                    const SizedBox(height: 32),
                    _buildSectionHeader('Professional Profile'),
                    const SizedBox(height: 16),
                    _buildTextField(
                      label: 'Organization',
                      controller: _organizationController,
                      icon: Icons.business_rounded,
                      readOnly: !_isEditing,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      label: 'License Number',
                      controller: _licenseController,
                      icon: Icons.verified_user_outlined,
                      readOnly: true, // Immutable
                      subtitle: 'Government issued license',
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      label: 'Responder Type',
                      controller: _responderTypeController,
                      icon: Icons.medical_information_outlined,
                      readOnly: !_isEditing,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      label: 'Vehicle Type',
                      controller: _vehicleTypeController,
                      icon: Icons.emergency_rounded,
                      readOnly: !_isEditing,
                    ),
                  ],

                  const SizedBox(height: 48),

                  if (_isEditing)
                    SizedBox(
                      width: double.infinity,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: AppShadows.sosMassiveGlow,
                        ),
                        child: ElevatedButton(
                          onPressed: _handleUpdate,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                          ),
                          child: const Text('Save Changes', 
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
                        ),
                      ),
                    ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildProfileImage(User? user) {
    return Center(
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary.withOpacity(0.2), width: 2),
            ),
            child: CircleAvatar(
              radius: 60,
              backgroundColor: Colors.grey.shade200,
              backgroundImage: _selectedImage != null 
                ? FileImage(_selectedImage!) as ImageProvider
                : (user?.profileImageUrl != null ? NetworkImage(user!.profileImageUrl!) : null),
              child: (_selectedImage == null && user?.profileImageUrl == null)
                ? const Icon(Icons.person, size: 60, color: Colors.grey)
                : null,
            ),
          ),
          if (_isEditing)
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  boxShadow: AppShadows.neumorphicOut,
                ),
                child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 20),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    bool readOnly = false,
    TextInputType keyboardType = TextInputType.text,
    String? subtitle,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
        ),
        Container(
          decoration: BoxDecoration(
            color: readOnly ? Colors.grey.shade50 : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: readOnly ? [] : AppShadows.neumorphicIn,
            border: Border.all(color: readOnly ? Colors.grey.shade200 : Colors.transparent),
          ),
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            validator: validator,
            readOnly: readOnly,
            style: TextStyle(
              color: readOnly ? Colors.grey.shade600 : Colors.black87,
              fontWeight: readOnly ? FontWeight.w500 : FontWeight.bold,
              fontSize: 15,
            ),
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: readOnly ? Colors.grey.shade400 : AppColors.primary, size: 20),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
        if (subtitle != null)
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 6),
            child: Text(subtitle, style: TextStyle(fontSize: 10, color: Colors.grey.shade400, fontStyle: FontStyle.italic)),
          ),
      ],
    );
  }
}
