import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../presentation/theme/app_theme.dart';
import 'package:go_router/go_router.dart';
import '../audio/voice_alert_service.dart';
import '../../data/datasources/local/local_data_source.dart';

// Top-level function for background message handling
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('Handling a background message: ${message.messageId}');
  // Implement background fallback logic if needed
}

class PushNotificationService {
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  static GlobalKey<NavigatorState>? _navigatorKey;
  static BuildContext? _currentDialogContext;
  static LocalDataSource? _localDataSource;

  static Future<void> initialize(GlobalKey<NavigatorState> navigatorKey, LocalDataSource localDataSource) async {
    try {
      _navigatorKey = navigatorKey;
      _localDataSource = localDataSource;
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
      FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
        debugPrint('🔔 FCM Foreground Message Received: ${message.data}');
        
        final type = message.data['type'];
        final legacyType = message.data['legacy_type'];
        
        // Match either the new SOS_TRIGGERED or the legacy EMERGENCY_REQUEST
        if (type == 'SOS_TRIGGERED' || type == 'EMERGENCY_REQUEST' || legacyType == 'EMERGENCY_REQUEST') {
          debugPrint('🚨 SOS Triggered! Triggering Visual Alert...');
          
          if (_localDataSource != null) {
            await _localDataSource!.saveEmergency(message.data);
          }
          
          showEmergencyAlert(message.data);
        } else if (type == 'EMERGENCY_ACCEPTED_BY_OTHER' || type == 'EMERGENCY_CANCELLED') {
          _dismissCurrentEmergencyModal();
        }
      });

      // Handle message tapped when app is in background but opened
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        if (message.data['type'] == 'EMERGENCY_REQUEST') {
          final requestId = message.data['emergencyId'] ?? '';
          if (requestId.isNotEmpty && _navigatorKey?.currentContext != null) {
            _navigatorKey!.currentContext!.push('/responder/emergency/$requestId');
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

  static void _dismissCurrentEmergencyModal() {
    if (_currentDialogContext != null) {
      if (Navigator.of(_currentDialogContext!).canPop()) {
        Navigator.of(_currentDialogContext!).pop();
      }
      _currentDialogContext = null;
    }
  }

  static void showEmergencyAlert(Map<String, dynamic> data) {
    if (_navigatorKey == null || _navigatorKey!.currentContext == null) {
      debugPrint('❌ Cannot show Emergency Modal: Navigator context is null');
      return;
    }

    final context = _navigatorKey!.currentContext!;

    // If another modal is somehow open, close it
    _dismissCurrentEmergencyModal();

    final emergencyType = data['emergencyType'] ?? 'Unknown Emergency';
    final distance = data['distanceKm'] ?? data['distance'] ?? 'Calculating...';
    
    // Trigger Voice Alert
    VoiceAlertService().speakMessage('Emergency Alert! ${emergencyType.replaceAll('_', ' ')} reported $distance kilometers away.');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        _currentDialogContext = dialogContext;
        final priority = data['priority'] ?? 'NORMAL';
        final requestId = data['emergencyId'] ?? data['id'] ?? '';

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
                Text('Distance: $distance km', style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 12),
                if (data['voiceSummary'] != null || data['medicalContext'] != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade100),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.medical_services_outlined, size: 16, color: Colors.blue.shade900),
                            const SizedBox(width: 8),
                            Text('Medical Context', 
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blue.shade900)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          data['voiceSummary'] ?? data['medicalContext'] ?? '',
                          style: TextStyle(fontSize: 13, color: Colors.blue.shade800),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      child: const Text('Dismiss', style: TextStyle(color: Colors.grey)),
                      onPressed: () {
                        Navigator.of(dialogContext).pop();
                        _currentDialogContext = null;
                      },
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('View Details', style: TextStyle(color: Colors.white)),
                      onPressed: () {
                        Navigator.of(dialogContext).pop();
                        _currentDialogContext = null;
                        if (requestId.isNotEmpty && _navigatorKey?.currentContext != null) {
                          _navigatorKey!.currentContext!.push('/responder/request/$requestId');
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
