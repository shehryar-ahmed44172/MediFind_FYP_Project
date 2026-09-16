import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/caregiver_providers.dart';
import '../../widgets/design_system/design_system.dart';

class LinkPatientScreen extends ConsumerStatefulWidget {
  const LinkPatientScreen({super.key});

  @override
  ConsumerState<LinkPatientScreen> createState() => _LinkPatientScreenState();
}

class _LinkPatientScreenState extends ConsumerState<LinkPatientScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  String _selectedRelationship = 'Father';

  final List<String> _relationshipOptions = [
    'Father', 'Mother', 'Son', 'Daughter', 'Spouse', 'Sibling', 'Friend', 'Other'
  ];

  bool _isLoading = false;

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  String? _validateEmail(String? value) {
    final email = (value ?? '').trim();
    if (email.isEmpty) return 'Enter the patient\'s email address.';
    if (!_emailPattern.hasMatch(email)) return 'Please enter a valid email address.';
    return null;
  }

  Future<void> _sendInvitation() async {
    final email = _emailController.text.trim();
    if (!(_formKey.currentState?.validate() ?? _emailPattern.hasMatch(email))) {
      return;
    }
    FocusScope.of(context).unfocus();

    setState(() => _isLoading = true);

    try {
      await ref.read(sendInvitationProvider({
        'patientEmail': email,
        'relationship': _selectedRelationship,
      }).future);

      if (mounted) {
        showMfSnackBar(context, 'Invitation sent successfully', tone: MfTone.success);
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        final message = e.toString().replaceAll('Exception:', '').trim();
        showMfSnackBar(context, message, tone: MfTone.danger);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return MfScaffold(
      title: 'Link patient',
      fallbackRoute: '/caregiver/my-patients',
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(MfSpace.gutter, MfSpace.lg, MfSpace.gutter, MfSpace.lg),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Semantics(
                      header: true,
                      child: Text('Invite a patient', style: text.titleLarge),
                    ),
                    const SizedBox(height: MfSpace.xs),
                    Text(
                      'Enter the patient\'s registered email address to send them a connection request.',
                      style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(height: MfSpace.lg),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      autofillHints: const [AutofillHints.email],
                      textInputAction: TextInputAction.done,
                      validator: _validateEmail,
                      onFieldSubmitted: (_) => _isLoading ? null : _sendInvitation(),
                      decoration: const InputDecoration(
                        labelText: 'Patient email',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                    ),
                    const SizedBox(height: MfSpace.md),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedRelationship,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Relationship to patient',
                        prefixIcon: Icon(Icons.family_restroom_rounded),
                      ),
                      items: _relationshipOptions.map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: (newValue) {
                        setState(() {
                          _selectedRelationship = newValue!;
                        });
                      },
                    ),
                    const SizedBox(height: MfSpace.md),
                    const MfInfoBanner(
                      icon: Icons.info_outline_rounded,
                      title: 'The patient must accept',
                      message: 'You can monitor the patient once they accept your request.',
                    ),
                    const SizedBox(height: MfSpace.lg),
                    MfPrimaryButton(
                      label: 'Send invitation',
                      icon: Icons.send_rounded,
                      loading: _isLoading,
                      onPressed: _isLoading ? null : _sendInvitation,
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
}
