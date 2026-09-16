import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../core/constants/app_constants.dart';
import 'push_core.dart';

/// Android foreground service that keeps a socket to the MediFind push
/// service open while the app is in the background or closed.
///
/// It runs in its own isolate (separate FlutterEngine): it reads the session
/// from [PushSessionStore] (SharedPreferences), connects with the JWT, shows a
/// local notification for every `push` event and acknowledges it. While the
/// main app is in the foreground it stays silent - the app handles pushes.
///
/// iOS is not supported (no background sockets without APNs); every entry
/// point is a no-op there.
class PushBackgroundService {
  PushBackgroundService._();

  static const int _notificationId = 7401;
  static const String ongoingText = 'MediFind emergency alerts are active';

  static bool get _supported => !kIsWeb && Platform.isAndroid;

  static bool _configured = false;

  /// Configure once per app launch (main isolate). Does not start the service.
  static Future<void> configure() async {
    if (!_supported || _configured) return;
    try {
      // The ongoing notification's channel must exist before the service starts.
      await PushNotifier.initialize();
      await FlutterBackgroundService().configure(
        androidConfiguration: AndroidConfiguration(
          onStart: medifindPushServiceOnStart,
          autoStart: false,
          // Restarted after reboot; it stops itself again if nobody is logged in.
          autoStartOnBoot: true,
          isForegroundMode: true,
          notificationChannelId: PushChannels.service,
          initialNotificationTitle: 'MediFind',
          initialNotificationContent: ongoingText,
          foregroundServiceNotificationId: _notificationId,
          foregroundServiceTypes: [AndroidForegroundType.remoteMessaging],
        ),
        iosConfiguration: IosConfiguration(autoStart: false),
      );
      _configured = true;
    } catch (e) {
      debugPrint('[PushService] configure failed: $e');
    }
  }

  static Future<bool> isRunning() async {
    if (!_supported) return false;
    try {
      return await FlutterBackgroundService().isRunning();
    } catch (_) {
      return false;
    }
  }

  /// Start after login (all roles). If already running, it re-reads the session.
  static Future<void> start() async {
    if (!_supported) return;
    await configure();
    if (!_configured) return;
    try {
      final service = FlutterBackgroundService();
      if (await service.isRunning()) {
        service.invoke('sessionChanged');
      } else {
        await service.startService();
      }
    } catch (e) {
      debugPrint('[PushService] start failed: $e');
    }
  }

  /// Tell a running service that tokens changed (login / refresh).
  static Future<void> notifySessionChanged() async {
    if (!_supported || !await isRunning()) return;
    FlutterBackgroundService().invoke('sessionChanged');
  }

  /// Stop on logout / account deletion.
  static Future<void> stop() async {
    if (!_supported) return;
    try {
      final service = FlutterBackgroundService();
      if (await service.isRunning()) service.invoke('stop');
    } catch (e) {
      debugPrint('[PushService] stop failed: $e');
    }
  }
}

/// Background isolate entry point. Must be top-level and kept by the compiler.
@pragma('vm:entry-point')
Future<void> medifindPushServiceOnStart(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  await _BackgroundPushRunner(service).run();
}

class _BackgroundPushRunner {
  final ServiceInstance service;
  _BackgroundPushRunner(this.service);

  io.Socket? _socket;
  PushSession? _session;
  bool _stopping = false;
  bool _refreshing = false;
  DateTime? _lastRefreshAt;
  Timer? _watchdog;
  final List<StreamSubscription<dynamic>> _subscriptions = [];

  Future<void> run() async {
    _session = await PushSessionStore.load();
    if (_session == null) {
      debugPrint('[PushService] No session - stopping');
      await _stop();
      return;
    }

    try {
      await PushNotifier.initialize();
    } catch (e) {
      debugPrint('[PushService] notifications init failed: $e');
    }

    if (service is AndroidServiceInstance) {
      final android = service as AndroidServiceInstance;
      await android.setAsForegroundService();
      await android.setForegroundNotificationInfo(
        title: 'MediFind',
        content: PushBackgroundService.ongoingText,
      );
    }

    _subscriptions.add(service.on('stop').listen((_) => _stop()));
    _subscriptions.add(service.on('sessionChanged').listen((_) => _reloadSession()));

    // Periodically confirm we are still logged in and connected; ask the
    // server to replay anything we might have missed.
    _watchdog = Timer.periodic(const Duration(minutes: 3), (_) async {
      if (_stopping) return;
      final session = await PushSessionStore.load();
      if (session == null) {
        await _stop();
        return;
      }
      final socket = _socket;
      if (socket == null || socket.disconnected) {
        _connect();
      } else {
        socket.emit('push:sync');
      }
    });

    _connect();
  }

  Future<void> _reloadSession() async {
    final session = await PushSessionStore.load();
    if (session == null) {
      await _stop();
      return;
    }
    final tokenChanged = session.accessToken != _session?.accessToken;
    _session = session;
    if (tokenChanged || _socket == null || _socket!.disconnected) _connect();
  }

  void _connect() {
    final session = _session;
    if (session == null || _stopping) return;
    _disposeSocket();

    final socket = io.io(
      AppConstants.socketUrl,
      io.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .disableAutoConnect()
          .enableForceNew()
          .enableReconnection()
          .setReconnectionDelay(2000)
          .setReconnectionDelayMax(30000)
          .setAuth({'token': session.accessToken})
          .setExtraHeaders({'Authorization': 'Bearer ${session.accessToken}'})
          .build(),
    );
    _socket = socket;

    socket.onConnect((_) => debugPrint('[PushService] socket connected'));
    socket.onDisconnect((_) => debugPrint('[PushService] socket disconnected'));
    socket.onConnectError((error) {
      final text = error?.toString() ?? '';
      debugPrint('[PushService] connect error: $text');
      if (text.contains('Unauthorized')) _refreshAndReconnect();
    });
    socket.on('push', (raw) => _onPush(raw));
    socket.connect();
  }

  Future<void> _onPush(dynamic raw) async {
    final message = PushMessage.tryParse(raw);
    if (message == null) return;
    try {
      if (message.isExpired) return;

      if (await PushSessionStore.wasSeen(message.id)) {
        _ack(message.id); // our earlier ack may have been lost
        return;
      }

      // The foreground app shows and acks pushes itself.
      if (await PushSessionStore.isAppInForeground()) return;

      final deaf = await PushSessionStore.isDeafOrTextOnly(_session);
      await PushNotifier.show(message, deaf: deaf);
      await PushSessionStore.markSeen(message.id);
      _ack(message.id);
    } catch (e) {
      debugPrint('[PushService] failed to handle push ${message.id}: $e');
    }
  }

  void _ack(String id) {
    final socket = _socket;
    if (socket != null && socket.connected) {
      socket.emit('push:ack', {'ids': [id]});
    }
  }

  /// Access token expired: refresh with the stored refresh token and reconnect.
  /// If the refresh token is rejected, stop quietly (the app will ask the user
  /// to log in again next time it opens).
  Future<void> _refreshAndReconnect() async {
    if (_refreshing || _stopping) return;
    final last = _lastRefreshAt;
    if (last != null && DateTime.now().difference(last) < const Duration(seconds: 30)) return;
    _refreshing = true;
    _lastRefreshAt = DateTime.now();

    try {
      // The main app may already have refreshed the token.
      final stored = await PushSessionStore.load();
      if (stored == null) {
        await _stop();
        return;
      }
      if (stored.accessToken != _session?.accessToken) {
        _session = stored;
        _connect();
        return;
      }

      final refreshToken = stored.refreshToken;
      if (refreshToken == null || refreshToken.isEmpty) {
        await _stop();
        return;
      }

      final dio = Dio(BaseOptions(
        baseUrl: AppConstants.baseUrl,
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 20),
        headers: {
          'Content-Type': 'application/json',
          if (AppConstants.baseUrl.contains('ngrok')) 'ngrok-skip-browser-warning': 'true',
        },
      ));

      final Response<dynamic> response;
      try {
        response = await dio.post('auth/refresh-token', data: {'refreshToken': refreshToken});
      } on DioException catch (e) {
        final status = e.response?.statusCode;
        if (status == 400 || status == 401 || status == 403) {
          debugPrint('[PushService] refresh rejected ($status) - stopping');
          await _stop();
        } else {
          // Network problem: try again later (reconnection / watchdog).
          _lastRefreshAt = null;
        }
        return;
      }

      final body = response.data;
      final data = (body is Map && body['data'] is Map) ? body['data'] as Map : body;
      final access = data is Map ? (data['accessToken'] ?? data['token'])?.toString() : null;
      if (access == null || access.isEmpty) {
        await _stop();
        return;
      }
      final rotated = data is Map ? data['refreshToken']?.toString() : null;

      await PushSessionStore.saveAccessToken(access);
      if (rotated != null && rotated.isNotEmpty) await PushSessionStore.saveRefreshToken(rotated);

      _session = PushSession(
        accessToken: access,
        refreshToken: (rotated != null && rotated.isNotEmpty) ? rotated : refreshToken,
        userId: stored.userId,
        role: stored.role,
        patientType: stored.patientType,
      );
      debugPrint('[PushService] token refreshed - reconnecting');
      _connect();
    } catch (e) {
      debugPrint('[PushService] refresh failed: $e');
    } finally {
      _refreshing = false;
    }
  }

  void _disposeSocket() {
    final socket = _socket;
    _socket = null;
    if (socket != null) {
      socket.clearListeners();
      socket.disconnect();
      socket.dispose();
    }
  }

  Future<void> _stop() async {
    if (_stopping) return;
    _stopping = true;
    _watchdog?.cancel();
    for (final sub in _subscriptions) {
      await sub.cancel();
    }
    _disposeSocket();
    await service.stopSelf();
  }
}
