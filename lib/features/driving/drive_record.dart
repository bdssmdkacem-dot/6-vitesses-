class DriveRecord {
  const DriveRecord({
    required this.startedAt,
    required this.durationSeconds,
    required this.distanceKm,
    required this.averageSpeedKmh,
    required this.maxSpeedKmh,
    required this.maxAcceleration,
    required this.maxBraking,
  });

  final DateTime startedAt;
  final int durationSeconds;
  final double distanceKm;
  final double averageSpeedKmh;
  final double maxSpeedKmh;
  final double maxAcceleration;
  final double maxBraking;

  Map<String, Object> toJson() => {
    'startedAt': startedAt.toIso8601String(),
    'durationSeconds': durationSeconds,
    'distanceKm': distanceKm,
    'averageSpeedKmh': averageSpeedKmh,
    'maxSpeedKmh': maxSpeedKmh,
    'maxAcceleration': maxAcceleration,
    'maxBraking': maxBraking,
  };

  factory DriveRecord.fromJson(Map<String, dynamic> json) => DriveRecord(
    startedAt: DateTime.parse(json['startedAt'] as String),
    durationSeconds: json['durationSeconds'] as int,
    distanceKm: (json['distanceKm'] as num).toDouble(),
    averageSpeedKmh: (json['averageSpeedKmh'] as num).toDouble(),
    maxSpeedKmh: (json['maxSpeedKmh'] as num).toDouble(),
    maxAcceleration: (json['maxAcceleration'] as num).toDouble(),
    maxBraking: (json['maxBraking'] as num).toDouble(),
  );
}
