import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'services/csv_node_manager.dart';

// Inicia la aplicación.
void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // Configura el tema y la pantalla principal de la aplicación.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Configuración IoT en CSV',
      theme: ThemeData(
        colorScheme: .fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'Importar y exportar CSV'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  // Crea el estado que maneja los nodos y las operaciones con el CSV.
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final csvNodeManager = CsvNodeManager();
  final _ruta = TextEditingController();
  Uint8List? _csvBytes;
  List<List<dynamic>> _nodos = [
  ['ID', 'Nodo', 'Sensor'],
  ['001', 'Sala', 'Temperatura'],
];
  String _mensaje = 'Exporta los nodos de ejemplo e importa el archivo para verificar su integridad.';
  bool _procesando = false;

  // Libera el controlador del campo de ruta cuando se cierra la pantalla.
  @override
  void dispose() {
    _ruta.dispose();
    super.dispose();
  }

  // Abre el selector de archivos y guarda la ruta del CSV o sus bytes en la web.
  Future<void> _seleccionarCsv() async {
    setState(() => _procesando = true);
    try {
      final resultado = await FilePicker.platform.pickFiles(
        dialogTitle: 'Seleccionar archivo CSV',
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: kIsWeb,
      );
      if (!mounted || resultado == null) return;
      final archivo = resultado.files.single;
      final ruta = kIsWeb ? archivo.name : archivo.path;
      if (ruta == null || (kIsWeb && archivo.bytes == null)) {
        setState(() => _mensaje = 'No se pudo obtener la ruta del archivo CSV.');
        return;
      }
      setState(() {
        _csvBytes = archivo.bytes;
        _ruta.text = ruta;
        _mensaje = 'Archivo seleccionado. Pulsa Importar CSV para cargarlo.';
      });
    } catch (error) {
      if (mounted) setState(() => _mensaje = 'No se pudo seleccionar el archivo: $error');
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  // Exporta los nodos o importa un CSV verificando su integridad, y muestra el resultado.
  Future<void> _procesar(bool exportar) async {
    setState(() => _procesando = true);
    try {
      String mensaje;
      if (exportar) {
        final ruta = await csvNodeManager.exportNodesToCsv(_nodos);
        if (!mounted) return;
        _ruta.text = ruta;
        _csvBytes = null;
        mensaje = kIsWeb
            ? 'CSV enviado a descargas con checksum SHA-256. Selecciónalo para importarlo.'
            : 'CSV exportado correctamente con checksum SHA-256.';
      } else {
        if (kIsWeb && _csvBytes == null) {
          setState(() => _mensaje = 'Selecciona el archivo CSV que deseas importar.');
          return;
        }
        String ruta = _ruta.text.trim();
        if (!kIsWeb && ruta.isEmpty) {
          final dir = await getApplicationDocumentsDirectory();
          ruta = '${dir.path}/iot_nodes_config.csv';
        }
        final valido = await csvNodeManager.verifyAndImportCsv(ruta, bytes: _csvBytes);
        if (!mounted) return;
        _ruta.text = ruta;
        if (valido) {
          _nodos = csvNodeManager.importedRows;
          mensaje = 'CSV importado correctamente. Integridad SHA-256 verificada.';
        } else {
          mensaje = 'No se importó el CSV: no existe, fue alterado o no tiene un checksum válido.';
        }
      }
      if (mounted) setState(() => _mensaje = mensaje);
    } catch (error) {
      if (mounted) setState(() => _mensaje = 'No se pudo completar la operación: $error');
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  // Muestra los nodos, el archivo seleccionado y los botones para importar y exportar.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text('Configuración de nodos IoT', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              ..._nodos.map((fila) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(fila.join(' | ')),
              )),
              const SizedBox(height: 20),
              TextField(
                controller: _ruta,
                enabled: !_procesando,
                readOnly: true,
                onTap: _seleccionarCsv,
                decoration: InputDecoration(
                  labelText: 'Ruta del archivo CSV',
                  hintText: 'Selecciona un archivo CSV',
                  helperText: kIsWeb
                      ? 'Toca para elegir un CSV de tu dispositivo.'
                      : 'Toca para elegir un CSV. Vacía: se usa el archivo exportado.',
                  helperMaxLines: 2,
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    tooltip: 'Seleccionar archivo CSV',
                    onPressed: _procesando ? null : _seleccionarCsv,
                    icon: const Icon(Icons.folder_open),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.icon(
                    onPressed: _procesando ? null : () => _procesar(true),
                    icon: const Icon(Icons.download),
                    label: const Text('Exportar CSV'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _procesando ? null : () => _procesar(false),
                    icon: const Icon(Icons.upload),
                    label: const Text('Importar CSV'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (_procesando) const LinearProgressIndicator(),
              const SizedBox(height: 12),
              SelectableText(_mensaje),
            ],
          ),
        ),
      ),
    );
  }
}
