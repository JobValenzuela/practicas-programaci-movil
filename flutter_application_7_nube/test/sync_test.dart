import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter_application_6_mysql/data/local_store.dart';
import 'package:flutter_application_6_mysql/models/task.dart';
import 'package:flutter_application_6_mysql/services/cloud_service.dart';
import 'package:flutter_application_6_mysql/services/sync_engine.dart';
import 'package:flutter_application_6_mysql/state/app_state.dart';

class FakeCloud implements CloudService {
  final records = <String, Task>{};
  bool offline = false, failAfterCommit = false;
  int active = 0, peak = 0;
  Future<void> Function(Task)? duringPush;
  @override
  String? get userId => 'owner';
  @override
  Future<String> authenticate() async {
    if (offline) throw TimeoutException('Sin red');
    return userId!;
  }

  @override
  Future<void> push(Task task, String owner) async {
    active++;
    if (active > peak) peak = active;
    try {
      records[task.id] = task;
      if (duringPush != null) await duringPush!(task);
      if (failAfterCommit) {
        failAfterCommit = false;
        throw TimeoutException('Respuesta perdida');
      }
    } finally {
      active--;
    }
  }

  @override
  Future<List<Task>> fetch() async => records.values.toList();
}

void main() {
  sqfliteFfiInit();
  late Directory dir;
  late LocalStore local;
  late FakeCloud cloud;
  late AppState state;
  late SyncEngine engine;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('synclab_test_');
    local = await LocalStore.open(
      factory: databaseFactoryFfi,
      path: '${dir.path}/tasks.db',
    );
    cloud = FakeCloud();
    engine = SyncEngine(local, cloud);
    state = AppState(local, engine);
    await state.start(automatic: false);
  });
  tearDown(() async {
    state.dispose();
    await local.db.close();
    await dir.delete(recursive: true);
  });
  Future<void> create(String title) =>
      state.save(title: title, synchronize: false);
  test('Crear online confirma SQLite y nube sin duplicados', () async {
    await create('Online');
    await engine.sync();
    await state.reload();
    expect(cloud.records.length, 1);
    expect(state.pending, 0);
    expect(state.tasks.single.pending, false);
    await engine.sync();
    expect(cloud.records.length, 1);
  });
  test(
    'Tres tareas offline persisten al cerrar y reabrir y se recuperan',
    () async {
      cloud.offline = true;
      for (var i = 0; i < 3; i++) {
        await create('Offline $i');
      }
      await engine.sync();
      expect(await local.pendingCount(), 3);
      state.dispose();
      await local.db.close();
      local = await LocalStore.open(
        factory: databaseFactoryFfi,
        path: '${dir.path}/tasks.db',
      );
      engine = SyncEngine(local, cloud);
      state = AppState(local, engine);
      await state.start(automatic: false);
      expect(state.tasks.length, 3);
      expect(state.pending, 3);
      cloud.offline = false;
      await engine.sync();
      await state.reload();
      expect(cloud.records.length, 3);
      expect(state.pending, 0);
    },
  );
  test(
    'Editar y eliminar offline transmite tombstone sin resurrección',
    () async {
      await create('Antes');
      await engine.sync();
      await state.reload();
      cloud.offline = true;
      await state.save(
        task: state.tasks.single,
        title: 'Después',
        synchronize: false,
      );
      await engine.sync();
      expect(cloud.records.values.single.title, 'Antes');
      cloud.offline = false;
      await engine.sync();
      await state.reload();
      expect(cloud.records.values.single.title, 'Después');
      cloud.offline = true;
      await state.save(
        task: state.tasks.single,
        title: 'Después',
        deleted: true,
        synchronize: false,
      );
      expect(state.tasks, isEmpty);
      await engine.sync();
      cloud.offline = false;
      await engine.sync();
      await engine.sync();
      await state.reload();
      expect(cloud.records.values.single.deleted, true);
      expect(state.tasks, isEmpty);
      expect(state.pending, 0);
    },
  );
  test(
    'Respuesta perdida después de commit conserva cola y reintenta idempotente',
    () async {
      await create('Interrupción');
      cloud.failAfterCommit = true;
      await engine.sync();
      expect(await local.pendingCount(), 1);
      expect(cloud.records.length, 1);
      await engine.sync();
      expect(await local.pendingCount(), 0);
      expect(cloud.records.length, 1);
    },
  );
  test(
    'Confirmación antigua no confirma edición creada durante envío',
    () async {
      await create('v1');
      final op = (await local.next())!;
      await state.save(
        task: state.tasks.single,
        title: 'v2',
        synchronize: false,
      );
      await local.acknowledge(op, 'owner');
      expect((await local.tasks()).single.pending, true);
      expect(await local.pendingCount(), 1);
      await engine.sync();
      expect(cloud.records.values.single.title, 'v2');
    },
  );
  test(
    'Descarga preserva cambios y eliminaciones locales pendientes',
    () async {
      await create('Local');
      final t = state.tasks.single;
      await local.merge([
        Task(
          id: t.id,
          title: 'Remota antigua',
          createdAt: t.createdAt,
          updatedAt: t.updatedAt,
        ),
      ]);
      expect((await local.tasks()).single.title, 'Local');
      await state.save(
        task: t,
        title: t.title,
        deleted: true,
        synchronize: false,
      );
      await local.merge([t]);
      expect(await local.tasks(), isEmpty);
    },
  );
  test('Disparadores concurrentes comparten una sincronización', () async {
    await create('Serial');
    final gate = Completer<void>();
    cloud.duringPush = (_) => gate.future;
    final first = engine.sync();
    final second = engine.sync();
    expect(identical(first, second), true);
    gate.complete();
    await Future.wait([first, second]);
    expect(cloud.peak, 1);
    expect(await local.pendingCount(), 0);
  });
  test(
    'Descarga remota real del servicio simulado converge con SQLite',
    () async {
      cloud.records['remote'] = Task(
        id: 'remote',
        title: 'Desde nube',
        createdAt: DateTime.now().toIso8601String(),
        updatedAt: DateTime.now().toIso8601String(),
      );
      await engine.sync();
      expect((await local.tasks()).single.title, 'Desde nube');
      await expectLater(local.bindOwner('other'), throwsStateError);
      expect((await local.tasks()).length, 1);
    },
  );
  test('Transacción fallida no deja tarea sin outbox', () async {
    await local.db.execute(
      "CREATE TRIGGER fail_outbox BEFORE INSERT ON outbox BEGIN SELECT RAISE(ABORT, 'test'); END",
    );
    await expectLater(create('No parcial'), throwsA(isA<DatabaseException>()));
    expect(await local.tasks(), isEmpty);
    expect(await local.pendingCount(), 0);
  });
}
