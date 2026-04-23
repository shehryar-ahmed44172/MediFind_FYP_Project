import 'package:flutter_riverpod/flutter_riverpod.dart';

/// StateProvider to track the current active tab index of the Responder dashboard.
/// Indices:
/// 0: Dashboard (Incoming Requests)
/// 1: History (Response History)
/// 2: Settings (App Settings)
/// 3: Profile (Public Profile View)
final responderNavIndexProvider = StateProvider<int>((ref) => 0);

/// StateProvider to track the current active tab index of the Caregiver dashboard.
/// Indices:
/// 0: Dashboard (Linked Patients Overview)
/// 1: My Patients (Detailed List)
/// 2: Maps (Live Patient Tracking)
/// 3: History (Incident History)
/// 4: Settings (App Settings)
/// 5: Profile (User Profile)
final caregiverNavIndexProvider = StateProvider<int>((ref) => 0);
