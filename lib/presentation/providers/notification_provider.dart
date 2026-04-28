import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_provider.dart';

final notificationsProvider = FutureProvider<List<dynamic>>((ref) async {
  final apiClient = ref.watch(apiClientProvider);
  final user = ref.watch(currentUserProvider).value;
  
  if (user == null) return [];
  
  return await apiClient.getNotificationHistory();
});

final unreadNotificationsCountProvider = Provider<int>((ref) {
  final notifications = ref.watch(notificationsProvider).value ?? [];
  return notifications.where((n) => n != null && n['isRead'] == false).length;
});

final markAllAsReadProvider = FutureProvider<void>((ref) async {
  final apiClient = ref.watch(apiClientProvider);
  await apiClient.markAllNotificationsRead();
  ref.invalidate(notificationsProvider);
});

final markAsReadProvider = FutureProvider.family<void, String>((ref, id) async {
  final apiClient = ref.watch(apiClientProvider);
  await apiClient.markNotificationRead(id);
  ref.invalidate(notificationsProvider);
});
