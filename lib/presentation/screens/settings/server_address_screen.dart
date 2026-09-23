import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../services/config/server_config.dart';
import '../../widgets/design_system/design_system.dart';

/// Lets a tester point the app at a different MediFind server.
///
/// Test builds run against a laptop on Wi-Fi or a tunnel whose address changes
/// from day to day. Typing the new address here beats waiting for a new APK.
class ServerAddressScreen extends ConsumerStatefulWidget {
  const ServerAddressScreen({super.key});

  @override
  ConsumerState<ServerAddressScreen> createState() => _ServerAddressScreenState();
}

enum _Check { none, testing, reachable, unreachable }

class _ServerAddressScreenState extends ConsumerState<ServerAddressScreen> {
  late final TextEditingController _controller =
      TextEditingController(text: AppConstants.runtimeApiHost);
  _Check _check = _Check.none;
  String? _checkDetail;
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Asks the address itself whether a MediFind server is there, so a typo is
  /// caught before it becomes "the app is broken".
  Future<bool> _testConnection(String host) async {
    setState(() {
      _check = _Check.testing;
      _checkDetail = null;
    });
    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: const {'ngrok-skip-browser-warning': 'true'},
      ));
      final response = await dio.get('$host/health');
      final ok = response.statusCode == 200;
      if (mounted) {
        setState(() {
          _check = ok ? _Check.reachable : _Check.unreachable;
          _checkDetail = ok ? null : 'The server answered with ${response.statusCode}.';
        });
      }
      return ok;
    } catch (e) {
      if (mounted) {
        setState(() {
          _check = _Check.unreachable;
          _checkDetail = 'Could not reach it. Check the address and your internet.';
        });
      }
      return false;
    }
  }

  Future<void> _save({required bool reset}) async {
    final typed = reset ? '' : ServerConfig.normalise(_controller.text);
    if (!reset && typed.isEmpty) {
      setState(() {
        _check = _Check.unreachable;
        _checkDetail = 'That does not look like an address.';
      });
      return;
    }

    setState(() => _saving = true);
    await ServerConfig.save(typed);
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (reset) _controller.text = '';
    });

    await showMfConfirmDialog(
      context,
      title: 'Restart the app',
      message: reset
          ? 'The app is back to its built-in server address. Close MediFind completely and open it again for the change to take effect.'
          : 'The app will use $typed. Close MediFind completely and open it again for the change to take effect.',
      confirmLabel: 'Got it',
      cancelLabel: 'Close',
      icon: Icons.restart_alt_rounded,
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final usingCustom = AppConstants.runtimeApiHost.isNotEmpty;

    return MfScaffold(
      title: 'Server address',
      subtitle: 'For testing builds',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            MfSpace.gutter, MfSpace.md, MfSpace.gutter, MfSpace.xl),
        children: [
          MfCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Currently connecting to', style: text.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
                const SizedBox(height: MfSpace.xxs),
                SelectableText(
                  AppConstants.activeHost,
                  style: text.titleSmall?.copyWith(fontFamily: 'monospace'),
                ),
                const SizedBox(height: MfSpace.xxs),
                MfStatusChip(
                  label: usingCustom ? 'Set in the app' : 'Built into this APK',
                  tone: usingCustom ? MfTone.primary : MfTone.neutral,
                ),
              ],
            ),
          ),
          const SizedBox(height: MfSpace.lg),

          const MfSectionTitle('New address'),
          MfCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _controller,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Server address',
                    hintText: 'https://example.trycloudflare.com',
                    prefixIcon: Icon(Icons.dns_outlined),
                  ),
                  onChanged: (_) {
                    if (_check != _Check.none) setState(() => _check = _Check.none);
                  },
                ),
                const SizedBox(height: MfSpace.xs),
                Text(
                  'Paste the address your team shared. A laptop on the same Wi-Fi looks like '
                  'http://192.168.1.5:3000',
                  style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
                if (_check != _Check.none) ...[
                  const SizedBox(height: MfSpace.sm),
                  _CheckResult(check: _check, detail: _checkDetail),
                ],
                const SizedBox(height: MfSpace.md),
                MfSecondaryButton(
                  label: _check == _Check.testing ? 'Checking…' : 'Test connection',
                  icon: Icons.wifi_tethering_rounded,
                  loading: _check == _Check.testing,
                  onPressed: _check == _Check.testing
                      ? null
                      : () {
                          final host = ServerConfig.normalise(_controller.text);
                          if (host.isEmpty) {
                            setState(() {
                              _check = _Check.unreachable;
                              _checkDetail = 'That does not look like an address.';
                            });
                            return;
                          }
                          _testConnection(host);
                        },
                ),
                const SizedBox(height: MfSpace.xs),
                MfPrimaryButton(
                  label: 'Save address',
                  icon: Icons.check_rounded,
                  loading: _saving,
                  onPressed: _saving ? null : () => _save(reset: false),
                ),
              ],
            ),
          ),

          const SizedBox(height: MfSpace.lg),
          const MfInfoBanner(
            icon: Icons.info_outline_rounded,
            title: 'Only use an address you trust',
            message:
                'Everything you do in the app — your emergencies, your medical profile and your '
                'messages — goes to this server. Only enter an address from your own team.',
          ),
          if (usingCustom) ...[
            const SizedBox(height: MfSpace.md),
            MfTextButton(
              label: 'Use the address built into this APK',
              icon: Icons.restore_rounded,
              onPressed: _saving ? null : () => _save(reset: true),
            ),
          ],
        ],
      ),
    );
  }
}

class _CheckResult extends StatelessWidget {
  final _Check check;
  final String? detail;
  const _CheckResult({required this.check, this.detail});

  @override
  Widget build(BuildContext context) {
    if (check == _Check.testing) {
      return const MfInfoBanner(
        icon: Icons.wifi_tethering_rounded,
        title: 'Checking the address…',
      );
    }
    final ok = check == _Check.reachable;
    return MfInfoBanner(
      icon: ok ? Icons.check_circle_outline_rounded : Icons.error_outline_rounded,
      tone: ok ? MfTone.success : MfTone.danger,
      title: ok ? 'MediFind server found' : 'No MediFind server there',
      message: detail ?? (ok ? 'You can save this address.' : null),
    );
  }
}
