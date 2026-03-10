import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../services/location/location_service.dart';
import '../../providers/connectivity_provider.dart';
import '../../providers/emergency_provider.dart';
import '../../providers/auth_provider.dart';

class EmergencyScreen extends ConsumerStatefulWidget {
  const EmergencyScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends ConsumerState<EmergencyScreen>
    with SingleTickerProviderStateMixin {
  String _selectedEmergencyType = 'CARDIAC';
  final _additionalInfoController = TextEditingController();
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _isFetchingLocation = false;

  static const List<Map<String, dynamic>> _emergencyTypes = [
    {'value': 'CARDIAC', 'label': 'Cardiac Emergency', 'icon': Icons.favorite_rounded},
    {'value': 'BREATHING', 'label': 'Breathing Issue', 'icon': Icons.wind_power_rounded},
    {'value': 'TRAUMA', 'label': 'Injury / Trauma', 'icon': Icons.personal_injury_outlined},
    {'value': 'FALL', 'label': 'Fall / Mobility', 'icon': Icons.accessibility_new_outlined},
    {'value': 'STROKE', 'label': 'Stroke', 'icon': Icons.psychology_outlined},
    {'value': 'OTHER', 'label': 'Other Emergency', 'icon': Icons.emergency_outlined},
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnimation =
        Tween<double>(begin: 0.95, end: 1.05).animate(_pulseController);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _additionalInfoController.dispose();
    super.dispose();
  }

  Future<void> _triggerSOS() async {
    final isConnected = ref.read(isConnectedProvider);

    if (!isConnected) {
      // FR9.8 — Offline fallback: open SMS or native call
      _showOfflineFallbackDialog();
      return;
    }

    setState(() => _isFetchingLocation = true);
    HapticFeedback.heavyImpact();

    try {
      final locationService = LocationService();
      final locationEnabled = await locationService.isLocationServiceEnabled();

      if (!locationEnabled) {
        if (mounted) {
          _showGpsDisabledDialog();
        }
        return;
      }

      final position = await locationService.getCurrentLocation();

      if (mounted) {
        // Navigate to countdown screen, passing emergency params
        context.go('/home/sos-countdown', extra: {
          'emergencyType': _selectedEmergencyType,
          'latitude': position.latitude,
          'longitude': position.longitude,
          'additionalInfo': _additionalInfoController.text.trim().isNotEmpty
              ? _additionalInfoController.text.trim()
              : null,
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Location error: $e'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isFetchingLocation = false);
    }
  }

  void _showOfflineFallbackDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.signal_wifi_off, color: Colors.red),
            SizedBox(width: 8),
            Text('No Internet Connection'),
          ],
        ),
        content: const Text(
          'You are offline. To get emergency help, you can call or SMS the emergency number.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.sms_outlined),
            label: const Text('Send SMS'),
            onPressed: () async {
              Navigator.pop(ctx);
              final uri = Uri.parse('smsto:1122');
              if (await canLaunchUrl(uri)) await launchUrl(uri);
            },
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            icon: const Icon(Icons.phone, color: Colors.white),
            label: const Text('Call 1122', style: TextStyle(color: Colors.white)),
            onPressed: () async {
              Navigator.pop(ctx);
              final uri = Uri.parse('tel:1122');
              if (await canLaunchUrl(uri)) await launchUrl(uri);
            },
          ),
        ],
      ),
    );
  }

  void _showGpsDisabledDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.location_off, color: Colors.orange),
            SizedBox(width: 8),
            Text('GPS Disabled'),
          ],
        ),
        content: const Text(
          'Location services are disabled. Please enable GPS to use SOS.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await LocationService().openLocationSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isConnected = ref.watch(isConnectedProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency Alert'),
        centerTitle: true,
        backgroundColor: Colors.red.shade800,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.red.shade50,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (!isConnected)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.signal_wifi_off, color: Colors.orange),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'No internet. SOS will use SMS/Call fallback.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),

            Text('Select Emergency Type',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 2.2,
              children: _emergencyTypes.map((type) {
                final isSelected = _selectedEmergencyType == type['value'];
                return InkWell(
                  onTap: () =>
                      setState(() => _selectedEmergencyType = type['value']),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: isSelected
                          ? Colors.red.shade700
                          : Colors.white,
                      border: Border.all(
                          color: isSelected
                              ? Colors.red.shade700
                              : Colors.red.shade200),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        Icon(type['icon'],
                            color: isSelected ? Colors.white : Colors.red.shade700,
                            size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            type['label'],
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? Colors.white
                                  : Colors.red.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 32),

            // SOS Button
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (ctx, child) => Transform.scale(
                scale: _pulseAnimation.value,
                child: child,
              ),
              child: GestureDetector(
                onTap: _isFetchingLocation ? null : _triggerSOS,
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.red.shade700,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.6),
                        spreadRadius: 12,
                        blurRadius: 24,
                      ),
                    ],
                  ),
                  child: _isFetchingLocation
                      ? const Center(
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 3),
                        )
                      : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.emergency_rounded,
                                size: 64, color: Colors.white),
                            SizedBox(height: 4),
                            Text('SOS',
                                style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white)),
                          ],
                        ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Tap to send emergency alert',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 32),

            // Additional info
            TextField(
              controller: _additionalInfoController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Additional Information (optional)',
                hintText: 'Describe your situation briefly...',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.red.shade200),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
