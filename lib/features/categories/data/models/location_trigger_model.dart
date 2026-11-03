/// تفعيل المجموعة تلقائيًا لما المستخدم يوصل مكان معيّن.
class LocationTriggerModel {
  final bool isEnabled;
  final double latitude;
  final double longitude;
  final double radiusMeters;

  static const double defaultRadiusMeters = 150;

  const LocationTriggerModel({
    required this.isEnabled,
    required this.latitude,
    required this.longitude,
    this.radiusMeters = defaultRadiusMeters,
  });

  LocationTriggerModel copyWith({
    bool? isEnabled,
    double? latitude,
    double? longitude,
    double? radiusMeters,
  }) {
    return LocationTriggerModel(
      isEnabled: isEnabled ?? this.isEnabled,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      radiusMeters: radiusMeters ?? this.radiusMeters,
    );
  }

  Map<String, dynamic> toMap() => {
    'isEnabled': isEnabled,
    'latitude': latitude,
    'longitude': longitude,
    'radiusMeters': radiusMeters,
  };

  /// يرجّع null لو البيانات ناقصة (مجموعات قديمة ما فيها موقع)
  static LocationTriggerModel? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final lat = raw['latitude'];
    final lng = raw['longitude'];
    if (lat is! num || lng is! num) return null;
    return LocationTriggerModel(
      isEnabled: raw['isEnabled'] as bool? ?? false,
      latitude: lat.toDouble(),
      longitude: lng.toDouble(),
      radiusMeters:
          (raw['radiusMeters'] as num?)?.toDouble() ?? defaultRadiusMeters,
    );
  }
}
