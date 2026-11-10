import 'package:dio/dio.dart';

/// The real weather over the kid's coarse region (backend `GET
/// /api/v1/me/weather`, Environment Canada; default Montréal, never the
/// kid's location). The 3D village shows it (ADR 0126, Hafid: "we need to
/// follow the real weather").
class VillageWeather {
  const VillageWeather({
    required this.condition,
    required this.observedAt,
    this.tempC,
    this.isDay,
  });

  /// Null for anything malformed: a bad body must never reach the scene.
  static VillageWeather? fromJson(Object? json) {
    if (json is! Map) return null;
    final condition = json['condition'];
    final observedAt = json['observed_at'];
    final temp = json['temp_c'];
    final isDay = json['is_day'];
    if (condition is! String || condition.isEmpty) return null;
    if (observedAt is! String || DateTime.tryParse(observedAt) == null) {
      return null;
    }
    return VillageWeather(
      condition: condition,
      observedAt: observedAt,
      tempC: temp is num ? temp.toDouble() : null,
      isDay: isDay is bool ? isDay : null,
    );
  }

  final String condition;

  /// ISO 8601, as served. The scene treats more than 3 h old as stale.
  final String observedAt;
  final double? tempC;
  final bool? isDay;

  /// BRIDGE.md's `weather` object.
  Map<String, Object?> toJson() => {
    'condition': condition,
    'temp_c': tempC,
    'observed_at': observedAt,
    'is_day': isDay,
  };
}

class WeatherApi {
  WeatherApi({required this.dio});

  final Dio dio;

  /// The latest observation, or null when there's nothing new: no
  /// observation (204), an older backend (404), offline, or any failure.
  /// The caller keeps what it had.
  Future<VillageWeather?> fetch({required String accessToken}) async {
    try {
      final response = await dio.get<Object?>(
        '/api/v1/me/weather',
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );
      if (response.statusCode != 200) return null;
      return VillageWeather.fromJson(response.data);
    } on DioException {
      return null;
    }
  }
}
