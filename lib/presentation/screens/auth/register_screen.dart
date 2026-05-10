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

// ─── Responder Type Options ──────────────────────────────────────────────────
// Matches ResponderType enum — field emergency responders (1122-style)
const _responderTypeOptions = [
  {'value': 'RESCUE_OFFICER',  'label': 'Rescue Officer (e.g. 1122)',         'sub': 'Rescue & emergency first aid trained'},
  {'value': 'PARAMEDIC',       'label': 'Paramedic',                          'sub': 'Advanced life support (ALS)'},
  {'value': 'EMT',             'label': 'Emergency Medical Technician (EMT)', 'sub': 'Basic / intermediate emergency care'},
  {'value': 'FIRST_RESPONDER', 'label': 'First Responder',                   'sub': 'Basic first aid & CPR trained'},
  {'value': 'VOLUNTEER',       'label': 'Community Volunteer',                'sub': 'Basic aid, no formal certification required'},
];

// ─── Predefined Specializations ─────────────────────────────────────────────
const _allSpecializations = [
  'General Emergency',
  'Cardiology',
  'Trauma & Surgery',
  'Neurology',
  'Pediatrics',
  'Burns & Critical Care',
  'Toxicology',
  'Orthopedics',
  'Obstetrics',
];

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
  // ── Common Controllers ──────────────────────────────────────────────────
  final _fullNameController        = TextEditingController();
  final _emailController           = TextEditingController();
  final _phoneController           = TextEditingController();
  final _cnicController            = TextEditingController();
  final _passwordController        = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _cityController            = TextEditingController();
  final _houseNoController         = TextEditingController();
  final _addressController         = TextEditingController();
  final _additionalAddressController = TextEditingController();
  final _dobController             = TextEditingController();
  DateTime? _selectedDob;

  // ── Responder-specific Controllers ─────────────────────────────────────
  final _organizationController = TextEditingController();
  final _licenseController      = TextEditingController();

  // ── Masked Formatters ──────────────────────────────────────────────────
  final _cnicFormatter = MaskTextInputFormatter(
    mask: '#####-#######-#',
    filter: {'#': RegExp(r'[0-9]')},
    type: MaskAutoCompletionType.lazy,
  );
  final _phoneFormatter = MaskTextInputFormatter(
    mask: '+92-###-#######',
    filter: {'#': RegExp(r'[0-9]')},
    type: MaskAutoCompletionType.lazy,
  );

  // ── Responder Selections ───────────────────────────────────────────────
  String _selectedResponderType   = 'RESCUE_OFFICER'; // mutable, user-selectable
  String _selectedVehicleType     = 'AMBULANCE';
  final List<String> _selectedSpecializations = [];

  // ── Document Uploads ───────────────────────────────────────────────────
  XFile? _cnicFront;
  XFile? _cnicBack;
  XFile? _employeeCardFront;
  XFile? _employeeCardBack;       // optional
  final _imagePicker = ImagePicker();

  // ── State ──────────────────────────────────────────────────────────────
  final _formKey              = GlobalKey<FormState>();
  bool _obscurePassword       = true;
  bool _obscureConfirmPassword = true;
  String _selectedPatientType = 'NORMAL';
  bool _isLoading             = false;
  bool _isFetchingLocation    = false;
  int  _locationAttempts      = 0;
  static const int _maxLocationAttempts = 3;

  @override
  void initState() {
    super.initState();
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

  // ── Date Picker ────────────────────────────────────────────────────────
  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(primary: _roleTheme['color'] as Color),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _selectedDob = picked;
        _dobController.text = '${picked.day}/${picked.month}/${picked.year}';
      });
    }
  }

  // ── Image Picker ───────────────────────────────────────────────────────
  Future<void> _pickImage(String docType) async {
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (picked != null) {
      setState(() {
        switch (docType) {
          case 'CNIC_FRONT': _cnicFront = picked;          break;
          case 'CNIC_BACK':  _cnicBack  = picked;          break;
          case 'EMP_FRONT':  _employeeCardFront = picked;  break;
          case 'EMP_BACK':   _employeeCardBack  = picked;  break;
        }
      });
    }
  }

  // ── Location Dialogs ───────────────────────────────────────────────────
  void _showLocationLimitDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.location_off_rounded, color: Colors.orange),
          SizedBox(width: 10),
          Text('Location Unavailable'),
        ]),
        content: const Text(
          'Unable to fetch your location after 3 attempts.\n\n'
          'Please ensure location services and internet are enabled, '
          'or enter your address manually.',
        ),
        actions: [
          TextButton(
            onPressed: () { Navigator.pop(ctx); setState(() => _locationAttempts = 0); },
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

  void _showLocationServiceDialog() {
    setState(() => _locationAttempts = _maxLocationAttempts);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.location_off_rounded, color: Colors.orange),
          SizedBox(width: 10),
          Expanded(child: Text('Location Turned Off')),
        ]),
        content: const Text(
          'Your device\'s location (GPS) is currently disabled.\n\n'
          'Please turn it on in Settings, then come back and try again.',
        ),
        actions: [
          TextButton(
            onPressed: () { Navigator.pop(ctx); setState(() => _locationAttempts = 0); },
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

  void _showPermissionPermanentlyDeniedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.location_disabled_rounded, color: Colors.red),
          SizedBox(width: 10),
          Expanded(child: Text('Permission Denied')),
        ]),
        content: const Text(
          'Location permission was permanently denied.\n\n'
          'Please open App Settings and grant location access to MediFind.',
        ),
        actions: [
          TextButton(
            onPressed: () { Navigator.pop(ctx); setState(() => _locationAttempts = 0); },
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

  // ── Fetch Location ─────────────────────────────────────────────────────
  Future<void> _fetchLocation() async {
    if (_locationAttempts >= _maxLocationAttempts) {
      _showLocationLimitDialog();
      return;
    }
    setState(() { _isFetchingLocation = true; _locationAttempts++; });
    try {
      final locationService = LocationService();
      final position = await locationService.getCurrentLocation();
      final place = await locationService.getPlaceFromCoordinates(
        position.latitude, position.longitude,
      );
      if (mounted) {
        setState(() {
          _cityController.text    = place['city'] ?? '';
          _addressController.text = place['address'] ?? '';
          _houseNoController.text = place['houseNumber'] ?? '';
          _locationAttempts = 0;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Location fetched successfully!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } on LocationException catch (e) {
      if (!mounted) return;
      if (e.code == 'LOCATION_DISABLED') {
        _showLocationServiceDialog();
      } else if (e.code == 'PERMISSION_PERMANENTLY_DENIED') {
        _showPermissionPermanentlyDeniedDialog();
      } else {
        final remaining = _maxLocationAttempts - _locationAttempts;
        if (remaining <= 0) { _showLocationLimitDialog(); }
        else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Location unavailable. $remaining attempt${remaining == 1 ? '' : 's'} remaining.'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ));
        }
      }
    } catch (e) {
      if (mounted) {
        final remaining = _maxLocationAttempts - _locationAttempts;
        if (remaining <= 0) { _showLocationLimitDialog(); }
        else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Location unavailable. $remaining attempt${remaining == 1 ? '' : 's'} remaining.'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ));
        }
      }
    } finally {
      if (mounted) setState(() => _isFetchingLocation = false);
    }
  }

  // ── Register ───────────────────────────────────────────────────────────
  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    // ── Document validation for Responders ──────────────────────────────
    if (widget.role == 'RESPONDER') {
      if (_cnicFront == null || _cnicBack == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('⚠ Please upload both sides of your CNIC before submitting.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
        return;
      }
      if (_employeeCardFront == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('⚠ Please upload the front of your Employee Card before submitting.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
        return;
      }
    }

    setState(() => _isLoading = true);
    try {
      debugPrint('📝 [Register] Starting registration for role: ${widget.role}');

      // ── Upload Responder Documents ─────────────────────────────────────
      String? cnicFrontUrl;
      String? cnicBackUrl;
      String? empFrontUrl;
      String? empBackUrl;

      if (widget.role == 'RESPONDER') {
        final authRepo = await ref.read(authRepositoryProvider.future);
        if (_cnicFront != null) {
          debugPrint('   Uploading CNIC Front...');
          cnicFrontUrl = await authRepo.uploadDocument(File(_cnicFront!.path));
        }
        if (_cnicBack != null) {
          debugPrint('   Uploading CNIC Back...');
          cnicBackUrl = await authRepo.uploadDocument(File(_cnicBack!.path));
        }
        if (_employeeCardFront != null) {
          debugPrint('   Uploading Employee Card Front...');
          empFrontUrl = await authRepo.uploadDocument(File(_employeeCardFront!.path));
        }
        if (_employeeCardBack != null) {
          debugPrint('   Uploading Employee Card Back...');
          empBackUrl = await authRepo.uploadDocument(File(_employeeCardBack!.path));
        }
      }

      // ── Compose Address ────────────────────────────────────────────────
      final composedAddress = [
        _houseNoController.text.trim(),
        _addressController.text.trim(),
        _additionalAddressController.text.trim(),
      ].where((s) => s.isNotEmpty).join(', ');

      // ── Build Request ──────────────────────────────────────────────────
      final Map<String, dynamic> request = {
        'fullName':    _fullNameController.text.trim(),
        'email':       _emailController.text.trim(),
        'phoneNumber': _phoneController.text.replaceAll('-', '').trim(),
        'password':    _passwordController.text,
        'role':        widget.role,
        'city':        _cityController.text.trim(),
        'address':     composedAddress,
        'cnic':        _cnicController.text.trim().isEmpty ? null : _cnicController.text.trim(),
        'dateOfBirth': _selectedDob?.toIso8601String(),

        // Patient-specific
        'patientType': widget.role == 'PATIENT' ? _selectedPatientType : null,

        // Responder-specific
        'organization':   widget.role == 'RESPONDER' ? _organizationController.text.trim() : null,
        'licenseNumber':  widget.role == 'RESPONDER' ? _licenseController.text.trim() : null,
        'responderType':  widget.role == 'RESPONDER' ? _selectedResponderType : null,
        'vehicleType':    widget.role == 'RESPONDER' ? _selectedVehicleType : null,
        'specialization': widget.role == 'RESPONDER' ? _selectedSpecializations : null,

        // Document URLs
        'cnicImageUrl':             cnicFrontUrl,
        'cnicBackImageUrl':         cnicBackUrl,
        'employeeCardImageUrl':     empFrontUrl,
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
            title: Row(children: [
              Icon(
                Icons.check_circle_rounded,
                color: isResponder ? Colors.orange : Colors.green,
                size: 28,
              ),
              const SizedBox(width: 10),
              const Text('Registration Successful'),
            ]),
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
            context.go('/pending-approval', extra: {'email': _emailController.text.trim()});
          } else {
            context.go('/verify-email', extra: {'email': _emailController.text.trim()});
          }
        }
      }
    } catch (e) {
      debugPrint('❌ [Register] Registration failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Registration failed: ${e.toString().replaceAll('Exception:', '').trim()}'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Role Theme ─────────────────────────────────────────────────────────
  Map<String, dynamic> get _roleTheme {
    switch (widget.role) {
      case 'RESPONDER':
        return {'color': const Color(0xFFD32F2F), 'icon': Icons.local_hospital_rounded, 'label': 'Emergency Responder'};
      case 'CAREGIVER':
        return {'color': const Color(0xFF00897B), 'icon': Icons.favorite_rounded, 'label': 'Caregiver'};
      default:
        return {'color': AppColors.primary, 'icon': Icons.person_rounded, 'label': 'Patient'};
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme     = Theme.of(context);
    final roleColor = _roleTheme['color'] as Color;
    final roleIcon  = _roleTheme['icon'] as IconData;
    final roleLabel = _roleTheme['label'] as String;
    final isResponder  = widget.role == 'RESPONDER';
    final isPatient    = widget.role == 'PATIENT';

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
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 6.wp, vertical: 1.hp),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [

                // ── Role Badge Header ──────────────────────────────────
                Row(children: [
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
                      Text('Create Account',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold, fontSize: 2.4.hp,
                        )),
                      Text('Registering as: $roleLabel',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: roleColor, fontWeight: FontWeight.w600, fontSize: 1.4.hp,
                        )),
                    ],
                  ),
                ]),
                SizedBox(height: 4.hp),

                // ── Responder Pending-Approval Notice ─────────────────
                if (isResponder) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.shade300),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline_rounded, color: Colors.orange.shade700, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Account Pending Admin Approval',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange.shade800,
                                  fontSize: 1.4.hp,
                                )),
                              const SizedBox(height: 4),
                              Text(
                                'After submitting, your credentials will be reviewed by an admin. '
                                'You will receive an activation email with a verification code once approved.',
                                style: TextStyle(color: Colors.orange.shade700, fontSize: 1.2.hp),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 3.hp),
                ],

                // ─── Demographic Information ───────────────────────────
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

                // CNIC: Required for Responder (identity verification), optional for others
                TextFormField(
                  controller: _cnicController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [_cnicFormatter],
                  decoration: InputDecoration(
                    labelText: isResponder ? 'CNIC Number' : 'CNIC Number (Optional)',
                    hintText: 'e.g. 34601-1234567-1',
                    prefixIcon: const Icon(Icons.credit_card_outlined),
                    helperText: isResponder
                        ? 'Required for identity verification'
                        : 'Used for identity purposes — you may skip this',
                    errorMaxLines: 2,
                  ),
                  textInputAction: TextInputAction.next,
                  validator: (v) {
                    if (isResponder) return StringUtils.validateCnic(v);
                    // Optional for Patient/Caregiver: only validate format if provided
                    if (v != null && v.trim().isNotEmpty) return StringUtils.validateCnic(v);
                    return null;
                  },
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
                  validator: (v) => v.isNullOrEmpty ? 'Please select your date of birth' : null,
                ),
                SizedBox(height: 3.hp),

                // ─── Location Information ─────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _SectionHeader(title: 'Location Information', color: roleColor),
                    TextButton.icon(
                      onPressed: _isFetchingLocation ? null : _fetchLocation,
                      icon: _isFetchingLocation
                          ? SizedBox(
                              width: 14, height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: roleColor),
                            )
                          : Icon(Icons.my_location_rounded, size: 18, color: roleColor),
                      label: Text(
                        _isFetchingLocation ? 'Fetching...' : 'Get My Location',
                        style: TextStyle(color: roleColor, fontWeight: FontWeight.bold, fontSize: 1.4.hp),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 2.hp),

                Row(children: [
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
                        if (v.isNullOrEmpty) return 'City is required';
                        if (v!.trim().length < 2) return 'Minimum 2 characters required';
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
                      validator: (v) => v.isNullOrEmpty ? 'House or flat number is required' : null,
                    ),
                  ),
                ]),
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
                    if (v.isNullOrEmpty) return 'Street or area is required';
                    if (v!.trim().length < 3) return 'Minimum 3 characters required';
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

                // ─── Accessibility Mode (Patient only, if not pre-selected) ──
                if (isPatient && widget.patientType == null) ...[
                  _SectionHeader(title: 'Accessibility Mode', color: roleColor),
                  SizedBox(height: 1.hp),
                  Text(
                    'Select your accessibility needs.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade600, fontSize: 1.2.hp,
                    ),
                  ),
                  SizedBox(height: 2.hp),
                  Row(children: [
                    _PatientTypeChip(
                      label: 'Standard Mode',
                      icon: Icons.person_rounded,
                      color: roleColor,
                      selected: _selectedPatientType == 'NORMAL',
                      onTap: () => setState(() => _selectedPatientType = 'NORMAL'),
                    ),
                    const SizedBox(width: 12),
                    _PatientTypeChip(
                      label: 'Deaf & Mute Mode',
                      icon: Icons.hearing_disabled_rounded,
                      color: const Color(0xFF00897B),
                      selected: _selectedPatientType == 'DEAF',
                      onTap: () => setState(() => _selectedPatientType = 'DEAF'),
                    ),
                  ]),
                  SizedBox(height: 3.hp),
                ],

                // ─── Responder Credentials ────────────────────────────
                if (isResponder) ...[
                  _SectionHeader(title: 'Responder Credentials', color: roleColor),
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
                      if (v.isNullOrEmpty) return 'Organization or hospital name is required';
                      if (v!.trim().length < 3) return 'Minimum 3 characters required';
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
                      helperText: 'Your official medical or professional license ID',
                      counterText: '',
                    ),
                    validator: (v) {
                      if (v.isNullOrEmpty) return 'Medical license number is required';
                      if (v!.trim().length < 5) return 'License number must be at least 5 characters';
                      return null;
                    },
                  ),
                  SizedBox(height: 1.6.hp),

                  // Responder Type — dropdown with description subtitle
                  DropdownButtonFormField<String>(
                    initialValue: _selectedResponderType,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Responder Type',
                      prefixIcon: Icon(Icons.medical_services_rounded),
                      helperText: 'Select the role that best matches your training',
                    ),
                    items: _responderTypeOptions.map((opt) => DropdownMenuItem<String>(
                      value: opt['value'],
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(opt['label']!,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          Text(opt['sub']!,
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                        ],
                      ),
                    )).toList(),
                    onChanged: (v) { if (v != null) setState(() => _selectedResponderType = v); },
                    validator: (v) => v == null ? 'Please select your responder type' : null,
                  ),
                  SizedBox(height: 1.6.hp),

                  // Vehicle Type
                  DropdownButtonFormField<String>(
                    value: _selectedVehicleType,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Vehicle Type',
                      prefixIcon: Icon(Icons.directions_car_rounded),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'AMBULANCE', child: Text('Ambulance')),
                      DropdownMenuItem(value: 'MOTORBIKE', child: Text('Motorbike')),
                      DropdownMenuItem(value: 'CAR',       child: Text('Car')),
                      DropdownMenuItem(value: 'ON_FOOT',   child: Text('On Foot / No Vehicle')),
                    ],
                    onChanged: (v) { if (v != null) setState(() => _selectedVehicleType = v); },
                  ),
                  SizedBox(height: 3.hp),

                  // ─── Specializations (multi-select) ─────────────────
                  _SectionHeader(title: 'Medical Specializations', color: roleColor),
                  SizedBox(height: 1.hp),
                  Text(
                    'Select all areas that apply to your practice (optional but recommended).',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade600, fontSize: 1.2.hp,
                    ),
                  ),
                  SizedBox(height: 1.5.hp),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _allSpecializations.map((spec) {
                      final selected = _selectedSpecializations.contains(spec);
                      return GestureDetector(
                        onTap: () => setState(() {
                          if (selected) {
                            _selectedSpecializations.remove(spec);
                          } else {
                            _selectedSpecializations.add(spec);
                          }
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: selected ? roleColor : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: selected ? roleColor : Colors.grey.shade300,
                              width: selected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (selected) ...[
                                const Icon(Icons.check_circle, color: Colors.white, size: 14),
                                const SizedBox(width: 5),
                              ],
                              Text(
                                spec,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                                  color: selected ? Colors.white : Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  if (_selectedSpecializations.isNotEmpty) ...[
                    SizedBox(height: 1.hp),
                    Text(
                      '${_selectedSpecializations.length} selected',
                      style: TextStyle(color: roleColor, fontWeight: FontWeight.w600, fontSize: 1.2.hp),
                    ),
                  ],
                  SizedBox(height: 3.hp),

                  // ─── Identity Documents ──────────────────────────────
                  _SectionHeader(title: 'Identity Documents', color: roleColor),
                  SizedBox(height: 1.hp),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: roleColor.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: roleColor.withOpacity(0.2)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.verified_user_outlined, color: roleColor, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'CNIC (both sides) and Employee Card (front) are required. '
                            'Employee Card back side is optional.',
                            style: TextStyle(color: roleColor, fontSize: 1.2.hp),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 2.hp),

                  // CNIC Row
                  Text('CNIC',
                    style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold)),
                  SizedBox(height: 1.hp),
                  Row(children: [
                    Expanded(child: _DocumentUploadCard(
                      label: 'Front Side',
                      icon: Icons.credit_card_rounded,
                      color: roleColor,
                      file: _cnicFront,
                      isRequired: true,
                      onTap: () => _pickImage('CNIC_FRONT'),
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: _DocumentUploadCard(
                      label: 'Back Side',
                      icon: Icons.credit_card_rounded,
                      color: roleColor,
                      file: _cnicBack,
                      isRequired: true,
                      onTap: () => _pickImage('CNIC_BACK'),
                    )),
                  ]),
                  SizedBox(height: 2.hp),

                  // Employee Card Row
                  Text('Employee Card',
                    style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold)),
                  SizedBox(height: 1.hp),
                  Row(children: [
                    Expanded(child: _DocumentUploadCard(
                      label: 'Front Side',
                      icon: Icons.badge_rounded,
                      color: roleColor,
                      file: _employeeCardFront,
                      isRequired: true,
                      onTap: () => _pickImage('EMP_FRONT'),
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: _DocumentUploadCard(
                      label: 'Back (Optional)',
                      icon: Icons.badge_rounded,
                      color: roleColor,
                      file: _employeeCardBack,
                      isRequired: false,
                      onTap: () => _pickImage('EMP_BACK'),
                    )),
                  ]),
                  SizedBox(height: 3.hp),
                ],

                // ─── Security ─────────────────────────────────────────
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
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
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
                      onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                    ),
                  ),
                  autofillHints: const [AutofillHints.password],
                  textInputAction: TextInputAction.done,
                  validator: (v) {
                    if (v.isNullOrEmpty) return 'Please confirm your password';
                    if (v != _passwordController.text) return 'Passwords do not match — please re-enter';
                    return null;
                  },
                ),
                SizedBox(height: 4.hp),

                // ─── Submit Button ────────────────────────────────────
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 24, width: 24,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
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
                      child: Text('Login',
                        style: TextStyle(fontSize: 1.4.hp, fontWeight: FontWeight.bold)),
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
    return Row(children: [
      Container(
        width: 4, height: 18,
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
      ),
      Text(title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
    ]);
  }
}

class _DocumentUploadCard extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color color;
  final XFile? file;
  final bool isRequired;
  final VoidCallback onTap;

  const _DocumentUploadCard({
    required this.label,
    required this.icon,
    required this.color,
    required this.file,
    required this.isRequired,
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
    if (widget.file != oldWidget.file && widget.file != null) _loadBytes();
  }

  Future<void> _loadBytes() async {
    final bytes = await widget.file!.readAsBytes();
    if (mounted) setState(() => _imageBytes = bytes);
  }

  @override
  Widget build(BuildContext context) {
    final theme   = Theme.of(context);
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
            color: hasFile
                ? widget.color
                : widget.isRequired
                    ? Colors.grey.shade400
                    : Colors.grey.shade300,
            width: hasFile ? 2.0 : 1.5,
          ),
        ),
        child: hasFile && _imageBytes != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.memory(_imageBytes!, fit: BoxFit.cover),
                    Positioned(
                      bottom: 0, left: 0, right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        color: Colors.black.withOpacity(0.55),
                        child: Text(
                          '✓ ${widget.label}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
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
                      // Show required/optional badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: widget.isRequired
                              ? Colors.red.shade50
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          widget.isRequired ? 'Required' : 'Optional',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: widget.isRequired ? Colors.red.shade400 : Colors.grey.shade500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.upload_file_outlined, size: 12, color: widget.color),
                          const SizedBox(width: 4),
                          Text(
                            'Tap to upload',
                            style: TextStyle(color: widget.color, fontSize: 11, fontWeight: FontWeight.w600),
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
    required this.label, required this.icon,
    required this.color, required this.selected, required this.onTap,
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
            border: Border.all(color: selected ? color : Colors.grey.shade300, width: selected ? 2 : 1),
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
