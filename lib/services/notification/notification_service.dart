import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../core/utils/exceptions.dart';

/// Custom Push Notification Service (Firebase-replacement)
/// Uses WebSocket connection for real-time push notifications
/// See FIREBASE_REPLACEMENT_ROADMAP.md for implementation details
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  // WebSocket connection for push notifications
  WebSocketChannel? _webSocketChannel;
  StreamSubscription? _messageSubscription;
  
  // Notification callbacks
  Function(Map<String, dynamic>)? _onMessageReceived;
  Function(Map<String, dynamic>)? _onNotificationTapped;
  
  // Device token for push notifications
  String? _deviceToken;
  
  static const platform = MethodChannel('com.medifind.app/notifications');

  /// Initialize the notification service with WebSocket connection
  Future<void> initializeNotifications() async {
    try {
      // Generate or retrieve device token
      _deviceToken = await _generateDeviceToken();
      
      // Request notification permissions
      await _requestNotificationPermissions();
      
      // Connect to custom WebSocket server for push notifications
      await _connectWebSocket();
      
    } catch (e) {
      throw AppException(
        message: 'Failed to initialize notifications',
        originalException: e,
      );
    }
  }

  /// Generate unique device token for this device
  Future<String> _generateDeviceToken() async {
    try {
      // Try to get from native channel if available
      try {
        final String token = await platform.invokeMethod('getDeviceToken');
        return token;
      } catch (e) {
        // Fallback: generate from device info
        return '${Platform.operatingSystem}_${DateTime.now().millisecondsSinceEpoch}_${Platform.localHostname}';
      }
    } catch (e) {
      throw AppException(
        message: 'Failed to generate device token',
        originalException: e,
      );
    }
  }

  /// Request notification permissions from user
  Future<void> _requestNotificationPermissions() async {
    try {
      if (Platform.isAndroid) {
        // Request notification permission for Android 13+
        try {
          await platform.invokeMethod('requestNotificationPermission');
        } catch (e) {
          // Permission request not available on this API level
        }
      } else if (Platform.isIOS) {
        // Request notification permission for iOS
        try {
          await platform.invokeMethod('requestNotificationPermission');
        } catch (e) {
          // Permission denied or already handled
        }
      }
    } catch (e) {
      // Continue even if permission request fails
      print('Warning: Could not request notification permissions: $e');
    }
  }

  /// Connect to custom WebSocket server for push notifications
  Future<void> _connectWebSocket() async {
    try {
      // Connect to custom backend WebSocket endpoint
      // Format: wss://api.medifind.com/ws/notifications/{userId}/{deviceToken}
      final String wsUrl = 'wss://api.medifind.com/ws/notifications?token=$_deviceToken';
      
      _webSocketChannel = WebSocketChannel.connect(
        Uri.parse(wsUrl),
      );

      // Listen to incoming messages
      _messageSubscription = _webSocketChannel!.stream.listen(
        (message) {
          _handleIncomingMessage(message);
        },
        onError: (error) {
          print('WebSocket error: $error');
          // Attempt to reconnect after delay
          _reconnectWebSocket();
        },
        onDone: () {
          print('WebSocket connection closed');
          // Attempt to reconnect
          _reconnectWebSocket();
        },
      );
    } catch (e) {
      throw AppException(
        message: 'Failed to connect WebSocket for notifications',
        originalException: e,
      );
    }
  }

  /// Reconnect WebSocket with exponential backoff
  Future<void> _reconnectWebSocket({int delaySeconds = 5}) async {
    try {
      await Future.delayed(Duration(seconds: delaySeconds));
      await _connectWebSocket();
    } catch (e) {
      print('Failed to reconnect WebSocket: $e');
      // Schedule another reconnect attempt
      _reconnectWebSocket(delaySeconds: delaySeconds * 2);
    }
  }

  /// Handle incoming notification message
  void _handleIncomingMessage(dynamic message) {
    try {
      // Parse message
      final Map<String, dynamic> notificationData = _parseMessage(message);
      
      // Call callback
      _onMessageReceived?.call(notificationData);
      
      // Show local notification if app is in foreground
      if (notificationData['showLocal'] == true) {
        _showLocalNotification(notificationData);
      }
    } catch (e) {
      print('Error handling incoming message: $e');
    }
  }

  /// Parse incoming WebSocket message
  Map<String, dynamic> _parseMessage(dynamic message) {
    try {
      if (message is String) {
        // Assume JSON format
        // In real implementation, use json.decode()
        return {
          'title': 'Emergency Notification',
          'body': message,
          'timestamp': DateTime.now().toIso8601String(),
          'showLocal': true,
        };
      }
      return {};
    } catch (e) {
      return {};
    }
  }

  /// Show local notification
  Future<void> _showLocalNotification(Map<String, dynamic> data) async {
    try {
      await platform.invokeMethod('showNotification', {
        'id': data['id'] ?? 1,
        'title': data['title'] ?? 'MediFind',
        'body': data['body'] ?? '',
        'payload': data.toString(),
      });
    } catch (e) {
      print('Failed to show notification: $e');
    }
  }

  /// Get device token
  Future<String?> getDeviceToken() async {
    return _deviceToken;
  }

  /// Subscribe to notification topic
  Future<void> subscribeToTopic(String topic) async {
    try {
      // Send subscription request through WebSocket
      if (_webSocketChannel != null) {
        _webSocketChannel!.sink.add({
          'action': 'subscribe',
          'topic': topic,
        }.toString());
      } else {
        throw Exception('WebSocket not connected');
      }
    } catch (e) {
      throw AppException(
        message: 'Failed to subscribe to topic: $topic',
        originalException: e,
      );
    }
  }

  /// Unsubscribe from notification topic
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      // Send unsubscribe request through WebSocket
      if (_webSocketChannel != null) {
        _webSocketChannel!.sink.add({
          'action': 'unsubscribe',
          'topic': topic,
        }.toString());
      } else {
        throw Exception('WebSocket not connected');
      }
    } catch (e) {
      throw AppException(
        message: 'Failed to unsubscribe from topic: $topic',
        originalException: e,
      );
    }
  }

  /// Set callback for received messages
  void setOnMessageCallback(Function(Map<String, dynamic>) callback) {
    _onMessageReceived = callback;
  }

  /// Set callback for notification tap
  void setOnNotificationTappedCallback(Function(Map<String, dynamic>) callback) {
    _onNotificationTapped = callback;
  }

  /// Send acknowledgment for received notification
  Future<void> acknowledgeNotification(String notificationId) async {
    try {
      if (_webSocketChannel != null) {
        _webSocketChannel!.sink.add({
          'action': 'ack',
          'notificationId': notificationId,
        }.toString());
      }
    } catch (e) {
      print('Failed to acknowledge notification: $e');
    }
  }

  /// Close notification service
  Future<void> dispose() async {
    try {
      await _messageSubscription?.cancel();
      await _webSocketChannel?.sink.close();
    } catch (e) {
      print('Error closing notification service: $e');
    }
  }
}
