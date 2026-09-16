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

      debugPrint('Notification permission: ${settings.authorizationStatus}');

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
        final data = _normalize(message.data);
        final type = data['type']?.toString();
        final legacyType = data['legacy_type']?.toString();

        final currentUserId = await _localDataSource?.getCurrentUserId();
        final currentUserRole = await _localDataSource?.getCurrentUserRole();

        // Responder: new SOS (new SOS_TRIGGERED or legacy EMERGENCY_REQUEST)
        if (type == 'SOS_TRIGGERED' || type == 'EMERGENCY_REQUEST' || legacyType == 'EMERGENCY_REQUEST') {
          if (currentUserRole != 'RESPONDER') return; // only responders see requests

          // Self-SOS filter: never alert about own SOS
          final targetPatientId = (data['patientId'] ?? data['userId'])?.toString();
          if (targetPatientId != null && targetPatientId == currentUserId) return;

          await _cacheEmergencySafely(data);
          showEmergencyAlert(data);
        } else if (type == 'PATIENT_EMERGENCY' && currentUserRole == 'CAREGIVER' && data['status'] == null) {
          showEmergencyAlert({...data, 'isCaregiverAlert': true});
        } else if (type == 'EMERGENCY_ACCEPTED_BY_OTHER' || type == 'EMERGENCY_CANCELLED' || type == 'EMERGENCY_RESOLVED') {
          if (currentUserRole == 'RESPONDER') dismissCurrentEmergencyModal();
        }
      });

      // Notification tapped while the app was in the background
      FirebaseMessaging.onMessageOpenedApp.listen(_openFromNotification);

      // Notification tapped while the app was terminated
      final initial = await _firebaseMessaging.getInitialMessage();
      if (initial != null) {
        // Let the router finish its first navigation (splash) first.
        Future.delayed(const Duration(seconds: 2), () => _openFromNotification(initial));
      }
    } catch (e) {
      debugPrint('Firebase messaging initialization error: $e');
    }
  }

  /// FCM data values are strings; the id may arrive as `emergencyId` only.
  static Map<String, dynamic> _normalize(Map<String, dynamic> raw) {
    final data = Map<String, dynamic>.from(raw);
    final emergencyId = (data['emergencyId'] ?? data['id'])?.toString();
    if (emergencyId != null && emergencyId.isNotEmpty) {
      data['id'] ??= emergencyId;
      data['emergencyId'] ??= emergencyId;
    }
    return data;
  }

  /// Caching is best-effort: a failure must never block the alert.
  static Future<void> _cacheEmergencySafely(Map<String, dynamic> data) async {
    final ds = _localDataSource;
    if (ds == null || (data['id']?.toString() ?? '').isEmpty) return;
    try {
      await ds.saveEmergency({...data, 'isResponderAlert': true});
    } catch (e) {
      debugPrint('Could not cache emergency from push: $e');
    }
  }

  static Future<void> _openFromNotification(RemoteMessage message) async {
    final data = _normalize(message.data);
    final type = data['type']?.toString();
    final emergencyId = data['emergencyId']?.toString() ?? '';
    final context = _navigatorKey?.currentContext;
    if (emergencyId.isEmpty || context == null) return;

    final role = await _localDataSource?.getCurrentUserRole();
    if (!context.mounted) return;

    const emergencyTypes = {
      'SOS_TRIGGERED',
      'EMERGENCY_REQUEST',
      'PATIENT_EMERGENCY',
      'RESPONDER_ASSIGNED',
      'EMERGENCY_STATUS_CHANGE',
      'RESPONDER_LOCATION_UPDATE',
      'EMERGENCY_RESOLVED',
      'PATIENT_SAFE',
    };
    if (type != null && !emergencyTypes.contains(type)) return;

    switch (role) {
      case 'RESPONDER':
        context.push('/responder/request/$emergencyId');
        break;
      case 'CAREGIVER':
        context.push('/caregiver/tracking/$emergencyId');
        break;
      case 'PATIENT':
        context.push('/emergency/$emergencyId/tracking');
        break;
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

  static String? _lastAlertKey;
  static DateTime? _lastAlertAt;

  static void showEmergencyAlert(Map<String, dynamic> rawData) {
    if (_navigatorKey == null || _navigatorKey!.currentContext == null) {
      debugPrint('Cannot show emergency modal: navigator context is null');
      return;
    }

    final data = _normalize(rawData);
    final isCaregiverAlert = data['isCaregiverAlert'] == true;
    final requestId = data['emergencyId']?.toString() ?? '';

    // The same SOS can arrive via socket AND FCM within seconds — show once.
    final key = '$requestId|$isCaregiverAlert';
    final now = DateTime.now();
    if (requestId.isNotEmpty &&
        key == _lastAlertKey &&
        _lastAlertAt != null &&
        now.difference(_lastAlertAt!) < const Duration(seconds: 15) &&
        _currentDialogContext != null) {
      return;
    }
    _lastAlertKey = key;
    _lastAlertAt = now;

    final context = _navigatorKey!.currentContext!;

    // If another modal is somehow open, close it
    dismissCurrentEmergencyModal();

    if (isCaregiverAlert) {
      _showCaregiverAlert(context, data, requestId);
      return;
    }

    final emergencyType = (data['emergencyType'] ?? 'Unknown Emergency').toString();
    final distanceRaw = data['distanceKm'] ?? data['distance'];
    final distanceKm = distanceRaw == null ? null : double.tryParse(distanceRaw.toString());
    final distanceText = distanceKm != null ? '${distanceKm.toStringAsFixed(1)} km away' : 'Distance unknown';

    // Trigger Voice Alert
    VoiceAlertService().speakMessage(
      'Emergency alert! ${emergencyType.replaceAll('_', ' ')}${distanceKm != null ? ', ${distanceKm.toStringAsFixed(1)} kilometers away' : ''}.',
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        _currentDialogContext = dialogContext;
        final priority = data['priority'] ?? 'NORMAL';

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
                    expiresAt: data['expiresAt'].toString(),
                    serverTime: data['serverTime'],
                    onExpired: () => dismissCurrentEmergencyModal(),
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.red, fontFamily: 'monospace'),
                  ),
                  const SizedBox(height: 12),
                ],
                Text(distanceText, style: const TextStyle(fontSize: 16)),
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
                      style: TextButton.styleFrom(minimumSize: const Size(88, 48)),
                      child: Text('Dismiss', style: TextStyle(color: Colors.grey.shade700)),
                      onPressed: () {
                        Navigator.of(dialogContext).pop();
                        _currentDialogContext = null;
                      },
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        minimumSize: const Size(120, 48),
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

  /// Caregiver-facing alert: a linked patient raised an SOS. No Accept/Reject —
  /// the caregiver can open live tracking.
  static void _showCaregiverAlert(BuildContext context, Map<String, dynamic> data, String emergencyId) {
    final patientName = (data['patientName'] ?? 'Your patient').toString();
    final emergencyType = (data['emergencyType'] ?? '').toString().replaceAll('_', ' ');

    VoiceAlertService().speakMessage('Emergency alert. $patientName needs help.');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        _currentDialogContext = dialogContext;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          icon: const Icon(Icons.emergency_share_rounded, color: Colors.red, size: 44),
          title: Text('$patientName triggered an SOS', textAlign: TextAlign.center),
          content: Text(
            emergencyType.isNotEmpty
                ? '$emergencyType emergency. Responders are being notified. You can follow it live.'
                : 'Responders are being notified. You can follow it live.',
            textAlign: TextAlign.center,
          ),
          actionsAlignment: MainAxisAlignment.spaceEvenly,
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _currentDialogContext = null;
              },
              child: const Text('Later'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                minimumSize: const Size(140, 48),
              ),
              icon: const Icon(Icons.location_searching_rounded),
              label: const Text('Track live'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _currentDialogContext = null;
                final ctx = _navigatorKey?.currentContext;
                if (emergencyId.isNotEmpty && ctx != null) {
                  ctx.push('/caregiver/tracking/$emergencyId');
                }
              },
            ),
          ],
        );
      },
    );
  }
}
