import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../../core/constants/app_constants.dart';

enum SocketEvent {
  connectionStatus,
  newEmergency,
  responderLocationUpdate,
  emergencyStatusChange,
  responderArrived,
  newMessage,
  notification,
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
      print('✅ Socket connected to ${AppConstants.socketUrl} for user: $userId');
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
      final unpackedData = (data is Map && data.containsKey('data')) ? data['data'] : data;
      print('🔔 Global Socket Notification Received: $unpackedData');
      _messageController.add(SocketMessage(SocketEvent.notification, unpackedData));
    });

    // Map guide events
    _socket!.on('NEW_EMERGENCY', (data) {
      print('🚨 NEW_EMERGENCY event received: $data');
      _messageController.add(SocketMessage(SocketEvent.newEmergency, data));
    });

    _socket!.on('LOCATION_UPDATE', (data) {
      // Unpack nested data if it exists (Backend sends { type: '...', data: { ... } })
      final unpackedData = (data is Map && data.containsKey('data')) ? data['data'] : data;
      _messageController.add(SocketMessage(SocketEvent.responderLocationUpdate, unpackedData));
    });

    _socket!.on('EMERGENCY_STATUS_CHANGE', (data) {
      final unpackedData = (data is Map && data.containsKey('data')) ? data['data'] : data;
      print('🔄 EMERGENCY_STATUS_CHANGE received: $unpackedData');
      _messageController.add(SocketMessage(SocketEvent.emergencyStatusChange, unpackedData));
    });

    _socket!.on('RESPONDER_ARRIVED', (data) {
      final unpackedData = (data is Map && data.containsKey('data')) ? data['data'] : data;
      _messageController.add(SocketMessage(SocketEvent.responderArrived, unpackedData));
    });

    _socket!.on('message:new', (data) {
      final unpackedData = (data is Map && data.containsKey('data')) ? data['data'] : data;
      print('💬 New Chat Message Received: $unpackedData');
      _messageController.add(SocketMessage(SocketEvent.newMessage, unpackedData));
    });

    // Server asks this client to join an emergency room (used for caregivers)
    _socket!.on('JOIN_EMERGENCY_ROOM', (data) {
      final emergencyId = (data is Map ? data['emergencyId'] : null)?.toString();
      if (emergencyId != null && emergencyId.isNotEmpty) {
        joinEmergencyRoom(emergencyId);
        joinLocationRoom(emergencyId);
        print('🏥 Auto-joined emergency room: $emergencyId (server-requested)');
      }
    });

    // Also listen for the RESPONDER_LOCATION_UPDATE event name the backend uses
    _socket!.on('RESPONDER_LOCATION_UPDATE', (data) {
      final unpackedData = (data is Map && data.containsKey('data')) ? data['data'] : data;
      _messageController.add(SocketMessage(SocketEvent.responderLocationUpdate, unpackedData));
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

  void joinChatRoom(String roomId) {
    if (!_isConnected || _socket == null) return;
    _socket!.emit('join:chat', roomId);
    print('Joined chat room: $roomId');
  }

  void leaveChatRoom(String roomId) {
    if (!_isConnected || _socket == null) return;
    _socket!.emit('leave:chat', roomId); // Optional on backend but good practice
    print('Left chat room: $roomId');
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
