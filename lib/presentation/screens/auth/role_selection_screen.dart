import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:medifind_mobile_application/core/utils/responsive.dart';

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
      title: 'Patient / User',
      subtitle: 'Manage your medical profile and request emergency help in seconds.',
      icon: Icons.person_rounded,
      color: Color(0xFF0E9AA7),
      tags: ['SOS Emergency Alert', 'Medical Profile', 'Caregiver Link'],
    ),
    _RoleData(
      value: 'RESPONDER',
      title: 'Emergency Responder',
      subtitle: 'Receive live dispatches and assist patients in emergencies near you.',
      icon: Icons.emergency_share_rounded,
      color: Color(0xFFD32F2F),
      tags: ['Live Dispatch', 'GPS Navigation', 'Patient Summary'],
    ),
    _RoleData(
      value: 'CAREGIVER',
      title: 'Caregiver',
      subtitle: 'Stay updated on a patient\'s emergencies and monitor their safety.',
      icon: Icons.favorite_rounded,
      color: Color(0xFF00897B),
      tags: ['Live Tracking', 'Emergency Alerts', 'Patient Monitor'],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: theme.colorScheme.primary),
          onPressed: () => context.go('/login'),
          tooltip: 'Back to Login',
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(5.wp, 0, 5.wp, 4.hp),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: 1.hp),

              // ── Header ────────────────────────────────────────────────
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.add_box_rounded,
                    size: 32, color: theme.colorScheme.primary),
              ).center(),
              SizedBox(height: 2.hp),

              Text(
                'Join MediFind',
                textAlign: TextAlign.center,
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                  fontSize: 3.4.hp,
                ),
              ),
              SizedBox(height: 0.8.hp),
              Text(
                'Choose the role that best describes you.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade500,
                  fontSize: 1.5.hp,
                ),
              ),
              SizedBox(height: 3.5.hp),

              // ── Role Cards ────────────────────────────────────────────
              ..._roles.map((role) => _buildRoleTile(context, role)),

              SizedBox(height: 4.hp),

              // ── Continue Button ───────────────────────────────────────
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: _selectedRole != null
                      ? [
                          BoxShadow(
                            color: theme.colorScheme.primary.withOpacity(0.35),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          )
                        ]
                      : [],
                ),
                child: ElevatedButton(
                  onPressed: _selectedRole == null
                      ? null
                      : () => context.go(
                            '/register',
                            extra: {
                              'role': _selectedRole,
                              'patientType': _selectedRole == 'PATIENT'
                                  ? _selectedPatientType
                                  : null,
                            },
                          ),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 1.8.hp),
                    backgroundColor: theme.colorScheme.primary,
                    disabledBackgroundColor: Colors.grey.shade200,
                    foregroundColor: Colors.white,
                    disabledForegroundColor: Colors.grey.shade400,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(
                    'Continue',
                    style: TextStyle(
                        fontSize: 1.8.hp, fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              SizedBox(height: 2.5.hp),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Already have an account? ',
                      style: TextStyle(
                          fontSize: 1.4.hp, color: Colors.grey.shade600)),
                  TextButton(
                    onPressed: () => context.go('/login'),
                    child: Text('Login',
                        style: TextStyle(
                            fontSize: 1.4.hp, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleTile(BuildContext context, _RoleData role) {
    final isSelected = _selectedRole == role.value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _RoleTile(
          data: role,
          isSelected: isSelected,
          onTap: () => setState(() => _selectedRole = role.value),
        ),

        // Patient sub-options (inline, slides in)
        if (role.value == 'PATIENT' && isSelected) ...[
          SizedBox(height: 1.4.hp),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select Accessibility Mode:',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: role.color,
                        fontSize: 1.35.hp,
                      ),
                ),
                SizedBox(height: 1.hp),
                Row(
                  children: [
                    _SubOptionChip(
                      label: 'Standard Mode',
                      icon: Icons.person_outline_rounded,
                      color: role.color,
                      isSelected: _selectedPatientType == 'NORMAL',
                      onTap: () =>
                          setState(() => _selectedPatientType = 'NORMAL'),
                    ),
                    const SizedBox(width: 10),
                    _SubOptionChip(
                      label: 'Deaf & Mute Mode',
                      icon: Icons.hearing_disabled_rounded,
                      color: role.color,
                      isSelected: _selectedPatientType == 'DEAF',
                      onTap: () =>
                          setState(() => _selectedPatientType = 'DEAF'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],

        SizedBox(height: 2.hp),
      ],
    );
  }
}

extension WidgetCenter on Widget {
  Widget center() => Center(child: this);
}

// ─── Data class ───────────────────────────────────────────────────────────────
class _RoleData {
  final String value;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final List<String> tags;

  const _RoleData({
    required this.value,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.tags,
  });
}

// ─── Role Tile ────────────────────────────────────────────────────────────────
class _RoleTile extends StatelessWidget {
  final _RoleData data;
  final bool isSelected;
  final VoidCallback onTap;

  const _RoleTile({
    required this.data,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = data.color;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withOpacity(0.05)
              : theme.scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade200,
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: color.withOpacity(0.20),
                blurRadius: 20,
                offset: const Offset(0, 6),
              )
            else
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(19),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left accent bar
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 5,
                  color: isSelected ? color : Colors.transparent,
                ),

                // Main content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Role icon
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          padding: const EdgeInsets.all(13),
                          decoration: BoxDecoration(
                            color: color.withOpacity(isSelected ? 0.16 : 0.10),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(data.icon, color: color, size: 26),
                        ),
                        const SizedBox(width: 14),

                        // Text + tags
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                data.title,
                                style:
                                    theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: isSelected
                                      ? color
                                      : theme.colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                data.subtitle,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.grey.shade600,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 6,
                                runSpacing: 5,
                                children: data.tags
                                    .map((t) => _CapabilityTag(
                                          label: t,
                                          color: color,
                                          active: isSelected,
                                        ))
                                    .toList(),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 10),

                        // Animated checkmark badge
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color:
                                isSelected ? color : Colors.transparent,
                            border: Border.all(
                              color: isSelected
                                  ? color
                                  : Colors.grey.shade300,
                              width: 2,
                            ),
                          ),
                          child: isSelected
                              ? const Icon(Icons.check_rounded,
                                  color: Colors.white, size: 15)
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Capability Tag ────────────────────────────────────────────────────────────
class _CapabilityTag extends StatelessWidget {
  final String label;
  final Color color;
  final bool active;

  const _CapabilityTag({
    required this.label,
    required this.color,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: active ? color.withOpacity(0.12) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color:
              active ? color.withOpacity(0.30) : Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: active ? color : Colors.grey.shade500,
        ),
      ),
    );
  }
}

// ─── Sub Option Chip ──────────────────────────────────────────────────────────
class _SubOptionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _SubOptionChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color : Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.22),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  )
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 17,
              color:
                  isSelected ? Colors.white : Colors.grey.shade600,
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
                color: isSelected
                    ? Colors.white
                    : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
