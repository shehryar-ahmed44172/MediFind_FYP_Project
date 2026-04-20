import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/emergency_provider.dart';
import '../../theme/app_theme.dart';
import '../../../services/socket/socket_service.dart';
import '../../../domain/entities/emergency.dart';
import '../../services/haptic_feedback_service.dart';

class EmergencyTrackingScreen extends ConsumerStatefulWidget {
  final String emergencyId;
  const EmergencyTrackingScreen({Key? key, required this.emergencyId}) : super(key: key);

  @override
  ConsumerState<EmergencyTrackingScreen> createState() => _EmergencyTrackingScreenState();
}

  double? _responderLat;
  double? _responderLong;
  String? _responderName;
  String? _responderPhone;

  @override
  void initState() {
    super.initState();
    // Connect Socket and join rooms when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final socketService = SocketService.instance;
      socketService.joinEmergencyRoom(widget.emergencyId);
      socketService.joinLocationRoom(widget.emergencyId);
      
      // Ensure the listener provider is active (Plan v5)
      ref.read(socketStreamProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Try to watch live emergency data, fallback to UI directly
    final emergencyAsync = ref.watch(getEmergencyProvider(widget.emergencyId));
    
    // Listen for Socket events to update local state
    ref.listen(socketStreamProvider, (previous, next) {
      if (next.hasValue) {
        final message = next.value!;
        final data = message.data as Map<String, dynamic>;

        if (message.event == SocketEvent.emergencyStatusChange) {
          final newStatus = data['status']?.toString() ?? data['newStatus']?.toString() ?? _currentStatus;
          setState(() {
            _currentStatus = newStatus;
            // Plan v6: Capture responder details if assigned
            if (data['responderName'] != null) _responderName = data['responderName'];
            if (data['responderPhone'] != null) _responderPhone = data['responderPhone'];
          });
          
          // Accessibility: Visual/Haptic feedback on arrival
          final user = ref.read(currentUserProvider).valueOrNull;
          if (newStatus == 'ARRIVED' && user?.patientType == 'DEAF') {
            HapticFeedbackService.sosPattern();
          }
        } 
        else if (message.event == SocketEvent.responderLocationUpdate) {
          // Plan v6: Update real-time map marker location
          setState(() {
            _responderLat = double.tryParse(data['latitude'].toString());
            _responderLong = double.tryParse(data['longitude'].toString());
            _eta = data['eta']?.toString() ?? _eta;
          });
          print('📍 Live Tracking Update: $_responderLat, $_responderLong');
        }
      }
    });

    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: emergencyAsync.when(
        data: (emergency) {
          if (emergency == null) {
            return const Center(child: Text('Emergency not found'));
          }
          return _buildBody(context, theme, emergency as Emergency);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildBody(BuildContext context, ThemeData theme, Emergency emergency) {
    return Stack(
      children: [
        // 1. Full Screen Map Background Simulator
        Positioned.fill(
          child: CustomPaint(
            painter: _TrackingMapPainter(),
            child: Container(
              color: AppColors.primary.withOpacity(0.02),
            ),
          ),
        ),

        // 2. Floating ETA Header Card (FR7.2)
        Positioned(
          top: MediaQuery.of(context).padding.top + 16,
          left: 16,
          right: 16,
          child: _buildETAHeader(theme),
        ),

        // 3. Floating Ambulance / User map pins mock
        // Pin positions animate based on live responder data (Plan v6)
        AnimatedPositioned(
          duration: const Duration(seconds: 1),
          top: _responderLat != null 
              ? (MediaQuery.of(context).size.height * 0.4) + ((_responderLat! - emergency.latitude) * 1000)
              : MediaQuery.of(context).size.height * 0.4,
          left: _responderLong != null 
              ? (MediaQuery.of(context).size.width * 0.3) + ((_responderLong! - emergency.longitude) * 1000)
              : MediaQuery.of(context).size.width * 0.3,
          child: _buildMapPin(Icons.local_hospital_rounded, Colors.red.shade700),
        ),
        Positioned(
          top: MediaQuery.of(context).size.height * 0.55,
          left: MediaQuery.of(context).size.width * 0.6,
          child: _buildMapPin(Icons.person_pin_circle_rounded, AppColors.primaryDark),
        ),

        // 4. Bottom Responder Details & Status Sheet (FR7.4, FR5.1-5.7 context)
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: _buildBottomDetailsSheet(context, theme, emergency),
        ),

        // 5. Visual "Arrived" Overlay for Deaf Users
        if (_currentStatus == 'ARRIVED' && (ref.watch(currentUserProvider).valueOrNull?.patientType == 'DEAF'))
          _buildArrivedVisualAlert(theme),
      ],
    );
  }

  Widget _buildArrivedVisualAlert(ThemeData theme) {
    return Positioned.fill(
      child: Container(
        color: Colors.green.withOpacity(0.9),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 100),
            const SizedBox(height: 24),
            const Text(
              'HELP IS HERE!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'The responder has arrived at your location.',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
            const SizedBox(height: 48),
            ElevatedButton(
              onPressed: () => setState(() => _currentStatus = 'RESOLVED'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: const Text('DISMISS', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildETAHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppShadows.neumorphicOut,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.directions_car_filled_rounded, color: Colors.green),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Help is arriving in',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    _eta,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                      fontSize: 22,
                    ),
                  ),
                ],
              ),
            ],
          ),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'LIVE',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                fontSize: 12,
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildMapPin(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.4),
            blurRadius: 12,
            spreadRadius: 4,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(color: Colors.white, width: 3),
      ),
      child: Icon(icon, color: Colors.white, size: 28),
    );
  }

  Widget _buildBottomDetailsSheet(BuildContext context, ThemeData theme, Emergency emergency) {
    final responderAsync = emergency.responderId != null
        ? ref.watch(userProfileProvider(emergency.responderId!))
        : const AsyncValue.data(null);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: AppShadows.neumorphicOut,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag indicator handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),

            // Responder Identifier Card
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                  child: Icon(Icons.medical_services_rounded, 
                    color: theme.colorScheme.primary, size: 30),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      responderAsync.when(
                        data: (responder) => Text(
                          _responderName ?? responder?.fullName ?? (emergency.responderId != null ? 'Responder Assigned' : 'Finding Responder...'),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        loading: () => Text(_responderName ?? 'Loading...', style: const TextStyle(fontWeight: FontWeight.bold)),
                        error: (_, __) => Text(_responderName ?? 'Assigned Responder'),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.star_rounded, color: Colors.orange.shade400, size: 16),
                          const SizedBox(width: 4),
                          const Text(
                            'Emergency Response Team',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Action Buttons
                Row(
                  children: [
                    _buildActionButton(Icons.chat_bubble_rounded, AppColors.primary),
                    const SizedBox(width: 12),
                    _buildActionButton(Icons.phone_rounded, Colors.green),
                  ],
                ),
              ],
            ),
            
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Divider(),
            ),

            // Emergency Status Tracker
            Text(
              'Emergency Status',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            _buildStatusTimeline(theme),

            const SizedBox(height: 24),

            // Cancel SOS String (FR4.5)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showCancelDialog(context),
                icon: const Icon(Icons.close_rounded, color: Colors.red),
                label: const Text('Cancel Request', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.withOpacity(0.1),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(IconData icon, Color color) {
    return InkWell(
      onTap: () {},
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
    );
  }

  Widget _buildStatusTimeline(ThemeData theme) {
    final statusOrder = ['PENDING', 'RESPONDER_ASSIGNED', 'EN_ROUTE', 'ARRIVED', 'RESOLVED'];
    final currentIndex = statusOrder.indexOf(_currentStatus).clamp(0, 4);

    return Column(
      children: [
        _StatusTimelineItem(label: 'SOS Alert Sent', isDone: currentIndex >= 0, isLast: false, theme: theme),
        _StatusTimelineItem(label: 'Responder Assigned', isDone: currentIndex >= 1, isLast: false, theme: theme),
        _StatusTimelineItem(label: 'Ambulance En Route', isDone: currentIndex > 2, isCurrent: currentIndex == 2, isLast: false, theme: theme),
        _StatusTimelineItem(label: 'Arrived at Location', isDone: currentIndex >= 3, isLast: true, theme: theme),
      ],
    );
  }

  void _showCancelDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Cancel Emergency?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to cancel the active emergency? The assigned responder will be notified immediately.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('No, keep active', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(cancelEmergencyProvider(widget.emergencyId).future);
              if (mounted) {
                context.go('/home');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Emergency cancelled. Responder notified.'),
                    backgroundColor: Colors.orange.shade800,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('Cancel Request', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _StatusTimelineItem extends StatelessWidget {
  final String label;
  final bool isDone;
  final bool isCurrent;
  final bool isLast;
  final ThemeData theme;

  const _StatusTimelineItem({
    required this.label,
    required this.isDone,
    this.isCurrent = false,
    required this.isLast,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDone ? Colors.green : (isCurrent ? theme.colorScheme.primary : Colors.grey.shade300);
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: isDone ? Colors.green : (isCurrent ? Colors.white : Colors.grey.shade300),
                shape: BoxShape.circle,
                border: isCurrent ? Border.all(color: theme.colorScheme.primary, width: 4) : null,
              ),
              child: isDone ? const Icon(Icons.check, size: 10, color: Colors.white) : null,
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 24,
                color: isDone ? Colors.green : Colors.grey.shade200,
              ),
          ],
        ),
        const SizedBox(width: 16),
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: isDone || isCurrent ? Colors.black87 : Colors.grey.shade500,
            fontWeight: isDone || isCurrent ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}

// Background map grid simulation
class _TrackingMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary.withOpacity(0.08)
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(size.width * 0.2, 0);
    path.lineTo(size.width * 0.3, size.height * 0.4);
    path.lineTo(size.width * 0.6, size.height * 0.55);
    path.lineTo(size.width * 0.8, size.height);
    
    canvas.drawPath(path, paint);
    
    paint.strokeWidth = 6;
    paint.color = AppColors.primary.withOpacity(0.04);
    canvas.drawLine(Offset(0, size.height * 0.3), Offset(size.width * 0.5, size.height * 0.3), paint);
    canvas.drawLine(Offset(size.width * 0.6, size.height * 0.8), Offset(size.width, size.height * 0.6), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
