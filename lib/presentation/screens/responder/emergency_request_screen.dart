import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/emergency_provider.dart';
import '../../theme/app_theme.dart';

class EmergencyRequestScreen extends ConsumerStatefulWidget {
  final String requestId;
  const EmergencyRequestScreen({Key? key, required this.requestId})
      : super(key: key);

  @override
  ConsumerState<EmergencyRequestScreen> createState() =>
      _EmergencyRequestScreenState();
}

class _EmergencyRequestScreenState
    extends ConsumerState<EmergencyRequestScreen> {
  bool _isAccepting = false;
  bool _isRejecting = false;
  bool _isPlayingVoice = false;

  Future<void> _accept() async {
    setState(() => _isAccepting = true);
    // TODO: Call acceptEmergencyProvider(widget.requestId)
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) {
      context.go('/responder/active');
    }
  }

  Future<void> _reject() async {
    setState(() => _isRejecting = true);
    // TODO: Call rejectEmergencyProvider(widget.requestId)
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      context.go('/responder');
    }
  }

  @override
  Widget build(BuildContext context) {
    final emergencyAsync = ref.watch(getEmergencyProvider(widget.requestId));
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Emergency Request'),
        centerTitle: true,
      ),
      body: emergencyAsync.when(
        data: (emergency) => _buildContent(context, theme, emergency),
        loading: () => _buildDemoContent(context, theme),
        error: (_, __) => _buildDemoContent(context, theme),
      ),
    );
  }

  // When provider has no data yet, show demo content
  Widget _buildDemoContent(BuildContext context, ThemeData theme) {
    return _buildRequestDetails(
      context: context,
      theme: theme,
      emergencyType: 'CARDIAC',
      patientName: 'John Doe',
      distance: '1.2 km',
      bloodGroup: 'O+',
      allergies: 'Penicillin',
      conditions: 'Hypertension, Diabetes',
    );
  }

  Widget _buildContent(BuildContext context, ThemeData theme, dynamic emergency) {
    return _buildRequestDetails(
      context: context,
      theme: theme,
      emergencyType: emergency?.emergencyType ?? 'UNKNOWN',
      patientName: 'Patient',
      distance: 'Calculating...',
      bloodGroup: 'Unknown',
      allergies: 'None listed',
      conditions: 'See medical profile',
    );
  }

  Widget _buildRequestDetails({
    required BuildContext context,
    required ThemeData theme,
    required String emergencyType,
    required String patientName,
    required String distance,
    required String bloodGroup,
    required String allergies,
    required String conditions,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Emergency Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFB71C1C), Color(0xFFEF5350)],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                const Icon(Icons.emergency_rounded,
                    color: Colors.white, size: 48),
                const SizedBox(height: 8),
                Text(
                  emergencyType.replaceAll('_', ' '),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(distance,
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 15)),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Voice Alert Button
          OutlinedButton.icon(
            onPressed: () {
              setState(() => _isPlayingVoice = !_isPlayingVoice);
              // TODO: Wire to voice_alert_service.speak(...)
            },
            icon: Icon(_isPlayingVoice
                ? Icons.stop_circle_outlined
                : Icons.volume_up_outlined),
            label: Text(_isPlayingVoice ? 'Stop Alert' : 'Play Voice Alert'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 16),

          // Medical Profile Summary
          Container(
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: AppShadows.neumorphicOut,
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.medical_information_outlined,
                          color: Colors.blue),
                      SizedBox(width: 8),
                      Text('Patient Medical Summary',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                  const Divider(),
                  _InfoRow(label: 'Patient', value: patientName),
                  _InfoRow(label: 'Blood Group', value: bloodGroup),
                  _InfoRow(label: 'Allergies', value: allergies),
                  _InfoRow(label: 'Conditions', value: conditions),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: (_isAccepting || _isRejecting) ? null : _reject,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: Colors.red),
                    foregroundColor: Colors.red,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isRejecting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.red),
                        )
                      : const Text('Reject', style: TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: (_isAccepting || _isRejecting) ? null : _accept,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isAccepting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Accept Emergency',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: const TextStyle(
                    color: Colors.grey, fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
