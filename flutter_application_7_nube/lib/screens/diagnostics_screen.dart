import 'package:flutter/material.dart';

import '../models/task.dart';
import '../state/app_state.dart';
import '../services/sync_engine.dart';

String displayDate(DateTime? date) {
  if (date == null) return 'Todavía no se ha completado';
  final d = date.toLocal();
  return '${d.day}/${d.month}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}:${d.second.toString().padLeft(2, '0')}';
}

class DiagnosticsScreen extends StatefulWidget {
  final AppState state;
  const DiagnosticsScreen({super.key, required this.state});
  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  List<Task>? cloud;
  DateTime? queried;
  String? error;
  bool loading = false;
  Future<void> query() async {
    setState(() {
      loading = true;
      error = null;
      cloud = null;
    });
    try {
      await widget.state.sync.cloud.authenticate();
      final data = await widget.state.sync.cloud.fetch();
      if (mounted) {
        setState(() {
          cloud = data;
          queried = DateTime.now();
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = 'Consulta remota fallida: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.state,
    builder: (context, _) {
      final s = widget.state;
      return Scaffold(
        appBar: AppBar(title: const Text('Diagnóstico')),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'LABORATORIO DE SINCRONIZACIÓN',
              style: TextStyle(
                letterSpacing: 1.5,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Column(
                children: [
                  row(
                    'Red detectada',
                    s.network
                        ? 'Disponible (no garantiza Internet)'
                        : 'Sin conexión',
                  ),
                  row('Supabase real', switch (s.sync.status) {
                    ServiceStatus.available => 'Disponible en última consulta',
                    ServiceStatus.offline => 'No disponible',
                    ServiceStatus.error => 'Error: requiere atención',
                    _ => 'Sin comprobar',
                  }),
                  row(
                    'Autenticación',
                    s.sync.cloud.userId == null
                        ? 'Sin sesión: primera conexión necesaria'
                        : 'Sesión anónima persistente',
                  ),
                  row(
                    'Propietario',
                    s.sync.cloud.userId ??
                        'Las tareas sin propietario se vinculan al autenticar',
                  ),
                  row('SQLite · tareas visibles', '${s.tasks.length}'),
                  row('SQLite · operaciones pendientes', '${s.pending}'),
                  row(
                    'Última sincronización exitosa',
                    displayDate(s.sync.lastSuccess),
                  ),
                ],
              ),
            ),
            if (s.sync.error != null || s.localError != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: SelectableText(
                  s.localError ?? s.sync.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: s.sync.running ? null : s.sync.sync,
              icon: const Icon(Icons.sync),
              label: Text(
                s.sync.running ? 'Sincronizando…' : 'Sincronizar ahora',
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: loading ? null : query,
              icon: const Icon(Icons.cloud_download_outlined),
              label: Text(
                loading
                    ? 'Consultando Supabase…'
                    : 'Consultar datos de la nube',
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'RESPUESTA DIRECTA DE SUPABASE',
              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
            ),
            const SizedBox(height: 8),
            const Text(
              'Esta consulta usa la red y no lee SQLite. Incluye eliminaciones lógicas para verificar el resultado.',
            ),
            if (error != null) SelectableText(error!),
            if (cloud != null) ...[
              Text('${cloud!.length} registros · ${displayDate(queried)}'),
              for (final task in cloud!)
                Card(
                  child: ListTile(
                    leading: Icon(
                      task.deleted
                          ? Icons.delete_outline
                          : Icons.cloud_done_outlined,
                    ),
                    title: Text(task.title),
                    subtitle: SelectableText(
                      '${task.id}\n${task.deleted
                          ? "Eliminada"
                          : task.completed
                          ? "Completada"
                          : "Pendiente"} · ${task.updatedAt}',
                    ),
                  ),
                ),
              if (cloud!.isEmpty)
                const Text(
                  'Supabase respondió correctamente: no hay registros para esta sesión.',
                ),
            ],
          ],
        ),
      );
    },
  );
  Widget row(String title, String value) =>
      ListTile(title: Text(title), subtitle: SelectableText(value));
}
