import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../presentation/theme/app_theme.dart';
import 'package:go_router/go_router.dart';
import '../audio/voice_alert_service.dart';
import '../../data/datasources/local/local_data_source.dart';
import '../../presentation/widgets/common/emergency_timer.dart';
import '../../firebase_options.dart';

// Top-level background handler — MUST use DefaultFirebaseOptions so Firebase
// can init correctly in the separate background isolate.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Guard: only init if not already initialized (background isolate starts fresh)
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  }
  debugPrint('📨 FCM Background message received: ${message.messageId}');
}

class PushNotificationService {
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  static GlobalKey<NavigatorState>? _navigatorKey;
  static BuildContext? _currentDialogContext;
  static LocalDataSource? _localDataSource;

  // Callback set by main.dart so token refresh can reach Riverpod providers
  static Future<void> Function(String token)? _onTokenRefreshCallback;

  static void setTokenRefreshCallback(Future<void> Function(String token) cb) {
    _onTokenRefreshCallback = cb;
  }

  static Future<void> initialize(GlobalKey<NavigatorState> navigatorKey, LocalDataSource localDataSource) async {
    try {
      _navigatorKey = navigatorKey;
      _localDataSource = localDataSource;
      // Firebase is already initialized in main() with DefaultFirebaseOptions.
      // Do NOT call initializeApp() again — it throws on some Android versions.

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

      // Auto-refresh: when FCM rotates the token (every ~30 days) send the
      // new token to the backend so push delivery never breaks silently.
      _firebaseMessaging.onTokenRefresh.listen((newToken) async {
        debugPrint('🔄 FCM token rotated — syncing to backend...');
        if (_onTokenRefreshCallback != null) {
          try {
            await _onTokenRefreshCallback!(newToken);
            debugPrint('✅ Refreshed FCM token synced to backend');
          } catch (e) {
            debugPrint('❌ Failed to sync refreshed FCM token: $e');
          }
        }
      });

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
        debugPrint('🔔 FCM Foreground Message Received: ${message.data}');
        
        final type = message.data['type'];
        final legacyType = message.data['legacy_type'];
        
        // Match either the new SOS_TRIGGERED or the legacy EMERGENCY_REQUEST
        if (type == 'SOS_TRIGGERED' || type == 'EMERGENCY_REQUEST' || legacyType == 'EMERGENCY_REQUEST') {
          
          // --- CRITICAL SECURITY CHECK ---
          if (_localDataSource != null) {
            final currentUserId = await _localDataSource!.getCurrentUserId();
            final currentUserRole = await _localDataSource!.getCurrentUserRole();
            final targetPatientId = (message.data['patientId'] ?? message.data['userId'])?.toString();
            
            // 1. Role Check: Only Responders should see this request
            if (currentUserRole != 'RESPONDER') {
              debugPrint('🛡️ [FCM Filter] Blocking SOS Alert: User is not a Responder ($currentUserRole)');
              return;
            }

            // 2. Self-SOS Filter: Never alert about own SOS
            if (targetPatientId != null && targetPatientId == currentUserId) {
              debugPrint('🛡️ [FCM Filter] Blocking SOS Alert: Self-SOS Detected ($targetPatientId)');
              return;
            }
            
            await _localDataSource!.saveEmergency(message.data);
          }
          
          debugPrint('🚨 SOS Verified! Triggering Visual Alert for Responder...');
          showEmergencyAlert(message.data);
        } else if (type == 'EMERGENCY_ACCEPTED_BY_OTHER' || type == 'EMERGENCY_CANCELLED' || type == 'EMERGENCY_RESOLVED') {
          dismissCurrentEmergencyModal();
        }
      });

      // Handle message tapped when app is in background but opened
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
        if (message.data['type'] == 'EMERGENCY_REQUEST' || message.data['type'] == 'SOS_TRIGGERED') {
          if (_localDataSource != null) {
            final role = await _localDataSource!.getCurrentUserRole();
            if (role != 'RESPONDER') return; // Ignore if not a responder
          }

          final requestId = message.data['emergencyId'] ?? message.data['id'] ?? '';
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

  static void dismissCurrentEmergencyModal() {
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
    dismissCurrentEmergencyModal();

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
                const Text(
                  'Emergency Request!',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
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
                const SizedBox(height: 16),
                if (data['expiresAt'] != null) ...[
                  const Text('REQUEST EXPIRES IN', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                  EmergencyTimer(
                    expiresAt: data['expiresAt'],
                    serverTime: data['serverTime'],
                    onExpired: () => dismissCurrentEmergencyModal(),
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.red, fontFamily: 'monospace'),
                  ),
                  const SizedBox(height: 12),
                ],
                Text('Distance: $distance km', style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 12),
                if (data['voiceSummary'] != null || data['medicalContext'] != null || data['bloodType'] != null) ...[
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
                            Text('Medical Summary', 
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blue.shade900)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (data['bloodType'] != null)
                          Text('Blood Type: ${data['bloodType']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        
                        if (data['voiceSummary'] != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text('Note: ${data['voiceSummary']}', style: TextStyle(fontSize: 13, color: Colors.blue.shade800)),
                          ),

                        if (data['allergies'] != null && data['allergies'] != '[]')
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text('Allergies: ${data['allergies'].toString().replaceAll('[', '').replaceAll(']', '').replaceAll('"', '')}', 
                              style: const TextStyle(fontSize: 13, color: Colors.red)),
                          ),
                          
                        if (data['chronicDiseases'] != null && data['chronicDiseases'] != '[]')
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text('Conditions: ${data['chronicDiseases'].toString().replaceAll('[', '').replaceAll(']', '').replaceAll('"', '')}', 
                              style: TextStyle(fontSize: 13, color: Colors.orange.shade900)),
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
