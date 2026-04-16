import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/emergency_provider.dart';
import '../../theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import '../../../services/audio/voice_alert_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/medical_profile_provider.dart';
import '../../../domain/entities/medical_profile.dart';
import '../../../domain/entities/emergency.dart' as emergency_entity;

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
  int _countdown = 5;
  Timer? _callTimer;

  @override
  void dispose() {
    _callTimer?.cancel();
    super.dispose();
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  Future<void> _accept() async {
    setState(() => _isAccepting = true);
    
    try {
      final responderIdResult = await ref.read(currentUserIdProvider.future);
      final responderId = responderIdResult ?? 'responder_generated_id';
      
      // Get the emergency data to find the userId
      final emergency = await ref.read(getEmergencyProvider(widget.requestId).future);

      await ref.read(acceptEmergencyProvider(AcceptRejectParams(
        emergencyId: widget.requestId,
        responderId: responderId,
      )).future);
      
      VoiceAlertService().speakMessage("Emergency accepted. Preparing automated analysis.");

      // Check if patient is deaf and play situational report
      if (emergency != null) {
        final profile = await ref.read(getMedicalProfileProvider(emergency.userId).future);
        
        if (profile != null && profile.disabilityType?.toLowerCase().contains('deaf') == true) {
          // Play the detailed medical report for the responder
          await VoiceAlertService().speakAutomatedEmergencyReport(
            emergency: emergency as emergency_entity.Emergency,
            medical: profile,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to accept: $e'), backgroundColor: Colors.red),
        );
        setState(() => _isAccepting = false);
      }
      return;
    }
    
    // Start countdown for auto-call
    _countdown = 60;
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_countdown > 1) {
          _countdown--;
        } else {
          timer.cancel();
          _makePhoneCall('+1234567890'); // Auto-dial placeholder
          if (mounted) {
            context.go('/responder/active/${widget.requestId}');
          }
        }
      });
    });
  }

  Future<void> _reject() async {
    setState(() => _isRejecting = true);
    try {
      final responderIdResult = await ref.read(currentUserIdProvider.future);
      final responderId = responderIdResult ?? 'responder_generated_id';
      await ref.read(rejectEmergencyProvider(AcceptRejectParams(
        emergencyId: widget.requestId,
        responderId: responderId,
      )).future);
    } catch (e) {
      print('Reject error: $e');
    }
    
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
        data: (emergency) => _buildContent(context, theme, emergency as emergency_entity.Emergency?),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error loading emergency: $e')),
      ),
    );
  }

  Widget _buildContent(BuildContext context, ThemeData theme, emergency_entity.Emergency? emergency) {
    if (emergency == null) return const Center(child: Text('Emergency not found'));

    final profileAsync = ref.watch(getMedicalProfileProvider(emergency.userId));

    return profileAsync.when(
      data: (profile) => _buildRequestDetails(
        context: context,
        theme: theme,
        emergencyType: emergency.emergencyType,
        patientName: profile?.fullName ?? 'Patient',
        distance: 'Calculating...', // Distance calculation logic can be added later
        bloodGroup: profile?.bloodType ?? 'Unknown',
        allergies: (profile?.allergies.isNotEmpty == true) ? profile!.allergies.join(', ') : 'None listed',
        conditions: (profile?.chronicDiseases.isNotEmpty == true) ? profile!.chronicDiseases.join(', ') : 'No chronic conditions',
        priority: emergency.status == 'HIGH' ? 'HIGH' : 'NORMAL',
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _buildRequestDetails(
        context: context,
        theme: theme,
        emergencyType: emergency.emergencyType,
        patientName: 'Patient',
        distance: '...',
        bloodGroup: 'Unknown',
        allergies: 'Error loading',
        conditions: 'Error loading profile',
      ),
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
    String priority = 'NORMAL',
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
              gradient: LinearGradient(
                colors: priority == 'HIGH'
                    ? [const Color(0xFFb71c1c), const Color(0xFFd32f2f)]
                    : [const Color(0xFFF57C00), const Color(0xFFFFB74D)],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                if (priority == 'HIGH')
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text('HIGH PRIORITY ESCALATION',
                        style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
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
              final isCurrentlyPlaying = _isPlayingVoice;
              setState(() => _isPlayingVoice = !isCurrentlyPlaying);
              
              if (isCurrentlyPlaying) {
                 VoiceAlertService().stop();
              } else {
                 final message = "Emergency Alert: ${emergencyType.replaceAll('_', ' ')}. "
                     "Patient: $patientName. "
                     "Blood Group: $bloodGroup. "
                     "Allergies: $allergies. "
                     "Conditions: $conditions. "
                     "Distance: $distance.";
                 VoiceAlertService().speakMessage(message);
              }
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
                          color: AppColors.primary),
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
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white)),
                            const SizedBox(height: 8),
                            Text('Calling patient in $_countdown...',
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 12)),
                          ],
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
