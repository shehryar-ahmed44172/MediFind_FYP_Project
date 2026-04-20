import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/emergency_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../../domain/entities/emergency.dart';

import '../home/widgets/connectivity_banner.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common/app_header.dart';

class ResponderHomeScreen extends ConsumerStatefulWidget {
  const ResponderHomeScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ResponderHomeScreen> createState() => _ResponderHomeScreenState();
}

class _ResponderHomeScreenState extends ConsumerState<ResponderHomeScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    // Plan v5: Fetch fresh data from server on dashboard load
    // This ensures we show pending requests even if the socket was offline
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(getActiveEmergenciesProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isConnected = ref.watch(isConnectedProvider);
    final userAsync = ref.watch(currentUserProvider);
    final emergenciesAsync = ref.watch(watchActiveEmergenciesProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Column(
        children: [
          const AppHeader(
            showLogout: true,
            showProfile: false, // Profile moved to bottom menu
            greetingOverride: 'Responder Dashboard',
          ),
          if (!isConnected) const ConnectivityBanner(),

          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: [
                _buildIncomingRequests(theme, userAsync, emergenciesAsync),
                _buildHistoryPlaceholder(theme),
                _buildSettingsPlaceholder(theme),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(theme),
    );
  }

  Widget _buildIncomingRequests(ThemeData theme, AsyncValue userAsync, AsyncValue emergenciesAsync) {
    return Column(
      children: [
        // Status Toggle
        Padding(
          padding: const EdgeInsets.all(16),
          child: userAsync.when(
            data: (user) => Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: AppShadows.neumorphicOut,
              ),
              child: Row(
                children: [
                  Icon(Icons.circle, 
                      color: (user?.isActive ?? false) ? Colors.green : Colors.grey, 
                      size: 14),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Status: ${(user?.isActive ?? false) ? 'Available' : 'Offline'}',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: (user?.isActive ?? false) ? Colors.green : Colors.grey)),
                        Text((user?.isActive ?? false) 
                            ? 'You are visible to patients' 
                            : 'You are invisible to patients',
                            style:
                                const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                  Switch(
                    value: user?.isActive ?? false,
                    onChanged: (value) async {
                      if (user != null) {
                        await ref.read(setResponderAvailabilityProvider(value).future);
                      }
                    },
                    activeColor: Colors.green,
                  ),
                ],
              ),
            ),
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => const Text('Failed to load status'),
          ),
        ),

        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: emergenciesAsync.when(
            data: (emergencies) => Row(
              children: [
                Text('Incoming Emergencies',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const Spacer(),
                if (emergencies.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(12)),
                    child: Text(
                      '${emergencies.length}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12),
                    ),
                  ),
              ],
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ),
        const SizedBox(height: 8),

        Expanded(
          child: emergenciesAsync.when(
            data: (emergencies) => emergencies.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_outline_rounded,
                            size: 72, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        const Text('No active emergency requests',
                            style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: emergencies.length,
                    itemBuilder: (ctx, i) {
                      final req = emergencies[i];
                      return _EmergencyRequestCard(request: req);
                    },
                  ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryPlaceholder(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_rounded, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text('Emergency History Coming Soon', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildSettingsPlaceholder(ThemeData theme) {
     return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.settings_suggest_rounded, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => context.push('/profile'),
            child: const Text('Go to User Profile'),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(Icons.home_rounded, 'Dashboard', 0, _currentIndex == 0, theme),
              _buildNavItem(Icons.history_rounded, 'History', 1, _currentIndex == 1, theme),
              _buildNavItem(Icons.person_rounded, 'Profile', 2, _currentIndex == 2, theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index, bool isSelected, ThemeData theme) {
    return InkWell(
      onTap: () {
        if (index == 2) {
          context.push('/profile');
           return;
        }
        setState(() => _currentIndex = index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.white.withOpacity(0.4),
              size: 26,
            ),
            if (isSelected) ...[
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }
}

class _EmergencyRequestCard extends StatelessWidget {
  final Emergency request;
  const _EmergencyRequestCard({required this.request});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppShadows.neumorphicOut,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.go('/responder/request/${request.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.emergency_rounded,
                    color: Colors.red, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.emergencyType.replaceAll('_', ' '),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Priority: ${request.status}',
                      style: TextStyle(color: Colors.grey.shade600,
                          fontSize: 13),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

