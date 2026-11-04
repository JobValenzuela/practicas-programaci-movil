import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:nfc_manager/nfc_manager.dart';

void main() => runApp(const GeoNfcLabApp());

class GeoNfcLabApp extends StatelessWidget {
  const GeoNfcLabApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GeoNFC Lab',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB)),
        scaffoldBackgroundColor: const Color(0xFFF7F9FC),
      ),
      home: const LabScreen(),
    );
  }
}

class VirtualTag {
  final String code;
  final String name;
  final String category;
  final String action;
  final IconData icon;

  const VirtualTag(this.code, this.name, this.category, this.action, this.icon);
}

const virtualTags = [
  VirtualTag('PROD-023', 'Producto de inventario', 'Inventarios',
      'Consultar información y existencias', Icons.inventory_2_outlined),
  VirtualTag('EMP-007', 'Credencial de empleado', 'Personal',
      'Registrar asistencia', Icons.badge_outlined),
  VirtualTag('SUC-001', 'Punto de entrega', 'Logística',
      'Registrar visita o entrega', Icons.local_shipping_outlined),
];

class EventLog {
  final String title;
  final String code;
  final String action;
  final String origin;
  final DateTime when;
  final double? latitude;
  final double? longitude;

  const EventLog({
    required this.title,
    required this.code,
    required this.action,
    required this.origin,
    required this.when,
    this.latitude,
    this.longitude,
  });
}

class LabScreen extends StatefulWidget {
  const LabScreen({super.key});

  @override
  State<LabScreen> createState() => _LabScreenState();
}

class _LabScreenState extends State<LabScreen> {
  int currentTab = 0;
  Position? position;
  double? referenceLat;
  double? referenceLng;
  bool locating = false;
  bool scanning = false;
  String gpsStatus = 'Ubicación todavía no consultada';
  String nfcStatus = 'Comprobando disponibilidad NFC...';
  NfcAvailability? nfcAvailability;
  String lastScan = 'Sin lecturas';
  String lastScanMode = '—';
  final List<EventLog> logs = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => checkNfc());
  }

  bool get supportsNfcPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> checkNfc() async {
    if (!supportsNfcPlatform) {
      if (!mounted) return;
      setState(() {
        nfcAvailability = NfcAvailability.unsupported;
        nfcStatus = 'Consulta NFC disponible solo en Android o iOS';
      });
      return;
    }
    try {
      final value = await NfcManager.instance.checkAvailability();
      if (!mounted) return;
      setState(() {
        nfcAvailability = value;
        nfcStatus = switch (value) {
          NfcAvailability.enabled => 'NFC disponible y activado',
          NfcAvailability.disabled => 'Este teléfono tiene NFC, pero está desactivado',
          NfcAvailability.unsupported => 'Este teléfono no admite NFC',
        };
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => nfcStatus = 'No se pudo comprobar NFC: $e');
    }
  }

  Future<void> getLocation() async {
    if (locating) return;
    setState(() {
      locating = true;
      gpsStatus = 'Solicitando ubicación del teléfono...';
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw Exception('Activa la ubicación del dispositivo.');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        throw Exception('Permiso de ubicación denegado.');
      }
      if (permission == LocationPermission.deniedForever) {
        throw Exception('Permiso bloqueado. Habilítalo en Ajustes de la app.');
      }
      final result = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
        timeLimit: const Duration(seconds: 20),
      );
      if (!mounted) return;
      setState(() {
        position = result;
        gpsStatus = 'Ubicación obtenida correctamente';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => gpsStatus = 'No se obtuvo ubicación: $e');
    } finally {
      if (mounted) setState(() => locating = false);
    }
  }

  void markReference() {
    if (position == null) return;
    setState(() {
      referenceLat = position!.latitude;
      referenceLng = position!.longitude;
    });
    notify('Punto de referencia guardado. Actualiza tu GPS para medir distancia.');
  }

  void addLog({
    required String title,
    required String code,
    required String action,
    required String origin,
  }) {
    setState(() {
      lastScan = '$title ($code)';
      lastScanMode = origin;
      logs.insert(0, EventLog(
        title: title,
        code: code,
        action: action,
        origin: origin,
        when: DateTime.now(),
        latitude: position?.latitude,
        longitude: position?.longitude,
      ));
    });
  }

  void simulate(VirtualTag tag) {
    addLog(
      title: tag.name,
      code: tag.code,
      action: tag.action,
      origin: 'SIMULACIÓN (no es lectura NFC real)',
    );
    notify('Simulación: ${tag.name} identificado');
  }

  Future<void> startNfcReading() async {
    if (scanning || nfcAvailability != NfcAvailability.enabled) {
      notify('Primero activa NFC y comprueba su disponibilidad.');
      return;
    }
    setState(() => scanning = true);
    try {
      await NfcManager.instance.startSession(
        pollingOptions: {NfcPollingOption.iso14443, NfcPollingOption.iso15693},
        onDiscovered: (NfcTag tag) async {
          if (!mounted) return;
          // Esta demo confirma la detección real, no interpreta ni valida
          // datos de tarjetas bancarias, credenciales u otros formatos.
          addLog(
            title: 'Etiqueta física detectada',
            code: 'NFC-REAL',
            action: 'NFC real detectado; lectura de contenido no implementada',
            origin: 'HARDWARE NFC REAL',
          );
          try {
            await NfcManager.instance.stopSession();
          } catch (_) {}
          if (mounted) {
            setState(() => scanning = false);
            notify('El teléfono detectó una etiqueta física.');
          }
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => scanning = false);
      notify('No se pudo iniciar la lectura: $e');
    }
  }

  Future<void> stopNfcReading() async {
    try {
      await NfcManager.instance.stopSession();
    } catch (_) {}
    if (mounted) setState(() => scanning = false);
  }

  void notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    if (scanning) {
      // La sesión NFC se cierra al salir. No hace falta esperar en dispose.
      NfcManager.instance.stopSession().catchError((Object _) {});
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const titles = ['Geolocalización', 'Lector NFC', 'Historial'];
    return Scaffold(
      appBar: AppBar(
        title: const Text('GeoNFC Lab', style: TextStyle(fontWeight: FontWeight.w800)),
        centerTitle: false,
        backgroundColor: const Color(0xFFF7F9FC),
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Text(titles[currentTab],
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(
              switch (currentTab) {
                0 => 'GPS real: ubicación, precisión y distancia.',
                1 => 'Detección de NFC real + etiquetas virtuales.',
                _ => 'Los eventos se guardan en memoria durante esta sesión.',
              },
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 16),
            if (currentTab == 0) gpsPage(),
            if (currentTab == 1) nfcPage(),
            if (currentTab == 2) historyPage(),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentTab,
        onDestinationSelected: (index) => setState(() => currentTab = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.my_location), label: 'GPS'),
          NavigationDestination(icon: Icon(Icons.nfc), label: 'NFC'),
          NavigationDestination(icon: Icon(Icons.history), label: 'Historial'),
        ],
      ),
    );
  }

  Widget panel({required Widget child}) => Card(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: Colors.blueGrey.shade50),
        ),
        child: Padding(padding: const EdgeInsets.all(18), child: child),
      );

  Widget gpsPage() {
    double? meters;
    if (position != null && referenceLat != null && referenceLng != null) {
      meters = Geolocator.distanceBetween(referenceLat!, referenceLng!,
          position!.latitude, position!.longitude);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [Icon(Icons.satellite_alt, color: Colors.blue),
          SizedBox(width: 8), Text('Ubicación del dispositivo',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))]),
        const SizedBox(height: 12),
        Text(gpsStatus),
        const SizedBox(height: 12),
        if (position != null) ...[
          SelectableText('Latitud: ${position!.latitude.toStringAsFixed(6)}'),
          SelectableText('Longitud: ${position!.longitude.toStringAsFixed(6)}'),
          Text('Precisión reportada: ±${position!.accuracy.toStringAsFixed(1)} m'),
          const SizedBox(height: 10),
        ],
        FilledButton.icon(
          onPressed: locating ? null : getLocation,
          icon: const Icon(Icons.my_location),
          label: Text(locating ? 'Consultando ubicación...' : 'Obtener / actualizar GPS'),
        ),
      ])),
      panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Demostración de geocerca (100 m)',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('Guarda un punto de referencia y vuelve a obtener tu ubicación para medir la distancia.'),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: position == null ? null : markReference,
          icon: const Icon(Icons.place_outlined),
          label: const Text('Marcar mi posición como referencia'),
        ),
        if (meters != null) ...[
          const SizedBox(height: 12),
          Text('Distancia estimada: ${meters.toStringAsFixed(1)} metros',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(meters <= 100 ? 'DENTRO de la zona de 100 m' : 'FUERA de la zona de 100 m',
              style: TextStyle(color: meters <= 100 ? Colors.green.shade700 : Colors.red.shade700,
                  fontWeight: FontWeight.bold)),
          const Text('La precisión GPS puede afectar los resultados cerca del límite.',
              style: TextStyle(fontSize: 12)),
        ],
      ])),
    ]);
  }

  Widget nfcPage() {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [Icon(Icons.nfc, color: Colors.blue), SizedBox(width: 8),
          Text('NFC físico', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))]),
        const SizedBox(height: 8),
        Text(nfcStatus),
        const SizedBox(height: 12),
        OutlinedButton.icon(onPressed: checkNfc, icon: const Icon(Icons.refresh),
          label: const Text('Verificar NFC de este celular')),
        const SizedBox(height: 6),
        if (scanning)
          OutlinedButton.icon(onPressed: stopNfcReading,
            icon: const Icon(Icons.close), label: const Text('Cancelar lectura'))
        else
          FilledButton.icon(
            onPressed: nfcAvailability == NfcAvailability.enabled ? startNfcReading : null,
            icon: const Icon(Icons.sensors), label: const Text('Iniciar lectura NFC REAL')),
        if (scanning) const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text('Acerca una etiqueta física compatible al teléfono...'),
        ),
      ])),
      const SizedBox(height: 4),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Text('ETIQUETAS VIRTUALES · SIMULACIÓN',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Colors.blueGrey)),
      ),
      const Text('Al tocar una tarjeta se ejecuta la lógica de la app como si recibiera ese identificador por NFC. No se usa radio NFC.'),
      const SizedBox(height: 8),
      ...virtualTags.map((tag) => panel(child: Row(children: [
        CircleAvatar(child: Icon(tag.icon)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tag.name, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text('${tag.code} · ${tag.category}', style: const TextStyle(fontSize: 12)),
          Text(tag.action, style: const TextStyle(fontSize: 12)),
        ])),
        IconButton(tooltip: 'Simular lectura', onPressed: () => simulate(tag),
            icon: const Icon(Icons.play_circle_fill, color: Colors.blue)),
      ]))),
      panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Último evento', style: TextStyle(fontWeight: FontWeight.bold)),
        Text(lastScan),
        Text(lastScanMode, style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
      ])),
    ]);
  }

  Widget historyPage() {
    if (logs.isEmpty) {
      return panel(child: const Column(children: [
        Icon(Icons.history, size: 56, color: Colors.blueGrey),
        SizedBox(height: 12),
        Text('Todavía no hay eventos'),
        SizedBox(height: 6),
        Text('Ve a NFC y selecciona una etiqueta virtual.'),
      ]));
    }
    return Column(children: [
      ...logs.map((log) => panel(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(log.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          Text('${log.code} · ${log.origin}',
              style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
          const SizedBox(height: 8),
          Text('Acción: ${log.action}'),
          Text('Fecha/hora: ${log.when.day.toString().padLeft(2, '0')}/${log.when.month.toString().padLeft(2, '0')}/${log.when.year} ${log.when.hour.toString().padLeft(2, '0')}:${log.when.minute.toString().padLeft(2, '0')}:${log.when.second.toString().padLeft(2, '0')}'),
          Text(log.latitude == null
              ? 'GPS: no consultado antes del registro'
              : 'GPS: ${log.latitude!.toStringAsFixed(6)}, ${log.longitude!.toStringAsFixed(6)}'),
        ],
      ))),
      TextButton.icon(onPressed: () => setState(() => logs.clear()),
          icon: const Icon(Icons.delete_outline), label: const Text('Borrar historial de sesión')),
    ]);
  }
}
