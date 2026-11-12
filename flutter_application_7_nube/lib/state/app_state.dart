import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:uuid/uuid.dart';

import '../models/task.dart';
import '../data/local_store.dart';
import '../services/sync_engine.dart';

class AppState extends ChangeNotifier {
  final LocalStore local;
  final SyncEngine sync;
  List<Task> tasks = [];
  int pending = 0;
  bool network = true;
  String? localError;
  StreamSubscription<List<ConnectivityResult>>? _connectivity;
  Timer? _retry;
  bool _disposed = false;
  AppState(this.local, this.sync);
  Future<void> start({bool automatic = true}) async {
    sync.onChanged = () {
      unawaited(reload());
    };
    final last = await local.metadata('last_success');
    sync.lastSuccess = DateTime.tryParse(last ?? '');
    await reload();
    if (!automatic) return;
    _connectivity = Connectivity().onConnectivityChanged.listen((results) {
      network = !results.contains(ConnectivityResult.none);
      if (network) unawaited(sync.sync());
      notifyListeners();
    });
    // Un intento por minuto en primer plano, nunca recursión tras un fallo.
    _retry = Timer.periodic(
      const Duration(minutes: 1),
      (_) => unawaited(sync.sync()),
    );
    unawaited(sync.sync());
  }

  Future<void> reload() async {
    try {
      tasks = await local.tasks();
      pending = await local.pendingCount();
      localError = null;
    } catch (_) {
      localError = 'No se pudo leer SQLite. Reintenta sin borrar los datos de la aplicación.';
    }
    if (!_disposed) notifyListeners();
  }

  Future<void> save({
    Task? task,
    required String title,
    String description = '',
    bool? completed,
    bool deleted = false,
    bool synchronize = true,
  }) async {
    if (title.trim().isEmpty || title.trim().length > 160) {
      throw ArgumentError('Escribe un título de 1 a 160 caracteres.');
    }
    final now = DateTime.now().toUtc().toIso8601String();
    await local.save(
      Task(
        id: task?.id ?? const Uuid().v4(),
        title: title.trim(),
        description: description.trim(),
        createdAt: task?.createdAt ?? now,
        updatedAt: now,
        userId: task?.userId ?? sync.cloud.userId,
        completed: completed ?? task?.completed ?? false,
        deleted: deleted,
      ),
    );
    await reload();
    if (synchronize) unawaited(sync.sync());
  }

  @override
  void dispose() {
    _disposed = true;
    _retry?.cancel();
    _connectivity?.cancel();
    sync.onChanged = null;
    super.dispose();
  }
}
