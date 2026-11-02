import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../features/auth/presentation/auth_controller.dart';
import '../../features/auth/presentation/profile_screen.dart';
import '../../features/auth/presentation/widgets/auth_gate_view.dart';
import '../../features/routing/presentation/route_planner_screen.dart';
import '../../features/stations/presentation/map_discovery_screen.dart';
import '../../features/vehicles/presentation/garage_screen.dart';

/// Master navigation shell switching between the AuthGateView and the 4 primary tabs.
class AppShellScreen extends ConsumerStatefulWidget {
  const AppShellScreen({super.key});

  @override
  ConsumerState<AppShellScreen> createState() => _AppShellScreenState();
}

class _AppShellScreenState extends ConsumerState<AppShellScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    MapDiscoveryScreen(),
    RoutePlannerScreen(),
    GarageScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    // Initial session bootstrap loading state
    if (authState.isLoading && !authState.isAuthenticated) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            color: AppTheme.primaryTeal,
          ),
        ),
      );
    }

    // Unauthenticated entry gate
    if (!authState.isAuthenticated) {
      return const AuthGateView();
    }

    // Authenticated 4-tab application shell
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore_rounded),
            label: 'Explore',
          ),
          NavigationDestination(
            icon: Icon(Icons.alt_route_outlined),
            selectedIcon: Icon(Icons.alt_route_rounded),
            label: 'Route Planner',
          ),
          NavigationDestination(
            icon: Icon(Icons.electric_car_outlined),
            selectedIcon: Icon(Icons.electric_car_rounded),
            label: 'EV Garage',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile & Saved',
          ),
        ],
      ),
    );
  }
}

/// Backwards-compatibility alias for AppShellScreen.
typedef AppShell = AppShellScreen;
