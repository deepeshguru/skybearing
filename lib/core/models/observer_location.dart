enum LocationSource { gps, manual, saved }

class ObserverLocation {
  const ObserverLocation({
    required this.latitudeDegrees,
    required this.longitudeDegrees,
    required this.elevationMeters,
    required this.source,
    this.horizontalAccuracyMeters,
    this.recordedAt,
  });

  final double latitudeDegrees;
  final double longitudeDegrees;
  final double elevationMeters;
  final LocationSource source;
  final double? horizontalAccuracyMeters;
  final DateTime? recordedAt;

  bool get hasPoorAccuracy =>
      horizontalAccuracyMeters != null && horizontalAccuracyMeters! > 1000;

  Map<String, Object?> toJson() => {
    'latitude': latitudeDegrees,
    'longitude': longitudeDegrees,
    'elevation': elevationMeters,
    'source': source.name,
    'accuracy': horizontalAccuracyMeters,
    'recordedAt': recordedAt?.toUtc().millisecondsSinceEpoch,
  };

  factory ObserverLocation.fromJson(Map<String, Object?> json) {
    final source = LocationSource.values.firstWhere(
      (value) => value.name == json['source'],
      orElse: () => LocationSource.saved,
    );
    return ObserverLocation(
      latitudeDegrees: (json['latitude'] as num).toDouble(),
      longitudeDegrees: (json['longitude'] as num).toDouble(),
      elevationMeters: (json['elevation'] as num?)?.toDouble() ?? 0,
      source: source,
      horizontalAccuracyMeters: (json['accuracy'] as num?)?.toDouble(),
      recordedAt: json['recordedAt'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              json['recordedAt']! as int,
              isUtc: true,
            ),
    );
  }

  factory ObserverLocation.manual({
    required double latitudeDegrees,
    required double longitudeDegrees,
    required double elevationMeters,
  }) => ObserverLocation(
    latitudeDegrees: latitudeDegrees,
    longitudeDegrees: longitudeDegrees,
    elevationMeters: elevationMeters,
    source: LocationSource.manual,
  );
}
