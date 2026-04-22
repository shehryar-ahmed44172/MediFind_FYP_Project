import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/emergency_repository_impl.dart';
import '../../domain/repositories/emergency_repository.dart';
import '../../services/notification/push_notification_service.dart';
import 'auth_provider.dart';
import '../../services/socket/socket_service.dart';
import '../../services/audio/voice_alert_service.dart';
import '../../presentation/services/haptic_feedback_service.dart';
import '../../services/location/location_service.dart';
import '../../domain/entities/emergency.dart';

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
final createEmergencyProvider = FutureProvider.family<Emergency, CreateEmergencyParams>((ref, params) async {
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
  return await repo.getActiveEmergencies();
});

// Watch active emergencies provider
final watchActiveEmergenciesProvider = StreamProvider<List<Emergency>>((ref) async* {
  final repo = await ref.watch(emergencyRepositoryProvider.future);
  yield* repo.watchActiveEmergencies();
});

// Update emergency status provider
final updateEmergencyStatusProvider = FutureProvider.family<void, UpdateEmergencyStatusParams>((ref, params) async {
  final emergencyRepo = await ref.watch(emergencyRepositoryProvider.future);
  await emergencyRepo.updateEmergencyStatus(params.emergencyId, params.status);
  ref.invalidate(getEmergencyProvider(params.emergencyId));
  ref.invalidate(getActiveEmergenciesProvider);
});

// Accept emergency provider
final acceptEmergencyProvider = FutureProvider.family<void, AcceptRejectParams>((ref, params) async {
  final emergencyRepo = await ref.watch(emergencyRepositoryProvider.future);
  await emergencyRepo.acceptEmergency(params.emergencyId, params.responderId);
  ref.refresh(getEmergencyProvider(params.emergencyId));
  ref.invalidate(watchActiveEmergenciesProvider);
  
  // Handle Accessibility-Aware Notifications
  final user = ref.read(currentUserProvider).valueOrNull;
  if (user?.patientType == 'DEAF') {
    // For Deaf users: Haptic + Visual Alert
    HapticFeedbackService.sosPattern();
    ref.read(visualEmergencyAlertProvider.notifier).state = "Responder is on the way. Stay calm.";
  } else {
    // For others: Voice Alert
    VoiceAlertService().speakMessage("Responder is on the way. Stay calm.");
  }
});

// Reject emergency provider
final rejectEmergencyProvider = FutureProvider.family<void, AcceptRejectParams>((ref, params) async {
  final emergencyRepo = await ref.watch(emergencyRepositoryProvider.future);
  await emergencyRepo.rejectEmergency(params.emergencyId, params.responderId);
  ref.invalidate(watchActiveEmergenciesProvider);
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

// Cancel emergency provider
final cancelEmergencyProvider = FutureProvider.family<void, String>((ref, emergencyId) async {
  final repo = await ref.watch(emergencyRepositoryProvider.future);
  await repo.cancelEmergency(emergencyId);
  ref.invalidate(getEmergencyProvider(emergencyId));
  ref.invalidate(watchActiveEmergenciesProvider);
});

// Resolve emergency provider
final resolveEmergencyProvider = FutureProvider.family<void, String>((ref, emergencyId) async {
  final repo = await ref.watch(emergencyRepositoryProvider.future);
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

  UpdateEmergencyStatusParams({
    required this.emergencyId,
    required this.status,
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
      if (message.event == SocketEvent.newEmergency) {
        final data = message.data;
        if (data is Map<String, dynamic>) {
          final repo = await ref.read(emergencyRepositoryProvider.future);
          // Cast the dynamic map to the format expected by saveEmergency (via repo.getEmergency update)
          // In this architecture, it's safer to use the repo to handle the persistence logic.
          // Since getEmergency(id) fetches from remote and saves to local, we can trigger it.
          // Or we can save directly if data is complete.
          
          final emergencyId = data['id'] ?? data['emergencyId'];
          if (emergencyId != null) {
            try {
              // Plan v5: Unified visual alert + persistence
              await repo.getEmergency(emergencyId.toString());
              ref.invalidate(getActiveEmergenciesProvider);
              
              // Trigger the visual modal immediately from the socket
              PushNotificationService.showEmergencyAlert(data);
              
              debugPrint('✅ Socket Notification: Persisted and Alerted $emergencyId');
            } catch (e) {
              debugPrint('❌ Failed to handle socket notification: $e');
            }
          }
        }
      }
    });
  });
});

// Socket Stream Provider for Real-Time Updates (Socket.io)
// Removing autoDispose to keep socket alive in background for SOS alerts
final socketStreamProvider = StreamProvider<SocketMessage>((ref) {
  final socketService = SocketService.instance;
  
  // Ensure connected with auth token
  ref.watch(currentUserProvider).whenData((user) {
    if (user != null) {
      // Get token from auth provider
      ref.watch(authRepositoryProvider).whenData((repo) async {
        final token = await repo.getAuthToken();
        if (token != null) {
          socketService.setAuthToken(token);
          // Plan v4: Pass userId to initiate the server-side room joining
          socketService.connect(user.id);
        }
      });
    }
  });

  ref.onDispose(() {
    socketService.disconnect();
  });
  
  return socketService.messageStream;
});
