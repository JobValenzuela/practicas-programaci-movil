import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../models/task.dart';
import '../services/sync_engine.dart';
import '../widgets/status_badge.dart';
import 'diagnostics_screen.dart';
import 'task_form.dart';

class HomeScreen extends StatefulWidget {
  final AppState state;
  const HomeScreen({super.key, required this.state});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int filter = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) widget.state.sync.sync();
  }

  Future<void> change(Task task, {bool deleted = false}) async {
    if (deleted) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('¿Eliminar tarea?'),
          content: Text(
            '“${task.title}” se eliminará de tu teléfono y el cambio se enviará a la nube.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Eliminar'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    try {
      await widget.state.save(
        task: task,
        title: task.title,
        description: task.description,
        completed: deleted ? task.completed : !task.completed,
        deleted: deleted,
      );
      if (deleted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Eliminación guardada localmente.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo guardar el cambio en SQLite. Reintenta.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.state,
    builder: (context, _) {
      final s = widget.state;
      final tasks = s.tasks
          .where(
            (t) => filter == 0 || (filter == 1 ? !t.completed : t.completed),
          )
          .toList();
      final status = s.sync.running
          ? 'Sincronizando…'
          : !s.network || s.sync.status == ServiceStatus.offline
          ? 'Sin conexión'
          : s.sync.status == ServiceStatus.error
          ? 'Error de sincronización'
          : s.pending > 0
          ? 'Pendiente'
          : s.sync.status == ServiceStatus.available
          ? 'Sincronizado'
          : 'Sin comprobar';
      return Scaffold(
        appBar: AppBar(
          title: const Row(
            children: [
              Icon(Icons.hub_outlined),
              SizedBox(width: 10),
              Text('SyncLab', style: TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Diagnóstico',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => DiagnosticsScreen(state: s),
                ),
              ),
              icon: const Icon(Icons.monitor_heart_outlined),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => showTaskForm(context, s),
          icon: const Icon(Icons.add),
          label: const Text('Nueva tarea'),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: RefreshIndicator(
              onRefresh: s.sync.sync,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
                children: [
                  const Text(
                    'TU DÍA, EN SINTONÍA',
                    style: TextStyle(
                      letterSpacing: 2,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xff657989),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Mis tareas',
                    style: Theme.of(context).textTheme.headlineLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Cada paso cuenta. Incluso sin conexión.',
                    style: TextStyle(color: Color(0xff647587)),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      stat('Total', s.tasks.length, Icons.layers_outlined),
                      const SizedBox(width: 8),
                      stat(
                        'Hechas',
                        s.tasks.where((t) => t.completed).length,
                        Icons.check_circle_outline,
                      ),
                      const SizedBox(width: 8),
                      stat('En cola', s.pending, Icons.sync),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Card(
                    color: const Color(0xffeaf0fa),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              StatusBadge(
                                status,
                                good: status == 'Sincronizado',
                              ),
                              TextButton.icon(
                                onPressed: s.sync.running ? null : s.sync.sync,
                                icon: const Icon(Icons.sync, size: 18),
                                label: const Text('Sincronizar ahora'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Última sincronización: ${displayDate(s.sync.lastSuccess)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          if (s.sync.cloud.userId == null)
                            const Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: Text(
                                'Puedes trabajar sin Internet. La primera sesión en la nube requiere conexión.',
                              ),
                            ),
                          if (s.localError != null || s.sync.error != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                s.localError ?? s.sync.error!,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (var i = 0; i < 3; i++)
                        ChoiceChip(
                          label: Text(
                            ['Todas', 'Pendientes', 'Completadas'][i],
                          ),
                          selected: filter == i,
                          onSelected: (_) => setState(() => filter = i),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: tasks.isEmpty
                        ? Padding(
                            key: ValueKey(filter),
                            padding: const EdgeInsets.symmetric(vertical: 45),
                            child: Column(
                              children: [
                                const Icon(
                                  Icons.auto_awesome_outlined,
                                  size: 58,
                                  color: Color(0xff788ad1),
                                ),
                                const SizedBox(height: 18),
                                Text(
                                  s.tasks.isEmpty
                                      ? 'Haz espacio para tus ideas'
                                      : 'Todo en orden por aquí',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Crea una tarea y da el primer paso.',
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          )
                        : Column(
                            children: [
                              for (final task in tasks)
                                Card(
                                  key: ValueKey(task.id),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                    child: ListTile(
                                      leading: Checkbox(
                                        value: task.completed,
                                        onChanged: (_) => change(task),
                                      ),
                                      title: Text(
                                        task.title,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          decoration: task.completed
                                              ? TextDecoration.lineThrough
                                              : null,
                                        ),
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          if (task.description.isNotEmpty)
                                            Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 6,
                                                  ),
                                              child: Text(
                                                task.description,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          const SizedBox(height: 6),
                                          StatusBadge(
                                            task.pending
                                                ? 'Pendiente de sincronizar'
                                                : 'Sincronizado',
                                            good: !task.pending,
                                          ),
                                        ],
                                      ),
                                      onTap: () =>
                                          showTaskForm(context, s, task: task),
                                      trailing: PopupMenuButton<String>(
                                        tooltip: 'Opciones de tarea',
                                        onSelected: (v) {
                                          if (v == 'edit') {
                                            showTaskForm(
                                              context,
                                              s,
                                              task: task,
                                            );
                                          } else {
                                            change(task, deleted: true);
                                          }
                                        },
                                        itemBuilder: (_) => const [
                                          PopupMenuItem(
                                            value: 'edit',
                                            child: Text('Editar'),
                                          ),
                                          PopupMenuItem(
                                            value: 'delete',
                                            child: Text('Eliminar'),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
  Widget stat(String label, int count, IconData icon) => Expanded(
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: const Color(0xff536acb)),
            const SizedBox(height: 12),
            Text(
              '$count',
              style: const TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
            ),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    ),
  );
}
