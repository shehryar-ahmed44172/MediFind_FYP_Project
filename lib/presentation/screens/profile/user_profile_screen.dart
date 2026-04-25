import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/auth_provider.dart';
import '../../providers/accessibility_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/profile/invitations_list_widget.dart';
import '../../../core/constants/app_constants.dart';

class UserProfileScreen extends ConsumerStatefulWidget {
  final String? userId;
  const UserProfileScreen({Key? key, this.userId}) : super(key: key);

  @override
  ConsumerState<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends ConsumerState<UserProfileScreen> {
  bool _isUploading = false;

  Future<void> _pickAndUploadImage() async {
    final ImagePicker picker = ImagePicker();
    
    // Show selection dialog
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Update Profile Picture', 
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildSourceOption(Icons.photo_library_outlined, 'Gallery', ImageSource.gallery),
                _buildSourceOption(Icons.camera_alt_outlined, 'Camera', ImageSource.camera),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );

    if (source == null) return;

    final XFile? image = await picker.pickImage(
      source: source,
      imageQuality: 70,
      maxWidth: 1000,
    );

    if (image != null) {
      if (!mounted) return;
      setState(() => _isUploading = true);
      
      try {
        await ref.read(uploadProfileImageProvider(File(image.path)).future);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile picture updated!')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Upload failed: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _isUploading = false);
      }
    }
  }

  Widget _buildSourceOption(IconData icon, String label, ImageSource source) {
    return InkWell(
      onTap: () => Navigator.pop(context, source),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.primary, size: 32),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  String _getProfileImageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    
    // Use socketUrl (which is the root) instead of baseUrl (which has /api/)
    final rootUrl = AppConstants.socketUrl.endsWith('/') 
        ? AppConstants.socketUrl.substring(0, AppConstants.socketUrl.length - 1)
        : AppConstants.socketUrl;
    final cleanPath = path.startsWith('/') ? path : '/$path';
    return '$rootUrl$cleanPath';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final userAsync = widget.userId != null 
        ? ref.watch(userProfileProvider(widget.userId!))
        : ref.watch(currentUserProvider);
    final settings = ref.watch(accessibilityProvider);
    final bool isOwnProfile = widget.userId == null;

    return Scaffold(
      body: userAsync.when(
        data: (user) {
          if (user == null) return const Center(child: Text('No user profile found'));

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              
              // Accessibility Mode Badge for Deaf Patients
              if (settings.textOnlyMode)
                Container(
                  margin: const EdgeInsets.only(bottom: 24),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.amber.shade300, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.amber.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.visibility_rounded, color: Colors.amber.shade900),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Visual Accessibility Active',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.amber.shade900,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              'High-contrast & visual alerts enabled',
                              style: TextStyle(
                                color: Colors.amber.shade800,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              // Profile Picture
              Center(
                child: Hero(
                  tag: 'profile_pic',
                  child: Stack(
                    children: [
                      Container(
                        width: 130,
                        height: 130,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: theme.scaffoldBackgroundColor,
                          boxShadow: AppShadows.neumorphicOut,
                          border: Border.all(color: Colors.white, width: 4),
                        ),
                        child: _isUploading
                          ? const Center(child: CircularProgressIndicator())
                          : user.profileImageUrl != null 
                            ? ClipOval(
                                child: Image.network(
                                  _getProfileImageUrl(user.profileImageUrl),
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => 
                                      const Icon(Icons.person, size: 60, color: Colors.grey),
                                ),
                              )
                            : const Icon(Icons.person, size: 70, color: Colors.grey),
                      ),
                      Positioned(
                        bottom: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: _isUploading ? null : _pickAndUploadImage,
                          child: Container(
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: AppShadows.neumorphicOut,
                            ),
                            padding: const EdgeInsets.all(10),
                            child: const Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // User Info Card
              Container(
                decoration: BoxDecoration(
                  color: theme.scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: AppShadows.neumorphicOut,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _profileTile(Icons.person_outline, 'Full Name', user.fullName, settings),
                      Divider(color: Colors.grey.withOpacity(0.1), height: 32),
                      _profileTile(Icons.email_outlined, 'Email', user.email, settings),
                      Divider(color: Colors.grey.withOpacity(0.1), height: 32),
                      _profileTile(Icons.phone_outlined, 'Phone Number', user.phoneNumber, settings),
                      
                      // CNIC Field
                      if (user.cnic != null) ...[
                        Divider(color: Colors.grey.withOpacity(0.1), height: 32),
                        _profileTile(Icons.badge_outlined, 'CNIC', user.cnic!, settings),
                      ],
                      
                      Divider(color: Colors.grey.withOpacity(0.1), height: 32),
                      _profileTile(Icons.security_rounded, 'Role', user.role, settings),

                      // Patient Specific
                      if (user.role == 'PATIENT' && user.patientType != null) ...[
                         Divider(color: Colors.grey.withOpacity(0.1), height: 32),
                        _profileTile(Icons.accessible_forward_rounded, 'Patient Type', 
                          user.patientType!, settings, 
                          color: user.patientType == 'DEAF' ? Colors.teal : null),
                      ],

                      // Responder Specific
                      if (user.role == 'RESPONDER') ...[
                        if (user.licenseNumber != null) ...[
                          Divider(color: Colors.grey.withOpacity(0.1), height: 32),
                          _profileTile(Icons.description_outlined, 'License Number', user.licenseNumber!, settings),
                        ],
                        if (user.organization != null) ...[
                          Divider(color: Colors.grey.withOpacity(0.1), height: 32),
                          _profileTile(Icons.business_outlined, 'Organization', user.organization!, settings),
                        ],
                        if (user.vehicleType != null) ...[
                          Divider(color: Colors.grey.withOpacity(0.1), height: 32),
                          _profileTile(Icons.emergency_rounded, 'Vehicle Type', user.vehicleType!, settings),
                        ],
                        if (user.verificationStatus != null) ...[
                          Divider(color: Colors.grey.withOpacity(0.1), height: 32),
                          _profileTile(Icons.verified_user_outlined, 'Verification', user.verificationStatus!, settings,
                            color: user.verificationStatus == 'VERIFIED' ? Colors.green : Colors.orange),
                        ],
                        
                        // Responder Stats
                        Divider(color: Colors.grey.withOpacity(0.1), height: 32),
                        Row(
                          children: [
                            Expanded(child: _profileTile(Icons.star_outline, 'Rating', '${user.rating ?? 5.0}', settings, color: Colors.amber)),
                            Expanded(child: _profileTile(Icons.assignment_turned_in_outlined, 'Completed', '${user.totalResponsesHandled ?? 0}', settings)),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Edit Button
              if (isOwnProfile) ...[
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: AppShadows.neumorphicOut,
                  ),
                  child: ElevatedButton.icon(
                    onPressed: () => context.push('/edit-profile'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.scaffoldBackgroundColor,
                      foregroundColor: theme.colorScheme.primary,
                      elevation: 0,
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ).copyWith(
                      overlayColor: MaterialStateProperty.all(theme.colorScheme.primary.withOpacity(0.05)),
                    ),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit Profile',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 32),
                
                // Logout
                TextButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Logout'),
                        content: const Text('Are you sure you want to logout?'),
                        actions: [
                          TextButton(
                            child: const Text('Cancel'),
                            onPressed: () => Navigator.pop(context),
                          ),
                          TextButton(
                            style: TextButton.styleFrom(foregroundColor: Colors.red),
                            child: const Text('Logout'),
                            onPressed: () async {
                              Navigator.pop(context);
                              await ref.read(logoutProvider.future);
                              if (context.mounted) context.go('/login');
                            },
                          ),
                        ],
                      ),
                    );
                  },
                  icon: const Icon(Icons.logout, color: Colors.red),
                  label: const Text('Logout', style: TextStyle(color: Colors.red)),
                ),
                const SizedBox(height: 32),
              ],
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error loading profile: $e')),
      ),
    );
  }

  Widget _profileTile(IconData icon, String title, String subtitle, AccessibilitySettings settings, {Color? color}) {
    final m = settings.fontSizeMultiplier;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: EdgeInsets.all(8 * m),
        decoration: BoxDecoration(
          color: (color ?? Colors.grey).withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color ?? Colors.grey.shade600, size: 20 * m),
      ),
      title: Text(title,
          style: TextStyle(fontSize: 11 * m, color: Colors.grey.shade500, letterSpacing: 1)),
      subtitle: Text(subtitle,
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16 * m)),
    );
  }
}
