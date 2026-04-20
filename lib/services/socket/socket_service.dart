import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../../core/constants/app_constants.dart';

enum SocketEvent {
  connectionStatus,
  newEmergency,
  responderLocationUpdate,
  emergencyStatusChange,
  responderArrived,
  unknown
}

class SocketMessage {
  final SocketEvent event;
  final dynamic data;

  SocketMessage(this.event, this.data);
}

class SocketService {
  IO.Socket? _socket;
  final StreamController<SocketMessage> _messageController =
      StreamController<SocketMessage>.broadcast();
  bool _isConnected = false;
  String? _authToken;

  SocketService._internal();
  static final SocketService instance = SocketService._internal();

  Stream<SocketMessage> get messageStream => _messageController.stream;
  bool get isConnected => _isConnected;

  void setAuthToken(String token) {
    _authToken = token;
  }

  String? _userId;

  void connect(String userId) {
    // If already connected for the same user, skip
    if (_isConnected && _userId == userId) return;
    
    // If connected for a different user, disconnect first
    if (_isConnected) disconnect();
    
    _userId = userId;

    _socket = IO.io(AppConstants.socketUrl, 
      IO.OptionBuilder()
        .setTransports(['websocket', 'polling']) // Allow polling as fallback
        .enableAutoConnect()
        .setAuth({'userId': userId})
        .setExtraHeaders(_authToken != null ? {'Authorization': 'Bearer $_authToken'} : {})
        .build()
    );

    _socket!.onConnect((_) {
      _isConnected = true;
      _messageController.add(SocketMessage(SocketEvent.connectionStatus, {'status': 'connected'}));
      print('Socket connected to ${AppConstants.socketUrl}');
    });

    _socket!.onDisconnect((_) {
      _isConnected = false;
      _messageController.add(SocketMessage(SocketEvent.connectionStatus, {'status': 'disconnected'}));
      print('Socket disconnected');
    });

    _socket!.onConnectError((data) => print('Socket Connect Error: $data'));
    _socket!.onError((data) => print('Socket Error: $data'));

    // Generic notification listener (Plan v4)
    _socket!.on('notification', (data) {
      print('Socket Notification Received: $data');
      _messageController.add(SocketMessage(SocketEvent.newEmergency, data));
    });

    // Map guide events
    _socket!.on('NEW_EMERGENCY', (data) {
      _messageController.add(SocketMessage(SocketEvent.newEmergency, data));
    });

    _socket!.on('RESPONDER_LOCATION_UPDATE', (data) {
      _messageController.add(SocketMessage(SocketEvent.responderLocationUpdate, data));
    });

    _socket!.on('EMERGENCY_STATUS_CHANGE', (data) {
      _messageController.add(SocketMessage(SocketEvent.emergencyStatusChange, data));
    });

    _socket!.on('RESPONDER_ARRIVED', (data) {
      _messageController.add(SocketMessage(SocketEvent.responderArrived, data));
    });
  }

  void joinEmergencyRoom(String emergencyId) {
    if (!_isConnected || _socket == null) return;
    _socket!.emit('join:emergency', emergencyId);
    print('Joined emergency room: $emergencyId');
  }

  void joinLocationRoom(String emergencyId) {
    if (!_isConnected || _socket == null) return;
    _socket!.emit('join:location', emergencyId);
    print('Joined location tracking room: $emergencyId');
  }

  void sendLocationUpdate(double latitude, double longitude) {
    if (!_isConnected || _socket == null) return;
    
    // The guide says POST /api/responders/location for general, 
    // but often sockets are used for frequent updates.
    // If the backend expects a specific event for live tracking, we add it here.
    _socket!.emit('update_location', {
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  void disconnect() {
    _socket?.disconnect();
    _socket = null;
    _isConnected = false;
  }

  void dispose() {
    disconnect();
    _messageController.close();
  }
}
