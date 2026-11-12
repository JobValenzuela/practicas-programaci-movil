import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/task.dart';

abstract interface class CloudService {
  String? get userId;
  Future<String> authenticate();
  Future<void> push(Task task, String owner);
  Future<List<Task>> fetch();
}

class SupabaseCloud implements CloudService {
  final SupabaseClient client;
  SupabaseCloud(this.client);
  @override
  String? get userId => client.auth.currentUser?.id;
  @override
  Future<String> authenticate() async {
    final session = client.auth.currentSession;
    if (session == null) {
      await client.auth.signInAnonymously().timeout(
        const Duration(seconds: 15),
      );
    } else if (session.isExpired) {
      await client.auth.refreshSession().timeout(const Duration(seconds: 15));
    }
    final owner = userId;
    if (owner == null) {
      throw StateError(
        'Se necesita Internet para la primera sesión anónima. Tus tareas siguen guardadas en SQLite.',
      );
    }
    return owner;
  }

  @override
  Future<void> push(Task task, String owner) async {
    await client
        .from('tasks')
        .upsert(task.toRemote(owner), onConflict: 'id')
        .select('id')
        .single()
        .timeout(const Duration(seconds: 15));
  }

  @override
  Future<List<Task>> fetch() async {
    final owner = userId;
    if (owner == null) {
      throw StateError('Primero se necesita una sesión válida.');
    }
    // Paginación para no truncar la descarga al límite de PostgREST.
    final tasks = <Task>[];
    for (var offset = 0; ; offset += 500) {
      final rows = await client
          .from('tasks')
          .select()
          .eq('user_id', owner)
          .order('id')
          .range(offset, offset + 499)
          .timeout(const Duration(seconds: 15));
      tasks.addAll(rows.map(Task.fromMap));
      if (rows.length < 500) break;
    }
    return tasks;
  }
}
