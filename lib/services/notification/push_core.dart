import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Shared building blocks for MediFind self-hosted push delivery.
///
/// Everything in this file is safe to use from BOTH the main UI isolate and
/// the Android background-service isolate: it only depends on
/// SharedPreferences and flutter_local_notifications (no Hive, no Riverpod,
/// no widgets).

// ---------------------------------------------------------------------------
// Push message model
// ---------------------------------------------------------------------------

/// A push delivered by the backend push service (`push` socket event or
/// `GET notifications/pending`).
class PushMessage {
  final String id;
  final String type;
  final String title;
  final String body;
  final String priority; // low | normal | high | emergency
  final Map<String, String> data;
  final DateTime? createdAt;
  final DateTime? expiresAt;

  const PushMessage({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.priority,
    required this.data,
    this.createdAt,
    this.expiresAt,
  });

  static PushMessage? tryParse(dynamic raw) {
    if (raw is! Map) return null;
    final id = raw['id']?.toString() ?? '';
    final type = raw['type']?.toString() ?? '';
    if (id.isEmpty || type.isEmpty) return null;

    final data = <String, String>{};
    final rawData = raw['data'];
    if (rawData is Map) {
      rawData.forEach((key, value) {
        if (key != null && value != null) data[key.toString()] = value.toString();
      });
    }

    return PushMessage(
      id: id,
      type: type,
      title: raw['title']?.toString() ?? 'MediFind',
      body: raw['body']?.toString() ?? '',
      priority: (raw['priority']?.toString() ?? 'normal').toLowerCase(),
      data: data,
      createdAt: DateTime.tryParse(raw['createdAt']?.toString() ?? ''),
      expiresAt: DateTime.tryParse(raw['expiresAt']?.toString() ?? ''),
    );
  }

  /// Emergency alerts are useless when late: never show an expired message.
  bool get isExpired {
    final expiry = expiresAt;
    return expiry != null && expiry.isBefore(DateTime.now());
  }

  String? get emergencyId {
    final id = data['emergencyId'] ?? data['id'];
    return (id == null || id.isEmpty) ? null : id;
  }

  /// New-emergency alerts (emergency channel, full-screen intent). Only an
  /// incoming SOS for responders and a patient SOS for caregivers qualify;
  /// progress updates such as RESPONDER_ARRIVING never do, whatever their
  /// priority.
  bool get isEmergency => type == PushTypes.sosTriggered || type == PushTypes.patientEmergency;

  /// Types that deserve a full-screen intent (incoming SOS).
  bool get wantsFullScreen =>
      type == PushTypes.sosTriggered || type == PushTypes.patientEmergency;

  /// Tap payload: JSON of type + data (+ push id).
  String toPayload() => jsonEncode({'id': id, 'type': type, 'data': data});

  static Map<String, dynamic>? decodePayload(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    try {
      final decoded = jsonDecode(payload);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }
}

class PushTypes {
  PushTypes._();
  static const sosTriggered = 'SOS_TRIGGERED';
  static const patientEmergency = 'PATIENT_EMERGENCY';
  static const responderAssigned = 'RESPONDER_ASSIGNED';
  static const emergencyResolved = 'EMERGENCY_RESOLVED';
  static const patientSafe = 'PATIENT_SAFE';
  static const acceptedByOther = 'EMERGENCY_ACCEPTED_BY_OTHER';
  static const chatMessage = 'CHAT_MESSAGE';
  static const caregiverInvitation = 'CAREGIVER_INVITATION';
  static const caregiverInvitationSent = 'CAREGIVER_INVITATION_SENT';
  static const caregiverResponse = 'CAREGIVER_RESPONSE';
  static const systemAlert = 'SYSTEM_ALERT';
  static const responderArriving = 'RESPONDER_ARRIVING';
  static const callIncoming = 'CALL_INCOMING';
}

// ---------------------------------------------------------------------------
// Session + dedupe storage (SharedPreferences, readable from any isolate)
// ---------------------------------------------------------------------------

class PushSession {
  final String accessToken;
  final String? refreshToken;
  final String? userId;
  final String? role;
  final String? patientType;

  const PushSession({
    required this.accessToken,
    this.refreshToken,
    this.userId,
    this.role,
    this.patientType,
  });
}

/// Mirror of the auth session in SharedPreferences.
///
/// Hive (the app's main store) must not be opened from two isolates at once,
/// so the background service reads the session from here instead. The main
/// isolate keeps it in sync from [LocalDataSource].
class PushSessionStore {
  PushSessionStore._();

  static const _kAccessToken = 'mf_push_access_token';
  static const _kRefreshToken = 'mf_push_refresh_token';
  static const _kUserId = 'mf_push_user_id';
  static const _kRole = 'mf_push_role';
  static const _kPatientType = 'mf_push_patient_type';
  static const _kSeenIds = 'mf_push_seen_ids';
  static const _kAppResumedAt = 'mf_push_app_resumed_at';
  static const _kBatteryPrompted = 'mf_push_battery_prompted';

  static const int _maxSeenIds = 200;

  static Future<SharedPreferences> _prefs({bool reload = false}) async {
    final prefs = await SharedPreferences.getInstance();
    // Another isolate may have written since this isolate cached the values.
    if (reload) await prefs.reload();
    return prefs;
  }

  static Future<void> _setOrRemove(String key, String? value) async {
    final prefs = await _prefs();
    if (value == null || value.isEmpty) {
      await prefs.remove(key);
    } else {
      await prefs.setString(key, value);
    }
  }

  static Future<void> saveAccessToken(String? token) => _setOrRemove(_kAccessToken, token);
  static Future<void> saveRefreshToken(String? token) => _setOrRemove(_kRefreshToken, token);
  static Future<void> saveUserId(String? userId) => _setOrRemove(_kUserId, userId);
  static Future<void> saveRole(String? role) => _setOrRemove(_kRole, role);
  static Future<void> savePatientType(String? patientType) => _setOrRemove(_kPatientType, patientType);

  static Future<PushSession?> load() async {
    try {
      final prefs = await _prefs(reload: true);
      final token = prefs.getString(_kAccessToken);
      if (token == null || token.isEmpty) return null;
      return PushSession(
        accessToken: token,
        refreshToken: prefs.getString(_kRefreshToken),
        userId: prefs.getString(_kUserId),
        role: prefs.getString(_kRole),
        patientType: prefs.getString(_kPatientType),
      );
    } catch (e) {
      debugPrint('[Push] Could not read session: $e');
      return null;
    }
  }

  static Future<void> clear() async {
    final prefs = await _prefs();
    await Future.wait([
      prefs.remove(_kAccessToken),
      prefs.remove(_kRefreshToken),
      prefs.remove(_kUserId),
      prefs.remove(_kRole),
      prefs.remove(_kPatientType),
      prefs.remove(_kAppResumedAt),
    ]);
  }

  /// Deaf patients (or anyone using accessibility text-only mode) get the
  /// strongest vibration and the visual alert layer.
  static Future<bool> isDeafOrTextOnly(PushSession? session) async {
    if (session == null) return false;
    if ((session.patientType ?? '').toUpperCase() == 'DEAF') return true;
    final userId = session.userId;
    if (userId == null) return false;
    final prefs = await _prefs();
    // Key written by AccessibilityNotifier (namespaced per user).
    return prefs.getBool('acc_${userId}_textOnly') ?? false;
  }

  // -- Dedupe -----------------------------------------------------------------

  static Future<bool> wasSeen(String id) async {
    final prefs = await _prefs(reload: true);
    return (prefs.getStringList(_kSeenIds) ?? const []).contains(id);
  }

  static Future<void> markSeen(String id) async {
    final prefs = await _prefs(reload: true);
    final ids = List<String>.from(prefs.getStringList(_kSeenIds) ?? const []);
    if (ids.contains(id)) return;
    ids.add(id);
    if (ids.length > _maxSeenIds) ids.removeRange(0, ids.length - _maxSeenIds);
    await prefs.setStringList(_kSeenIds, ids);
  }

  // -- Foreground heartbeat -----------------------------------------------------

  /// Written by the main isolate every few seconds while the app is resumed
  /// (0 when paused). The background service skips pushes while it is fresh,
  /// so the user never gets the same alert twice.
  static Future<void> setAppResumed(bool resumed) async {
    final prefs = await _prefs();
    await prefs.setInt(_kAppResumedAt, resumed ? DateTime.now().millisecondsSinceEpoch : 0);
  }

  static Future<bool> isAppInForeground({Duration freshness = const Duration(seconds: 35)}) async {
    final prefs = await _prefs(reload: true);
    final at = prefs.getInt(_kAppResumedAt) ?? 0;
    if (at == 0) return false;
    return DateTime.now().millisecondsSinceEpoch - at < freshness.inMilliseconds;
  }

  // -- Battery prompt -----------------------------------------------------------

  static Future<bool> wasBatteryPromptShown() async =>
      (await _prefs()).getBool(_kBatteryPrompted) ?? false;

  static Future<void> markBatteryPromptShown() async =>
      (await _prefs()).setBool(_kBatteryPrompted, true);
}

// ---------------------------------------------------------------------------
// Local notifications
// ---------------------------------------------------------------------------

class PushChannels {
  PushChannels._();
  static const emergency = 'medifind_emergency';
  static const emergencyDeaf = 'medifind_emergency_deaf';
  static const updates = 'medifind_updates';
  static const messages = 'medifind_messages';
  static const service = 'medifind_service';
}

/// Displays push messages as system notifications.
class PushNotifier {
  PushNotifier._();

  static final FlutterLocalNotificationsPlugin plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  // Long, insistent pattern for incoming SOS (ms: wait, vibrate, pause, ...).
  static final Int64List _emergencyVibration =
      Int64List.fromList([0, 1000, 500, 1000, 500, 1000, 500, 1000]);

  // Stronger pattern for deaf users: longer pulses, shorter gaps, repeated.
  static final Int64List _deafVibration = Int64List.fromList(
      [0, 1500, 300, 1500, 300, 1500, 300, 1500, 300, 1500, 300, 1500]);

  static final Int64List _updateVibration = Int64List.fromList([0, 400, 200, 400]);

  static const _androidIcon = '@mipmap/launcher_icon';

  /// Initialises the plugin and creates the Android channels. Safe to call
  /// repeatedly. [onTap] is only needed in the main isolate.
  static Future<void> initialize({DidReceiveNotificationResponseCallback? onTap}) async {
    if (_initialized && onTap == null) return;
    const settings = InitializationSettings(
      android: AndroidInitializationSettings(_androidIcon),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await plugin.initialize(settings: settings, onDidReceiveNotificationResponse: onTap);
    _initialized = true;
    await _createChannels();
  }

  static AndroidFlutterLocalNotificationsPlugin? get _android => defaultTargetPlatform == TargetPlatform.android
      ? plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      : null;

  static Future<void> _createChannels() async {
    final android = _android;
    if (android == null) return;
    await android.createNotificationChannel(AndroidNotificationChannel(
      PushChannels.emergency,
      'Emergency alerts',
      description: 'Incoming SOS requests and patient emergencies',
      importance: Importance.max,
      enableVibration: true,
      vibrationPattern: _emergencyVibration,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      enableLights: true,
    ));
    await android.createNotificationChannel(AndroidNotificationChannel(
      PushChannels.emergencyDeaf,
      'Emergency alerts (strong vibration)',
      description: 'Emergency alerts with a stronger vibration for deaf users',
      importance: Importance.max,
      enableVibration: true,
      vibrationPattern: _deafVibration,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      enableLights: true,
    ));
    await android.createNotificationChannel(AndroidNotificationChannel(
      PushChannels.updates,
      'Emergency updates',
      description: 'Responder assigned, emergency resolved and other status updates',
      importance: Importance.high,
      enableVibration: true,
      vibrationPattern: _updateVibration,
    ));
    await android.createNotificationChannel(const AndroidNotificationChannel(
      PushChannels.messages,
      'Messages',
      description: 'Chat messages, invitations and announcements',
      importance: Importance.defaultImportance,
    ));
    await android.createNotificationChannel(const AndroidNotificationChannel(
      PushChannels.service,
      'Background alert service',
      description: 'Keeps MediFind connected so emergency alerts arrive when the app is closed',
      importance: Importance.low,
      playSound: false,
      enableVibration: false,
      showBadge: false,
    ));
  }

  /// Stable per-message notification id, identical in every isolate, so a
  /// message shown twice replaces itself instead of stacking.
  static int notificationIdFor(String pushId) {
    var hash = 0x811c9dc5;
    for (final unit in pushId.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash;
  }

  static Future<void> show(PushMessage message, {bool deaf = false}) async {
    await initialize();

    final String channelId;
    final String channelName;
    final Importance importance;
    final Priority priority;
    Int64List? vibration;
    AndroidNotificationCategory? category;

    if (message.isEmergency) {
      channelId = deaf ? PushChannels.emergencyDeaf : PushChannels.emergency;
      channelName = deaf ? 'Emergency alerts (strong vibration)' : 'Emergency alerts';
      importance = Importance.max;
      priority = Priority.max;
      vibration = deaf ? _deafVibration : _emergencyVibration;
      category = message.type == PushTypes.sosTriggered
          ? AndroidNotificationCategory.call
          : AndroidNotificationCategory.alarm;
    } else if (message.type == PushTypes.chatMessage ||
        message.type == PushTypes.caregiverInvitation ||
        message.type == PushTypes.caregiverInvitationSent ||
        message.type == PushTypes.caregiverResponse) {
      channelId = PushChannels.messages;
      channelName = 'Messages';
      importance = Importance.defaultImportance;
      priority = Priority.defaultPriority;
      category = message.type == PushTypes.chatMessage ? AndroidNotificationCategory.message : null;
    } else {
      // Status updates (RESPONDER_ASSIGNED, RESPONDER_ARRIVING, EMERGENCY_RESOLVED,
      // PATIENT_SAFE, SYSTEM_ALERT e.g. "SOS marked as false alarm", ...).
      // Never full-screen. Deaf / text-only users get the strong-vibration
      // channel so "help is on the way" is not missed without sound.
      channelId = deaf ? PushChannels.emergencyDeaf : PushChannels.updates;
      channelName = deaf ? 'Emergency alerts (strong vibration)' : 'Emergency updates';
      importance = deaf ? Importance.max : Importance.high;
      priority = deaf ? Priority.max : Priority.high;
      vibration = deaf ? _deafVibration : _updateVibration;
      category = AndroidNotificationCategory.status;
    }

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        importance: importance,
        priority: priority,
        category: category,
        visibility: message.isEmergency ? NotificationVisibility.public : NotificationVisibility.private,
        fullScreenIntent: message.wantsFullScreen,
        enableVibration: true,
        vibrationPattern: vibration,
        onlyAlertOnce: true,
        autoCancel: true,
        ticker: message.title,
        styleInformation: BigTextStyleInformation(message.body),
        timeoutAfter: _timeoutFor(message),
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
        presentBadge: true,
        interruptionLevel:
            message.isEmergency ? InterruptionLevel.timeSensitive : InterruptionLevel.active,
      ),
    );

    await plugin.show(
      id: notificationIdFor(message.id),
      title: message.title,
      body: message.body,
      notificationDetails: details,
      payload: message.toPayload(),
    );
  }

  /// Emergency notifications disappear when the alert expires.
  static int? _timeoutFor(PushMessage message) {
    final expiry = message.expiresAt;
    if (expiry == null || !message.isEmergency) return null;
    final ms = expiry.difference(DateTime.now()).inMilliseconds;
    return ms > 0 ? ms : null;
  }
}
