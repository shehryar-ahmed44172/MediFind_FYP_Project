import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/emergency_provider.dart';
import '../../theme/app_theme.dart';

class EmergencyTrackingScreen extends ConsumerWidget {
  final String emergencyId;
  const EmergencyTrackingScreen({Key? key, required this.emergencyId}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Try to watch live emergency data, fallback to UI directly
    final emergencyAsync = ref.watch(getEmergencyProvider(emergencyId));

    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: emergencyAsync.when(
        data: (emergency) => _buildBody(context, theme),
        loading: () => _buildBody(context, theme),
        error: (_, __) => _buildBody(context, theme), // Shows the UI even without backend
      ),
    );
  }

  Widget _buildBody(BuildContext context, ThemeData theme) {
    return Stack(
      children: [
        // 1. Full Screen Map Background Simulator
        Positioned.fill(
          child: CustomPaint(
            painter: _TrackingMapPainter(),
            child: Container(
              color: Colors.blue.withOpacity(0.02),
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
        Positioned(
          top: MediaQuery.of(context).size.height * 0.4,
          left: MediaQuery.of(context).size.width * 0.3,
          child: _buildMapPin(Icons.local_hospital_rounded, Colors.red.shade700),
        ),
        Positioned(
          top: MediaQuery.of(context).size.height * 0.55,
          left: MediaQuery.of(context).size.width * 0.6,
          child: _buildMapPin(Icons.person_pin_circle_rounded, Colors.blue.shade700),
        ),

        // 4. Bottom Responder Details & Status Sheet (FR7.4, FR5.1-5.7 context)
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: _buildBottomDetailsSheet(context, theme),
        ),
      ],
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
                    '05 Min',
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

  Widget _buildBottomDetailsSheet(BuildContext context, ThemeData theme) {
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
                      Text(
                        'Dr. Ahmed Khan',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.star_rounded, color: Colors.orange.shade400, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            '4.9 (120+ Rescues)',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Action Buttons
                Row(
                  children: [
                    _buildActionButton(Icons.chat_bubble_rounded, Colors.blue),
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
    return Column(
      children: [
        _StatusTimelineItem(label: 'SOS Alert Sent', isDone: true, isLast: false, theme: theme),
        _StatusTimelineItem(label: 'Responder Assigned', isDone: true, isLast: false, theme: theme),
        _StatusTimelineItem(label: 'Ambulance En Route', isDone: false, isCurrent: true, isLast: false, theme: theme),
        _StatusTimelineItem(label: 'Arrived at Location', isDone: false, isLast: true, theme: theme),
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
            onPressed: () {
              Navigator.pop(ctx);
              context.go('/home');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Emergency cancelled. Responder notified.'),
                  backgroundColor: Colors.orange.shade800,
                  behavior: SnackBarBehavior.floating,
                ),
              );
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
      ..color = Colors.blue.withOpacity(0.08)
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
    paint.color = Colors.blue.withOpacity(0.04);
    canvas.drawLine(Offset(0, size.height * 0.3), Offset(size.width * 0.5, size.height * 0.3), paint);
    canvas.drawLine(Offset(size.width * 0.6, size.height * 0.8), Offset(size.width, size.height * 0.6), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
