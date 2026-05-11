import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../core/constants/app_constants.dart';

enum WebSocketEvent {
  connectionStatus,
  locationUpdate,
  statusUpdate,
  etaUpdate,
  unknown
}

class WebSocketMessage {
  final WebSocketEvent event;
  final Map<String, dynamic> data;

  WebSocketMessage(this.event, this.data);

  factory WebSocketMessage.fromJson(Map<String, dynamic> json) {
    final typeStr = json['type'] as String?;
    WebSocketEvent event;
    switch (typeStr) {
      case 'location_update':
        event = WebSocketEvent.locationUpdate;
        break;
      case 'status_update':
        event = WebSocketEvent.statusUpdate;
        break;
      case 'eta_update':
        event = WebSocketEvent.etaUpdate;
        break;
      default:
        event = WebSocketEvent.unknown;
    }
    return WebSocketMessage(event, json['data'] ?? {});
  }
}

class WebSocketService {
  WebSocketChannel? _channel;
  final StreamController<WebSocketMessage> _messageController =
      StreamController<WebSocketMessage>.broadcast();
  bool _isConnected = false;
  String? _currentEmergencyId;
  String? _authToken;

  // Connection attempts for auto-reconnect
  int _reconnectAttempts = 0;
  Timer? _reconnectTimer;
  static const int maxReconnectAttempts = 5;

  WebSocketService._internal();
  static final WebSocketService instance = WebSocketService._internal();

  Stream<WebSocketMessage> get messageStream => _messageController.stream;
  bool get isConnected => _isConnected;

  void setAuthToken(String token) {
    _authToken = token;
  }

  void connect(String emergencyId) {
    if (_isConnected && _currentEmergencyId == emergencyId) return;
    
    _currentEmergencyId = emergencyId;
    _reconnectAttempts = 0;
    _doConnect();
  }

  void _doConnect() {
    try {
      // Use wss if baseUrl is https, else ws
      // Remove /api/ from baseUrl to get the host root, then construct ws path
      final host = AppConstants.baseUrl.replaceAll('/api/', '');
      final wsUrl = host.replaceFirst('http', 'ws');
      final uri = Uri.parse('$wsUrl/api/v1/ws/emergency/$_currentEmergencyId');
      
      // In a real app, pass auth token via headers or connect message
      _channel = WebSocketChannel.connect(uri);
      
      _isConnected = true;
      _messageController.add(
        WebSocketMessage(WebSocketEvent.connectionStatus, {'status': 'connected'})
      );

      _channel?.stream.listen(
        (dynamic message) {
          try {
            final json = jsonDecode(message as String) as Map<String, dynamic>;
            _messageController.add(WebSocketMessage.fromJson(json));
          } catch (e) {
            print('WebSocket message decoding error: $e');
          }
        },
        onDone: () {
          _handleDisconnect();
        },
        onError: (error) {
          print('WebSocket error: $error');
          _handleDisconnect();
        },
      );
    } catch (e) {
      print('WebSocket connection error: $e');
      _handleDisconnect();
    }
  }

  void _handleDisconnect() {
    _isConnected = false;
    _channel = null;
    _messageController.add(
      WebSocketMessage(WebSocketEvent.connectionStatus, {'status': 'disconnected'})
    );

    // Auto-reconnect logic
    if (_currentEmergencyId != null && _reconnectAttempts < maxReconnectAttempts) {
      _reconnectAttempts++;
      final delay = Duration(seconds: _reconnectAttempts * 2);
      print('WebSocket reconnecting in ${delay.inSeconds}s (Attempt $_reconnectAttempts)...');
      _reconnectTimer?.cancel();
      _reconnectTimer = Timer(delay, _doConnect);
    } else if (_reconnectAttempts >= maxReconnectAttempts) {
      print('WebSocket max reconnect attempts reached.');
    }
  }

  void sendLocationUpdate(double latitude, double longitude) {
    if (!_isConnected || _channel == null) return;
    
    final payload = jsonEncode({
      'type': 'location_update',
      'data': {
        'latitude': latitude,
        'longitude': longitude,
        'timestamp': DateTime.now().toIso8601String(),
      }
    });
    
    _channel?.sink.add(payload);
  }

  void disconnect() {
    _reconnectTimer?.cancel();
    _currentEmergencyId = null;
    _isConnected = false;
    _channel?.sink.close();
    _channel = null;
  }
  
  void dispose() {
    disconnect();
    _messageController.close();
  }
}
