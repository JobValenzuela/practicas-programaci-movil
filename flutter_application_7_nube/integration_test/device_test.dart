import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_application_6_mysql/data/local_store.dart';
import 'package:flutter_application_6_mysql/main.dart';
import 'package:flutter_application_6_mysql/services/sync_engine.dart';
import 'package:flutter_application_6_mysql/state/app_state.dart';

import '../test/sync_test.dart' show FakeCloud;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Android: SQLite real persiste y reintenta una red simulada', (
    tester,
  ) async {
    var local = await LocalStore.open(path: 'synclab_device_test.db');
    await local.db.delete('outbox');
    await local.db.delete('tasks');
    final cloud = FakeCloud()..offline = true;
    var state = AppState(local, SyncEngine(local, cloud));
    await state.start(automatic: false);
    for (var i = 0; i < 3; i++) {
      await state.save(title: 'Prueba dispositivo $i', synchronize: false);
    }
    await state.sync.sync();
    expect(state.sync.status, ServiceStatus.offline);
    expect(await local.pendingCount(), 3);
    state.dispose();
    await local.db.close();
    local = await LocalStore.open(path: 'synclab_device_test.db');
    state = AppState(local, SyncEngine(local, cloud));
    await state.start(automatic: false);
    expect(state.tasks.length, 3);
    expect(state.pending, 3);
    await tester.pumpWidget(SyncLabApp(state: state));
    await tester.pumpAndSettle();
    expect(find.text('Prueba dispositivo 0'), findsOneWidget);
    final task = state.tasks.first;
    await state.save(
      task: task,
      title: 'Edición offline Android',
      synchronize: false,
    );
    await state.save(
      task: state.tasks.last,
      title: state.tasks.last.title,
      deleted: true,
      synchronize: false,
    );
    cloud.offline = false;
    cloud.failAfterCommit = true;
    await state.sync.sync();
    expect(await local.pendingCount(), greaterThan(0));
    await state.sync.sync();
    await state.reload();
    expect(state.pending, 0);
    expect(state.tasks.length, 2);
    expect(cloud.records.length, 3);
    expect(cloud.records.values.where((t) => t.deleted).length, 1);
    expect(
      cloud.records.values
          .where((t) => t.title == 'Edición offline Android')
          .length,
      1,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
    await local.db.close();
  });
}
