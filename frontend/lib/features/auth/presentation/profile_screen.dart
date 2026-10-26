import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../stations/presentation/station_controller.dart';
import '../../stations/presentation/widgets/station_detail_sheet.dart';
import 'auth_controller.dart';

/// Screen managing authentication, EV driver profile, and saved station bookmarks.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isRegisterMode = false;
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  String _preferredConnector = 'CCS2';

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: Text(authState.isAuthenticated ? 'EV Driver Profile' : 'Sign In')),
      body: authState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : authState.isAuthenticated
              ? _buildAuthenticatedView(context, authState, isDark)
              : _buildAuthForm(context, authState, isDark),
    );
  }

  Widget _buildAuthForm(BuildContext context, AuthState authState, bool isDark) {
    final notifier = ref.read(authControllerProvider.notifier);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.electric_car, size: 56, color: AppTheme.primaryTeal),
          const SizedBox(height: 10),
          Text(
            _isRegisterMode ? 'Create Driver Account' : 'Welcome to ChargeTrail',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            _isRegisterMode ? 'Save favorite chargers, submit hidden bays & vote' : 'Sign in to access saved stations and EV community features',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
          ),
          const SizedBox(height: 18),
          if (authState.errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(8)),
              child: Text(authState.errorMessage!, style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 12)),
            ),
            const SizedBox(height: 12),
          ],
          if (_isRegisterMode) ...[
            TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person_outline))),
            const SizedBox(height: 10),
          ],
          TextField(controller: _emailCtrl, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email Address', prefixIcon: Icon(Icons.email_outlined))),
          const SizedBox(height: 10),
          TextField(controller: _passwordCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock_outline))),
          const SizedBox(height: 10),
          if (_isRegisterMode) ...[
            DropdownButtonFormField<String>(
              initialValue: _preferredConnector,
              decoration: const InputDecoration(labelText: 'Vehicle Charging Port', prefixIcon: Icon(Icons.ev_station_outlined)),
              items: const [
                DropdownMenuItem(value: 'CCS2', child: Text('CCS2 (Standard)')),
                DropdownMenuItem(value: 'Type 2', child: Text('Type 2 (AC)')),
                DropdownMenuItem(value: 'CHAdeMO', child: Text('CHAdeMO (Japan/Nissan)')),
              ],
              onChanged: (val) => val != null ? setState(() => _preferredConnector = val) : null,
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 6),
          FilledButton(
            onPressed: () {
              if (_isRegisterMode) {
                notifier.register(email: _emailCtrl.text.trim(), password: _passwordCtrl.text, fullName: _nameCtrl.text.trim(), preferredConnector: _preferredConnector);
              } else {
                notifier.login(email: _emailCtrl.text.trim(), password: _passwordCtrl.text);
              }
            },
            style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryTeal, padding: const EdgeInsets.symmetric(vertical: 14)),
            child: Text(_isRegisterMode ? 'Register Account' : 'Sign In', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () => setState(() => _isRegisterMode = !_isRegisterMode),
            child: Text(_isRegisterMode ? 'Already have an account? Sign In' : 'New to ChargeTrail? Create Account'),
          ),
          const Divider(height: 24),
          OutlinedButton.icon(
            onPressed: () => notifier.loginAsDemoDriver(),
            icon: const Icon(Icons.flash_on, color: AppTheme.accentAmber),
            label: const Text('Continue as Malaysian Demo Driver'),
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthenticatedView(BuildContext context, AuthState authState, bool isDark) {
    final user = authState.currentUser!;
    final notifier = ref.read(authControllerProvider.notifier);
    final allStations = ref.watch(stationControllerProvider).allStations;
    final savedStations = allStations.where((s) => user.savedStationIds.contains(s.id)).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: AppTheme.primaryTeal,
                  child: Text(user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : 'U', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.fullName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      Text(user.email, style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600])),
                      const SizedBox(height: 4),
                      Text('Connector: ${user.preferredConnector}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryTeal)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Preferred Charging Connector', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: ['CCS2', 'Type 2', 'CHAdeMO'].map((conn) {
                    return ChoiceChip(
                      label: Text(conn),
                      selected: user.preferredConnector == conn,
                      onSelected: (val) => val ? notifier.updateProfile(preferredConnector: conn) : null,
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text('Saved Stations (${savedStations.length})', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (savedStations.isEmpty) ...[
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: isDark ? AppTheme.cardDark : Colors.white, borderRadius: BorderRadius.circular(14)),
            child: Column(
              children: [
                Icon(Icons.bookmark_border, size: 40, color: Colors.grey[400]),
                const SizedBox(height: 8),
                const Text('No Saved Stations Yet', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Tap the bookmark icon on any station in the map to save it here.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
          ),
        ] else ...[
          ...savedStations.map((station) {
            return Card(
              margin: const EdgeInsets.only(bottom: 6),
              child: ListTile(
                leading: const CircleAvatar(backgroundColor: Color(0xFFE0F2F1), child: Icon(Icons.ev_station, color: AppTheme.primaryTeal)),
                title: Text(station.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                subtitle: Text('${station.operatorName ?? "Community"} • ${station.city} • ${station.maxPowerKw.toInt()} kW', style: const TextStyle(fontSize: 11)),
                trailing: IconButton(icon: const Icon(Icons.bookmark, color: AppTheme.primaryTeal), onPressed: () => notifier.toggleBookmark(station.id)),
                onTap: () => StationDetailSheet.show(context, station),
              ),
            );
          }),
        ],
        const SizedBox(height: 18),
        OutlinedButton.icon(
          onPressed: () => notifier.logout(),
          icon: const Icon(Icons.logout, color: Colors.red),
          label: const Text('Log Out', style: TextStyle(color: Colors.red)),
          style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.redAccent), padding: const EdgeInsets.symmetric(vertical: 10)),
        ),
      ],
    );
  }
}
