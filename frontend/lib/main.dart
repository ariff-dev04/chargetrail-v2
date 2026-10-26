import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/profile_screen.dart';
import 'features/routing/presentation/route_planner_screen.dart';
import 'features/stations/presentation/map_discovery_screen.dart';
import 'features/vehicles/presentation/garage_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProviderScope(
      child: ChargeTrailApp(),
    ),
  );
}

/// Root widget configuring the Material 3 app shell and themes.
class ChargeTrailApp extends StatelessWidget {
  const ChargeTrailApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ChargeTrail v2',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const AppShell(),
    );
  }
}

/// Navigation shell hosting the primary Map Discovery and modular feature tabs.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    MapDiscoveryScreen(),
    RoutePlannerScreen(),
    GarageScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
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
            selectedIcon: Icon(Icons.explore),
            label: 'Explore',
          ),
          NavigationDestination(
            icon: Icon(Icons.alt_route_outlined),
            selectedIcon: Icon(Icons.alt_route),
            label: 'Route Planner',
          ),
          NavigationDestination(
            icon: Icon(Icons.electric_car_outlined),
            selectedIcon: Icon(Icons.electric_car),
            label: 'EV Garage',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile & Saved',
          ),
        ],
      ),
    );
  }
}
