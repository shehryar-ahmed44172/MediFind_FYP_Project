import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/router.dart';
import '../../data/datasources/local/local_data_source.dart';
import '../../domain/entities/user.dart';
import '../../presentation/providers/accessibility_provider.dart';
import '../../presentation/providers/auth_provider.dart';
import '../../presentation/providers/emergency_provider.dart';
import '../../presentation/providers/notification_provider.dart';
import '../../presentation/services/haptic_feedback_service.dart';
import '../../presentation/theme/app_theme.dart';
import '../../presentation/widgets/common/emergency_timer.dart';
import '../audio/voice_alert_service.dart';
import '../socket/socket_service.dart';
import 'push_background_service.dart';
import 'push_core.dart';

/// Client for the MediFind self-hosted push service (no third-party push
/// provider).
///
/// Delivery paths:
///  * app open      - `push` events on the app socket ([SocketService]);
///                    emergencies are handled in-app (alert dialogs, deaf
///                    visual alert), other types as local notifications.
///  * app closed    - Android foreground service ([PushBackgroundService])
///                    with its own socket shows local notifications.
///  * missed pushes - `GET notifications/pending` on login and app resume.
///
/// Every message is de-duplicated by id, dropped when expired, and
/// acknowledged (`push:ack`, or `POST notifications/ack` as fallback) once
/// shown or handled.
class MedifindPushService {
  MedifindPushService._();

  static GlobalKey<NavigatorState>? _navigatorKey;
  static BuildContext? _currentDialogContext;
  static LocalDataSource? _localDataSource;
  static ProviderContainer? _container;

  static bool _initialized = false;
  static bool _appResumed = true;
  static Timer? _heartbeat;
  static StreamSubscription<SocketMessage>? _socketSubscription;
  static final Set<String> _inFlight = {};
  static bool _syncing = false;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  /// Call once after the first frame (main isolate).
  static Future<void> initialize(
    GlobalKey<NavigatorState> navigatorKey,
    LocalDataSource localDataSource,
    ProviderContainer container,
  ) async {
    _navigatorKey = navigatorKey;
    _localDataSource = localDataSource;
    _container = container;
    if (_initialized) return;
    _initialized = true;

    try {
      await PushNotifier.initialize(onTap: _onNotificationTap);
    } catch (e) {
      debugPrint('[Push] local notifications init failed: $e');
    }

    _socketSubscription ??= SocketService.instance.messageStream.listen((message) {
      if (message.event == SocketEvent.push) {
        _handleIncoming(message.data, viaSocket: true);
      }
    });

    await PushBackgroundService.configure();
    _setHeartbeat(true);

    // Notification tapped while the app was terminated.
    try {
      final launch = await PushNotifier.plugin.getNotificationAppLaunchDetails();
      final payload = launch?.notificationResponse?.payload;
      if (launch != null && launch.didNotificationLaunchApp && payload != null) {
        unawaited(_routeWhenReady(payload));
      }
    } catch (e) {
      debugPrint('[Push] launch details unavailable: $e');
    }
  }

  /// After login (and on app start with a stored session).
  static Future<void> onLoggedIn(User user) async {
    final ds = _localDataSource;
    // Back-fill the session mirror for sessions created before this version.
    try {
      if (ds != null) {
        final token = await ds.getAuthToken();
        if (token != null) await PushSessionStore.saveAccessToken(token);
        final refresh = await ds.getRefreshToken();
        if (refresh != null) await PushSessionStore.saveRefreshToken(refresh);
      }
      await PushSessionStore.saveUserId(user.id);
      await PushSessionStore.saveRole(user.role);
      await PushSessionStore.savePatientType(user.patientType);
    } catch (e) {
      debugPrint('[Push] session mirror failed: $e');
    }

    await requestNotificationPermission();
    await PushBackgroundService.start();
    await syncPending();
  }

  /// On logout / account deletion.
  static Future<void> onLoggedOut() async {
    await PushBackgroundService.stop();
    dismissCurrentEmergencyModal();
  }

  /// Wire to `WidgetsBindingObserver.didChangeAppLifecycleState`.
  static void onAppLifecycleChanged(AppLifecycleState state) {
    final resumed = state == AppLifecycleState.resumed;
    if (resumed == _appResumed) return;
    _setHeartbeat(resumed);
    if (resumed) {
      unawaited(syncPending());
      SocketService.instance.requestPushSync();
    }
  }

  static void _setHeartbeat(bool resumed) {
    _appResumed = resumed;
    _heartbeat?.cancel();
    _heartbeat = null;
    unawaited(PushSessionStore.setAppResumed(resumed));
    if (resumed) {
      _heartbeat = Timer.periodic(const Duration(seconds: 15), (_) {
        unawaited(PushSessionStore.setAppResumed(true));
      });
    }
  }

  /// Android 13+ runtime notification permission (no-op elsewhere).
  static Future<void> requestNotificationPermission() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await PushNotifier.plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    } catch (e) {
      debugPrint('[Push] notification permission request failed: $e');
    }
  }

  /// Short human-readable status (diagnostics).
  static Future<String> statusSummary() async {
    final socket = SocketService.instance.isConnected ? 'socket connected' : 'socket offline';
    if (kIsWeb || !Platform.isAndroid) return 'Self-hosted push, $socket (foreground only)';
    final running = await PushBackgroundService.isRunning();
    return 'Self-hosted push, $socket, background service ${running ? 'running' : 'stopped'}';
  }

  // ---------------------------------------------------------------------------
  // Incoming messages
  // ---------------------------------------------------------------------------

  /// Fetch pushes missed while the socket was down, handle and ack them.
  static Future<void> syncPending() async {
    final container = _container;
    if (container == null || _syncing) return;
    final ds = _localDataSource;
    final token = await ds?.getAuthToken();
    if (token == null || token.isEmpty) return;

    _syncing = true;
    try {
      final pending = await container.read(apiClientProvider).getPendingPush();
      final acked = <String>[];
      for (final raw in pending) {
        final id = await _handleIncoming(raw, viaSocket: false);
        if (id != null) acked.add(id);
      }
      if (acked.isNotEmpty) await _ack(acked, preferHttp: true);
    } catch (e) {
      debugPrint('[Push] pending sync failed: $e');
    } finally {
      _syncing = false;
    }
  }

  /// Returns the id to acknowledge, or null when nothing should be acked
  /// (invalid, expired, or left to the background service). Socket messages
  /// are acked here directly.
  static Future<String?> _handleIncoming(dynamic raw, {required bool viaSocket}) async {
    final message = PushMessage.tryParse(raw);
    if (message == null || message.isExpired) return null;
    if (!_inFlight.add(message.id)) return null;

    try {
      if (await PushSessionStore.wasSeen(message.id)) {
        if (viaSocket) await _ack([message.id]);
        return message.id;
      }

      if (!_appResumed && await PushBackgroundService.isRunning()) {
        // App in background with the Android service alive: it shows the
        // notification (avoids duplicates).
        return null;
      }

      if (_appResumed) {
        await _handleInForeground(message);
      } else {
        await PushNotifier.show(message, deaf: await _isDeafUser());
      }

      await PushSessionStore.markSeen(message.id);
      if (viaSocket) await _ack([message.id]);
      return message.id;
    } catch (e) {
      debugPrint('[Push] failed to handle ${message.type} ${message.id}: $e');
      return null;
    } finally {
      _inFlight.remove(message.id);
    }
  }

  static Future<void> _ack(List<String> ids, {bool preferHttp = false}) async {
    if (ids.isEmpty) return;
    if (!preferHttp && SocketService.instance.ackPush(ids)) return;
    try {
      await _container?.read(apiClientProvider).ackPush(ids);
    } catch (e) {
      // Not fatal: the server re-sends, and dedupe prevents a second alert.
      debugPrint('[Push] ack failed: $e');
    }
  }

  static Future<bool> _isDeafUser() async {
    final session = await PushSessionStore.load();
    if (await PushSessionStore.isDeafOrTextOnly(session)) return true;
    final container = _container;
    if (container == null) return false;
    return container.read(accessibilityProvider).textOnlyMode;
  }

  static Future<User?> _currentUser() async {
    final container = _container;
    if (container == null) return null;
    try {
      return container.read(currentUserProvider).valueOrNull ??
          await container.read(currentUserProvider.future);
    } catch (_) {
      return null;
    }
  }

  /// Foreground behaviour: the same in-app flows the previous foreground handler
  /// used (responder SOS dialog, caregiver "Track live" dialog, emergency
  /// cache updates, deaf visual alert). Anything not handled in-app is shown
  /// as a normal heads-up notification.
  static Future<void> _handleInForeground(PushMessage message) async {
    final container = _container;
    final user = await _currentUser();
    final role = user?.role ?? await _localDataSource?.getCurrentUserRole();
    final data = _normalize(message.data);
    final hasUi = _navigatorKey?.currentContext != null;

    switch (message.type) {
      case PushTypes.sosTriggered:
        if (role != 'RESPONDER') return; // only responders see requests
        final patientId = (data['patientId'] ?? data['userId'])?.toString();
        if (patientId != null && user != null && patientId == user.id) return;
        await _cacheEmergencySafely(data);
        if (container != null) {
          container.invalidate(getActiveEmergenciesProvider);
          container.invalidate(responderAlertsProvider);
        }
        if (hasUi) {
          showEmergencyAlert({...data, 'expiresAt': data['expiresAt'] ?? message.expiresAt?.toIso8601String()});
          return;
        }
        break;

      case PushTypes.patientEmergency:
        if (role == 'CAREGIVER' && data['status'] == null && hasUi) {
          container?.invalidate(getActiveEmergenciesProvider);
          showEmergencyAlert({...data, 'isCaregiverAlert': true});
          return;
        }
        break;

      case PushTypes.acceptedByOther:
      case PushTypes.emergencyResolved:
        if (role == 'RESPONDER') {
          await _markCachedEmergency(data, data['status'] == 'CANCELLED' ? 'CANCELLED' : 'RESOLVED');
          dismissCurrentEmergencyModal();
          if (container != null) {
            container.invalidate(getActiveEmergenciesProvider);
            container.invalidate(watchActiveEmergenciesProvider);
            container.invalidate(responderAlertsProvider);
          }
          return;
        }
        break;

      case PushTypes.callIncoming:
        // App in the foreground: the socket already opened the ringing call screen
        return;

      case PushTypes.chatMessage:
        if (role == 'RESPONDER') return; // responders never get chat pushes
        final roomId = data['roomId']?.toString();
        if (roomId != null && _currentPath() == '/chat/$roomId') return;
        break;
    }

    // Deaf / text-only patients: full-screen visual alert for emergency updates.
    if (role == 'PATIENT' &&
        container != null &&
        hasUi &&
        const {
          PushTypes.responderAssigned,
          PushTypes.responderArriving,
          PushTypes.emergencyResolved,
        }.contains(message.type) &&
        await _isDeafUser()) {
      if (container.read(accessibilityProvider).vibrationFeedback) {
        unawaited(HapticFeedbackService.sosPattern());
      }
      final text = message.body.isNotEmpty ? message.body : message.title;
      container.read(visualEmergencyAlertProvider.notifier).state =
          '${message.title.toUpperCase()}: $text';
      container.invalidate(getActiveEmergenciesProvider);
      return;
    }

    if (container != null) container.invalidate(notificationsProvider);
    await PushNotifier.show(message, deaf: await _isDeafUser());
  }

  /// Push data values are strings; the id may arrive as `emergencyId` only.
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
      debugPrint('[Push] could not cache emergency: $e');
    }
  }

  static Future<void> _markCachedEmergency(Map<String, dynamic> data, String status) async {
    final ds = _localDataSource;
    final id = data['emergencyId']?.toString();
    if (ds == null || id == null || id.isEmpty) return;
    try {
      final cached = await ds.getEmergency(id);
      if (cached != null) {
        cached['status'] = status;
        await ds.saveEmergency(cached);
      }
    } catch (e) {
      debugPrint('[Push] could not update cached emergency: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Notification tap routing
  // ---------------------------------------------------------------------------

  static void _onNotificationTap(NotificationResponse response) {
    unawaited(_routeWhenReady(response.payload));
  }

  static String? _currentPath() {
    try {
      return AppRouter.router.routerDelegate.currentConfiguration.uri.path;
    } catch (_) {
      return null;
    }
  }

  /// Waits until the router has left splash/login with a logged-in user
  /// (cold start from a notification), then navigates.
  static Future<void> _routeWhenReady(String? payload) async {
    final decoded = PushMessage.decodePayload(payload);
    if (decoded == null) return;

    for (var i = 0; i < 50; i++) {
      final path = _currentPath();
      final loggedIn = _container?.read(authStateProvider).valueOrNull ?? false;
      final ready = loggedIn &&
          _navigatorKey?.currentContext != null &&
          path != null &&
          path != '/splash' &&
          path != '/login';
      if (ready) break;
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }
    if (!(_container?.read(authStateProvider).valueOrNull ?? false)) return;

    final type = decoded['type']?.toString() ?? '';
    final rawData = decoded['data'];
    final data = <String, String>{};
    if (rawData is Map) {
      rawData.forEach((k, v) {
        if (k != null && v != null) data[k.toString()] = v.toString();
      });
    }
    final emergencyId = data['emergencyId'] ?? data['id'] ?? '';
    final role = (await _currentUser())?.role ?? await _localDataSource?.getCurrentUserRole();

    final target = routeFor(type: type, data: data, role: role, emergencyId: emergencyId);
    final router = AppRouter.router;
    if (target != null) {
      router.push(target);
      return;
    }

    // Other types: refresh notifications and make sure we are on a home tab.
    _container?.invalidate(notificationsProvider);
    final home = switch (role) {
      'RESPONDER' => '/responder',
      'CAREGIVER' => '/caregiver',
      _ => '/home',
    };
    final path = _currentPath();
    if (path == null || path == '/splash' || path == '/login') router.go(home);
  }

  /// Deep link for a tapped notification, or null for "home".
  @visibleForTesting
  static String? routeFor({
    required String type,
    required Map<String, String> data,
    required String? role,
    required String emergencyId,
  }) {
    if (type == PushTypes.chatMessage) {
      final roomId = data['roomId'];
      return (roomId == null || roomId.isEmpty) ? null : '/chat/$roomId';
    }
    if (emergencyId.isEmpty) return null;

    switch (role) {
      case 'RESPONDER':
        if (type == PushTypes.sosTriggered) return '/responder/request/$emergencyId';
        return null;
      case 'CAREGIVER':
        if (type == PushTypes.patientEmergency ||
            type == PushTypes.responderAssigned ||
            type == PushTypes.patientSafe ||
            type == PushTypes.responderArriving) {
          return '/caregiver/tracking/$emergencyId';
        }
        return null;
      case 'PATIENT':
        if (type == PushTypes.responderAssigned ||
            type == PushTypes.emergencyResolved ||
            type == PushTypes.responderArriving) {
          return '/emergency/$emergencyId/tracking';
        }
        return null;
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // In-app emergency dialogs (unchanged behaviour)
  // ---------------------------------------------------------------------------

  static void dismissCurrentEmergencyModal() {
    final ctx = _currentDialogContext;
    _currentDialogContext = null;
    _closeDialog(ctx);
  }

  /// Closes only the given dialog. If other screens were pushed above it, the dialog
  /// route is removed in place instead of popping whatever screen is on top.
  static void _closeDialog(BuildContext? dialogContext) {
    if (dialogContext == null || !dialogContext.mounted) return;
    final route = ModalRoute.of(dialogContext);
    if (route == null || !route.isActive) return;
    final navigator = Navigator.of(dialogContext);
    if (route.isCurrent) {
      navigator.pop();
    } else {
      navigator.removeRoute(route);
    }
  }

  /// Alerts already shown (SOS id + audience). The same SOS arrives by socket, push and
  /// pending-sync replay; it must pop up only once.
  static final Set<String> _shownAlertKeys = <String>{};

  static void showEmergencyAlert(Map<String, dynamic> rawData) {
    if (_navigatorKey == null || _navigatorKey!.currentContext == null) {
      debugPrint('Cannot show emergency modal: navigator context is null');
      return;
    }

    final data = _normalize(rawData);
    final isCaregiverAlert = data['isCaregiverAlert'] == true;
    final requestId = data['emergencyId']?.toString() ?? '';

    // The same SOS can arrive via the in-app socket event AND a push within
    // seconds - show once.
    final key = '$requestId|$isCaregiverAlert';
    if (requestId.isNotEmpty && !_shownAlertKeys.add(key)) {
      return;
    }

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
                    onExpired: () {
                      if (identical(_currentDialogContext, dialogContext)) _currentDialogContext = null;
                      _closeDialog(dialogContext);
                    },
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
                            child: Text(
                                'Allergies: ${data['allergies'].toString().replaceAll('[', '').replaceAll(']', '').replaceAll('"', '')}',
                                style: const TextStyle(fontSize: 13, color: Colors.red)),
                          ),
                        if (data['chronicDiseases'] != null && data['chronicDiseases'] != '[]')
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                                'Conditions: ${data['chronicDiseases'].toString().replaceAll('[', '').replaceAll(']', '').replaceAll('"', '')}',
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

  /// Caregiver-facing alert: a linked patient raised an SOS. No Accept/Reject -
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
