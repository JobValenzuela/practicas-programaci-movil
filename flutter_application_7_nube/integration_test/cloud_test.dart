import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_application_6_mysql/data/local_store.dart';
import 'package:flutter_application_6_mysql/models/task.dart';
import 'package:flutter_application_6_mysql/services/cloud_service.dart';
import 'package:flutter_application_6_mysql/services/sync_engine.dart';
import 'package:flutter_application_6_mysql/state/app_state.dart';

// Inyección de corte de transporte; las peticiones permitidas llegan a Supabase real.
class NetworkGate implements CloudService {
  final CloudService remote;
  bool offline = false, loseReply = false;
  NetworkGate(this.remote);
  @override
  String? get userId => remote.userId;
  @override
  Future<String> authenticate() {
    if (offline) throw TimeoutException('Corte de transporte de prueba');
    return remote.authenticate();
  }

  @override
  Future<List<Task>> fetch() => remote.fetch();
  @override
  Future<void> push(Task task, String owner) async {
    await remote.push(task, owner);
    if (loseReply) {
      loseReply = false;
      throw TimeoutException('Respuesta perdida después del commit real');
    }
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Android: SQLite y Supabase real convergen tras cortes y reinicio de base',
    (tester) async {
      await Supabase.initialize(
        url: const String.fromEnvironment('SUPABASE_URL'),
        publishableKey: const String.fromEnvironment(
          'SUPABASE_PUBLISHABLE_KEY',
        ),
        debug: false,
      );
      final gate = NetworkGate(SupabaseCloud(Supabase.instance.client));
      var local = await LocalStore.open(path: 'synclab_cloud_test.db');
      var state = AppState(local, SyncEngine(local, gate));
      await state.start(automatic: false);
      final prefix =
          'Integración Android ${DateTime.now().millisecondsSinceEpoch}';
      await state.save(title: '$prefix online', synchronize: false);
      final onlineId = state.tasks
          .firstWhere((t) => t.title == '$prefix online')
          .id;
      await state.sync.sync();
      await state.reload();
      expect(state.sync.error, isNull, reason: state.sync.error);
      expect(state.pending, 0);
      expect((await gate.fetch()).where((t) => t.id == onlineId).length, 1);
      gate.offline = true;
      for (var i = 0; i < 3; i++) {
        await state.save(title: '$prefix offline $i', synchronize: false);
      }
      await state.sync.sync();
      expect(state.pending, 3);
      state.dispose();
      await local.db.close();
      local = await LocalStore.open(path: 'synclab_cloud_test.db');
      state = AppState(local, SyncEngine(local, gate));
      await state.start(automatic: false);
      expect(state.pending, 3);
      final edit = state.tasks.firstWhere(
        (t) => t.title == '$prefix offline 0',
      );
      await state.save(
        task: edit,
        title: '$prefix editada',
        completed: true,
        synchronize: false,
      );
      final online = state.tasks.firstWhere((t) => t.id == onlineId);
      await state.save(
        task: online,
        title: online.title,
        deleted: true,
        synchronize: false,
      );
      gate.offline = false;
      gate.loseReply = true;
      await state.sync.sync();
      expect(await local.pendingCount(), greaterThan(0));
      await state.sync.sync();
      await state.reload();
      expect(state.sync.error, isNull, reason: state.sync.error);
      expect(state.pending, 0);
      final remote = (await gate.fetch())
          .where((t) => t.title.startsWith(prefix))
          .toList();
      expect(remote.length, 4);
      expect(remote.map((t) => t.id).toSet().length, 4);
      expect(remote.singleWhere((t) => t.id == onlineId).deleted, true);
      expect(remote.singleWhere((t) => t.id == edit.id).completed, true);
      expect(state.tasks.any((t) => t.id == onlineId), false);
      for (final task
          in state.tasks.where((t) => t.title.startsWith(prefix)).toList()) {
        await state.save(
          task: task,
          title: task.title,
          deleted: true,
          synchronize: false,
        );
      }
      await state.sync.sync();
      expect(await local.pendingCount(), 0);
      state.dispose();
      await local.db.close();
    },
  );
}
