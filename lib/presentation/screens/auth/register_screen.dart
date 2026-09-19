import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import '../../../core/extensions/extensions.dart';
import '../../../core/utils/exceptions.dart';
import '../../../core/utils/utils.dart';
import '../../../services/location/location_service.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/design_system/design_system.dart';
import 'widgets/auth_common.dart';

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

/// Upload lifecycle of one responder document during submit.
enum _DocUploadState { idle, uploading, uploaded, failed }

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
  final _houseNoFocus              = FocusNode();
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
  // Vehicle is fixed — all responders use Motorbike Ambulance
  final String _selectedVehicleType = 'MOTORBIKE_AMBULANCE';
  final List<String> _selectedSpecializations = [];

  // ── Motorbike-specific fields ──────────────────────────────────────────
  final _motorbikeNumberController = TextEditingController();
  XFile? _drivingLicense;
  XFile? _motorbikeDoc;

  // ── Document Uploads ───────────────────────────────────────────────────
  XFile? _cnicFront;
  XFile? _cnicBack;
  XFile? _employeeCardFront;
  XFile? _employeeCardBack;       // optional
  final _imagePicker = ImagePicker();

  /// Per-document upload state shown on each document card during submit.
  final Map<String, _DocUploadState> _uploadStates = {};

  // ── State ──────────────────────────────────────────────────────────────
  final _formKey              = GlobalKey<FormState>();
  bool _obscurePassword       = true;
  bool _obscureConfirmPassword = true;
  String _selectedPatientType = 'NORMAL';
  bool _isLoading             = false;
  bool _isFetchingLocation    = false;
  int  _locationAttempts      = 0;
  static const int _maxLocationAttempts = 3;

  /// Email rejected by the server as already registered (inline error).
  String? _duplicateEmail;

  bool get _isResponder => widget.role == 'RESPONDER';
  bool get _isPatient => widget.role == 'PATIENT';

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
    _motorbikeNumberController.dispose();
    _cityController.dispose();
    _houseNoController.dispose();
    _houseNoFocus.dispose();
    _addressController.dispose();
    _additionalAddressController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  // ── Date Picker ────────────────────────────────────────────────────────
  Future<void> _selectDate() async {
    final bool isResponder = _isResponder;
    // Responders must be 18+: latest allowed date is today minus 18 years
    final DateTime maxDate = isResponder
        ? DateTime(DateTime.now().year - 18, DateTime.now().month, DateTime.now().day)
        : DateTime.now();
    final DateTime initialDate = isResponder
        ? maxDate
        : DateTime.now().subtract(const Duration(days: 365 * 18));

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: maxDate,
      helpText: isResponder ? 'Responders must be 18 or older' : 'Select date of birth',
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
        _uploadStates.remove(docType);
        switch (docType) {
          case 'CNIC_FRONT':     _cnicFront         = picked; break;
          case 'CNIC_BACK':      _cnicBack          = picked; break;
          case 'EMP_FRONT':      _employeeCardFront = picked; break;
          case 'EMP_BACK':       _employeeCardBack  = picked; break;
          case 'DRIVING_LICENSE':_drivingLicense    = picked; break;
          case 'BIKE_DOC':       _motorbikeDoc      = picked; break;
        }
      });
    }
  }

  // ── Location Dialogs ───────────────────────────────────────────────────
  Future<void> _showLocationLimitDialog() async {
    final retry = await showMfConfirmDialog(
      context,
      icon: Icons.location_off_outlined,
      title: 'Location unavailable',
      message: 'Unable to fetch your location after 3 attempts.\n\n'
          'Please ensure location services and internet are enabled, '
          'or enter your address manually.',
      cancelLabel: 'Enter manually',
      confirmLabel: 'Try again',
    );
    if (retry && mounted) setState(() => _locationAttempts = 0);
  }

  Future<void> _showLocationServiceDialog() async {
    setState(() => _locationAttempts = _maxLocationAttempts);
    final open = await showMfConfirmDialog(
      context,
      icon: Icons.location_off_outlined,
      title: 'Location is turned off',
      message: 'Your device location (GPS) is currently disabled.\n\n'
          'Turn it on in Settings, then come back and try again.',
      confirmLabel: 'Open settings',
      barrierDismissible: false,
    );
    if (!mounted) return;
    setState(() => _locationAttempts = 0);
    if (open) await LocationService().openLocationSettings();
  }

  Future<void> _showPermissionPermanentlyDeniedDialog() async {
    final open = await showMfConfirmDialog(
      context,
      icon: Icons.location_disabled_outlined,
      title: 'Location permission denied',
      message: 'Location permission was permanently denied.\n\n'
          'Open App Settings and grant location access to MediFind.',
      confirmLabel: 'App settings',
      barrierDismissible: false,
    );
    if (!mounted) return;
    setState(() => _locationAttempts = 0);
    if (open) await LocationService().openAppSettings();
  }

  void _showLocationRetrySnack() {
    final remaining = _maxLocationAttempts - _locationAttempts;
    if (remaining <= 0) {
      _showLocationLimitDialog();
    } else {
      showMfSnackBar(
        context,
        'Location unavailable. $remaining attempt${remaining == 1 ? '' : 's'} remaining.',
        tone: MfTone.warning,
      );
    }
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
        // Maps rarely know house numbers here: ask the user to type it instead of guessing
        if (_houseNoController.text.isEmpty) {
          _houseNoFocus.requestFocus();
          showMfSnackBar(context, 'City and area filled from your location. Please add your house or flat number.', tone: MfTone.success);
        } else {
          showMfSnackBar(context, 'Address filled from your location. Please check the house number.', tone: MfTone.success);
        }
      }
    } on LocationException catch (e) {
      if (!mounted) return;
      if (e.code == 'LOCATION_DISABLED') {
        _showLocationServiceDialog();
      } else if (e.code == 'PERMISSION_PERMANENTLY_DENIED') {
        _showPermissionPermanentlyDeniedDialog();
      } else {
        _showLocationRetrySnack();
      }
    } catch (e) {
      if (mounted) _showLocationRetrySnack();
    } finally {
      if (mounted) setState(() => _isFetchingLocation = false);
    }
  }

  // ── Documents ──────────────────────────────────────────────────────────
  XFile? _fileFor(String docType) {
    switch (docType) {
      case 'CNIC_FRONT': return _cnicFront;
      case 'CNIC_BACK': return _cnicBack;
      case 'EMP_FRONT': return _employeeCardFront;
      case 'EMP_BACK': return _employeeCardBack;
      case 'DRIVING_LICENSE': return _drivingLicense;
      case 'BIKE_DOC': return _motorbikeDoc;
    }
    return null;
  }

  static const _requiredDocs = ['CNIC_FRONT', 'CNIC_BACK', 'EMP_FRONT', 'DRIVING_LICENSE', 'BIKE_DOC'];

  int get _requiredDocsAdded => _requiredDocs.where((d) => _fileFor(d) != null).length;

  /// Uploads one document and tracks its state for the card indicator.
  Future<String?> _uploadDoc(dynamic authRepo, String docType) async {
    final file = _fileFor(docType);
    if (file == null) return null;
    debugPrint('   Uploading $docType...');
    setState(() => _uploadStates[docType] = _DocUploadState.uploading);
    try {
      final String url = await authRepo.uploadDocument(File(file.path));
      if (mounted) setState(() => _uploadStates[docType] = _DocUploadState.uploaded);
      return url;
    } catch (_) {
      if (mounted) setState(() => _uploadStates[docType] = _DocUploadState.failed);
      rethrow;
    }
  }

  // ── Register ───────────────────────────────────────────────────────────
  Future<void> _register() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      showMfSnackBar(context, 'Please fix the highlighted fields.', tone: MfTone.danger);
      return;
    }

    // ── Document validation for Responders ──────────────────────────────
    if (_isResponder) {
      String? missing;
      if (_cnicFront == null || _cnicBack == null) {
        missing = 'Please upload both sides of your CNIC before submitting.';
      } else if (_employeeCardFront == null) {
        missing = 'Please upload the front of your Employee Card before submitting.';
      } else if (_drivingLicense == null) {
        missing = 'Please upload your Driving License before submitting.';
      } else if (_motorbikeDoc == null) {
        missing = 'Please upload your Motorbike Documents before submitting.';
      }
      if (missing != null) {
        showMfSnackBar(context, missing, tone: MfTone.danger);
        return;
      }
    }

    setState(() => _isLoading = true);
    try {
      debugPrint('[Register] Starting registration for role: ${widget.role}');

      // ── Upload Responder Documents ─────────────────────────────────────
      String? cnicFrontUrl;
      String? cnicBackUrl;
      String? empFrontUrl;
      String? empBackUrl;
      String? drivingLicenseUrl;
      String? motorbikeDocUrl;

      if (_isResponder) {
        final authRepo = await ref.read(authRepositoryProvider.future);
        cnicFrontUrl = await _uploadDoc(authRepo, 'CNIC_FRONT');
        cnicBackUrl = await _uploadDoc(authRepo, 'CNIC_BACK');
        empFrontUrl = await _uploadDoc(authRepo, 'EMP_FRONT');
        empBackUrl = await _uploadDoc(authRepo, 'EMP_BACK');
        drivingLicenseUrl = await _uploadDoc(authRepo, 'DRIVING_LICENSE');
        motorbikeDocUrl = await _uploadDoc(authRepo, 'BIKE_DOC');
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
        'patientType': _isPatient ? _selectedPatientType : null,

        // Responder-specific
        'organization':   _isResponder ? _organizationController.text.trim() : null,
        'licenseNumber':  _isResponder ? _licenseController.text.trim() : null,
        'responderType':  _isResponder ? _selectedResponderType : null,
        'vehicleType':       _isResponder ? _selectedVehicleType : null,
        'motorbikeNumber':   _isResponder ? _motorbikeNumberController.text.trim() : null,
        'specialization': _isResponder ? _selectedSpecializations : null,

        // Document URLs
        'cnicImageUrl':             cnicFrontUrl,
        'cnicBackImageUrl':         cnicBackUrl,
        'employeeCardImageUrl':     empFrontUrl,
        'employeeCardBackImageUrl': empBackUrl,
        'drivingLicenseUrl':        drivingLicenseUrl,
        'motorbikeDocUrl':          motorbikeDocUrl,
      };

      await ref.read(registerProvider(request).future);
      debugPrint('[Register] Registration successful');

      if (mounted) {
        final bool isResponder = _isResponder;
        await showAuthMessageDialog(
          context,
          icon: isResponder ? Icons.hourglass_top_rounded : Icons.check_circle_outline_rounded,
          tone: isResponder ? MfTone.warning : MfTone.success,
          title: isResponder ? 'Awaiting admin approval' : 'Account created',
          message: isResponder
              ? 'Your account has been created successfully. Please wait for admin approval. You will receive an email with your verification code once your documents are reviewed.'
              : 'Your account has been created. Please enter the 6-digit code sent to your email to verify your account.',
          buttonLabel: isResponder ? 'Got it' : 'Verify email',
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
      debugPrint('[Register] Registration failed: $e');
      if (mounted) {
        final raw = e.toString().replaceAll('Exception:', '').trim();
        final lower = raw.toLowerCase();
        final isDuplicateEmail = lower.contains('email') &&
            (lower.contains('already') || lower.contains('exist') || lower.contains('registered') || lower.contains('in use'));
        if (isDuplicateEmail) {
          setState(() => _duplicateEmail = _emailController.text.trim());
          _formKey.currentState?.validate();
          showMfSnackBar(context, 'An account with this email already exists.', tone: MfTone.danger);
        } else {
          showMfSnackBar(context, 'Registration failed: $raw', tone: MfTone.danger);
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Role presentation ──────────────────────────────────────────────────
  String get _roleLabel {
    switch (widget.role) {
      case 'RESPONDER':
        return 'Emergency responder';
      case 'CAREGIVER':
        return 'Caregiver';
      default:
        return 'Patient';
    }
  }

  IconData get _roleIcon {
    switch (widget.role) {
      case 'RESPONDER':
        return Icons.emergency_share_rounded;
      case 'CAREGIVER':
        return Icons.favorite_border_rounded;
      default:
        return Icons.person_rounded;
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final isResponder = _isResponder;
    final isPatient = _isPatient;
    const gap = SizedBox(height: MfSpace.md);
    const sectionGap = SizedBox(height: MfSpace.lg);

    int section = 0;
    String numbered(String title) => '${++section}. $title';

    return MfScaffold(
      title: 'Create account',
      subtitle: 'Registering as $_roleLabel',
      onBack: () => context.go('/select-role'),
      bottomBar: MfPrimaryButton(
        label: _isLoading
            ? (isResponder ? 'Uploading documents' : 'Creating account')
            : 'Create account',
        icon: Icons.person_add_alt_1_outlined,
        loading: _isLoading,
        onPressed: _register,
      ),
      body: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        // Column (not a lazy ListView) so every validator runs on submit.
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(MfSpace.gutter, MfSpace.md, MfSpace.gutter, MfSpace.xl),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Role summary ─────────────────────────────────────
                    MfCard(
                      padding: const EdgeInsets.all(MfSpace.sm),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: MfColors.tone(context, MfTone.primary).container,
                              borderRadius: MfRadius.smAll,
                            ),
                            child: Icon(_roleIcon, color: MfColors.tone(context, MfTone.primary).foreground),
                          ),
                          const SizedBox(width: MfSpace.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_roleLabel, style: text.titleSmall),
                                Text(
                                  'Fill in each section below. Fields marked optional can be skipped.',
                                  style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                          if (isPatient && widget.patientType != null) ...[
                            const SizedBox(width: MfSpace.xs),
                            MfStatusChip(
                              label: _selectedPatientType == 'DEAF' ? 'Deaf mode' : 'Hearing',
                              icon: _selectedPatientType == 'DEAF'
                                  ? Icons.hearing_disabled_rounded
                                  : Icons.hearing_rounded,
                              tone: MfTone.primary,
                            ),
                          ],
                        ],
                      ),
                    ),
                    gap,

                    // ── Responder Pending-Approval Notice ────────────────
                    if (isResponder) ...[
                      const MfInfoBanner(
                        icon: Icons.hourglass_top_rounded,
                        tone: MfTone.warning,
                        title: 'Account requires admin approval',
                        message: 'After submitting, your credentials will be reviewed by an admin. '
                            'You will receive an activation email with a verification code once approved.',
                      ),
                      gap,
                    ],

                    // ─── Hearing choice (Patient only, if not pre-selected) ──
                    if (isPatient && widget.patientType == null) ...[
                      MfSectionTitle(
                        numbered('Your hearing'),
                        subtitle: 'This sets how MediFind communicates with you in an emergency.',
                      ),
                      const SizedBox(height: MfSpace.xs),
                      _HearingOption(
                        icon: Icons.hearing_disabled_rounded,
                        title: 'I am Deaf / Hard of hearing',
                        subtitle: 'Text-first communication and visual alerts',
                        selected: _selectedPatientType == 'DEAF',
                        onTap: () => setState(() => _selectedPatientType = 'DEAF'),
                      ),
                      const SizedBox(height: MfSpace.xs),
                      _HearingOption(
                        icon: Icons.hearing_rounded,
                        title: 'I can hear',
                        subtitle: 'Standard alerts and notifications',
                        selected: _selectedPatientType == 'NORMAL',
                        onTap: () => setState(() => _selectedPatientType = 'NORMAL'),
                      ),
                      sectionGap,
                    ],

                    // ─── Personal details ────────────────────────────────
                    MfSectionTitle(numbered('Personal details')),
                    const SizedBox(height: MfSpace.xs),
                    TextFormField(
                      controller: _fullNameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Full name',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                        errorMaxLines: 2,
                      ),
                      autofillHints: const [AutofillHints.name],
                      textInputAction: TextInputAction.next,
                      validator: (v) => StringUtils.validateName(v),
                    ),
                    gap,
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email address',
                        prefixIcon: Icon(Icons.email_outlined),
                        errorMaxLines: 2,
                      ),
                      autofillHints: const [AutofillHints.email],
                      textInputAction: TextInputAction.next,
                      onChanged: (_) {
                        if (_duplicateEmail != null) setState(() => _duplicateEmail = null);
                      },
                      validator: (v) {
                        if (_duplicateEmail != null && v?.trim() == _duplicateEmail) {
                          return 'An account with this email already exists';
                        }
                        return StringUtils.validateEmail(v);
                      },
                    ),
                    gap,
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [_phoneFormatter],
                      decoration: const InputDecoration(
                        labelText: 'Phone number',
                        hintText: '+92-300-1234567',
                        prefixIcon: Icon(Icons.phone_outlined),
                        errorMaxLines: 2,
                      ),
                      autofillHints: const [AutofillHints.telephoneNumber],
                      textInputAction: TextInputAction.next,
                      validator: (v) => StringUtils.validatePhoneNumber(v),
                    ),
                    gap,
                    // CNIC: Required for Responder (identity verification), optional for others
                    TextFormField(
                      controller: _cnicController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [_cnicFormatter],
                      decoration: InputDecoration(
                        labelText: isResponder ? 'CNIC number' : 'CNIC number (optional)',
                        hintText: 'e.g. 34601-1234567-1',
                        prefixIcon: const Icon(Icons.credit_card_outlined),
                        helperText: isResponder
                            ? 'Required for identity verification'
                            : 'Used for identity purposes. You may skip this.',
                        helperMaxLines: 2,
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
                    gap,
                    TextFormField(
                      controller: _dobController,
                      readOnly: true,
                      onTap: _selectDate,
                      decoration: const InputDecoration(
                        labelText: 'Date of birth',
                        hintText: 'Select your birth date',
                        prefixIcon: Icon(Icons.calendar_today_outlined),
                        suffixIcon: Icon(Icons.expand_more_rounded),
                        errorMaxLines: 2,
                      ),
                      validator: (v) {
                        if (v.isNullOrEmpty) return 'Please select your date of birth';
                        if (isResponder && _selectedDob != null) {
                          final age = DateTime.now().difference(_selectedDob!).inDays / 365.25;
                          if (age < 18) return 'Responders must be at least 18 years old';
                        }
                        return null;
                      },
                    ),
                    sectionGap,

                    // ─── Location ────────────────────────────────────────
                    MfSectionTitle(
                      numbered(isResponder ? 'Operating area' : 'Address'),
                      subtitle: isResponder
                          ? 'Responders are dispatched by live GPS; only your city is needed.'
                          : 'Used by responders to reach you.',
                    ),
                    const SizedBox(height: MfSpace.xs),
                    MfSecondaryButton(
                      label: _isFetchingLocation ? 'Getting your location' : 'Use my current location',
                      icon: Icons.my_location_rounded,
                      loading: _isFetchingLocation,
                      onPressed: _fetchLocation,
                    ),
                    gap,
                    // City — required for everyone
                    TextFormField(
                      controller: _cityController,
                      textCapitalization: TextCapitalization.words,
                      maxLength: 50,
                      decoration: InputDecoration(
                        labelText: 'City',
                        prefixIcon: const Icon(Icons.location_city_outlined),
                        helperText: isResponder ? 'The city you operate in' : null,
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
                    // House / Flat + Street + Additional Address — Patients & Caregivers only
                    // Responders operate via GPS, not a home address
                    if (!isResponder) ...[
                      gap,
                      TextFormField(
                        controller: _houseNoController,
                        focusNode: _houseNoFocus,
                        maxLength: 20,
                        decoration: const InputDecoration(
                          labelText: 'House / flat',
                          prefixIcon: Icon(Icons.home_outlined),
                          counterText: '',
                          errorMaxLines: 2,
                        ),
                        textInputAction: TextInputAction.next,
                        validator: (v) => v.isNullOrEmpty ? 'House or flat number is required' : null,
                      ),
                      gap,
                      TextFormField(
                        controller: _addressController,
                        maxLength: 100,
                        decoration: const InputDecoration(
                          labelText: 'Street / area',
                          prefixIcon: Icon(Icons.map_outlined),
                          counterText: '',
                          errorMaxLines: 2,
                        ),
                        textInputAction: TextInputAction.next,
                        validator: (v) {
                          if (v.isNullOrEmpty) return 'Street or area is required';
                          if (v!.trim().length < 3) return 'Minimum 3 characters required';
                          return null;
                        },
                      ),
                      gap,
                      TextFormField(
                        controller: _additionalAddressController,
                        maxLength: 100,
                        decoration: const InputDecoration(
                          labelText: 'Additional address (optional)',
                          prefixIcon: Icon(Icons.add_location_alt_outlined),
                          counterText: '',
                        ),
                        textInputAction: TextInputAction.next,
                      ),
                    ],
                    sectionGap,

                    // ─── Responder Credentials ───────────────────────────
                    if (isResponder) ...[
                      MfSectionTitle(numbered('Responder credentials')),
                      const SizedBox(height: MfSpace.xs),
                      TextFormField(
                        controller: _organizationController,
                        textCapitalization: TextCapitalization.words,
                        maxLength: 100,
                        decoration: const InputDecoration(
                          labelText: 'Organization / hospital name',
                          prefixIcon: Icon(Icons.business_outlined),
                          counterText: '',
                          errorMaxLines: 2,
                        ),
                        textInputAction: TextInputAction.next,
                        validator: (v) {
                          if (v.isNullOrEmpty) return 'Organization or hospital name is required';
                          if (v!.trim().length < 3) return 'Minimum 3 characters required';
                          return null;
                        },
                      ),
                      gap,
                      TextFormField(
                        controller: _licenseController,
                        maxLength: 30,
                        decoration: const InputDecoration(
                          labelText: 'Medical license number',
                          prefixIcon: Icon(Icons.badge_outlined),
                          helperText: 'Your official medical or professional license ID',
                          helperMaxLines: 2,
                          counterText: '',
                          errorMaxLines: 2,
                        ),
                        textInputAction: TextInputAction.next,
                        validator: (v) {
                          if (v.isNullOrEmpty) return 'Medical license number is required';
                          if (v!.trim().length < 5) return 'License number must be at least 5 characters';
                          return null;
                        },
                      ),
                      gap,
                      DropdownButtonFormField<String>(
                        initialValue: _selectedResponderType,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'Responder type',
                          prefixIcon: const Icon(Icons.medical_services_outlined),
                          // Show the subtitle of the selected type as helper text
                          helperText: _responderTypeOptions
                              .firstWhere((o) => o['value'] == _selectedResponderType,
                                  orElse: () => {'sub': 'Select the role that best matches your training'})['sub'],
                          helperMaxLines: 2,
                        ),
                        items: _responderTypeOptions
                            .map((opt) => DropdownMenuItem<String>(
                                  value: opt['value'],
                                  child: Text(opt['label']!, overflow: TextOverflow.ellipsis),
                                ))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _selectedResponderType = v);
                        },
                        validator: (v) => v == null ? 'Please select your responder type' : null,
                      ),
                      gap,
                      // Vehicle Type — fixed as Motorbike Ambulance
                      Semantics(
                        label: 'Vehicle type: Motorbike ambulance. Fixed for all responders.',
                        excludeSemantics: true,
                        child: MfCard(
                          padding: const EdgeInsets.symmetric(horizontal: MfSpace.md, vertical: MfSpace.sm),
                          color: cs.surfaceContainerLow,
                          child: Row(
                            children: [
                              Icon(Icons.two_wheeler_rounded, color: cs.onSurfaceVariant),
                              const SizedBox(width: MfSpace.sm),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Vehicle type', style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                                    Text('Motorbike ambulance', style: text.titleSmall),
                                  ],
                                ),
                              ),
                              Icon(Icons.lock_outline_rounded, size: 18, color: cs.onSurfaceVariant),
                            ],
                          ),
                        ),
                      ),
                      gap,
                      TextFormField(
                        controller: _motorbikeNumberController,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          labelText: 'Motorbike registration number',
                          hintText: 'e.g. LHR-1234',
                          prefixIcon: Icon(Icons.pin_outlined),
                          errorMaxLines: 2,
                        ),
                        textInputAction: TextInputAction.next,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Motorbike number is required';
                          return null;
                        },
                      ),
                      sectionGap,

                      // ─── Specializations (multi-select) ────────────────
                      MfSectionTitle(
                        numbered('Medical specializations'),
                        subtitle: _selectedSpecializations.isEmpty
                            ? 'Optional but recommended. Select all that apply.'
                            : '${_selectedSpecializations.length} selected',
                      ),
                      const SizedBox(height: MfSpace.xs),
                      Wrap(
                        spacing: MfSpace.xs,
                        runSpacing: MfSpace.xs,
                        children: [
                          for (final spec in _allSpecializations)
                            FilterChip(
                              label: Text(spec),
                              selected: _selectedSpecializations.contains(spec),
                              materialTapTargetSize: MaterialTapTargetSize.padded,
                              onSelected: (sel) => setState(() {
                                if (sel) {
                                  _selectedSpecializations.add(spec);
                                } else {
                                  _selectedSpecializations.remove(spec);
                                }
                              }),
                            ),
                        ],
                      ),
                      sectionGap,

                      // ─── Identity Documents ────────────────────────────
                      MfSectionTitle(
                        numbered('Verification documents'),
                        subtitle: '$_requiredDocsAdded of ${_requiredDocs.length} required documents added',
                      ),
                      const SizedBox(height: MfSpace.xs),
                      Semantics(
                        label: '$_requiredDocsAdded of ${_requiredDocs.length} required documents added',
                        excludeSemantics: true,
                        child: ClipRRect(
                          borderRadius: MfRadius.smAll,
                          child: LinearProgressIndicator(
                            value: _requiredDocsAdded / _requiredDocs.length,
                            minHeight: 6,
                          ),
                        ),
                      ),
                      const SizedBox(height: MfSpace.sm),
                      const MfInfoBanner(
                        icon: Icons.verified_user_outlined,
                        tone: MfTone.primary,
                        title: 'Clear photos speed up approval',
                        message: 'CNIC (both sides), Employee Card (front), Driving License and Motorbike '
                            'Documents are required. Employee Card back side is optional.',
                      ),
                      const SizedBox(height: MfSpace.sm),
                      MfCard(
                        padding: const EdgeInsets.all(MfSpace.sm),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _docGroupLabel(context, 'CNIC'),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: _docCard('CNIC_FRONT', 'Front side', Icons.credit_card_outlined, true)),
                                const SizedBox(width: MfSpace.sm),
                                Expanded(child: _docCard('CNIC_BACK', 'Back side', Icons.credit_card_outlined, true)),
                              ],
                            ),
                            const SizedBox(height: MfSpace.md),
                            _docGroupLabel(context, 'Employee card'),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: _docCard('EMP_FRONT', 'Front side', Icons.badge_outlined, true)),
                                const SizedBox(width: MfSpace.sm),
                                Expanded(child: _docCard('EMP_BACK', 'Back side', Icons.badge_outlined, false)),
                              ],
                            ),
                            const SizedBox(height: MfSpace.md),
                            _docGroupLabel(context, 'Driving license'),
                            _docCard('DRIVING_LICENSE', 'Driving license', Icons.drive_eta_outlined, true),
                            const SizedBox(height: MfSpace.md),
                            _docGroupLabel(
                              context,
                              'Motorbike documents',
                              subtitle: 'Registration certificate (RC book)',
                            ),
                            _docCard('BIKE_DOC', 'Registration / RC book', Icons.two_wheeler_rounded, true),
                          ],
                        ),
                      ),
                      sectionGap,
                    ],

                    // ─── Security ────────────────────────────────────────
                    MfSectionTitle(
                      numbered('Password'),
                      subtitle: 'At least 8 characters with uppercase, lowercase, a number and a symbol.',
                    ),
                    const SizedBox(height: MfSpace.xs),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        errorMaxLines: 3,
                        suffixIcon: IconButton(
                          tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                          icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      autofillHints: const [AutofillHints.newPassword],
                      textInputAction: TextInputAction.next,
                      validator: (v) => StringUtils.validatePassword(v),
                    ),
                    gap,
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirmPassword,
                      decoration: InputDecoration(
                        labelText: 'Confirm password',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        errorMaxLines: 2,
                        suffixIcon: IconButton(
                          tooltip: _obscureConfirmPassword ? 'Show password' : 'Hide password',
                          icon: Icon(_obscureConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                          onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                        ),
                      ),
                      autofillHints: const [AutofillHints.password],
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) {
                        if (!_isLoading) _register();
                      },
                      validator: (v) {
                        if (v.isNullOrEmpty) return 'Please confirm your password';
                        if (v != _passwordController.text) return 'Passwords do not match. Please re-enter.';
                        return null;
                      },
                    ),
                    sectionGap,

                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'Already have an account?',
                          style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                        ),
                        MfTextButton(label: 'Log in', onPressed: () => context.go('/login')),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _docGroupLabel(BuildContext context, String title, {String? subtitle}) {
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: MfSpace.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: text.titleSmall),
          if (subtitle != null)
            Text(subtitle, style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _docCard(String docType, String label, IconData icon, bool isRequired) {
    return _DocumentUploadCard(
      label: label,
      icon: icon,
      file: _fileFor(docType),
      isRequired: isRequired,
      uploadState: _uploadStates[docType] ?? _DocUploadState.idle,
      onTap: _isLoading ? null : () => _pickImage(docType),
    );
  }
}

// ─── Helper Widgets ─────────────────────────────────────────────────────────

class _HearingOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _HearingOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final t = MfColors.tone(context, MfTone.primary);
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      button: true,
      label: '$title. $subtitle',
      excludeSemantics: true,
      child: Material(
        color: selected ? Color.alphaBlend(t.container, cs.surface) : cs.surface,
        shape: RoundedRectangleBorder(
          borderRadius: MfRadius.mdAll,
          side: BorderSide(color: selected ? cs.primary : cs.outlineVariant, width: selected ? 2 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Padding(
              padding: const EdgeInsets.all(MfSpace.sm),
              child: Row(
                children: [
                  Icon(icon, size: 28, color: selected ? t.foreground : cs.onSurfaceVariant),
                  const SizedBox(width: MfSpace.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: text.titleSmall),
                        Text(subtitle, style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  Icon(
                    selected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
                    color: selected ? cs.primary : cs.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DocumentUploadCard extends StatefulWidget {
  final String label;
  final IconData icon;
  final XFile? file;
  final bool isRequired;
  final _DocUploadState uploadState;
  final VoidCallback? onTap;

  const _DocumentUploadCard({
    required this.label,
    required this.icon,
    required this.file,
    required this.isRequired,
    required this.uploadState,
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
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final hasFile = widget.file != null;
    final success = MfColors.tone(context, MfTone.success);

    // ── Status line (icon + label) ────────────────────────────────────────
    IconData statusIcon;
    String statusLabel;
    Color statusColor;
    switch (widget.uploadState) {
      case _DocUploadState.uploading:
        statusIcon = Icons.cloud_upload_outlined;
        statusLabel = 'Uploading';
        statusColor = cs.primary;
        break;
      case _DocUploadState.uploaded:
        statusIcon = Icons.check_circle_rounded;
        statusLabel = 'Uploaded';
        statusColor = success.foreground;
        break;
      case _DocUploadState.failed:
        statusIcon = Icons.error_outline_rounded;
        statusLabel = 'Upload failed';
        statusColor = cs.error;
        break;
      case _DocUploadState.idle:
        if (hasFile) {
          statusIcon = Icons.check_circle_outline_rounded;
          statusLabel = 'Added';
          statusColor = success.foreground;
        } else {
          statusIcon = Icons.upload_file_outlined;
          statusLabel = widget.isRequired ? 'Required' : 'Optional';
          statusColor = cs.onSurfaceVariant;
        }
    }

    final borderColor = widget.uploadState == _DocUploadState.failed
        ? cs.error
        : hasFile
            ? success.solid
            : cs.outlineVariant;

    Widget preview;
    if (hasFile && _imageBytes != null) {
      preview = Stack(
        fit: StackFit.expand,
        children: [
          Image.memory(_imageBytes!, fit: BoxFit.cover),
          if (widget.uploadState == _DocUploadState.uploading)
            ColoredBox(
              color: cs.surface.withValues(alpha: 0.7),
              child: const Center(
                child: SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2.5)),
              ),
            ),
        ],
      );
    } else if (hasFile) {
      preview = const Center(
        child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
      );
    } else {
      preview = ColoredBox(
        color: cs.surfaceContainerLow,
        child: Center(child: Icon(widget.icon, size: 32, color: cs.onSurfaceVariant)),
      );
    }

    final semantics = '${widget.label}. $statusLabel. '
        '${hasFile ? 'Double tap to replace.' : 'Double tap to choose a photo.'}';

    return Semantics(
      button: widget.onTap != null,
      label: semantics,
      excludeSemantics: true,
      child: Material(
        color: cs.surface,
        shape: RoundedRectangleBorder(
          borderRadius: MfRadius.mdAll,
          side: BorderSide(color: borderColor, width: hasFile ? 1.5 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: 96, child: preview),
              Padding(
                padding: const EdgeInsets.all(MfSpace.xs),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.label, style: text.labelLarge, maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(statusIcon, size: 16, color: statusColor),
                        const SizedBox(width: MfSpace.xxs),
                        Flexible(
                          child: Text(
                            statusLabel,
                            style: text.labelMedium?.copyWith(color: statusColor),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: MfSpace.xxs),
                    Row(
                      children: [
                        Icon(
                          hasFile ? Icons.swap_horiz_rounded : Icons.add_photo_alternate_outlined,
                          size: 16,
                          color: widget.onTap == null ? cs.onSurfaceVariant : cs.primary,
                        ),
                        const SizedBox(width: MfSpace.xxs),
                        Flexible(
                          child: Text(
                            hasFile ? 'Replace' : 'Choose photo',
                            style: text.labelMedium?.copyWith(
                              color: widget.onTap == null ? cs.onSurfaceVariant : cs.primary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
