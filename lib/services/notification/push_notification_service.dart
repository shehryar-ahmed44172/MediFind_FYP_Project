import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../presentation/theme/app_theme.dart';
import 'package:go_router/go_router.dart';

// Top-level function for background message handling
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('Handling a background message: ${message.messageId}');
  // Implement background fallback logic if needed
}

class PushNotificationService {
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  static Future<void> initialize(BuildContext context) async {
    try {
      await Firebase.initializeApp();
      
      // Request permissions
      NotificationSettings settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        print('User granted permission');
      }

      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print('Got a message whilst in the foreground!');
        
        if (message.data['type'] == 'EMERGENCY_REQUEST') {
          _showCustomEmergencyModal(context, message.data);
        }
      });

      // Handle message tapped when app is in background but opened
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        if (message.data['type'] == 'EMERGENCY_REQUEST') {
          final requestId = message.data['emergencyId'] ?? '';
          if (requestId.isNotEmpty) {
            context.push('/responder/emergency/$requestId');
          }
        }
      });
      
    } catch (e) {
      print('Firebase initialization error: $e');
    }
  }

  static Future<String?> getToken() async {
    return await _firebaseMessaging.getToken();
  }

  static void _showCustomEmergencyModal(BuildContext context, Map<String, dynamic> data) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        final emergencyType = data['emergencyType'] ?? 'Unknown Emergency';
        final distance = data['distance'] ?? 'Calculating...';
        final priority = data['priority'] ?? 'NORMAL';
        final requestId = data['emergencyId'] ?? '';

        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: AppShadows.neumorphicOut,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: priority == 'HIGH' ? Colors.red.shade900 : Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.warning_rounded, color: Colors.white, size: 40),
                ),
                const SizedBox(height: 16),
                Text(
                  'Emergency Request!',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  emergencyType.replaceAll('_', ' '),
                  style: TextStyle(fontSize: 18, color: Colors.grey.shade700),
                  textAlign: TextAlign.center,
                ),
                if (priority == 'HIGH') ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'HIGH PRIORITY ESCALATION',
                      style: TextStyle(color: Colors.red.shade900, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Text('Distance: $distance', style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      child: const Text('Dismiss', style: TextStyle(color: Colors.grey)),
                      onPressed: () => Navigator.of(dialogContext).pop(),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('View Details', style: TextStyle(color: Colors.white)),
                      onPressed: () {
                        Navigator.of(dialogContext).pop();
                        if (requestId.isNotEmpty) {
                          context.push('/responder/emergency/$requestId');
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
