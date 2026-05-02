import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/extensions/extensions.dart';
import '../../../core/utils/utils.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../../services/location/location_service.dart';
import '../../../core/utils/exceptions.dart';
import 'package:medifind_mobile_application/core/utils/responsive.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  final String role;
  final String? patientType; // NORMAL, DEAF (Passed from RoleSelection)
  
  const RegisterScreen({
    super.key,
    required this.role,
    this.patientType,
  });

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
  final _cityController = TextEditingController();
  final _houseNoController = TextEditingController();
  final _addressController = TextEditingController();
  final _additionalAddressController = TextEditingController();
  final _dobController = TextEditingController();
  DateTime? _selectedDob;

  // Responder specific controllers
  final _organizationController = TextEditingController();
  final _licenseController = TextEditingController();

  final _cnicFormatter = MaskTextInputFormatter(
    mask: '#####-#######-#',
    filter: {"#": RegExp(r'[0-9]')},
    type: MaskAutoCompletionType.lazy,
  );

  final _phoneFormatter = MaskTextInputFormatter(
    mask: '+92-###-#######',
    filter: {"#": RegExp(r'[0-9]')},
    type: MaskAutoCompletionType.lazy,
  );

  final String _selectedResponderType = 'EMERGENCY_RESPONDER';
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
  bool _isFetchingLocation = false;
  int _locationAttempts = 0;
  static const int _maxLocationAttempts = 3;

  @override
  void initState() {
    super.initState();
    // Initialize from widget parameter if available
    if (widget.patientType != null) {
      _selectedPatientType = widget.patientType!;
    }
  }

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
    _cityController.dispose();
    _houseNoController.dispose();
    _addressController.dispose();
    _additionalAddressController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 18)), // Default 18 years ago
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: _roleTheme['color'] as Color,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDob = picked;
        _dobController.text = "${picked.day}/${picked.month}/${picked.year}";
      });
    }
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

  void _showLocationLimitDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.location_off_rounded, color: Colors.orange),
            SizedBox(width: 10),
            Text('Location Unavailable'),
          ],
        ),
        content: const Text(
          'Unable to fetch your location after 3 attempts.\n\nPlease ensure location services and internet are enabled, or enter your address manually.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _locationAttempts = 0);
            },
            child: const Text('Try Again'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Enter Manually'),
          ),
        ],
      ),
    );
  }

  /// Shown when the device GPS/location service is turned off.
  /// Opens Location Settings once and resets the attempt counter.
  void _showLocationServiceDialog() {
    setState(() => _locationAttempts = _maxLocationAttempts);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.location_off_rounded, color: Colors.orange),
            SizedBox(width: 10),
            Expanded(child: Text('Location Turned Off')),
          ],
        ),
        content: const Text(
          'Your device\'s location (GPS) is currently disabled.\n\nPlease turn it on in Settings, then come back and try again.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _locationAttempts = 0);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _locationAttempts = 0);
              await LocationService().openLocationSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  /// Shown when location permission was permanently denied.
  /// Routes the user to App Settings to grant permission manually.
  void _showPermissionPermanentlyDeniedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.location_disabled_rounded, color: Colors.red),
            SizedBox(width: 10),
            Expanded(child: Text('Permission Denied')),
          ],
        ),
        content: const Text(
          'Location permission was permanently denied.\n\nPlease open App Settings and grant location access to MediFind.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _locationAttempts = 0);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _locationAttempts = 0);
              await LocationService().openAppSettings();
            },
            child: const Text('App Settings'),
          ),
        ],
      ),
    );
  }

  Future<void> _fetchLocation() async {
    if (_locationAttempts >= _maxLocationAttempts) {
      _showLocationLimitDialog();
      return;
    }

    setState(() {
      _isFetchingLocation = true;
      _locationAttempts++;
    });

    try {
      final locationService = LocationService();
      final position = await locationService.getCurrentLocation();
      final place = await locationService.getPlaceFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (mounted) {
        setState(() {
          _cityController.text = place['city'] ?? '';
          _addressController.text = place['address'] ?? '';
          _locationAttempts = 0;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location fetched successfully!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final remaining = _maxLocationAttempts - _locationAttempts;
        if (remaining <= 0) {
          _showLocationLimitDialog();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Location unavailable. $remaining attempt${remaining == 1 ? '' : 's'} remaining.',
              ),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isFetchingLocation = false);
    }
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      debugPrint('📝 [Register] Starting registration process for role: ${widget.role}');
      String? cnicFrontUrl;
      String? cnicBackUrl;
      String? empFrontUrl;
      String? empBackUrl;

      if (widget.role == 'RESPONDER') {
        debugPrint('📤 [Register] Uploading responder documents...');
        final authRepo = await ref.read(authRepositoryProvider.future);
        if (_cnicFront != null) {
          debugPrint('   - Uploading CNIC Front: ${_cnicFront!.path}');
          cnicFrontUrl = await authRepo.uploadDocument(File(_cnicFront!.path));
        }
        if (_cnicBack != null) {
          debugPrint('   - Uploading CNIC Back: ${_cnicBack!.path}');
          cnicBackUrl = await authRepo.uploadDocument(File(_cnicBack!.path));
        }
        if (_employeeCardFront != null) {
          debugPrint('   - Uploading Employee Card Front: ${_employeeCardFront!.path}');
          empFrontUrl = await authRepo.uploadDocument(File(_employeeCardFront!.path));
        }
        if (_employeeCardBack != null) {
          debugPrint('   - Uploading Employee Card Back: ${_employeeCardBack!.path}');
          empBackUrl = await authRepo.uploadDocument(File(_employeeCardBack!.path));
        }
      }

      debugPrint('📡 [Register] Sending registration request to API...');
      final composedAddress = [
        _houseNoController.text.trim(),
        _addressController.text.trim(),
        _additionalAddressController.text.trim(),
      ].where((s) => s.isNotEmpty).join(', ');

      final Map<String, dynamic> request = {
        'fullName': _fullNameController.text.trim(),
        'email': _emailController.text.trim(),
        'phoneNumber': _phoneController.text.replaceAll('-', '').trim(),
        'password': _passwordController.text,
        'role': widget.role,
        'city': _cityController.text.trim(),
        'address': composedAddress,
        'cnic': _cnicController.text.trim(),
        'dateOfBirth': _selectedDob?.toIso8601String(),
        'patientType': widget.role == 'PATIENT' ? _selectedPatientType : null,
        'organization':
            widget.role == 'RESPONDER' ? _organizationController.text.trim() : null,
        'licenseNumber':
            widget.role == 'RESPONDER' ? _licenseController.text.trim() : null,
        'responderType':
            widget.role == 'RESPONDER' ? _selectedResponderType : null,
        'vehicleType': widget.role == 'RESPONDER' ? _selectedVehicleType : null,
        'cnicImageUrl': cnicFrontUrl,
        'cnicBackImageUrl': cnicBackUrl,
        'employeeCardImageUrl': empFrontUrl,
        'employeeCardBackImageUrl': empBackUrl,
      };

      await ref.read(registerProvider(request).future);
      debugPrint('✅ [Register] Registration successful!');

      if (mounted) {
        final bool isResponder = widget.role == 'RESPONDER';
        final String successMsg = isResponder
            ? 'Your account has been created successfully. Please wait for admin approval. You will receive an email with your verification code once your documents are reviewed.'
            : 'Your account has been created. Please enter the 6-digit code sent to your email to verify your account.';

        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: isResponder ? Colors.orange : Colors.green, size: 28),
                const SizedBox(width: 10),
                const Text('Registration Successful'),
              ],
            ),
            content: Text(successMsg),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isResponder ? Colors.orange : Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(isResponder ? 'Got it' : 'Verify Email'),
              ),
            ],
          ),
        );
        if (mounted) {
          if (isResponder) {
            context.go('/login');
          } else {
            context.go('/verify-email', extra: {'email': _emailController.text.trim()});
          }
        }
      }
    } catch (e) {
      debugPrint('❌ [Register] Registration failed: $e');
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
          'color': AppColors.primary, // MediFind primary logo color
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
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: roleColor),
          onPressed: () => context.go('/select-role'),
          tooltip: 'Go Back',
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: 6.wp,
              vertical: 1.hp,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [

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
                            fontSize: 2.4.hp,
                          ),
                        ),
                        Text(
                          'Registering as: $roleLabel',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: roleColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 1.4.hp,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 4.hp),

                // ─── Demographic Information ───────────────────────
                _SectionHeader(title: 'Demographic Information', color: roleColor),
                SizedBox(height: 2.hp),
                TextFormField(
                  controller: _fullNameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                    errorMaxLines: 2,
                  ),
                  autofillHints: const [AutofillHints.name],
                  textInputAction: TextInputAction.next,
                  validator: (v) => StringUtils.validateName(v),
                ),
                SizedBox(height: 1.6.hp),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email Address',
                    prefixIcon: Icon(Icons.email_outlined),
                    errorMaxLines: 2,
                  ),
                  autofillHints: const [AutofillHints.email],
                  textInputAction: TextInputAction.next,
                  validator: (v) => StringUtils.validateEmail(v),
                ),
                SizedBox(height: 1.6.hp),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [_phoneFormatter],
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    hintText: '+92-300-1234567',
                    prefixIcon: Icon(Icons.phone_outlined),
                    errorMaxLines: 2,
                  ),
                  autofillHints: const [AutofillHints.telephoneNumber],
                  textInputAction: TextInputAction.next,
                  validator: (v) => StringUtils.validatePhoneNumber(v),
                ),
                SizedBox(height: 1.6.hp),
                TextFormField(
                  controller: _cnicController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [_cnicFormatter],
                  decoration: const InputDecoration(
                    labelText: 'CNIC Number',
                    hintText: 'e.g. 34601-1234567-1',
                    prefixIcon: Icon(Icons.credit_card_outlined),
                    errorMaxLines: 2,
                  ),
                  textInputAction: TextInputAction.next,
                  validator: (v) => StringUtils.validateCnic(v),
                ),
                SizedBox(height: 1.6.hp),
                TextFormField(
                  controller: _dobController,
                  readOnly: true,
                  onTap: _selectDate,
                  decoration: const InputDecoration(
                    labelText: 'Date of Birth',
                    hintText: 'Select your birth date',
                    prefixIcon: Icon(Icons.calendar_today_rounded),
                  ),
                  validator: (v) => v.isNullOrEmpty ? '⚠ Date of birth is required' : null,
                ),
                SizedBox(height: 3.hp),

                // ─── Location Information ───────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _SectionHeader(title: 'Location Information', color: roleColor),
                    TextButton.icon(
                      onPressed: _isFetchingLocation ? null : _fetchLocation,
                      icon: _isFetchingLocation
                          ? SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: roleColor))
                          : Icon(Icons.my_location_rounded,
                              size: 18, color: roleColor),
                      label: Text(
                        _isFetchingLocation ? 'Fetching...' : 'Get My Location',
                        style: TextStyle(
                            color: roleColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 1.4.hp),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 2.hp),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _cityController,
                        textCapitalization: TextCapitalization.words,
                        maxLength: 50,
                        decoration: const InputDecoration(
                          labelText: 'City',
                          prefixIcon: Icon(Icons.location_city_rounded),
                          counterText: '',
                          errorMaxLines: 2,
                        ),
                        textInputAction: TextInputAction.next,
                        validator: (v) {
                          if (v.isNullOrEmpty) return '⚠ City is required';
                          if (v!.trim().length < 2) return '⚠ Min 2 characters';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: TextFormField(
                        controller: _houseNoController,
                        maxLength: 20,
                        decoration: const InputDecoration(
                          labelText: 'House / Flat',
                          prefixIcon: Icon(Icons.home_outlined),
                          counterText: '',
                          errorMaxLines: 2,
                        ),
                        textInputAction: TextInputAction.next,
                        validator: (v) =>
                            v.isNullOrEmpty ? '⚠ House number is required' : null,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 1.6.hp),
                TextFormField(
                  controller: _addressController,
                  maxLength: 100,
                  decoration: const InputDecoration(
                    labelText: 'Street / Area',
                    prefixIcon: Icon(Icons.map_rounded),
                    counterText: '',
                  ),
                  validator: (v) {
                    if (v.isNullOrEmpty) return 'Street / Area is required';
                    if (v!.trim().length < 3) return 'Min 3 characters';
                    return null;
                  },
                ),
                SizedBox(height: 1.6.hp),
                TextFormField(
                  controller: _additionalAddressController,
                  maxLength: 100,
                  decoration: const InputDecoration(
                    labelText: 'Additional Address (Optional)',
                    prefixIcon: Icon(Icons.add_location_alt_outlined),
                    counterText: '',
                  ),
                ),
                SizedBox(height: 3.hp),

                // ─── Role Specific Fields ───────────────────────────
                // We only show Accessibility Mode if it wasn't pre-selected in Role Selection
                if (widget.role == 'PATIENT' && widget.patientType == null) ...[
                  _SectionHeader(title: 'Accessibility Mode', color: roleColor),
                  SizedBox(height: 1.hp),
                  Text(
                    'Select your accessibility needs.',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: Colors.grey.shade600, fontSize: 1.2.hp),
                  ),
                  SizedBox(height: 2.hp),
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
                  SizedBox(height: 3.hp),
                ],

                if (widget.role == 'RESPONDER') ...[
                  _SectionHeader(
                      title: 'Responder Credentials', color: roleColor),
                  SizedBox(height: 2.hp),
                  TextFormField(
                    controller: _organizationController,
                    textCapitalization: TextCapitalization.words,
                    maxLength: 100,
                    decoration: const InputDecoration(
                      labelText: 'Organization / Hospital Name',
                      prefixIcon: Icon(Icons.business_rounded),
                      counterText: '',
                    ),
                    validator: (v) {
                      if (v.isNullOrEmpty) return 'Organization name is required';
                      if (v!.trim().length < 3) return 'Min 3 characters';
                      return null;
                    },
                  ),
                  SizedBox(height: 1.6.hp),
                  TextFormField(
                    controller: _licenseController,
                    maxLength: 30,
                    decoration: const InputDecoration(
                      labelText: 'Medical License Number',
                      prefixIcon: Icon(Icons.badge_rounded),
                      counterText: '',
                    ),
                    validator: (v) {
                      if (v.isNullOrEmpty) return 'License number is required';
                      if (v!.trim().length < 5) return 'Min 5 characters';
                      return null;
                    },
                  ),
                  SizedBox(height: 1.6.hp),

                  // Responder Type is fixed to 'Emergency Responder' as per requirements
                  SizedBox(height: 1.6.hp),

                  // Vehicle Type (full width, Motorbike added)
                  DropdownButtonFormField<String>(
                    initialValue: _selectedVehicleType,
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
                  SizedBox(height: 3.hp),

                  // ─── Document Uploads ───────────────────────────
                  _SectionHeader(title: 'Identity Documents', color: roleColor),
                  SizedBox(height: 1.hp),
                  Text(
                    'Upload your CNIC and Employee Card for admin verification.',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: Colors.grey.shade600, fontSize: 1.2.hp),
                  ),
                  SizedBox(height: 2.hp),

                  // CNIC Row
                  Text(
                    'CNIC',
                    style: theme.textTheme.labelLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 1.hp),
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
                  SizedBox(height: 2.hp),

                  // Employee Card Row
                  Text(
                    'Employee Card',
                    style: theme.textTheme.labelLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 1.hp),
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
                  SizedBox(height: 3.hp),
                ],

                // ─── Security ───────────────────────────────────────
                _SectionHeader(title: 'Security', color: roleColor),
                SizedBox(height: 2.hp),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    errorMaxLines: 2,
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  autofillHints: const [AutofillHints.newPassword],
                  textInputAction: TextInputAction.next,
                  validator: (v) => StringUtils.validatePassword(v),
                ),
                SizedBox(height: 1.6.hp),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  decoration: InputDecoration(
                    labelText: 'Confirm Password',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    errorMaxLines: 2,
                    suffixIcon: IconButton(
                      icon: Icon(_obscureConfirmPassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined),
                      onPressed: () => setState(() =>
                          _obscureConfirmPassword = !_obscureConfirmPassword),
                    ),
                  ),
                  autofillHints: const [AutofillHints.password],
                  textInputAction: TextInputAction.done,
                  validator: (v) {
                    if (v.isNullOrEmpty) return '⚠ Confirm password is required';
                    if (v != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 4.hp),

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
                      padding: EdgeInsets.symmetric(vertical: 2.hp),
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
                        : Text(
                            'Create Account',
                            style: TextStyle(
                              fontSize: 1.8.hp,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
                SizedBox(height: 3.hp),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Already have an account? ', style: TextStyle(fontSize: 1.4.hp)),
                    TextButton(
                      onPressed: () => context.go('/login'),
                      child: Text('Login', style: TextStyle(fontSize: 1.4.hp, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                SizedBox(height: 2.hp),
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
