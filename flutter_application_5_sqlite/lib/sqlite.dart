import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

// 1. Modelo: convierte una lectura a un mapa y viceversa.
class SensorReading {
  final int? id;
  final String sensorType;
  final double value;
  final String timestamp;

  const SensorReading({
    this.id,
    required this.sensorType,
    required this.value,
    required this.timestamp,
  });

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'sensorType': sensorType,
    'value': value,
    'timestamp': timestamp,
  };

  factory SensorReading.fromMap(Map<String, Object?> map) => SensorReading(
    id: map['id'] as int?,
    sensorType: map['sensorType'] as String,
    value: (map['value'] as num).toDouble(),
    timestamp: map['timestamp'] as String,
  );
}

// 2. Singleton y DAO: centraliza la conexion y el acceso a los datos.
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static const fileName = 'iot_local.db';
  Future<Database>? _database;

  DatabaseHelper._init();

  // Compartir el Future evita abrir varias conexiones al mismo tiempo.
  Future<Database> get database => _database ??= _initDB();

  Future<Database> _initDB() async {
    try {
      // En Chrome, SQLite se ejecuta con WebAssembly y persiste en IndexedDB.
      final factory = kIsWeb ? databaseFactoryFfiWeb : databaseFactory;
      final path = kIsWeb
          ? fileName
          : p.join(await factory.getDatabasesPath(), fileName);
      return await factory.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 1,
          onConfigure: (db) async {
            await db.execute('PRAGMA foreign_keys = ON');
          },
          onCreate: (db, version) async {
            await db.execute('''
              CREATE TABLE readings (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                sensorType TEXT NOT NULL,
                value REAL NOT NULL,
                timestamp TEXT NOT NULL
              )
            ''');
          },
        ),
      );
    } catch (_) {
      _database = null;
      rethrow;
    }
  }

  // 3. Insercion parametrizada: los valores no se concatenan al SQL.
  Future<int> insertReading(SensorReading reading) async {
    final db = await database;
    return db.insert('readings', reading.toMap());
  }

  // 4. Transaccion: se guarda todo el lote o se revierte si algo falla.
  Future<void> insertBatchReadings(List<SensorReading> readings) async {
    final db = await database;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final reading in readings) {
        batch.insert('readings', reading.toMap());
      }
      await batch.commit(noResult: true);
    });
  }

  // 5. Consulta segura: el signo ? recibe el valor de whereArgs.
  Future<List<SensorReading>> getReadingsByType(String type) async {
    final db = await database;
    final result = await db.query(
      'readings',
      where: 'sensorType = ?',
      whereArgs: [type],
      orderBy: 'id DESC',
    );
    return result.map(SensorReading.fromMap).toList();
  }
}

// Pantalla sencilla para probar el DAO con datos locales.
class SqlitePage extends StatefulWidget {
  const SqlitePage({super.key});

  @override
  State<SqlitePage> createState() => _SqlitePageState();
}

class _SqlitePageState extends State<SqlitePage> {
  final _valueController = TextEditingController();
  String _type = 'temperature';
  List<SensorReading> _readings = [];
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadReadings();
  }

  @override
  void dispose() {
    _valueController.dispose();
    super.dispose();
  }

  // Deshabilita los botones mientras se consulta o escribe en SQLite.
  Future<void> _loadReadings({Future<void> Function()? save}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (save != null) await save();
      final readings = await DatabaseHelper.instance.getReadingsByType(_type);
      if (!mounted) return;
      setState(() => _readings = readings);
    } catch (e) {
      if (mounted) setState(() => _error = 'No se pudo acceder a SQLite: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveReading() async {
    final value = double.tryParse(
      _valueController.text.trim().replaceAll(',', '.'),
    );
    if (value == null || !value.isFinite) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escribe un valor numerico valido.')),
      );
      return;
    }
    await _loadReadings(
      save: () async {
        await DatabaseHelper.instance.insertReading(
          SensorReading(
            sensorType: _type,
            value: value,
            timestamp: DateTime.now().toIso8601String(),
          ),
        );
        _valueController.clear();
      },
    );
  }

  Future<void> _saveBatch() async {
    final timestamp = DateTime.now().toIso8601String();
    await _loadReadings(
      save: () => DatabaseHelper.instance.insertBatchReadings([
        SensorReading(
          sensorType: 'temperature',
          value: 24.5,
          timestamp: timestamp,
        ),
        SensorReading(
          sensorType: 'temperature',
          value: 25,
          timestamp: timestamp,
        ),
        SensorReading(sensorType: 'humidity', value: 60, timestamp: timestamp),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lecturas de sensores - SQLite')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text('Base local: iot_local.db'),
              if (kIsWeb)
                const Text('Chrome guarda la base en IndexedDB de este sitio.'),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                initialValue: _type,
                decoration: const InputDecoration(
                  labelText: 'Tipo de sensor / filtro',
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'temperature',
                    child: Text('Temperatura'),
                  ),
                  DropdownMenuItem(value: 'humidity', child: Text('Humedad')),
                ],
                onChanged: _busy
                    ? null
                    : (value) {
                        if (value == null) return;
                        setState(() => _type = value);
                        _loadReadings();
                      },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _valueController,
                enabled: !_busy,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Valor',
                  hintText: 'Ejemplo: 24.5',
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton(
                    onPressed: _busy ? null : _saveReading,
                    child: const Text('Guardar lectura'),
                  ),
                  OutlinedButton(
                    onPressed: _busy ? null : _saveBatch,
                    child: const Text('Insertar lote de ejemplo'),
                  ),
                  TextButton(
                    onPressed: _busy ? null : () => _loadReadings(),
                    child: const Text('Consultar'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'El lote guarda 2 temperaturas y 1 humedad en una transaccion. Cambia el filtro para consultarlas.',
              ),
              const SizedBox(height: 20),
              if (_busy) const LinearProgressIndicator(),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              Text(
                'Lecturas guardadas: ${_readings.length}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (!_busy && _error == null && _readings.isEmpty)
                const Text('Todavia no hay lecturas de este tipo.'),
              for (final reading in _readings)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.sensors),
                  title: Text(
                    '#${reading.id}: ${reading.value} ${reading.sensorType == 'temperature' ? '°C' : '%'}',
                  ),
                  subtitle: Text(reading.timestamp),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
