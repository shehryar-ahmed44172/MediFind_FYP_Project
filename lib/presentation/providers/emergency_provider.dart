import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../data/repositories/emergency_repository_impl.dart';
import '../../domain/repositories/emergency_repository.dart';
import '../../services/notification/push_notification_service.dart';
import 'auth_provider.dart';
import 'accessibility_provider.dart';
import '../../services/socket/socket_service.dart';
import '../../services/audio/voice_alert_service.dart';
import '../../presentation/services/haptic_feedback_service.dart';
import '../../services/location/location_service.dart';
import '../../domain/entities/emergency.dart';
import '../../domain/entities/responder_alert.dart';
import '../../core/utils/emergency_status.dart';
import '../../data/datasources/remote/medifind_api_client.dart' show CreateEmergencyResult;

// Provider to track if a visual emergency alert should be shown (for accessibility)
final visualEmergencyAlertProvider = StateProvider<String?>((ref) => null);

// Simulation Mode Provider (Plan v6)
final simulationModeProvider = StateProvider<bool>((ref) => false);
// Emergency Repository Provider
final emergencyRepositoryProvider = FutureProvider<EmergencyRepository>((ref) async {
  // CRITICAL: Wait for auth initialization so the API Client has its token set
  await ref.watch(authRepositoryProvider.future);
  final apiClient = ref.watch(apiClientProvider);
  final localDataSource = await ref.watch(localDataSourceProvider.future);
  return EmergencyRepositoryImpl(
    apiClient: apiClient,
    localDataSource: localDataSource,
  );
});

// Create emergency provider
// autoDispose: every SOS must hit the API (params objects are never reused).
final createEmergencyProvider = FutureProvider.autoDispose.family<CreateEmergencyResult, CreateEmergencyParams>((ref, params) async {
  final emergencyRepo = await ref.watch(emergencyRepositoryProvider.future);
  return await emergencyRepo.createEmergency(
    params.emergencyType,
    params.latitude,
    params.longitude,
    params.additionalInfo,
  );
});

// Get emergency provider
final getEmergencyProvider = FutureProvider.family<Emergency, String>((ref, emergencyId) async {
  final emergencyRepo = await ref.watch(emergencyRepositoryProvider.future);
  return await emergencyRepo.getEmergency(emergencyId);
});

// Get user emergencies provider
final getUserEmergenciesProvider = FutureProvider.family<List<Emergency>, String>((ref, userId) async {
  final emergencyRepo = await ref.watch(emergencyRepositoryProvider.future);
  return await emergencyRepo.getUserEmergencies(userId);
});

// Watch emergency provider
final watchEmergencyProvider = StreamProvider.family<Emergency, String>((ref, emergencyId) async* {
  final emergencyRepo = await ref.watch(emergencyRepositoryProvider.future);
  yield* emergencyRepo.watchEmergency(emergencyId);
});

// Watch user emergencies provider
final watchUserEmergenciesProvider = StreamProvider.family<List<Emergency>, String>((ref, userId) async* {
  final emergencyRepo = await ref.watch(emergencyRepositoryProvider.future);
  yield* emergencyRepo.watchUserEmergencies(userId);
});

// Get active emergencies provider
final getActiveEmergenciesProvider = FutureProvider<List<Emergency>>((ref) async {
  final repo = await ref.watch(emergencyRepositoryProvider.future);
  final user = ref.read(currentUserProvider).valueOrNull;

  if (user?.role == 'RESPONDER') {
    return await repo.getResponderActiveRequests();
  }

  return await repo.getActiveEmergencies();
});

// Watch active emergencies provider
final watchActiveEmergenciesProvider = StreamProvider<List<Emergency>>((ref) async* {
  final repo = await ref.watch(emergencyRepositoryProvider.future);
  yield* repo.watchActiveEmergencies();
});

// Update emergency status provider (assigned responder progress updates)
final updateEmergencyStatusProvider = FutureProvider.autoDispose.family<void, UpdateEmergencyStatusParams>((ref, params) async {
  final emergencyRepo = await ref.read(emergencyRepositoryProvider.future);
  await emergencyRepo.updateEmergencyStatus(
    params.emergencyId,
    params.status,
    latitude: params.latitude,
    longitude: params.longitude,
  );
  ref.invalidate(getEmergencyProvider(params.emergencyId));
  ref.invalidate(getActiveEmergenciesProvider);
});

// Accept emergency provider (responder side).
// NOTE: no patient-facing voice/visual alert here — this runs on the
// RESPONDER's phone. Patients are notified via socket/push by the server.
final acceptEmergencyProvider = FutureProvider.autoDispose.family<void, AcceptRejectParams>((ref, params) async {
  final emergencyRepo = await ref.read(emergencyRepositoryProvider.future);
  await emergencyRepo.acceptEmergency(params.emergencyId, params.responderId);
  ref.invalidate(getEmergencyProvider(params.emergencyId));
  ref.invalidate(watchActiveEmergenciesProvider);
  ref.invalidate(responderAlertsProvider);
});

// Reject emergency provider
final rejectEmergencyProvider = FutureProvider.autoDispose.family<void, AcceptRejectParams>((ref, params) async {
  final emergencyRepo = await ref.read(emergencyRepositoryProvider.future);
  await emergencyRepo.rejectEmergency(params.emergencyId, params.responderId);
  ref.invalidate(watchActiveEmergenciesProvider);
  ref.invalidate(responderAlertsProvider);
});

/// Live list of this responder's open requests, fetched from
/// `GET responders/emergencies` (source of truth) and synced into the cache.
/// Invalidate to refresh (polling, pull-to-refresh, socket events).
final responderAlertsProvider = FutureProvider.autoDispose<List<ResponderAlert>>((ref) async {
  final repo = await ref.read(emergencyRepositoryProvider.future);
  final responderId = await ref.read(currentUserIdProvider.future);
  return repo.syncResponderAlerts(responderId);
});

// Set responder availability provider
final setResponderAvailabilityProvider = FutureProvider.family<void, bool>((ref, isAvailable) async {
  final repo = await ref.watch(emergencyRepositoryProvider.future);

  if (isAvailable) {
    try {
      // CRITICAL FIX: The backend uses PostGIS `ST_DWithin`. If the responder
      // has no location set, they will NEVER receive emergency notifications.
      final position = await LocationService().getCurrentLocation();
      await repo.updateResponderLocation(position.latitude, position.longitude);
      debugPrint('📍 Pushed Responder Location to Backend: ${position.latitude}, ${position.longitude}');
    } catch (e) {
      debugPrint('❌ Failed to push responder location: $e');
      // If we completely fail to get location, we might want to alert the UI,
      // but we still attempt to set availability as a fallback.
    }
  }

  await repo.updateResponderAvailability(isAvailable);
  ref.invalidate(currentUserProvider);
});

// Provider to push a fake location for testing (Plan v7)
final pushFakeLocationProvider = FutureProvider.family<void, double>((ref, offset) async {
  final repo = await ref.read(emergencyRepositoryProvider.future);
  final position = await LocationService().getCurrentLocation();
  // Add a slight offset (approx 0.05 is ~5km)
  await repo.updateResponderLocation(position.latitude + offset, position.longitude + offset);
  debugPrint('🧪 Pushed Fake Location (Offset $offset): ${position.latitude + offset}');
});

// Provider to update responder location (NEW)
final updateResponderLocationProvider = FutureProvider.family<void, Position>((ref, position) async {
  final repo = await ref.watch(emergencyRepositoryProvider.future);
  await repo.updateResponderLocation(position.latitude, position.longitude);
});

// Cancel emergency provider
final cancelEmergencyProvider = FutureProvider.autoDispose.family<void, String>((ref, emergencyId) async {
  final repo = await ref.read(emergencyRepositoryProvider.future);
  await repo.cancelEmergency(emergencyId);
  ref.invalidate(getEmergencyProvider(emergencyId));
  ref.invalidate(watchActiveEmergenciesProvider);
});

// Resolve emergency provider
final resolveEmergencyProvider = FutureProvider.autoDispose.family<void, String>((ref, emergencyId) async {
  final repo = await ref.read(emergencyRepositoryProvider.future);
  await repo.resolveEmergency(emergencyId);
  ref.invalidate(getEmergencyProvider(emergencyId));
  ref.invalidate(getActiveEmergenciesProvider);
});

// Cancel responder assignment provider
final cancelResponderAssignmentProvider = FutureProvider.family<void, String>((ref, emergencyId) async {
  final repo = await ref.watch(emergencyRepositoryProvider.future);
  await repo.cancelAssignment(emergencyId);
  ref.invalidate(getEmergencyProvider(emergencyId));
  ref.invalidate(watchActiveEmergenciesProvider);
});

// Get responder history provider
final getResponderHistoryProvider = FutureProvider<List<dynamic>>((ref) async {
  final repo = await ref.watch(emergencyRepositoryProvider.future);
  return await repo.getResponderHistory();
});

// Rate responder provider
final rateResponderProvider = FutureProvider.family<Map<String, dynamic>, RateResponderParams>((ref, params) async {
  final apiClient = ref.watch(apiClientProvider);
  return await apiClient.rateResponder(params.responderId, params.emergencyId, params.stars);
});

class RateResponderParams {
  final String responderId;
  final String emergencyId;
  final int stars;

  const RateResponderParams({
    required this.responderId,
    required this.emergencyId,
    required this.stars,
  });
}

// Parameters
class CreateEmergencyParams {
  final String emergencyType;
  final double latitude;
  final double longitude;
  final String? additionalInfo;

  CreateEmergencyParams({
    required this.emergencyType,
    required this.latitude,
    required this.longitude,
    this.additionalInfo,
  });
}

class UpdateEmergencyStatusParams {
  final String emergencyId;
  final String status;
  final double? latitude;
  final double? longitude;

  UpdateEmergencyStatusParams({
    required this.emergencyId,
    required this.status,
    this.latitude,
    this.longitude,
  });
}

class AcceptRejectParams {
  final String emergencyId;
  final String responderId;

  AcceptRejectParams({
    required this.emergencyId,
    required this.responderId,
  });
}

// Provider to handle incoming socket messages and persist them (Plan v5)
final socketNotificationHandlerProvider = Provider<void>((ref) {
  ref.listen<AsyncValue<SocketMessage>>(socketStreamProvider, (previous, next) {
    next.whenData((message) async {
      final data = message.data;
      if (data is! Map<String, dynamic>) return;

      final user = ref.read(currentUserProvider).valueOrNull;
      if (user == null) return;

      // For `notification` events the server sends the full envelope:
      //   { type, title, body, data: { emergencyId, patientId, ... }, timestamp }
      // For other events (newEmergency, emergencyStatusChange) the socket service
      // already unpacks to the inner data object.
      // Extract type and inner payload accordingly.
      final String? eventType;
      final Map<String, dynamic> payload;
      if (message.event == SocketEvent.notification) {
        eventType = data['type']?.toString();
        payload = (data['data'] is Map<String, dynamic>)
            ? Map<String, dynamic>.from(data['data'] as Map)
            : data;
      } else {
        eventType = data['type']?.toString();
        payload = data;
      }

      // --- SELF-FILTER: Never alert a user about their own SOS ---
      final targetPatientId = (payload['patientId'] ?? payload['userId'] ?? payload['id'])?.toString();
      final currentUserId = user.id.toString();

      if (targetPatientId != null && targetPatientId == currentUserId) {
        debugPrint('🛡️ [Filter] Self-SOS Detected ($targetPatientId). Blocking alert for Patient.');
        return;
      }

      debugPrint('📩 [Socket] Event: ${message.event}, Type: $eventType, Target: $targetPatientId, Me: $currentUserId');

      // --- 1. Handle NEW_EMERGENCY (Responder Only) ---
      if (message.event == SocketEvent.newEmergency) {
        if (user.role == 'RESPONDER') {
          final repo = await ref.read(emergencyRepositoryProvider.future);
          final emergencyId = payload['id'] ?? payload['emergencyId'];
          if (emergencyId != null) {
            try {
              await repo.getEmergency(emergencyId.toString());
              ref.invalidate(getActiveEmergenciesProvider);
              ref.invalidate(responderAlertsProvider);
              PushNotificationService.showEmergencyAlert(payload);
            } catch (e) {
              debugPrint('Socket: could not pre-fetch emergency $emergencyId: $e');
              PushNotificationService.showEmergencyAlert(payload);
            }
          }
        }
      }

      // --- 2. Handle Generic NOTIFICATION (Responders & Caregivers) ---
      else if (message.event == SocketEvent.notification) {
        debugPrint('🔔 Notification Type: $eventType for Role: ${user.role}');

        // PRIVACY FIX: SYSTEM_ALERT from admin
        if (eventType == 'SYSTEM_ALERT') {
          final recipientId = (payload['recipientId'] ?? data['recipientId'])?.toString();
          if (recipientId != null && recipientId.isNotEmpty && recipientId != user.id) {
            debugPrint('🛡️ [Privacy] SYSTEM_ALERT for $recipientId blocked — current user is ${user.id}');
            return;
          }
          debugPrint('📣 [Admin] SYSTEM_ALERT received for current user: ${data['title']}');
          return;
        }

        // PRIVACY FIX: Responders should NEVER receive chat notifications
        if (eventType == 'CHAT_MESSAGE' && user.role == 'RESPONDER') {
          debugPrint('🛡️ [Privacy] Blocked chat notification for Responder');
          return;
        }

        // --- RESPONDER LOGIC: SOS Triggered ---
        if ((eventType == 'SOS_TRIGGERED' || eventType == 'EMERGENCY_REQUEST') && user.role == 'RESPONDER') {
          final repo = await ref.read(emergencyRepositoryProvider.future);
          final emergencyId = payload['id'] ?? payload['emergencyId'];
          if (emergencyId != null) {
            try {
              await repo.getEmergency(emergencyId.toString());
              ref.invalidate(getActiveEmergenciesProvider);
              ref.invalidate(responderAlertsProvider);
              PushNotificationService.showEmergencyAlert(payload);
            } catch (e) {
              debugPrint('Socket: could not pre-fetch emergency $emergencyId: $e');
              // Still alert the responder — caching must never block the alert.
              PushNotificationService.showEmergencyAlert(payload);
            }
          }
        }

        // --- RESPONDER LOGIC: Emergency Cancelled/Resolved by others ---
        else if ((eventType == 'EMERGENCY_RESOLVED' || eventType == 'EMERGENCY_CANCELLED' || eventType == 'EMERGENCY_ACCEPTED_BY_OTHER') && user.role == 'RESPONDER') {
          debugPrint('🧹 SOS Request no longer active: $eventType');

          final emergencyId = payload['emergencyId'] ?? payload['id'];
          if (emergencyId != null) {
            try {
              final localDs = await ref.read(localDataSourceProvider.future);
              final cached = await localDs.getEmergency(emergencyId.toString());
              if (cached != null) {
                cached['status'] = eventType == 'EMERGENCY_CANCELLED' ? 'CANCELLED' : 'RESOLVED';
                await localDs.saveEmergency(cached);
                debugPrint('📦 Local cache updated: $emergencyId → ${cached['status']}');
              }
            } catch (e) {
              debugPrint('⚠️ Could not update local cache for cancelled emergency: $e');
            }
          }

          PushNotificationService.dismissCurrentEmergencyModal();
          ref.invalidate(getActiveEmergenciesProvider);
          ref.invalidate(watchActiveEmergenciesProvider);
          ref.invalidate(responderAlertsProvider);
        }

        // --- CAREGIVER LOGIC: Patient SOS ---
        // Only the initial SOS notification (not later "Emergency Update"
        // notifications, which carry a status) opens the caregiver dialog.
        else if (eventType == 'PATIENT_EMERGENCY' && user.role == 'CAREGIVER' && payload['status'] == null) {
          debugPrint('🚨 Caregiver SOS Notification Received!');
          PushNotificationService.showEmergencyAlert({
            ...payload,
            'isCaregiverAlert': true,
          });
          ref.invalidate(getActiveEmergenciesProvider);
        }
      }

      // --- 3. Handle EMERGENCY_STATUS_CHANGE (Patient & Responder) ---
      else if (message.event == SocketEvent.emergencyStatusChange) {
        final rawData = message.data;
        final data = (rawData is Map && rawData.containsKey('data')) ? rawData['data'] : rawData;
        if (data is! Map<String, dynamic>) return;

        final emergencyId = data['emergencyId']?.toString();
        final newStatus = (data['status'] ?? data['newStatus'] ?? '').toString().toUpperCase();

        debugPrint('🔄 Status Change for $emergencyId: $newStatus');

        if (emergencyId != null) {
          final repo = await ref.read(emergencyRepositoryProvider.future);

          // Force refresh the emergency in cache
          try {
            await repo.getEmergency(emergencyId);
            ref.invalidate(getEmergencyProvider(emergencyId));
            ref.invalidate(getActiveEmergenciesProvider);

            // If status is terminal (cancelled/resolved), also invalidate stream
            // so responder home screen removes it immediately
            if (EmergencyStatus.isTerminal(newStatus) || EmergencyStatus.isAssigned(newStatus)) {
              ref.invalidate(watchActiveEmergenciesProvider);
              if (user.role == 'RESPONDER') ref.invalidate(responderAlertsProvider);
            }
            if (EmergencyStatus.isTerminal(newStatus)) {
              SocketService.instance.forgetEmergencyRooms(emergencyId);
            }

            // --- ACCESSIBILITY LOGIC: DEAF Patient Feedback ---
            final ownerId = data['patientId']?.toString();
            final isOwnEmergency = ownerId == null || ownerId == user.id;
            if (!isOwnEmergency) {
              // Status change for someone else's emergency — no patient alert.
            } else if (user.role == 'PATIENT' && user.patientType?.toUpperCase() == 'DEAF') {
              if (newStatus == 'ASSIGNED' || newStatus == 'RESPONDER_ASSIGNED') {
                if (ref.read(accessibilityProvider).vibrationFeedback) HapticFeedbackService.sosPattern();
                ref.read(visualEmergencyAlertProvider.notifier).state =
                    "HELP IS ON THE WAY: ${data['responderName'] ?? 'A responder'} has accepted your request.";
              } else if (newStatus == 'ARRIVED') {
                if (ref.read(accessibilityProvider).vibrationFeedback) HapticFeedbackService.heavy();
                ref.read(visualEmergencyAlertProvider.notifier).state =
                    "RESPONDER ARRIVED: Look around for ${data['responderName'] ?? 'help'}.";
              } else if (newStatus == 'ACTIVE' && data['message'] != null) {
                if (ref.read(accessibilityProvider).vibrationFeedback) HapticFeedbackService.heavy();
                ref.read(visualEmergencyAlertProvider.notifier).state =
                    'FINDING ANOTHER RESPONDER: ${data['message']}';
              }
            } else if (user.role == 'PATIENT') {
              // Voice feedback for normal patients
              if (newStatus == 'ASSIGNED' || newStatus == 'RESPONDER_ASSIGNED') {
                VoiceAlertService().speakMessage("Help is on the way. ${data['responderName'] ?? 'A responder'} has accepted your request.");
              }
            }
          } catch (e) {
            debugPrint('❌ Error updating emergency status: $e');
          }
        }
      }
    });
  });
});

// Socket Stream Provider for Real-Time Updates (Socket.io)
// Not autoDispose: keeps the socket alive in background for SOS alerts.
final socketStreamProvider = StreamProvider<SocketMessage>((ref) {
  final socketService = SocketService.instance;

  // Ensure connected with auth token
  ref.watch(currentUserProvider).whenData((user) {
    if (user != null) {
      ref.watch(authRepositoryProvider).whenData((repo) async {
        final token = await repo.getAuthToken();
        if (token != null) {
          socketService.setAuthToken(token);
          socketService.connect(user.id);
          // Server auto-joins responders to their broadcast room from the
          // token; the explicit join is kept for older servers.
          if (user.role == 'RESPONDER') {
            socketService.joinRespondersRoom();
          }
        }
      });
    }
  });

  // IMPORTANT: do NOT disconnect the shared singleton here. Rebuilds of this
  // provider (e.g. when the user profile refreshes) would otherwise drop the
  // connection and every joined room. Logout disconnects explicitly.

  return socketService.messageStream;
});

// Stream provider for tracking a specific responder's location (NEW)
final responderLocationProvider = StreamProvider.family<Map<String, dynamic>, String>((ref, emergencyId) {
  final socketService = SocketService.instance;

  // CRITICAL: Join the location room for this specific emergency
  socketService.joinLocationRoom(emergencyId);

  return socketService.messageStream
      .where((msg) => msg.event == SocketEvent.responderLocationUpdate)
      .where((msg) => msg.data is Map)
      .map((msg) => Map<String, dynamic>.from(msg.data as Map))
      .where((data) => data['emergencyId']?.toString() == emergencyId);
});
