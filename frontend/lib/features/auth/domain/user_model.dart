/// Immutable User Profile domain model and authentication state representations.
class UserProfile {
  final String id;
  final String email;
  final String fullName;
  final String? phoneNumber;
  final String preferredConnector;
  final String role;
  final bool isActive;
  final List<String> savedStationIds;
  final DateTime? createdAt;

  const UserProfile({
    required this.id,
    required this.email,
    required this.fullName,
    this.phoneNumber,
    this.preferredConnector = 'CCS2',
    this.role = 'user',
    this.isActive = true,
    this.savedStationIds = const [],
    this.createdAt,
  });

  bool get isAdmin => role == 'admin';

  bool isBookmarked(String stationId) => savedStationIds.contains(stationId);

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final rawSaved = json['saved_station_ids'] as List<dynamic>? ?? [];
    final savedList = rawSaved.map((e) => e.toString()).toList();

    DateTime? parsedDate;
    if (json['created_at'] != null) {
      try {
        parsedDate = DateTime.parse(json['created_at'] as String);
      } catch (_) {}
    }

    return UserProfile(
      id: json['id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      phoneNumber: json['phone_number'] as String?,
      preferredConnector: json['preferred_connector'] as String? ?? 'CCS2',
      role: json['role'] as String? ?? 'user',
      isActive: json['is_active'] as bool? ?? true,
      savedStationIds: savedList,
      createdAt: parsedDate,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'full_name': fullName,
        'phone_number': phoneNumber,
        'preferred_connector': preferredConnector,
        'role': role,
        'is_active': isActive,
        'saved_station_ids': savedStationIds,
        'created_at': createdAt?.toIso8601String(),
      };

  UserProfile copyWith({
    String? id,
    String? email,
    String? fullName,
    String? phoneNumber,
    bool clearPhoneNumber = false,
    String? preferredConnector,
    String? role,
    bool? isActive,
    List<String>? savedStationIds,
    DateTime? createdAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      phoneNumber: clearPhoneNumber ? null : (phoneNumber ?? this.phoneNumber),
      preferredConnector: preferredConnector ?? this.preferredConnector,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      savedStationIds: savedStationIds ?? this.savedStationIds,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
