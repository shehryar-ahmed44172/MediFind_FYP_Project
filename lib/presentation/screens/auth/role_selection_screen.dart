import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/design_system/design_system.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  String? _selectedRole;
  String _selectedPatientType = 'NORMAL';

  static const _roles = [
    _RoleData(
      value: 'PATIENT',
      title: 'Patient',
      subtitle: 'Keep a medical profile and request emergency help in seconds.',
      icon: Icons.person_rounded,
    ),
    _RoleData(
      value: 'CAREGIVER',
      title: 'Caregiver',
      subtitle: 'Follow a patient\'s emergencies and monitor their safety.',
      icon: Icons.favorite_border_rounded,
    ),
    _RoleData(
      value: 'RESPONDER',
      title: 'Emergency responder',
      subtitle: 'Receive live dispatches and assist patients near you.',
      icon: Icons.emergency_share_rounded,
    ),
  ];

  void _continue() {
    context.go(
      '/register',
      extra: {
        'role': _selectedRole,
        'patientType': _selectedRole == 'PATIENT' ? _selectedPatientType : null,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return MfScaffold(
      title: 'Create account',
      onBack: () => context.go('/login'),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(MfSpace.gutter, MfSpace.xs, MfSpace.gutter, MfSpace.lg),
          children: [
            Semantics(
              header: true,
              child: Text('Join MediFind', style: text.headlineSmall),
            ),
            const SizedBox(height: MfSpace.xxs),
            Text(
              'Choose the role that best describes you.',
              style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: MfSpace.lg),
            for (final role in _roles) ...[
              _RoleCard(
                data: role,
                selected: _selectedRole == role.value,
                onTap: () => setState(() => _selectedRole = role.value),
              ),
              if (role.value == 'PATIENT' && _selectedRole == 'PATIENT') ...[
                const SizedBox(height: MfSpace.md),
                _HearingChoice(
                  value: _selectedPatientType,
                  onChanged: (v) => setState(() => _selectedPatientType = v),
                ),
              ],
              const SizedBox(height: MfSpace.sm),
            ],
            const SizedBox(height: MfSpace.sm),
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
      bottomBar: MfPrimaryButton(
        label: 'Continue',
        icon: Icons.arrow_forward_rounded,
        onPressed: _selectedRole == null ? null : _continue,
      ),
    );
  }
}

// ─── Data class ───────────────────────────────────────────────────────────────
class _RoleData {
  final String value;
  final String title;
  final String subtitle;
  final IconData icon;

  const _RoleData({
    required this.value,
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}

// ─── Selectable card (role or hearing option) ────────────────────────────────
class _SelectableCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;

  const _SelectableCard({
    required this.icon,
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final t = MfColors.tone(context, MfTone.primary);
    final hc = MfColors.isHighContrast(context);

    final shape = RoundedRectangleBorder(
      borderRadius: MfRadius.mdAll,
      side: BorderSide(
        color: selected ? t.foreground : cs.outlineVariant,
        width: selected || hc ? 2 : 1,
      ),
    );

    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: subtitle == null ? title : '$title. $subtitle',
      excludeSemantics: true,
      child: Material(
        color: selected ? Color.alphaBlend(cs.primaryContainer.withValues(alpha: 0.5), cs.surface) : cs.surface,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          customBorder: shape,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: compact ? MfSize.primaryButton : 72),
            child: Padding(
              padding: EdgeInsets.all(compact ? MfSpace.sm : MfSpace.md),
              child: Row(
                children: [
                  Container(
                    width: compact ? 40 : 48,
                    height: compact ? 40 : 48,
                    decoration: BoxDecoration(
                      color: t.container,
                      borderRadius: MfRadius.smAll,
                    ),
                    child: Icon(icon, color: t.foreground, size: compact ? 22 : 24),
                  ),
                  const SizedBox(width: MfSpace.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(title, style: compact ? text.titleSmall : text.titleMedium),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle!,
                            style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: MfSpace.xs),
                  Icon(
                    selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                    color: selected ? t.foreground : cs.outline,
                    size: 24,
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

class _RoleCard extends StatelessWidget {
  final _RoleData data;
  final bool selected;
  final VoidCallback onTap;

  const _RoleCard({required this.data, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _SelectableCard(
      icon: data.icon,
      title: data.title,
      subtitle: data.subtitle,
      selected: selected,
      onTap: onTap,
    );
  }
}

// ─── Patient hearing choice (maps to patientType DEAF / NORMAL) ──────────────
class _HearingChoice extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _HearingChoice({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(left: MfSpace.md),
      child: Container(
        padding: const EdgeInsets.only(left: MfSpace.sm),
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: cs.outlineVariant, width: 2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text('Your hearing', style: text.titleSmall),
            ),
            const SizedBox(height: 2),
            Text(
              'This sets how MediFind communicates with you in an emergency.',
              style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: MfSpace.sm),
            _SelectableCard(
              compact: true,
              icon: Icons.hearing_disabled_rounded,
              title: 'I am Deaf / Hard of hearing',
              subtitle: 'Text-first communication and visual alerts',
              selected: value == 'DEAF',
              onTap: () => onChanged('DEAF'),
            ),
            const SizedBox(height: MfSpace.xs),
            _SelectableCard(
              compact: true,
              icon: Icons.hearing_rounded,
              title: 'I can hear',
              subtitle: 'Standard alerts and notifications',
              selected: value == 'NORMAL',
              onTap: () => onChanged('NORMAL'),
            ),
          ],
        ),
      ),
    );
  }
}
