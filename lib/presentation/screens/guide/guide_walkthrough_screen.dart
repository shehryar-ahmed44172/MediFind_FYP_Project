import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../services/guide/guide_prefs.dart';
import '../../providers/accessibility_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/design_system/design_system.dart';
import 'guide_content.dart';

/// Five-page welcome tour shown once after the first sign-in, and again
/// whenever the user asks for it from the help screen.
///
/// Everything is text and pictures: a deaf user misses nothing, and a first
/// time user is never left guessing what the SOS button does.
class GuideWalkthroughScreen extends ConsumerStatefulWidget {
  const GuideWalkthroughScreen({super.key});

  @override
  ConsumerState<GuideWalkthroughScreen> createState() => _GuideWalkthroughScreenState();
}

class _GuideWalkthroughScreenState extends ConsumerState<GuideWalkthroughScreen> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish(String? userId) async {
    if (userId != null) await GuidePrefs.markSeen(userId);
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    final textOnly = ref.watch(accessibilityProvider.select((s) => s.textOnlyMode));
    final role = (user?.role ?? 'PATIENT').toUpperCase();
    final isDeaf = role == 'PATIENT' &&
        ((user?.patientType ?? '').toUpperCase() == 'DEAF' || textOnly);

    final steps = GuideContent.walkthrough(role, isDeaf);
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final isLast = _page == steps.length - 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // ── Header: who this guide is for + skip ────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(MfSpace.gutter, MfSpace.sm, MfSpace.sm, 0),
              child: Row(
                children: [
                  Image.asset('assets/logos/medifind_mark.png',
                      width: 26, height: 26, excludeFromSemantics: true),
                  const SizedBox(width: MfSpace.xs),
                  Expanded(
                    child: Text(
                      'Guide for ${GuideContent.roleLabel(role, isDeaf).toLowerCase()}s',
                      style: text.labelLarge?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _finish(user?.id),
                    child: const Text('Skip'),
                  ),
                ],
              ),
            ),

            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: steps.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, i) => _GuidePage(step: steps[i]),
              ),
            ),

            // ── Dots ────────────────────────────────────────────────────────
            Semantics(
              label: 'Step ${_page + 1} of ${steps.length}',
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(steps.length, (i) {
                  final active = i == _page;
                  return AnimatedContainer(
                    duration: MfMotion.fast,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: active ? 22 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: active ? cs.primary : cs.outlineVariant,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(MfSpace.gutter),
              child: Row(
                children: [
                  if (_page > 0)
                    Expanded(
                      child: MfSecondaryButton(
                        label: 'Back',
                        tone: MfTone.neutral,
                        onPressed: () => _controller.previousPage(
                          duration: MfMotion.normal,
                          curve: Curves.easeOutCubic,
                        ),
                      ),
                    ),
                  if (_page > 0) const SizedBox(width: MfSpace.sm),
                  Expanded(
                    flex: 2,
                    child: MfPrimaryButton(
                      label: isLast ? 'Start using MediFind' : 'Next',
                      icon: isLast ? Icons.check_rounded : Icons.arrow_forward_rounded,
                      onPressed: isLast
                          ? () => _finish(user?.id)
                          : () => _controller.nextPage(
                                duration: MfMotion.normal,
                                curve: Curves.easeOutCubic,
                              ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuidePage extends StatelessWidget {
  final GuideStep step;
  const _GuidePage({required this.step});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final tone = MfColors.tone(context, MfTone.primary);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(MfSpace.gutter, MfSpace.lg, MfSpace.gutter, MfSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 132,
              height: 132,
              decoration: BoxDecoration(
                color: tone.container,
                shape: BoxShape.circle,
                border: Border.all(color: tone.border, width: 2),
              ),
              child: Icon(step.icon, size: 62, color: tone.foreground),
            ),
          ),
          const SizedBox(height: MfSpace.lg),
          Semantics(
            header: true,
            child: Text(step.title, style: text.headlineSmall),
          ),
          const SizedBox(height: MfSpace.sm),
          Text(
            step.body,
            style: text.bodyLarge?.copyWith(color: cs.onSurfaceVariant, height: 1.5),
          ),
          if (step.points.isNotEmpty) ...[
            const SizedBox(height: MfSpace.md),
            MfCard(
              tone: MfTone.primary,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final point in step.points)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.check_circle_rounded, size: 18, color: tone.foreground),
                          const SizedBox(width: MfSpace.xs),
                          Expanded(child: Text(point, style: text.bodyMedium)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
