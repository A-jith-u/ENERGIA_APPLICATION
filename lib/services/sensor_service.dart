import 'package:http/http.dart' as http;
import 'dart:convert';

class SensorReading {
  final int id;
  final String deviceId;
  final double voltage;
  final double current;
  final double powerFactor;
  final double power;
  final double? energy;
  final double? frequency;
  final DateTime createdAt;

  SensorReading({
    required this.id,
    required this.deviceId,
    required this.voltage,
    required this.current,
    required this.powerFactor,
    required this.power,
    this.energy,
    this.frequency,
    required this.createdAt,
  });

  factory SensorReading.fromJson(Map<String, dynamic> json) {
    return SensorReading(
      id: json['id'] ?? 0,
      deviceId: json['device_id'] ?? '',
      voltage: (json['voltage'] as num?)?.toDouble() ?? 0.0,
      current: (json['current'] as num?)?.toDouble() ?? 0.0,
      powerFactor: (json['power_factor'] as num?)?.toDouble() ?? 0.0,
      power: (json['power'] as num?)?.toDouble() ?? 0.0,
      energy: (json['energy'] as num?)?.toDouble(),
      frequency: (json['frequency'] as num?)?.toDouble(),
      createdAt: DateTime.parse(
        json['created_at'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }
}

class SensorService {
  /// Base URL for sensor API endpoints
  /// IP: 10.111.183.200 (Backend server)
  /// Port: 5000 (FastAPI server)
  final String baseUrl = "http://10.111.183.200:5000/api";

  /// Fetch sensor readings from backend
  ///
  /// Parameters:
  ///   - deviceId: Filter by specific device (optional)
  ///   - limit: Maximum number of records (default 100)
  ///   - offset: Pagination offset (default 0)
  Future<List<SensorReading>> getSensorReadings({
    String? deviceId,
    int limit = 100,
    int offset = 0,
  }) async {
    try {
      String url = "$baseUrl/sensor-readings?limit=$limit&offset=$offset";
      if (deviceId != null) {
        url += "&device_id=$deviceId";
      }

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final List<dynamic> data = json['data'] ?? [];
        return data.map((item) => SensorReading.fromJson(item)).toList();
      } else {
        throw Exception(
          'Failed to load sensor readings: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('Error fetching sensor readings: $e');
      return [];
    }
  }

  /// Fetch statistics for sensor readings
  ///
  /// Parameters:
  ///   - deviceId: Filter by specific device (optional)
  ///   - hours: Time range for statistics (default 24 hours)
  ///
  /// Returns:
  ///   - avg_voltage, avg_current, avg_power, avg_frequency
  ///   - min_voltage, max_voltage, min_power, max_power
  ///   - reading_count
  Future<Map<String, dynamic>> getSensorStats({
    String? deviceId,
    int hours = 24,
  }) async {
    try {
      String url = "$baseUrl/sensor-readings/stats?hours=$hours";
      if (deviceId != null) {
        url += "&device_id=$deviceId";
      }

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return json['stats'] ?? {};
      } else {
        throw Exception('Failed to load statistics: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching statistics: $e');
      return {};
    }
  }

  /// Fetch latest sensor reading for a device
  ///
  /// Parameters:
  ///   - deviceId: Device identifier
  ///
  /// Returns:
  ///   - Latest SensorReading or null if no data
  Future<SensorReading?> getLatestReading(String deviceId) async {
    try {
      final readings = await getSensorReadings(deviceId: deviceId, limit: 1);
      return readings.isNotEmpty ? readings.first : null;
    } catch (e) {
      print('Error fetching latest reading: $e');
      return null;
    }
  }

  /// Fetch readings for a time range
  ///
  /// Parameters:
  ///   - deviceId: Device identifier
  ///   - hours: Number of hours in the past
  Future<List<SensorReading>> getReadingsByTimeRange({
    required String deviceId,
    required int hours,
  }) async {
    try {
      // Calculate timestamp for filtering
      final cutoffTime = DateTime.now().subtract(Duration(hours: hours));

      final readings = await getSensorReadings(
        deviceId: deviceId,
        limit: 1000, // Get more records for time range
      );

      // Filter by time on client side
      return readings.where((r) => r.createdAt.isAfter(cutoffTime)).toList();
    } catch (e) {
      print('Error fetching readings by time range: $e');
      return [];
    }
  }
}
