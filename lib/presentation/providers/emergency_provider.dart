import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/emergency_repository_impl.dart';
import '../../domain/entities/emergency.dart';
import '../../domain/repositories/emergency_repository.dart';
import 'auth_provider.dart';
import '../../services/socket/socket_service.dart';
import '../../services/audio/voice_alert_service.dart';
// Emergency Repository Provider
final emergencyRepositoryProvider = FutureProvider<EmergencyRepository>((ref) async {
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
  
  // Voice Alert Notification
  VoiceAlertService().speakMessage("Responder is on the way. Stay calm.");
});

// Reject emergency provider
final rejectEmergencyProvider = FutureProvider.family<void, AcceptRejectParams>((ref, params) async {
  final emergencyRepo = await ref.watch(emergencyRepositoryProvider.future);
  await emergencyRepo.rejectEmergency(params.emergencyId, params.responderId);
});

// Set responder availability provider
final setResponderAvailabilityProvider = FutureProvider.family<void, bool>((ref, isAvailable) async {
  final repo = await ref.watch(emergencyRepositoryProvider.future);
  await repo.updateResponderAvailability(isAvailable);
  ref.invalidate(currentUserProvider);
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

// Socket Stream Provider for Real-Time Updates (Socket.io)
final socketStreamProvider = StreamProvider.autoDispose<SocketMessage>((ref) {
  final socketService = SocketService.instance;
  
  // Ensure connected with auth token
  ref.watch(currentUserProvider).whenData((user) {
    if (user != null) {
      // Get token from auth provider
      ref.watch(authRepositoryProvider).whenData((repo) async {
        final token = await repo.getAuthToken();
        if (token != null) {
          socketService.setAuthToken(token);
          socketService.connect();
        }
      });
    }
  });

  ref.onDispose(() {
    socketService.disconnect();
  });
  
  return socketService.messageStream;
});
