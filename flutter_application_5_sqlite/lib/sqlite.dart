// Estas librerías me permiten detectar si estoy en web y crear la interfaz.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
// Uso path para armar la ruta de la base y sqflite para trabajar con SQLite.
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
// Esta versión permite usar SQLite desde el navegador.
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

// Esta clase representa una lectura con su tipo de sensor, valor y fecha.
class SensorReading {
  // El id puede estar vacío al crear la lectura porque SQLite lo genera.
  final int? id;
  final String sensorType;
  final double value;
  final String timestamp;

  // Para crear una lectura necesito el tipo, el valor y la fecha.
  const SensorReading({
    this.id,
    required this.sensorType,
    required this.value,
    required this.timestamp,
  });

  // Convierto la lectura a un mapa para guardarla en la tabla.
  Map<String, Object?> toMap() => {
    // Solo incluyo el id si la lectura ya tiene uno.
    if (id != null) 'id': id,
    'sensorType': sensorType,
    'value': value,
    'timestamp': timestamp,
  };

  // Con los datos que devuelve SQLite vuelvo a construir una lectura.
  factory SensorReading.fromMap(Map<String, Object?> map) => SensorReading(
    id: map['id'] as int?,
    sensorType: map['sensorType'] as String,
    // Lo convierto a double porque SQLite también puede devolver un entero.
    value: (map['value'] as num).toDouble(),
    timestamp: map['timestamp'] as String,
  );
}

// Aquí reúno las operaciones de la base para usarlas desde la pantalla.
class DatabaseHelper {
  // Comparto una sola instancia para manejar el acceso a la base.
  static final DatabaseHelper instance = DatabaseHelper._init();
  static const fileName = 'iot_local.db';
  Future<Database>? _database;

  // El constructor privado evita crear otras instancias desde fuera.
  DatabaseHelper._init();

  // Abro la base la primera vez y reutilizo esa misma apertura después.
  Future<Database> get database => _database ??= _initDB();

  Future<Database> _initDB() async {
    try {
      // Elijo la versión de SQLite según si la app corre en web o en móvil.
      final factory = kIsWeb ? databaseFactoryFfiWeb : databaseFactory;
      // En web uso el nombre; en móvil busco la carpeta de bases de datos.
      final path = kIsWeb
          ? fileName
          : p.join(await factory.getDatabasesPath(), fileName);
      return await factory.openDatabase(
        path,
        options: OpenDatabaseOptions(
          // Esta versión sirve para controlar futuros cambios en la estructura.
          version: 1,
          onConfigure: (db) async {
            // Activo la validación de relaciones si después agrego otras tablas.
            await db.execute('PRAGMA foreign_keys = ON');
          },
          // Creo la tabla solo cuando la base se abre por primera vez.
          // El id aumenta solo y los demás campos son obligatorios.
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
      // Si falla la apertura, permito volver a intentarlo y paso el error.
      _database = null;
      rethrow;
    }
  }

  // Guardo una lectura y devuelvo el id que le asignó SQLite.
  Future<int> insertReading(SensorReading reading) async {
    final db = await database;
    return db.insert('readings', reading.toMap());
  }

  // Guardo varias lecturas juntas: si alguna falla, no se guarda ninguna.
  Future<void> insertBatchReadings(List<SensorReading> readings) async {
    final db = await database;
    await db.transaction((txn) async {
      // Agrupo las inserciones para ejecutarlas en un solo lote.
      final batch = txn.batch();
      for (final reading in readings) {
        batch.insert('readings', reading.toMap());
      }
      // Ejecuto el lote sin pedir el resultado individual de cada inserción.
      await batch.commit(noResult: true);
    });
  }

  // Busco las lecturas del tipo elegido y muestro primero las de mayor id.
  Future<List<SensorReading>> getReadingsByType(String type) async {
    final db = await database;
    final result = await db.query(
      'readings',
      // Paso el tipo aparte para no pegarlo directamente en la consulta SQL.
      where: 'sensorType = ?',
      whereArgs: [type],
      orderBy: 'id DESC',
    );
    // Transformo cada fila en una lectura que la pantalla pueda mostrar.
    return result.map(SensorReading.fromMap).toList();
  }
}

// Esta pantalla permite guardar lecturas y consultar las que ya tengo.
// Tiene estado porque la lista y el filtro cambian al usarla.
class SqlitePage extends StatefulWidget {
  const SqlitePage({super.key});

  @override
  State<SqlitePage> createState() => _SqlitePageState();
}

class _SqlitePageState extends State<SqlitePage> {
  // Con este controlador leo y limpio el valor escrito en el campo de texto.
  final _valueController = TextEditingController();
  // Empiezo con temperatura como tipo de lectura y filtro seleccionado.
  String _type = 'temperature';
  // Aquí guardo las lecturas consultadas y el estado de carga o error.
  List<SensorReading> _readings = [];
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Consulto los datos guardados en cuanto se abre la pantalla.
    _loadReadings();
  }

  @override
  void dispose() {
    // Libero el controlador cuando esta pantalla deja de usarse.
    _valueController.dispose();
    super.dispose();
  }

  // Actualizo la lista y, si recibo una función de guardado, la ejecuto antes.
  Future<void> _loadReadings({Future<void> Function()? save}) async {
    // Marco que hay una operación en curso y borro el error anterior.
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (save != null) await save();
      final readings = await DatabaseHelper.instance.getReadingsByType(_type);
      // Si la pantalla ya se cerró, no intento actualizar su estado.
      if (!mounted) return;
      setState(() => _readings = readings);
    } catch (e) {
      // Guardo el mensaje de error para mostrarlo en la pantalla.
      if (mounted) setState(() => _error = 'No se pudo acceder a SQLite: $e');
    } finally {
      // Al terminar, vuelvo a habilitar los controles aunque haya un error.
      if (mounted) setState(() => _busy = false);
    }
  }

  // Reviso el valor escrito antes de guardar una nueva lectura.
  Future<void> _saveReading() async {
    // Acepto punto o coma decimal y quito los espacios de los extremos.
    final value = double.tryParse(
      _valueController.text.trim().replaceAll(',', '.'),
    );
    // Si el texto no es un número válido y finito, aviso y detengo el guardado.
    if (value == null || !value.isFinite) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escribe un valor numerico valido.')),
      );
      return;
    }
    // Guardo con el tipo seleccionado y la fecha actual, y actualizo la lista.
    await _loadReadings(
      save: () async {
        await DatabaseHelper.instance.insertReading(
          SensorReading(
            sensorType: _type,
            value: value,
            timestamp: DateTime.now().toIso8601String(),
          ),
        );
        // Dejo el campo vacío después de guardar la lectura.
        _valueController.clear();
      },
    );
  }

  // Creo tres lecturas de ejemplo para probar el guardado por lote.
  Future<void> _saveBatch() async {
    // Uso la misma fecha y hora para las tres lecturas.
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
    // Armo la pantalla con una barra de título y el contenido centrado.
    return Scaffold(
      appBar: AppBar(title: const Text('Lecturas de sensores - SQLite')),
      body: Center(
        child: ConstrainedBox(
          // Limito el ancho para que el formulario no se estire demasiado.
          constraints: const BoxConstraints(maxWidth: 640),
          // Permito desplazar el contenido cuando hay muchas lecturas.
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Muestro qué base uso y dónde se guarda si estoy en web.
              const Text('Base local: iot_local.db'),
              if (kIsWeb)
                const Text('Chrome guarda la base en IndexedDB de este sitio.'),
              const SizedBox(height: 20),
              // El tipo elegido sirve tanto para guardar como para filtrar.
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
                // Bloqueo el selector mientras trabajo con la base.
                onChanged: _busy
                    ? null
                    : (value) {
                        if (value == null) return;
                        setState(() => _type = value);
                        _loadReadings();
                      },
              ),
              const SizedBox(height: 12),
              // Aquí escribo el valor de la lectura con un teclado numérico.
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
              // Estos botones guardan una lectura, insertan el lote o consultan.
              // Wrap los acomoda en otra fila si no hay suficiente espacio.
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
              // Muestro el avance de carga y cualquier error que haya ocurrido.
              if (_busy) const LinearProgressIndicator(),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              // Cuento solo las lecturas del filtro seleccionado.
              Text(
                'Lecturas guardadas: ${_readings.length}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              // Si la consulta terminó sin datos, muestro un aviso.
              if (!_busy && _error == null && _readings.isEmpty)
                const Text('Todavia no hay lecturas de este tipo.'),
              // Muestro cada lectura con su id, valor, unidad y fecha.
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
