import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/medical_profile_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/design_system/design_system.dart';
import '../../../domain/entities/medical_profile.dart';

// ─── Relationship options ────────────────────────────────────────────────────
const _relationships = [
  'Father', 'Mother', 'Spouse', 'Sibling',
  'Son', 'Daughter', 'Family', 'Friend', 'Doctor', 'Other',
];

String _contactKey(EmergencyContact c) => c.name + c.phoneNumber;

class EmergencyContactsScreen extends ConsumerWidget {
  const EmergencyContactsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(currentUserIdProvider).valueOrNull;

    // Header back is handled by MfScaffold: it pops, or falls back to the
    // role home (/home for patients) when there is nothing to pop.
    return MfScaffold(
      title: 'Emergency contacts',
      subtitle: 'People to reach in an emergency',
      actions: [
        if (userId != null)
          MfIconButton(
            icon: Icons.person_add_alt_1_outlined,
            tooltip: 'Add contact',
            onPressed: () => _showAddContactSheet(context, ref, userId),
          ),
      ],
      bottomBar: userId == null
          ? null
          : MfPrimaryButton(
              label: 'Add contact',
              icon: Icons.add_rounded,
              onPressed: () => _showAddContactSheet(context, ref, userId),
            ),
      body: userId == null
          ? const MfEmptyState(
              icon: Icons.lock_outline_rounded,
              title: 'Please log in to view contacts',
            )
          : _ContactsBody(userId: userId),
    );
  }
}

// ─── Body ────────────────────────────────────────────────────────────────────

class _ContactsBody extends ConsumerStatefulWidget {
  final String userId;
  const _ContactsBody({required this.userId});

  @override
  ConsumerState<_ContactsBody> createState() => _ContactsBodyState();
}

class _ContactsBodyState extends ConsumerState<_ContactsBody> {
  /// Contacts removed optimistically (swiped / deleted) while the profile
  /// refreshes, so a dismissed card is never left in the tree.
  final Set<String> _removed = {};

  Future<bool> _confirmRemove(EmergencyContact contact) {
    return showMfConfirmDialog(
      context,
      icon: Icons.delete_outline_rounded,
      title: 'Remove contact?',
      message: 'Remove ${contact.name} from your emergency contacts?',
      confirmLabel: 'Remove',
      destructive: true,
    );
  }

  Future<void> _remove(EmergencyContact contact) async {
    final key = _contactKey(contact);
    setState(() => _removed.add(key));
    try {
      final repo = await ref.read(medicalProfileRepositoryProvider.future);
      await repo.removeEmergencyContact(widget.userId, contact.name);
      ref.invalidate(getMedicalProfileProvider(widget.userId));
      if (mounted) {
        showMfSnackBar(context, '${contact.name} removed');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _removed.remove(key));
        showMfSnackBar(context, 'Failed to remove: $e', tone: MfTone.danger);
      }
    }
  }

  Future<void> _deleteWithConfirm(EmergencyContact contact) async {
    if (await _confirmRemove(contact)) {
      await _remove(contact);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = widget.userId;
    final profileAsync = ref.watch(getMedicalProfileProvider(userId));
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return profileAsync.when(
      data: (profile) {
        final all = profile?.emergencyContacts ?? [];
        // Drop optimistic removals once the server no longer returns them.
        _removed.removeWhere((k) => !all.any((c) => _contactKey(c) == k));
        final contacts = all.where((c) => !_removed.contains(_contactKey(c))).toList();

        if (contacts.isEmpty) {
          return MfEmptyState(
            icon: Icons.contact_phone_outlined,
            title: 'No emergency contacts added yet',
            message: 'Add people who should be reached if you need help.',
            actionLabel: 'Add emergency contact',
            actionIcon: Icons.add_rounded,
            onAction: () => _showAddContactSheet(context, ref, userId),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(MfSpace.gutter, MfSpace.sm, MfSpace.gutter, MfSpace.lg),
          itemCount: contacts.length + 1,
          separatorBuilder: (_, __) => const SizedBox(height: MfSpace.xs),
          itemBuilder: (context, index) {
            if (index == 0) {
              // ── Count header ────────────────────────────────────────────
              return Padding(
                padding: const EdgeInsets.only(bottom: MfSpace.xxs),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded, size: 18, color: cs.onSurfaceVariant),
                    const SizedBox(width: MfSpace.xs),
                    Expanded(
                      child: Text(
                        '${contacts.length} contact${contacts.length > 1 ? 's' : ''} saved · Swipe left or use Delete to remove',
                        style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              );
            }
            final contact = contacts[index - 1];
            return _ContactCard(
              contact: contact,
              confirmDismiss: () => _confirmRemove(contact),
              onDismissed: () => _remove(contact),
              onDelete: () => _deleteWithConfirm(contact),
            );
          },
        );
      },
      loading: () => Padding(
        padding: const EdgeInsets.all(MfSpace.gutter),
        child: MfSkeleton.list(count: 3, itemHeight: 120),
      ),
      error: (e, _) => MfErrorState(
        title: 'Unable to load contacts',
        message: '$e',
        onRetry: () => ref.invalidate(getMedicalProfileProvider(userId)),
      ),
    );
  }
}

// ─── Contact card with swipe-to-delete + explicit actions ────────────────────

class _ContactCard extends StatelessWidget {
  final EmergencyContact contact;
  final Future<bool> Function() confirmDismiss;
  final VoidCallback onDismissed;
  final VoidCallback onDelete;

  const _ContactCard({
    required this.contact,
    required this.confirmDismiss,
    required this.onDismissed,
    required this.onDelete,
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
      showMfSnackBar(context, 'Could not start a call to ${contact.phoneNumber}', tone: MfTone.danger);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final danger = MfColors.tone(context, MfTone.danger);

    return Dismissible(
      key: ValueKey(_contactKey(contact)),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: MfSpace.lg),
        decoration: BoxDecoration(
          color: Color.alphaBlend(danger.container, cs.surface),
          borderRadius: MfRadius.mdAll,
          border: Border.all(color: danger.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delete_outline_rounded, color: danger.foreground),
            const SizedBox(width: MfSpace.xs),
            Text('Remove', style: text.labelLarge?.copyWith(color: danger.foreground)),
          ],
        ),
      ),
      confirmDismiss: (_) => confirmDismiss(),
      onDismissed: (_) => onDismissed(),
      child: MfCard(
        semanticLabel: '${contact.name}, ${contact.relationship}, ${contact.phoneNumber}',
        padding: const EdgeInsets.fromLTRB(MfSpace.md, MfSpace.sm, MfSpace.xs, MfSpace.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                MfAvatar(name: contact.name, size: 44),
                const SizedBox(width: MfSpace.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(contact.name, style: text.titleSmall),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.people_outline_rounded, size: 16, color: cs.onSurfaceVariant),
                          const SizedBox(width: MfSpace.xxs),
                          Flexible(
                            child: Text(
                              contact.relationship,
                              style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Icon(Icons.phone_outlined, size: 16, color: cs.onSurfaceVariant),
                          const SizedBox(width: MfSpace.xxs),
                          Flexible(child: Text(contact.phoneNumber, style: text.bodyMedium)),
                        ],
                      ),
                    ],
                  ),
                ),
                MfIconButton(
                  icon: Icons.delete_outline_rounded,
                  tooltip: 'Delete contact',
                  color: danger.foreground,
                  onPressed: onDelete,
                ),
              ],
            ),
            const SizedBox(height: MfSpace.xs),
            Padding(
              padding: const EdgeInsets.only(right: MfSpace.xs),
              child: MfSecondaryButton(
                label: 'Call ${contact.name}',
                icon: Icons.call_outlined,
                onPressed: () => _callContact(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Add Contact bottom sheet ─────────────────────────────────────────────────

void _showAddContactSheet(
    BuildContext context, WidgetRef ref, String userId) {
  showMfBottomSheet<void>(
    context,
    title: 'Add emergency contact',
    subtitle: 'Name, phone number and relationship',
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
        final messenger = ScaffoldMessenger.maybeOf(context);
        final snack = mfSnackBar(
          context,
          '${contact.name} added to emergency contacts',
          tone: MfTone.success,
        );
        Navigator.of(context).pop();
        messenger
          ?..hideCurrentSnackBar()
          ..showSnackBar(snack);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showMfSnackBar(context, 'Failed to add contact: $e', tone: MfTone.danger);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: MfSpace.xs),
        Form(
          key: _formKey,
          child: Column(
            children: [
              // Name
              TextFormField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Full name *',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty)
                        ? 'Name is required'
                        : null,
              ),
              const SizedBox(height: MfSpace.sm),

              // Phone
              TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                inputFormatters: [_phoneMask],
                decoration: const InputDecoration(
                  labelText: 'Phone number *',
                  hintText: '+92-300-1234567',
                  prefixIcon: Icon(Icons.phone_outlined),
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
              const SizedBox(height: MfSpace.sm),

              // Relationship dropdown
              DropdownButtonFormField<String>(
                initialValue: _relationship,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Relationship *',
                  prefixIcon: Icon(Icons.people_outline_rounded),
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
        const SizedBox(height: MfSpace.lg),

        // Save button
        MfPrimaryButton(
          label: _saving ? 'Saving...' : 'Save contact',
          icon: Icons.check_rounded,
          loading: _saving,
          onPressed: _save,
        ),
      ],
    );
  }
}
