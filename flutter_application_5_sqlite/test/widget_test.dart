import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_4_sqlite/sqlite.dart';

void main() {
  test('Una lectura nueva omite el id para usar AUTOINCREMENT', () {
    const reading = SensorReading(
      sensorType: 'temperature',
      value: 24.5,
      timestamp: '2026-10-07T12:00:00',
    );
    expect(reading.toMap().containsKey('id'), isFalse);
    final restored = SensorReading.fromMap({...reading.toMap(), 'id': 1});
    expect(restored.id, 1);
    expect(restored.sensorType, reading.sensorType);
    expect(restored.value, reading.value);
    expect(restored.timestamp, reading.timestamp);
  });

  test('El mapeo admite valores SQLite enteros y decimales', () {
    final reading = SensorReading.fromMap({
      'id': 2,
      'sensorType': 'humidity',
      'value': 60,
      'timestamp': '2026-10-07T12:00:00',
    });
    expect(reading.value, 60.0);
  });
}
