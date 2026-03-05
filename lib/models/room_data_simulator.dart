import 'dart:math';

/// Room data simulation model
/// Generates realistic sensor data for multiple rooms across different categories
class RoomDataSimulator {
  static final Random _random = Random();

  /// Room structure: stores metadata about rooms
  static final Map<String, Map<String, dynamic>> _roomStructure = {
    // Floor 1 - Classrooms
    'Floor-1-Class-101': {
      'floor': 'Floor 1',
      'category': 'Class',
      'name': 'Class 101',
      'baseLoad': 2.5,
      'hasRealData': true,
      'deviceId': 'ESP32-CLASS-101',
    },
    'Floor-1-Class-102': {
      'floor': 'Floor 1',
      'category': 'Class',
      'name': 'Class 102',
      'baseLoad': 2.3,
    },
    'Floor-1-Class-103': {
      'floor': 'Floor 1',
      'category': 'Class',
      'name': 'Class 103',
      'baseLoad': 2.4,
    },

    // Floor 1 - Labs
    'Floor-1-Lab-1': {
      'floor': 'Floor 1',
      'category': 'Lab',
      'name': 'Computer Lab 1',
      'baseLoad': 4.2,
    },
    'Floor-1-Lab-2': {
      'floor': 'Floor 1',
      'category': 'Lab',
      'name': 'Computer Lab 2',
      'baseLoad': 4.0,
    },

    // Floor 1 - Staffroom
    'Floor-1-StaffRoom': {
      'floor': 'Floor 1',
      'category': 'StaffRoom',
      'name': 'Staff Room',
      'baseLoad': 1.8,
    },

    // Floor 2 - Classrooms
    'Floor-2-Class-201': {
      'floor': 'Floor 2',
      'category': 'Class',
      'name': 'Class 201',
      'baseLoad': 2.5,
    },
    'Floor-2-Class-202': {
      'floor': 'Floor 2',
      'category': 'Class',
      'name': 'Class 202',
      'baseLoad': 2.6,
    },
    'Floor-2-Class-203': {
      'floor': 'Floor 2',
      'category': 'Class',
      'name': 'Class 203',
      'baseLoad': 2.4,
    },

    // Floor 2 - Labs
    'Floor-2-Lab-3': {
      'floor': 'Floor 2',
      'category': 'Lab',
      'name': 'Computer Lab 3',
      'baseLoad': 4.1,
    },
    'Floor-2-Lab-4': {
      'floor': 'Floor 2',
      'category': 'Lab',
      'name': 'Computer Lab 4',
      'baseLoad': 3.9,
    },

    // Floor 2 - Staffroom
    'Floor-2-StaffRoom': {
      'floor': 'Floor 2',
      'category': 'StaffRoom',
      'name': 'Staff Room Floor 2',
      'baseLoad': 1.9,
    },

    // Floor 3 - Classrooms
    'Floor-3-Class-301': {
      'floor': 'Floor 3',
      'category': 'Class',
      'name': 'Class 301',
      'baseLoad': 2.5,
    },
    'Floor-3-Class-302': {
      'floor': 'Floor 3',
      'category': 'Class',
      'name': 'Class 302',
      'baseLoad': 2.3,
    },

    // Floor 3 - Labs
    'Floor-3-Lab-5': {
      'floor': 'Floor 3',
      'category': 'Lab',
      'name': 'Electronics Lab',
      'baseLoad': 4.3,
    },

    // Floor 3 - Staffroom
    'Floor-3-StaffRoom': {
      'floor': 'Floor 3',
      'category': 'StaffRoom',
      'name': 'Staff Room Floor 3',
      'baseLoad': 2.0,
    },
  };

  /// Get all available floors
  static List<String> getFloors() {
    final Set<String> floors = {};
    _roomStructure.forEach((key, data) {
      floors.add(data['floor'] as String);
    });
    return floors.toList()..sort();
  }

  /// Get rooms for a specific floor (includes all categories)
  static List<Map<String, dynamic>> getRoomsByFloor(String floor) {
    final List<Map<String, dynamic>> rooms = [];
    _roomStructure.forEach((key, data) {
      if (data['floor'] == floor) {
        rooms.add({
          'id': key,
          'name': data['name'],
          'category': data['category'],
          'floor': data['floor'],
        });
      }
    });
    return rooms;
  }

  /// Get all classes
  static List<Map<String, dynamic>> getAllClasses() {
    final List<Map<String, dynamic>> rooms = [];
    _roomStructure.forEach((key, data) {
      if (data['category'] == 'Class') {
        rooms.add({
          'id': key,
          'name': data['name'],
          'category': data['category'],
          'floor': data['floor'],
        });
      }
    });
    return rooms;
  }

  /// Get all labs and staff rooms
  static List<Map<String, dynamic>> getLabsAndStaffRooms() {
    final List<Map<String, dynamic>> rooms = [];
    _roomStructure.forEach((key, data) {
      if (data['category'] == 'Lab' || data['category'] == 'StaffRoom') {
        rooms.add({
          'id': key,
          'name': data['name'],
          'category': data['category'],
          'floor': data['floor'],
        });
      }
    });
    return rooms;
  }

  /// Get all rooms
  static List<Map<String, dynamic>> getAllRooms() {
    final List<Map<String, dynamic>> rooms = [];
    _roomStructure.forEach((key, data) {
      rooms.add({
        'id': key,
        'name': data['name'],
        'category': data['category'],
        'floor': data['floor'],
      });
    });
    return rooms;
  }

  /// Generate realistic sensor data for a specific room
  /// Returns: {'timestamp', 'voltage', 'current', 'power', 'energy', 'frequency', 'power_factor'}
  static Map<String, dynamic> generateSensorData(String roomId) {
    if (!_roomStructure.containsKey(roomId)) {
      return _generateDefaultSensorData();
    }

    final roomData = _roomStructure[roomId]!;
    final baseLoad = roomData['baseLoad'] as double;

    // Add some variance to the load (±20%)
    final variance = baseLoad * (0.8 + _random.nextDouble() * 0.4);

    // Standard electrical values (typical for AC supply in India)
    const voltage = 230.0; // Volts
    const frequency = 50.0; // Hz
    const powerFactor = 0.95; // Typical PF

    // Calculate current from power and voltage
    // P = V * I * PF => I = P / (V * PF)
    final powerW = variance * 1000; // Convert kW to W
    final currentA = powerW / (voltage * powerFactor);

    // Energy (simulated cumulative consumption)
    final energyKwh =
        (variance * DateTime.now().hour) + _random.nextDouble() * 10;

    return {
      'timestamp': DateTime.now().toIso8601String(),
      'voltage': voltage,
      'current': double.parse(currentA.toStringAsFixed(2)),
      'power': double.parse(variance.toStringAsFixed(2)), // in kW
      'energy': double.parse(energyKwh.toStringAsFixed(2)), // in kWh
      'frequency': frequency,
      'power_factor': powerFactor,
      'room_id': roomId,
      'room_name': roomData['name'],
    };
  }

  /// Generate default sensor data when room is not found
  static Map<String, dynamic> _generateDefaultSensorData() {
    return {
      'timestamp': DateTime.now().toIso8601String(),
      'voltage': 230.0,
      'current': 0.0,
      'power': 0.0,
      'energy': 0.0,
      'frequency': 50.0,
      'power_factor': 0.95,
    };
  }

  /// Generate time-series data for charts
  /// Returns list of data points over time
  static List<Map<String, dynamic>> generateTimeSeriesData(
    String roomId,
    int numberOfPoints,
  ) {
    if (!_roomStructure.containsKey(roomId)) {
      return [];
    }

    final roomData = _roomStructure[roomId]!;
    final baseLoad = roomData['baseLoad'] as double;
    final List<Map<String, dynamic>> data = [];

    for (int i = 0; i < numberOfPoints; i++) {
      // Simulate time-based usage patterns
      // Higher usage during day, lower during night
      final hour = (i * 24 / numberOfPoints).toInt() % 24;
      final dayloadFactor = _getDayloadFactor(hour);
      final variance =
          baseLoad * dayloadFactor * (0.8 + _random.nextDouble() * 0.4);

      const voltage = 230.0;
      const frequency = 50.0;
      const powerFactor = 0.95;

      final powerW = variance * 1000;
      final currentA = powerW / (voltage * powerFactor);
      final energyKwh = (variance * (i + 1)) / numberOfPoints;

      data.add({
        'timestamp':
            DateTime.now()
                .subtract(Duration(hours: numberOfPoints - i))
                .toIso8601String(),
        'voltage': voltage,
        'current': double.parse(currentA.toStringAsFixed(2)),
        'power': double.parse(variance.toStringAsFixed(2)),
        'energy': double.parse(energyKwh.toStringAsFixed(2)),
        'frequency': frequency,
        'power_factor': powerFactor,
        'room_id': roomId,
        'room_name': roomData['name'],
      });
    }

    return data;
  }

  /// Helper to simulate day/night load patterns
  static double _getDayloadFactor(int hour) {
    // Night: 20:00 - 08:00 (0.4x load)
    // Morning: 08:00 - 10:00 (0.8x load)
    // Day: 10:00 - 17:00 (1.2x load - peak)
    // Evening: 17:00 - 20:00 (0.9x load)

    if (hour >= 20 || hour < 8) {
      return 0.4;
    } else if (hour >= 8 && hour < 10) {
      return 0.8;
    } else if (hour >= 10 && hour < 17) {
      return 1.2;
    } else {
      return 0.9;
    }
  }

  /// Get second dropdown options based on first dropdown selection
  static List<Map<String, dynamic>> getSecondDropdownOptions(
    String firstDropdownValue,
  ) {
    switch (firstDropdownValue) {
      case 'floorwise':
        // Return list of floors
        return getFloors()
            .map((floor) => {'id': floor, 'name': floor})
            .toList();

      case 'classwise':
        // Return all classes
        return getAllClasses();

      case 'all':
        // Return all rooms
        return getAllRooms();

      case 'others':
        // Return labs and staff rooms
        return getLabsAndStaffRooms();

      default:
        return [];
    }
  }

  /// Get classes for a specific floor (for third dropdown in floorwise selection)
  static List<Map<String, dynamic>> getClassesByFloor(String floor) {
    final List<Map<String, dynamic>> classes = [];
    _roomStructure.forEach((key, data) {
      if (data['floor'] == floor && data['category'] == 'Class') {
        classes.add({
          'id': key,
          'name': data['name'],
          'category': data['category'],
          'floor': data['floor'],
        });
      }
    });
    return classes;
  }

  /// Get all rooms (classes, labs, staff rooms) for a specific floor
  static List<Map<String, dynamic>> getAllRoomsByFloor(String floor) {
    final List<Map<String, dynamic>> rooms = [];
    _roomStructure.forEach((key, data) {
      if (data['floor'] == floor) {
        rooms.add({
          'id': key,
          'name': data['name'],
          'category': data['category'],
          'floor': data['floor'],
        });
      }
    });
    return rooms;
  }

  /// Check if a room has real database data
  static bool hasRealDatabaseData(String roomId) {
    if (!_roomStructure.containsKey(roomId)) {
      return false;
    }
    return (_roomStructure[roomId]?['hasRealData'] as bool?) ?? false;
  }

  /// Get the device ID for a room with real database data
  static String? getDeviceId(String roomId) {
    if (!hasRealDatabaseData(roomId)) {
      return null;
    }
    return _roomStructure[roomId]?['deviceId'] as String?;
  }
}
