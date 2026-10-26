import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/station_model.dart';

/// Local offline cache storing stations in SharedPreferences.
/// Pre-seeded with 12 flagship Malaysian EV stations across Peninsular Malaysia.
class StationLocalCache {
  static const String _storageKey = 'chargetrail_cached_stations_v1';

  final SharedPreferences? _prefs;

  StationLocalCache([this._prefs]);

  /// Asynchronously retrieve cached stations or return default Malaysian dataset.
  Future<List<ChargingStation>> getCachedStations() async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      final rawJson = prefs.getString(_storageKey);
      if (rawJson != null && rawJson.isNotEmpty) {
        final decoded = jsonDecode(rawJson) as List<dynamic>;
        final stations = decoded
            .map((item) => ChargingStation.fromJson(item as Map<String, dynamic>))
            .toList();
        if (stations.isNotEmpty) {
          return stations;
        }
      }
    } catch (_) {}
    return defaultMalaysianStations();
  }

  /// Persist retrieved stations to local storage for subsequent offline launches.
  Future<void> saveStations(List<ChargingStation> stations) async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      final payload = jsonEncode(stations.map((s) => s.toJson()).toList());
      await prefs.setString(_storageKey, payload);
    } catch (_) {}
  }

  static ChargingStation _s({
    required String id,
    required String name,
    required String operator,
    required String address,
    required String city,
    required String state,
    required double lat,
    required double lng,
    required double maxKw,
    bool is24h = false,
    String hours = '24 Hours',
    double cost = 1.40,
    double parking = 3.00,
    String level = 'Basement Parking',
    double rating = 4.7,
    int reviews = 25,
    required List<PlugInfo> plugs,
    required List<String> amenities,
    required List<AccessStep> steps,
  }) {
    return ChargingStation(
      id: id,
      name: name,
      operatorName: operator,
      address: address,
      city: city,
      state: state,
      latitude: lat,
      longitude: lng,
      plugTypes: plugs,
      maxPowerKw: maxKw,
      isAvailable: true,
      is24Hours: is24h,
      chargingCostMyr: cost,
      parkingFeeMyr: parking,
      parkingLevel: level,
      operationHours: hours,
      amenities: amenities,
      howToAccess: steps,
      rating: rating,
      reviewCount: reviews,
      source: 'community',
      isVerified: true,
    );
  }

  /// 12 verified Malaysian baseline stations ensuring rich discovery across the peninsula.
  static List<ChargingStation> defaultMalaysianStations() {
    return [
      _s(
        id: '9ec6c0f7-48d9-48b1-ad1b-0e6a157fa1bf',
        name: 'Suria KLCC Gentari Charging Hub',
        operator: 'Gentari',
        address: '241, Suria KLCC, 50088 Kuala Lumpur',
        city: 'Kuala Lumpur',
        state: 'Wilayah Persekutuan Kuala Lumpur',
        lat: 3.1578,
        lng: 101.7118,
        maxKw: 180.0,
        cost: 1.50,
        parking: 5.00,
        level: 'Basement B1, Pillar B12',
        hours: '06:00 - 24:00',
        rating: 4.8,
        reviews: 34,
        plugs: const [PlugInfo(type: 'CCS2', powerKw: 180.0, count: 3), PlugInfo(type: 'Type 2', powerKw: 22.0, count: 1)],
        amenities: const ['Dining', 'Restroom', 'Shopping', 'Surau', 'Security'],
        steps: const [
          AccessStep(stepNumber: 1, instruction: 'Enter via Jalan Ampang basement ramp into Carpark B1.'),
          AccessStep(stepNumber: 2, instruction: 'Follow green EV Hub floor markings toward Pillar B12.'),
        ],
      ),
      _s(
        id: 'bb112233-4455-6677-8899-aabbccddeeff',
        name: 'Pavilion Bukit Bintang JomCharge',
        operator: 'JomCharge',
        address: '168, Jalan Bukit Bintang, 55100 Kuala Lumpur',
        city: 'Kuala Lumpur',
        state: 'Wilayah Persekutuan Kuala Lumpur',
        lat: 3.1488,
        lng: 101.7133,
        maxKw: 120.0,
        level: 'Basement B2, Pillar D8',
        hours: '10:00 - 22:00',
        plugs: const [PlugInfo(type: 'CCS2', powerKw: 120.0, count: 2), PlugInfo(type: 'Type 2', powerKw: 11.0, count: 2)],
        amenities: const ['Dining', 'Restroom', 'Shopping', 'Cinema'],
        steps: const [
          AccessStep(stepNumber: 1, instruction: 'Enter via Jalan Raja Chulan carpark entrance.'),
          AccessStep(stepNumber: 2, instruction: 'Descend to B2 and turn right at Zone D lift lobby.'),
        ],
      ),
      _s(
        id: 'a1b2c3d4-e5f6-4a1b-8c2d-3e4f5a6b7c8d',
        name: 'IOI City Mall Putrajaya JomCharge',
        operator: 'JomCharge',
        address: 'IOI City Mall, Lebuh IRC, IOI Resort City, 62502 Putrajaya',
        city: 'Putrajaya',
        state: 'Wilayah Persekutuan Putrajaya',
        lat: 2.9698,
        lng: 101.7135,
        maxKw: 120.0,
        is24h: true,
        level: 'Phase 2, Level P1, Pillar G4',
        plugs: const [PlugInfo(type: 'CCS2', powerKw: 120.0, count: 2), PlugInfo(type: 'Type 2', powerKw: 11.0, count: 2)],
        amenities: const ['Dining', 'Restroom', 'Shopping', 'Cinema', 'Surau'],
        steps: const [
          AccessStep(stepNumber: 1, instruction: 'Enter through Phase 2 West Carpark entrance from Persiaran IRC.'),
          AccessStep(stepNumber: 2, instruction: 'Proceed straight into Zone G near Lotus hypermarket entrance.'),
        ],
      ),
      _s(
        id: 'cc223344-5566-7788-99aa-bbccddeeff00',
        name: 'Cyberjaya Tamarind Square Gentari',
        operator: 'Gentari',
        address: 'Persiaran Multimedia, Cyber 10, 63000 Cyberjaya, Selangor',
        city: 'Cyberjaya',
        state: 'Selangor',
        lat: 2.9213,
        lng: 101.6559,
        maxKw: 60.0,
        cost: 1.20,
        parking: 2.00,
        level: 'Level P1, Near Main Escalator',
        plugs: const [PlugInfo(type: 'CCS2', powerKw: 60.0, count: 2), PlugInfo(type: 'Type 2', powerKw: 22.0, count: 2)],
        amenities: const ['Dining', 'Restroom', 'Supermarket'],
        steps: const [
          AccessStep(stepNumber: 1, instruction: 'Enter Tamarind Square basement carpark from Persiaran Multimedia.'),
          AccessStep(stepNumber: 2, instruction: 'Keep left on Level P1; bays are opposite Village Grocer entrance.'),
        ],
      ),
      _s(
        id: 'b2c3d4e5-f6a1-4b2c-9d3e-4f5a6b7c8d9e',
        name: 'Sunway Pyramid chargEV Station',
        operator: 'chargEV',
        address: '3, Jalan PJS 11/15, Bandar Sunway, 47500 Petaling Jaya, Selangor',
        city: 'Petaling Jaya',
        state: 'Selangor',
        lat: 3.0733,
        lng: 101.6078,
        maxKw: 60.0,
        cost: 1.20,
        parking: 4.00,
        level: 'CP2 Carpark Level B1, Orange Zone',
        hours: '07:00 - 23:00',
        plugs: const [PlugInfo(type: 'CCS2', powerKw: 60.0, count: 2), PlugInfo(type: 'Type 2', powerKw: 22.0, count: 2)],
        amenities: const ['Dining', 'Restroom', 'Shopping', 'Cinema'],
        steps: const [
          AccessStep(stepNumber: 1, instruction: 'Enter CP2 carpark entrance opposite Sunway Resort Hotel.'),
          AccessStep(stepNumber: 2, instruction: 'Keep right to enter Orange Zone B1 next to Lift Lobby 3.'),
        ],
      ),
      _s(
        id: 'dd334455-6677-8899-aabb-ccddeeff0011',
        name: 'Genting Highlands SkyAvenue JomCharge',
        operator: 'JomCharge',
        address: 'SkyAvenue, Resort World Genting, 69000 Genting Highlands, Pahang',
        city: 'Genting Highlands',
        state: 'Pahang',
        lat: 3.4237,
        lng: 101.7932,
        maxKw: 120.0,
        cost: 1.60,
        parking: 6.00,
        level: 'Level B3, Amber Zone Bay 12',
        plugs: const [PlugInfo(type: 'CCS2', powerKw: 120.0, count: 2), PlugInfo(type: 'Type 2', powerKw: 11.0, count: 2)],
        amenities: const ['Dining', 'Restroom', 'Theme Park', 'Shopping'],
        steps: const [
          AccessStep(stepNumber: 1, instruction: 'Ascend to SkyAvenue multi-storey carpark entrance.'),
          AccessStep(stepNumber: 2, instruction: 'Drive to Level B3 Amber Zone near theme park ticketing.'),
        ],
      ),
      _s(
        id: 'c3d4e5f6-a1b2-4c3d-0e4f-5a6b7c8d9e0f',
        name: 'Shell Recharge Tapah RSA Northbound',
        operator: 'Shell Recharge',
        address: 'North-South Expressway KM 332.3 Northbound, 35000 Tapah, Perak',
        city: 'Tapah',
        state: 'Perak',
        lat: 4.1950,
        lng: 101.2789,
        maxKw: 180.0,
        is24h: true,
        cost: 1.60,
        parking: 0.0,
        level: 'Outdoor Rest Area, Bay 1-2',
        plugs: const [PlugInfo(type: 'CCS2', powerKw: 180.0, count: 2)],
        amenities: const ['Dining', 'Restroom', 'Convenience Store', 'Surau', 'Petrol Station'],
        steps: const [
          AccessStep(stepNumber: 1, instruction: 'Exit PLUS highway at Tapah RSA Northbound rest stop.'),
          AccessStep(stepNumber: 2, instruction: "Pass the food court; bays are directly next to McDonald's drive-thru."),
        ],
      ),
      _s(
        id: 'ee445566-7788-99aa-bbcc-ddeeff001122',
        name: 'Ipoh Sunway Lost World JomCharge',
        operator: 'JomCharge',
        address: 'No. 1, Persiaran Lagun Sunway 1, 31150 Ipoh, Perak',
        city: 'Ipoh',
        state: 'Perak',
        lat: 4.6250,
        lng: 101.1550,
        maxKw: 120.0,
        parking: 2.00,
        level: 'Open Carpark Zone A, Bay 1-2',
        plugs: const [PlugInfo(type: 'CCS2', powerKw: 120.0, count: 2)],
        amenities: const ['Dining', 'Restroom', 'Theme Park', 'Hotel'],
        steps: const [
          AccessStep(stepNumber: 1, instruction: 'Enter Lost World open visitor carpark from Persiaran Lagun Sunway.'),
          AccessStep(stepNumber: 2, instruction: 'Bays are situated directly opposite the main ticketing arch.'),
        ],
      ),
      _s(
        id: 'e5f6a1b2-c3d4-4e5f-2a6b-7c8d9e0f1a2b',
        name: 'Gurney Plaza Shell Recharge',
        operator: 'Shell Recharge',
        address: '170, Gurney Dr, 10250 George Town, Penang',
        city: 'George Town',
        state: 'Penang',
        lat: 5.4372,
        lng: 100.3096,
        maxKw: 60.0,
        cost: 1.30,
        level: 'Multi-storey Carpark Level 5, Bay 501-504',
        hours: '10:00 - 22:00',
        plugs: const [PlugInfo(type: 'CCS2', powerKw: 60.0, count: 2), PlugInfo(type: 'Type 2', powerKw: 11.0, count: 2)],
        amenities: const ['Dining', 'Restroom', 'Shopping', 'Cinema', 'Sea View'],
        steps: const [
          AccessStep(stepNumber: 1, instruction: 'Follow multi-storey carpark spiral ramp up to Level 5.'),
          AccessStep(stepNumber: 2, instruction: 'Chargers are located directly opposite mall glass entrance doors.'),
        ],
      ),
      _s(
        id: 'ff556677-8899-aabb-ccdd-eeff00112233',
        name: 'Shell Recharge Seremban RSA Southbound',
        operator: 'Shell Recharge',
        address: 'North-South Expressway KM 272.2 Southbound, 70300 Seremban, Negeri Sembilan',
        city: 'Seremban',
        state: 'Negeri Sembilan',
        lat: 2.7258,
        lng: 101.9424,
        maxKw: 180.0,
        is24h: true,
        cost: 1.60,
        parking: 0.0,
        level: 'Outdoor RSA Bay, Next to Shell Canopy',
        plugs: const [PlugInfo(type: 'CCS2', powerKw: 180.0, count: 2)],
        amenities: const ['Dining', 'Restroom', 'Convenience Store', 'Surau', 'Petrol Station'],
        steps: const [
          AccessStep(stepNumber: 1, instruction: 'Exit PLUS highway at Seremban Southbound RSA.'),
          AccessStep(stepNumber: 2, instruction: 'Chargers are placed directly adjacent to the main Shell petrol canopy.'),
        ],
      ),
      _s(
        id: 'aa001122-3344-5566-7788-99aabbccddee',
        name: 'Ayer Keroh Overhead Bridge RSA Gentari',
        operator: 'Gentari',
        address: 'North-South Expressway KM 210.0, 75450 Ayer Keroh, Melaka',
        city: 'Ayer Keroh',
        state: 'Melaka',
        lat: 2.2740,
        lng: 102.2850,
        maxKw: 150.0,
        is24h: true,
        cost: 1.50,
        parking: 0.0,
        level: 'Overhead Restaurant Bridge, Bay 1-2',
        plugs: const [PlugInfo(type: 'CCS2', powerKw: 150.0, count: 2)],
        amenities: const ['Dining', 'Restroom', 'Souvenirs', 'Surau'],
        steps: const [
          AccessStep(stepNumber: 1, instruction: 'Enter Ayer Keroh Overhead Bridge Rest Area from PLUS highway.'),
          AccessStep(stepNumber: 2, instruction: 'Follow signs towards the bridge restaurant car park bays.'),
        ],
      ),
      _s(
        id: 'd4e5f6a1-b2c3-4d4e-1f5a-6b7c8d9e0f1a',
        name: 'Mid Valley Southkey Gentari Hub',
        operator: 'Gentari',
        address: '1, Persiaran Southkey 1, 80150 Johor Bahru, Johor',
        city: 'Johor Bahru',
        state: 'Johor',
        lat: 1.4989,
        lng: 103.7774,
        maxKw: 120.0,
        is24h: true,
        level: 'South Carpark Level P2, Pillar S18',
        plugs: const [PlugInfo(type: 'CCS2', powerKw: 120.0, count: 2), PlugInfo(type: 'CHAdeMO', powerKw: 50.0, count: 1)],
        amenities: const ['Dining', 'Restroom', 'Shopping', 'Supermarket'],
        steps: const [
          AccessStep(stepNumber: 1, instruction: 'Enter South Carpark ramp from Jalan Bakar Batu.'),
          AccessStep(stepNumber: 2, instruction: 'Descend to Level P2 and turn right at Pillar S10 into EV zone.'),
        ],
      ),
    ];
  }
}
