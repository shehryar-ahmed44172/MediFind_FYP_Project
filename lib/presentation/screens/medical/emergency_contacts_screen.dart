import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/medical_profile_provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../../domain/entities/medical_profile.dart';

// ─── Relationship options ────────────────────────────────────────────────────
const _relationships = [
  'Father', 'Mother', 'Spouse', 'Sibling',
  'Son', 'Daughter', 'Family', 'Friend', 'Doctor', 'Other',
];

class EmergencyContactsScreen extends ConsumerWidget {
  const EmergencyContactsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(currentUserIdProvider).valueOrNull;

    return Scaffold(
      // ── AppBar with back navigation ──────────────────────────────────────
      appBar: AppBar(
        title: const Text(
          'Emergency Contacts',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
          tooltip: 'Go Back',
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.primary,
        elevation: 0,
        surfaceTintColor: Colors.white,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: Colors.grey.shade200),
        ),
      ),

      body: SafeArea(
        child: userId == null
            ? const Center(child: Text('Please log in to view contacts'))
            : _ContactsBody(userId: userId),
      ),

      // ── FAB — opens the Add Contact bottom sheet directly ────────────────
      floatingActionButton: userId == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _showAddContactSheet(context, ref, userId),
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text(
                'Add Contact',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ),
    );
  }
}

// ─── Body ────────────────────────────────────────────────────────────────────

class _ContactsBody extends ConsumerWidget {
  final String userId;
  const _ContactsBody({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(getMedicalProfileProvider(userId));

    return profileAsync.when(
      data: (profile) {
        final contacts = profile?.emergencyContacts ?? [];

        if (contacts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.contact_phone_outlined,
                    size: 88, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text(
                  'No emergency contacts added yet',
                  style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 15,
                      fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap the button below to add your first contact.',
                  style:
                      TextStyle(color: Colors.grey.shade400, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                ElevatedButton.icon(
                  onPressed: () =>
                      _showAddContactSheet(context, ref, userId),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 28, vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  icon:
                      const Icon(Icons.add, color: Colors.white, size: 18),
                  label: const Text('Add Emergency Contact',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            // ── Count header ──────────────────────────────────────────────
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: AppColors.primary.withOpacity(0.06),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 15, color: AppColors.primary.withOpacity(0.7)),
                  const SizedBox(width: 6),
                  Text(
                    '${contacts.length} contact${contacts.length > 1 ? 's' : ''} saved  •  Swipe left to delete',
                    style: TextStyle(
                        fontSize: 12,
                        color: AppColors.primary.withOpacity(0.8),
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),

            // ── Contact list ──────────────────────────────────────────────
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                itemCount: contacts.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final contact = contacts[index];
                  return _ContactCard(
                    contact: contact,
                    userId: userId,
                    ref: ref,
                  );
                },
              ),
            ),
          ],
        );
      },
      loading: () =>
          const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off_rounded, color: Colors.grey, size: 56),
              const SizedBox(height: 16),
              const Text(
                'Unable to load contacts',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                '$e',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => ref.invalidate(getMedicalProfileProvider(userId)),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(minimumSize: const Size(0, 48)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Contact card with swipe-to-delete ───────────────────────────────────────

class _ContactCard extends StatelessWidget {
  final EmergencyContact contact;
  final String userId;
  final WidgetRef ref;

  const _ContactCard({
    required this.contact,
    required this.userId,
    required this.ref,
  });

  Future<void> _callContact(BuildContext context) async {
    final number = contact.phoneNumber.replaceAll(RegExp(r'[\s\-()]'), '');
    final uri = Uri(scheme: 'tel', path: number);
    var launched = false;
    if (number.isNotEmpty) {
      try {
        launched = await launchUrl(uri);
      } catch (e) {
        debugPrint('Could not launch dialer: $e');
      }
    }
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not start a call to ${contact.phoneNumber}'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(contact.name + contact.phoneNumber),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.error.withOpacity(0.07),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.error.withOpacity(0.3)),
        ),
        child: const Icon(Icons.delete_outline_rounded,
            color: Colors.redAccent, size: 28),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            title: const Text('Remove Contact?',
                style: TextStyle(fontWeight: FontWeight.w700)),
            content: Text(
                'Remove ${contact.name} from your emergency contacts?'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel')),
              TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Remove',
                      style: TextStyle(color: AppColors.error))),
            ],
          ),
        );
      },
      onDismissed: (_) async {
        try {
          final repo =
              await ref.read(medicalProfileRepositoryProvider.future);
          await repo.removeEmergencyContact(userId, contact.name);
          ref.invalidate(getMedicalProfileProvider(userId));
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('${contact.name} removed'),
              behavior: SnackBarBehavior.floating,
            ));
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Failed to remove: $e'),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
            ));
          }
        }
      },
      child: Card(
        elevation: 0,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: Colors.white,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: AppColors.primary.withOpacity(0.12),
              radius: 24,
              child: Text(
                contact.name.isNotEmpty
                    ? contact.name[0].toUpperCase()
                    : '?',
                style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 18),
              ),
            ),
            title: Text(
              contact.name,
              style: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 15),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(Icons.people_outline,
                        size: 13, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text(contact.relationship,
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600)),
                  ],
                ),
                Row(
                  children: [
                    Icon(Icons.phone_outlined,
                        size: 13, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text(contact.phoneNumber,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                  ],
                ),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.call_rounded,
                  color: AppColors.success, size: 26),
              tooltip: 'Call ${contact.name}',
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              onPressed: () => _callContact(context),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Add Contact bottom sheet ─────────────────────────────────────────────────

void _showAddContactSheet(
    BuildContext context, WidgetRef ref, String userId) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AddContactSheet(userId: userId, ref: ref),
  );
}

class _AddContactSheet extends StatefulWidget {
  final String userId;
  final WidgetRef ref;
  const _AddContactSheet({required this.userId, required this.ref});

  @override
  State<_AddContactSheet> createState() => _AddContactSheetState();
}

class _AddContactSheetState extends State<_AddContactSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  String _relationship = 'Father';
  bool _saving = false;

  final _phoneMask = MaskTextInputFormatter(
    mask: '+92-###-#######',
    filter: {'#': RegExp(r'[0-9]')},
    type: MaskAutoCompletionType.lazy,
  );

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final contact = EmergencyContact(
        name: _nameCtrl.text.trim(),
        phoneNumber: _phoneCtrl.text.trim(),
        relationship: _relationship,
      );

      final repo =
          await widget.ref.read(medicalProfileRepositoryProvider.future);
      await repo.addEmergencyContact(widget.userId, contact);
      widget.ref.invalidate(getMedicalProfileProvider(widget.userId));

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${contact.name} added to emergency contacts ✓'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to add contact: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(24, 8, 24, 24 + bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2)),
          ),

          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.primary.withOpacity(0.1),
                child: Icon(Icons.person_add_alt_1_rounded,
                    color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              const Text('Add Emergency Contact',
                  style: TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 24),

          Form(
            key: _formKey,
            child: Column(
              children: [
                // Name
                TextFormField(
                  controller: _nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Full Name *',
                    prefixIcon:
                        const Icon(Icons.person_outline_rounded),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty)
                          ? 'Name is required'
                          : null,
                ),
                const SizedBox(height: 14),

                // Phone
                TextFormField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [_phoneMask],
                  decoration: InputDecoration(
                    labelText: 'Phone Number *',
                    hintText: '+92-300-1234567',
                    prefixIcon:
                        const Icon(Icons.phone_outlined),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Phone number is required';
                    }
                    final digits =
                        v.replaceAll(RegExp(r'[^0-9]'), '');
                    if (digits.length < 10) {
                      return 'Enter a valid phone number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Relationship dropdown
                DropdownButtonFormField<String>(
                  value: _relationship,
                  decoration: InputDecoration(
                    labelText: 'Relationship *',
                    prefixIcon:
                        const Icon(Icons.people_outline_rounded),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  items: _relationships
                      .map((r) => DropdownMenuItem(
                          value: r, child: Text(r)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _relationship = v);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Save button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              icon: _saving
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_rounded,
                      color: Colors.white),
              label: Text(
                _saving ? 'Saving…' : 'Save Contact',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
