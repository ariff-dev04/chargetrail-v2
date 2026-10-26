import 'dart:math';
import '../domain/station_model.dart';

/// Curated Open EV registry containing 32 regional Malaysian stations.
class MalaysiaEvRegistry {
  // [id, name, operator, city, state, lat, lng, kw, plug, address, level]
  static const List<List<dynamic>> _kCatalog = [
    // --- Greater Kuala Lumpur ---
    ['my-ev-01', 'Mid Valley Megamall chargEV Hub', 'chargEV', 'Kuala Lumpur', 'Kuala Lumpur', 3.1186, 101.6778, 60.0, 'CCS2', 'Lingkaran Syed Putra, Mid Valley City', 'Zone A, Pillar P4'],
    ['my-ev-02', 'Bangsar Shopping Centre JomCharge', 'JomCharge', 'Kuala Lumpur', 'Kuala Lumpur', 3.1432, 101.6671, 120.0, 'CCS2', '285, Jalan Maarof, Bangsar', 'Basement B2, Pillar C10'],
    ['my-ev-03', '163 Retail Park Mont Kiara Gentari', 'Gentari', 'Kuala Lumpur', 'Kuala Lumpur', 3.1695, 101.6521, 60.0, 'CCS2', '8, Jalan Kiara, Mont Kiara', 'Basement B1, Pillar E6'],
    ['my-ev-04', 'Pavilion Damansara Heights Tesla Supercharger', 'Tesla', 'Kuala Lumpur', 'Kuala Lumpur', 3.1481, 101.6625, 250.0, 'CCS2', '3, Jalan Damanlela, Bukit Damansara', 'Basement B1, Pillar T1-T4'],
    ['my-ev-05', 'Cheras Leisure Mall JomCharge', 'JomCharge', 'Kuala Lumpur', 'Kuala Lumpur', 3.1025, 101.7431, 60.0, 'CCS2', 'Jalan Manis 6, Taman Segar, Cheras', 'Level 2 Covered Carpark'],
    ['my-ev-06', 'KL Sentral Nu Sentral Mall chargEV', 'chargEV', 'Kuala Lumpur', 'Kuala Lumpur', 3.1332, 101.6870, 60.0, 'CCS2', '201, Jalan Tun Sambanthan, Brickfields', 'Level P3 Pillar J8'],

    // --- Selangor (PJ, Subang, Shah Alam, Cyberjaya, Bangi, Kajang) ---
    ['my-ev-07', 'The Starling Mall Uptown Damansara Gentari', 'Gentari', 'Petaling Jaya', 'Selangor', 3.1352, 101.6231, 60.0, 'CCS2', '6, Jalan SS 21/37, Damansara Utama', 'Basement B1, Pillar B15'],
    ['my-ev-08', 'Paradigm Mall PJ Shell Recharge', 'Shell Recharge', 'Petaling Jaya', 'Selangor', 3.1051, 101.5959, 120.0, 'CCS2', '1, Jalan SS 7/26a, Kelana Jaya', 'Level LG Carpark'],
    ['my-ev-09', 'Empire Shopping Gallery Subang chargEV', 'chargEV', 'Subang Jaya', 'Selangor', 3.0818, 101.5830, 60.0, 'CCS2', 'Jalan SS 16/1, Subang Jaya', 'Basement B2 Pillar A12'],
    ['my-ev-10', 'Setia City Mall Shah Alam Gentari', 'Gentari', 'Shah Alam', 'Selangor', 3.1118, 101.4623, 120.0, 'CCS2', '7, Persiaran Setia Dagang, Setia Alam', 'LG Carpark near Village Grocer'],
    ['my-ev-11', "D'Pulze Shopping Centre Cyberjaya JomCharge", 'JomCharge', 'Cyberjaya', 'Selangor', 2.9218, 101.6510, 60.0, 'CCS2', 'Persiaran Flora, Cyber 12', 'Basement B2, Pillar C4'],
    ['my-ev-12', 'De Centrum Mall Bangi chargEV', 'chargEV', 'Bangi', 'Selangor', 2.9781, 101.7340, 50.0, 'CCS2', 'Jalan Ikram-Uniten', 'Ground Floor Carpark'],
    ['my-ev-13', 'Plaza Metro Kajang JomCharge', 'JomCharge', 'Kajang', 'Selangor', 2.9934, 101.7912, 60.0, 'CCS2', 'Jalan Tun Abdul Aziz, Bandar Kajang', 'Level 3 Carpark'],

    // --- Negeri Sembilan & Melaka ---
    ['my-ev-14', 'AEON Mall Seremban 2 Gentari', 'Gentari', 'Seremban', 'Negeri Sembilan', 2.6953, 101.9078, 120.0, 'CCS2', '112, Persiaran S2 B1, Seremban 2', 'Open Carpark Bay 1-2'],
    ['my-ev-15', 'Port Dickson Waterfront Shell Recharge', 'Shell Recharge', 'Port Dickson', 'Negeri Sembilan', 2.5228, 101.7963, 60.0, 'CCS2', 'Persiaran Waterfront', 'Waterfront Promenade'],
    ['my-ev-16', 'Dataran Pahlawan Melaka Megamall chargEV', 'chargEV', 'Melaka', 'Melaka', 2.1899, 102.2505, 60.0, 'CCS2', 'Jalan Merdeka, Bandar Hilir', 'Basement B1 Pillar E14'],
    ['my-ev-17', "Freeport A'Famosa Outlet Gentari Hub", 'Gentari', 'Alor Gajah', 'Melaka', 2.4418, 102.2081, 150.0, 'CCS2', 'Jalan Kemus, Simpang Empat', 'Main Entrance Carpark'],

    // --- Johor ---
    ['my-ev-18', 'Johor Premium Outlets Gentari Supercharger', 'Gentari', 'Kulai', 'Johor', 1.6218, 103.6265, 180.0, 'CCS2', 'Jalan Premium Outlets, Indahpura', 'Open Carpark Zone B'],
    ['my-ev-19', 'Paradigm Mall JB JomCharge Hub', 'JomCharge', 'Johor Bahru', 'Johor', 1.5152, 103.6853, 120.0, 'CCS2', 'Jalan Skudai', 'Level 3A Covered Bay'],
    ['my-ev-20', 'R&F Mall Princess Cove chargEV', 'chargEV', 'Johor Bahru', 'Johor', 1.4589, 103.7712, 60.0, 'CCS2', '1, Jalan Tanjung Puteri', 'Basement Carpark near CIQ'],
    ['my-ev-21', 'Wetex Parade Muar Gentari', 'Gentari', 'Muar', 'Johor', 2.0451, 102.5694, 60.0, 'CCS2', '326, Jalan Ali, Pekan Muar', 'Covered Parking Bay 1-2'],
    ['my-ev-22', 'Batu Pahat Mall JomCharge', 'JomCharge', 'Batu Pahat', 'Johor', 1.8653, 102.9610, 60.0, 'CCS2', 'Jalan Kluang', 'Basement 1 Carpark'],

    // --- Perak, Penang & Kedah ---
    ['my-ev-23', 'Ipoh Parade chargEV Hub', 'chargEV', 'Ipoh', 'Perak', 4.5956, 101.0901, 60.0, 'CCS2', '105, Jalan Sultan Abdul Jalil', 'Basement B1, Pillar C8'],
    ['my-ev-24', 'Taiping Sentral Mall Gentari', 'Gentari', 'Taiping', 'Perak', 4.8621, 100.7258, 60.0, 'CCS2', '36, Jalan Istana Larut', 'Open Carpark Bay 1'],
    ['my-ev-25', 'Design Village Outlet Mall Batu Kawan Gentari', 'Gentari', 'Bandar Cassia', 'Penang', 5.2415, 100.4372, 150.0, 'CCS2', '733, Jalan Cassia Barat 2', 'Design Village Main Carpark'],
    ['my-ev-26', 'Queensbay Mall Penang Shell Recharge', 'Shell Recharge', 'Bayan Lepas', 'Penang', 5.3332, 100.3065, 120.0, 'CCS2', '100, Persiaran Bayan Indah', 'Multi-storey Carpark Level 3'],
    ['my-ev-27', 'Aman Central Alor Setar JomCharge', 'JomCharge', 'Alor Setar', 'Kedah', 6.1245, 100.3670, 60.0, 'CCS2', '1, Darul Aman Highway', 'Basement B1 Pillar G2'],

    // --- East Coast & East Malaysia ---
    ['my-ev-28', 'East Coast Mall Kuantan Gentari', 'Gentari', 'Kuantan', 'Pahang', 3.8164, 103.3245, 120.0, 'CCS2', 'Jalan Putra Square 6, Putra Square', 'Basement B1 Pillar B20'],
    ['my-ev-29', 'KTCC Mall Kuala Terengganu chargEV', 'chargEV', 'Kuala Terengganu', 'Terengganu', 5.3289, 103.1415, 60.0, 'CCS2', 'Muara Selatan', 'Level 2 Covered Bay'],
    ['my-ev-30', 'KB Mall Kota Bharu JomCharge', 'JomCharge', 'Kota Bharu', 'Kelantan', 6.1189, 102.2450, 60.0, 'CCS2', '1, Jalan Hamzah', 'Ground Floor Carpark'],
    ['my-ev-31', 'Vivacity Megamall Kuching Gentari', 'Gentari', 'Kuching', 'Sarawak', 1.5289, 110.3621, 120.0, 'CCS2', 'Jalan Wan Alwi', 'Basement B1 Pillar E4'],
    ['my-ev-32', 'Imago Shopping Mall Kota Kinabalu Shell Recharge', 'Shell Recharge', 'Kota Kinabalu', 'Sabah', 5.9712, 116.0645, 60.0, 'CCS2', 'KK Times Square Phase 2', 'Basement B1 Pillar A8'],
  ];

  /// Retrieve all registered open data stations converted to domain models.
  static List<ChargingStation> getAllStations() {
    return _kCatalog.map((row) {
      final id = row[0] as String;
      final name = row[1] as String;
      final operator = row[2] as String;
      final city = row[3] as String;
      final state = row[4] as String;
      final lat = (row[5] as num).toDouble();
      final lng = (row[6] as num).toDouble();
      final kw = (row[7] as num).toDouble();
      final plugType = row[8] as String;
      final address = row[9] as String;
      final level = row[10] as String;

      return ChargingStation(
        id: id,
        name: name,
        operatorName: operator,
        address: address,
        city: city,
        state: state,
        latitude: lat,
        longitude: lng,
        plugTypes: [PlugInfo(type: plugType, powerKw: kw, count: 2)],
        maxPowerKw: kw,
        isAvailable: true,
        is24Hours: true,
        chargingCostMyr: 1.40,
        parkingFeeMyr: 3.0,
        parkingLevel: level,
        operationHours: '24 Hours',
        amenities: const ['Dining', 'Restroom', 'Shopping'],
        howToAccess: [
          AccessStep(stepNumber: 1, instruction: 'Follow carpark directions to $level.'),
        ],
        rating: 4.6,
        reviewCount: 8,
        source: 'open_data_my',
        isVerified: false,
      );
    }).toList();
  }

  /// Get open data stations within a radial distance (km) of given coordinates.
  static List<ChargingStation> getStationsNear(
    double lat,
    double lng, {
    double radiusKm = 35.0,
  }) {
    return getAllStations().where((station) {
      final dLat = (station.latitude - lat) * 111.0;
      final dLon = (station.longitude - lng) * 111.0 * cos(lat * pi / 180.0);
      final dist = sqrt(dLat * dLat + dLon * dLon);
      return dist <= radiusKm;
    }).toList();
  }
}
