import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/medical_profile_provider.dart';
import '../../widgets/design_system/design_system.dart';

/// Full-screen, high-contrast card a deaf patient shows to people nearby.
///
/// Reachable from Home ("Show to people nearby"), Medical ID, SOS tracking,
/// Accessibility settings and the global deaf visual alert. An optional
/// [message] (e.g. a quick phrase) is displayed at the top in very large text.
class DeafCommunicationCardScreen extends ConsumerStatefulWidget {
  final String? message;
  const DeafCommunicationCardScreen({super.key, this.message});

  @override
  ConsumerState<DeafCommunicationCardScreen> createState() => _DeafCommunicationCardScreenState();
}

class _DeafCommunicationCardScreenState extends ConsumerState<DeafCommunicationCardScreen> {
  // Always white-on-black regardless of theme: maximum legibility for bystanders.
  static const _bg = Colors.black;
  static const _fg = Colors.white;

  late String? _typed = widget.message;

  @override
  void initState() {
    super.initState();
    HapticFeedback.selectionClick();
  }

  Future<void> _typeMessage() async {
    final controller = TextEditingController(text: _typed ?? '');
    final result = await showMfBottomSheet<String>(
      context,
      title: 'Type a message to show',
      subtitle: 'It will be displayed in very large text.',
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: controller,
            autofocus: true,
            minLines: 2,
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'For example: I need a pen and paper'),
          ),
          const SizedBox(height: MfSpace.md),
          MfPrimaryButton(
            label: 'Show message',
            icon: Icons.fullscreen_rounded,
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
          ),
        ],
      ),
    );
    if (result == null || !mounted) return;
    setState(() => _typed = result.isEmpty ? null : result);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    final profile = user == null ? null : ref.watch(getMedicalProfileProvider(user.id)).valueOrNull;
    final text = Theme.of(context).textTheme;

    final allergies = profile?.allergies.where((a) => a.trim().isNotEmpty).toList() ?? const <String>[];
    final blood = (profile?.bloodType ?? '').trim();

    final big = text.displaySmall?.copyWith(color: _fg, fontWeight: FontWeight.w700, height: 1.15);
    final large = text.headlineMedium?.copyWith(color: _fg, fontWeight: FontWeight.w600, height: 1.25);
    final body = text.titleLarge?.copyWith(color: _fg, fontWeight: FontWeight.w500);
    final label = text.titleSmall?.copyWith(color: _fg.withValues(alpha: 0.75), fontWeight: FontWeight.w500);

    Widget infoBlock() => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (user != null) ...[
              Text('Name', style: label),
              Text(user.fullName, style: large),
              const SizedBox(height: MfSpace.md),
            ],
            Text('Blood group', style: label),
            Text(blood.isEmpty ? 'Not recorded' : blood, style: large),
            const SizedBox(height: MfSpace.md),
            Text('Allergies', style: label),
            Text(allergies.isEmpty ? 'None recorded' : allergies.join(', '), style: large),
          ],
        );

    Widget mainBlock() => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_typed != null) ...[
              Semantics(liveRegion: true, child: Text(_typed!, style: big)),
              const SizedBox(height: MfSpace.lg),
              const Divider(color: Colors.white24, height: 1),
              const SizedBox(height: MfSpace.lg),
            ],
            Row(
              children: [
                const Icon(Icons.hearing_disabled_rounded, color: _fg, size: 48),
                const SizedBox(width: MfSpace.sm),
                Expanded(child: Text('I am DEAF', style: big)),
              ],
            ),
            const SizedBox(height: MfSpace.md),
            Text('Please write or type to communicate with me.', style: large),
            const SizedBox(height: MfSpace.lg),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(MfSpace.md),
              decoration: BoxDecoration(
                border: Border.all(color: _fg, width: 2),
                borderRadius: MfRadius.mdAll,
              ),
              child: Row(
                children: [
                  const Icon(Icons.local_hospital_outlined, color: _fg, size: 36),
                  const SizedBox(width: MfSpace.sm),
                  Expanded(child: Text('Medical emergency?\nCall 1122.', style: large)),
                ],
              ),
            ),
          ],
        );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Theme(
        data: Theme.of(context).copyWith(
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(foregroundColor: _fg, minimumSize: const Size(48, 48)),
          ),
        ),
        child: Scaffold(
          backgroundColor: _bg,
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: MfSpace.xs, vertical: MfSpace.xxs),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Close card',
                        color: _fg,
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
                      ),
                      Expanded(
                        child: Text(
                          'Turn brightness up · rotate for larger text',
                          style: text.bodySmall?.copyWith(color: _fg.withValues(alpha: 0.75)),
                          maxLines: 2,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _typeMessage,
                        icon: const Icon(Icons.keyboard_outlined),
                        label: const Text('Type'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth > 640;
                      return SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(MfSpace.lg, MfSpace.xs, MfSpace.lg, MfSpace.xl),
                        child: wide
                            ? Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(flex: 3, child: mainBlock()),
                                  const SizedBox(width: MfSpace.xl),
                                  Expanded(flex: 2, child: infoBlock()),
                                ],
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  mainBlock(),
                                  const SizedBox(height: MfSpace.lg),
                                  const Divider(color: Colors.white24, height: 1),
                                  const SizedBox(height: MfSpace.lg),
                                  infoBlock(),
                                  const SizedBox(height: MfSpace.lg),
                                  Text(
                                    'Shown by the MediFind app on behalf of a deaf patient.',
                                    style: body?.copyWith(color: _fg.withValues(alpha: 0.7)),
                                  ),
                                ],
                              ),
                      );
                    },
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
