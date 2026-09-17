import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../../core/constants/app_constants.dart';

enum SocketEvent {
  connectionStatus,
  newEmergency,
  responderLocationUpdate,
  emergencyStatusChange,
  responderArrived,
  newMessage,
  notification,
  /// Self-hosted push message (`push` event) - see MedifindPushService.
  push,
  unknown
}

class SocketMessage {
  final SocketEvent event;
  final dynamic data;

  SocketMessage(this.event, this.data);
}

/// App-wide Socket.io connection (singleton).
///
/// Auth: the server authenticates the handshake with the JWT sent in
/// `auth.token` and derives the user from it. `userId` is sent as well for
/// older servers. After a token refresh/login call [updateAuthToken] so the
/// socket reconnects with the new token.
///
/// Rooms joined through this service are remembered and automatically
/// re-joined after every (re)connect, so screens don't lose live updates when
/// the connection drops or the token rotates.
class SocketService {
  io.Socket? _socket;
  /// Last live-tracking location per emergency (see RESPONDER_LOCATION_UPDATE).
  final Map<String, DateTime> _lastLiveLocationAt = {};

  final StreamController<SocketMessage> _messageController =
      StreamController<SocketMessage>.broadcast();
  bool _isConnected = false;
  String? _authToken;
  String? _userId;

  /// Token the current socket was created with (to detect rotation).
  String? _connectedWithToken;

  final Set<String> _emergencyRooms = {};
  final Set<String> _locationRooms = {};
  final Set<String> _chatRooms = {};
  bool _joinedResponders = false;

  SocketService._internal();
  static final SocketService instance = SocketService._internal();

  Stream<SocketMessage> get messageStream => _messageController.stream;
  bool get isConnected => _isConnected;

  /// In-app call signalling events (`call:incoming`, `call:accepted`, `call:signal`, ...).
  final StreamController<({String event, Map<String, dynamic> data})> _callController =
      StreamController<({String event, Map<String, dynamic> data})>.broadcast();
  Stream<({String event, Map<String, dynamic> data})> get callEvents => _callController.stream;

  static const List<String> _callEventNames = [
    'call:incoming', 'call:accepted', 'call:declined', 'call:cancelled', 'call:ended', 'call:missed', 'call:signal',
  ];

  /// Emits [event] and completes with the server's acknowledgement, or `{ok: false}` when
  /// offline or when the server does not answer within [timeout].
  Future<Map<String, dynamic>> emitWithAck(String event, Map<String, dynamic> data,
      {Duration timeout = const Duration(seconds: 10)}) {
    final socket = _socket;
    if (!_isConnected || socket == null) {
      return Future.value({'ok': false, 'code': 'OFFLINE', 'message': 'No connection to the server.'});
    }
    final completer = Completer<Map<String, dynamic>>();
    socket.emitWithAck(event, data, ack: (response) {
      if (completer.isCompleted) return;
      completer.complete(response is Map ? Map<String, dynamic>.from(response) : {'ok': false});
    });
    return completer.future.timeout(timeout,
        onTimeout: () => {'ok': false, 'code': 'TIMEOUT', 'message': 'The server did not respond.'});
  }

  /// Fire-and-forget emit (returns false when offline).
  bool emit(String event, Map<String, dynamic> data) {
    final socket = _socket;
    if (!_isConnected || socket == null) return false;
    socket.emit(event, data);
    return true;
  }

  /// Stores the token for the next [connect]. Does not reconnect by itself.
  void setAuthToken(String token) {
    _authToken = token;
  }

  /// Stores a new token and, if a user session is active, reconnects so the
  /// server sees the fresh JWT. Rooms are re-joined on connect.
  void updateAuthToken(String token) {
    final changed = token != _authToken;
    _authToken = token;
    final userId = _userId;
    if (changed && userId != null && _socket != null) {
      debugPrint('Socket: auth token changed, reconnecting');
      _openSocket(userId);
    }
  }

  void connect(String userId) {
    final sameSession = _socket != null &&
        _userId == userId &&
        _connectedWithToken == _authToken;
    // Already connected (or connecting) for this user with this token.
    if (sameSession) {
      if (!_isConnected && _socket!.disconnected) _socket!.connect();
      return;
    }

    // Different user → forget the previous user's rooms.
    if (_userId != null && _userId != userId) {
      _clearRooms();
    }
    _userId = userId;
    _openSocket(userId);
  }

  void _openSocket(String userId) {
    _disposeSocket();

    final token = _authToken;
    _connectedWithToken = token;

    final socket = io.io(
      AppConstants.socketUrl,
      io.OptionBuilder()
          .setTransports(['websocket', 'polling']) // Allow polling as fallback
          .disableAutoConnect()
          // Always create a fresh Manager so new auth options are applied
          // (socket_io_client caches managers per URL otherwise).
          .enableForceNew()
          .enableReconnection()
          .setAuth({
            if (token != null) 'token': token,
            'userId': userId,
          })
          .setExtraHeaders(token != null ? {'Authorization': 'Bearer $token'} : {})
          .build(),
    );
    _socket = socket;

    socket.onConnect((_) {
      _isConnected = true;
      _messageController.add(SocketMessage(SocketEvent.connectionStatus, {'status': 'connected'}));
      debugPrint('Socket connected to ${AppConstants.socketUrl}');
      _rejoinRooms();
    });

    socket.onDisconnect((_) {
      _isConnected = false;
      _messageController.add(SocketMessage(SocketEvent.connectionStatus, {'status': 'disconnected'}));
      debugPrint('Socket disconnected');
    });

    socket.onConnectError((data) => debugPrint('Socket connect error: $data'));
    socket.onError((data) => debugPrint('Socket error: $data'));

    // Generic notification listener. The full envelope is forwarded so
    // type/title/body are accessible; handlers read data['data'] themselves.
    socket.on('notification', (data) {
      _messageController.add(SocketMessage(SocketEvent.notification, data));
    });

    for (final name in _callEventNames) {
      socket.on(name, (data) {
        if (data is Map) _callController.add((event: name, data: Map<String, dynamic>.from(data)));
      });
    }

    // Self-hosted push delivery (store-and-forward, must be acknowledged).
    socket.on('push', (data) {
      _messageController.add(SocketMessage(SocketEvent.push, data));
    });

    socket.on('NEW_EMERGENCY', (data) {
      _messageController.add(SocketMessage(SocketEvent.newEmergency, _unpack(data)));
    });

    socket.on('LOCATION_UPDATE', (data) {
      final unpacked = _unpack(data);
      final id = unpacked is Map ? unpacked['emergencyId']?.toString() : null;
      if (id != null) _lastLiveLocationAt[id] = DateTime.now();
      _messageController.add(SocketMessage(SocketEvent.responderLocationUpdate, unpacked));
    });

    // Periodic availability sync from the responder app (separate GPS reading).
    // Ignored while live tracking for that emergency is flowing, otherwise the
    // marker would jump between the two readings.
    socket.on('RESPONDER_LOCATION_UPDATE', (data) {
      final unpacked = _unpack(data);
      final id = unpacked is Map ? unpacked['emergencyId']?.toString() : null;
      final live = id == null ? null : _lastLiveLocationAt[id];
      if (live != null && DateTime.now().difference(live) < const Duration(seconds: 20)) return;
      _messageController.add(SocketMessage(SocketEvent.responderLocationUpdate, unpacked));
    });

    socket.on('EMERGENCY_STATUS_CHANGE', (data) {
      _messageController.add(SocketMessage(SocketEvent.emergencyStatusChange, _unpack(data)));
    });

    socket.on('RESPONDER_ARRIVED', (data) {
      _messageController.add(SocketMessage(SocketEvent.responderArrived, _unpack(data)));
    });

    socket.on('message:new', (data) {
      _messageController.add(SocketMessage(SocketEvent.newMessage, _unpack(data)));
    });

    // Server-side automatic messages (e.g. deaf patient voice alert text)
    socket.on('NEW_MESSAGE', (data) {
      _messageController.add(SocketMessage(SocketEvent.newMessage, _unpack(data)));
    });

    // Server asks this client to join an emergency room (used for caregivers)
    socket.on('JOIN_EMERGENCY_ROOM', (data) {
      final emergencyId = (data is Map ? data['emergencyId'] : null)?.toString();
      if (emergencyId != null && emergencyId.isNotEmpty) {
        joinEmergencyRoom(emergencyId);
        joinLocationRoom(emergencyId);
      }
    });

    socket.connect();
  }

  /// Server events are usually `{ type, data: {...} }`; return the inner map.
  dynamic _unpack(dynamic data) {
    if (data is Map && data.containsKey('data') && data['data'] is Map) {
      return Map<String, dynamic>.from(data['data'] as Map);
    }
    if (data is Map && data is! Map<String, dynamic>) {
      return Map<String, dynamic>.from(data);
    }
    return data;
  }

  void _rejoinRooms() {
    final socket = _socket;
    if (socket == null) return;
    if (_joinedResponders) socket.emit('join:responders', null);
    for (final id in _emergencyRooms) {
      socket.emit('join:emergency', id);
    }
    for (final id in _locationRooms) {
      socket.emit('join:location', id);
    }
    for (final id in _chatRooms) {
      socket.emit('join:chat', id);
    }
    if (_emergencyRooms.isNotEmpty || _locationRooms.isNotEmpty || _chatRooms.isNotEmpty) {
      debugPrint('Socket: re-joined ${_emergencyRooms.length} emergency, '
          '${_locationRooms.length} location, ${_chatRooms.length} chat rooms');
    }
  }

  void joinRespondersRoom() {
    _joinedResponders = true;
    if (_isConnected) _socket?.emit('join:responders', null);
  }

  void joinEmergencyRoom(String emergencyId) {
    if (emergencyId.isEmpty) return;
    _emergencyRooms.add(emergencyId);
    if (_isConnected) _socket?.emit('join:emergency', emergencyId);
  }

  void joinLocationRoom(String emergencyId) {
    if (emergencyId.isEmpty) return;
    _locationRooms.add(emergencyId);
    if (_isConnected) _socket?.emit('join:location', emergencyId);
  }

  /// Stop re-joining an emergency's rooms (e.g. after it is resolved).
  void forgetEmergencyRooms(String emergencyId) {
    _emergencyRooms.remove(emergencyId);
    _locationRooms.remove(emergencyId);
  }

  void joinChatRoom(String roomId) {
    if (roomId.isEmpty) return;
    _chatRooms.add(roomId);
    if (_isConnected) _socket?.emit('join:chat', roomId);
  }

  void leaveChatRoom(String roomId) {
    _chatRooms.remove(roomId);
    if (_isConnected) _socket?.emit('leave:chat', roomId);
  }

  void sendLocationUpdate(
    String emergencyId,
    double latitude,
    double longitude,
    String status,
  ) {
    if (!_isConnected || _socket == null) return;
    _socket!.emit('update_location', {
      'emergencyId': emergencyId,
      'latitude': latitude,
      'longitude': longitude,
      'status': status,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Acknowledge push messages so the server stops re-sending them.
  /// Returns false when the socket is not connected (use the HTTP fallback).
  bool ackPush(List<String> ids) {
    if (ids.isEmpty) return true;
    final socket = _socket;
    if (!_isConnected || socket == null) return false;
    socket.emit('push:ack', {'ids': ids});
    return true;
  }

  /// Ask the server to replay undelivered push messages.
  void requestPushSync() {
    if (_isConnected) _socket?.emit('push:sync');
  }

  void _clearRooms() {
    _emergencyRooms.clear();
    _locationRooms.clear();
    _chatRooms.clear();
    _joinedResponders = false;
  }

  void _disposeSocket() {
    final socket = _socket;
    _socket = null;
    _isConnected = false;
    if (socket != null) {
      socket.clearListeners();
      socket.disconnect();
      socket.dispose();
    }
  }

  /// Ends the session (logout / account switch): closes the socket and
  /// forgets the user, token and all joined rooms.
  void disconnect() {
    _disposeSocket();
    _clearRooms();
    _userId = null;
    _authToken = null;
    _connectedWithToken = null;
  }

  void dispose() {
    disconnect();
    _messageController.close();
  }
}
