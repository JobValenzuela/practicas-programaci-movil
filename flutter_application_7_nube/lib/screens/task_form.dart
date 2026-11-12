import 'package:flutter/material.dart';

import '../models/task.dart';
import '../state/app_state.dart';

Future<void> showTaskForm(
  BuildContext context,
  AppState state, {
  Task? task,
}) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => TaskForm(state: state, task: task),
  );
  if (saved == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Guardado en SQLite. La sincronización se intentará automáticamente.',
        ),
      ),
    );
  }
}

class TaskForm extends StatefulWidget {
  final AppState state;
  final Task? task;
  const TaskForm({super.key, required this.state, this.task});
  @override
  State<TaskForm> createState() => _TaskFormState();
}

class _TaskFormState extends State<TaskForm> {
  final keyForm = GlobalKey<FormState>();
  late final title = TextEditingController(text: widget.task?.title);
  late final description = TextEditingController(
    text: widget.task?.description,
  );
  bool saving = false;
  String? error;
  @override
  void dispose() {
    title.dispose();
    description.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (!keyForm.currentState!.validate()) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await widget.state.save(
        task: widget.task,
        title: title.text,
        description: description.text,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() {
          error = 'No se pudo guardar en SQLite. Tus campos se conservaron; reintenta.';
          saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving,
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: keyForm,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.task == null ? 'Una nueva idea' : 'Editar tarea',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const Text('Primero en tu teléfono. Después, en la nube.'),
              const SizedBox(height: 24),
              TextFormField(
                controller: title,
                autofocus: true,
                enabled: !saving,
                maxLength: 160,
                decoration: const InputDecoration(
                  labelText: 'Título',
                  hintText: '¿Qué quieres lograr?',
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Escribe un título.' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: description,
                enabled: !saving,
                maxLines: 3,
                maxLength: 4000,
                decoration: const InputDecoration(
                  labelText: 'Descripción (opcional)',
                ),
              ),
              if (error != null)
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: saving ? null : save,
                icon: const Icon(Icons.save_outlined),
                label: Text(saving ? 'Guardando…' : 'Guardar tarea'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
