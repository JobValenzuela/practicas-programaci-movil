import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_application_6_mysql/data/local_store.dart';
import 'package:flutter_application_6_mysql/services/cloud_service.dart';
import 'package:flutter_application_6_mysql/services/sync_engine.dart';
import 'package:flutter_application_6_mysql/state/app_state.dart';

Future<void> waitNetwork(bool connected) async {
  for (var i = 0; i < 120; i++) {
    final results = await Connectivity().checkConnectivity();
    if ((!results.contains(ConnectivityResult.none)) == connected) return;
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }
  throw TimeoutException('La red física no cambió al estado solicitado.');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Radios reales: CRUD offline, reapertura SQLite y recuperación automática',
    (tester) async {
      await Supabase.initialize(
        url: const String.fromEnvironment('SUPABASE_URL'),
        publishableKey: const String.fromEnvironment(
          'SUPABASE_PUBLISHABLE_KEY',
        ),
        debug: false,
      );
      final cloud = SupabaseCloud(Supabase.instance.client);
      var local = await LocalStore.open(path: 'synclab_physical_network.db');
      var state = AppState(local, SyncEngine(local, cloud));
      await state.start();
      final prefix = 'Radios reales ${DateTime.now().millisecondsSinceEpoch}';
      await state.save(title: '$prefix inicial');
      await state.sync.sync();
      await state.reload();
      expect(state.sync.error, isNull, reason: state.sync.error);
      final initial = state.tasks.firstWhere(
        (t) => t.title == '$prefix inicial',
      );
      expect(initial.pending, false);
      // El controlador ADB corta las radios después de observar este marcador.
      // ignore: avoid_print
      print('SYNCLAB_DISABLE_NETWORK');
      await waitNetwork(false);
      for (var i = 0; i < 3; i++) {
        await state.save(title: '$prefix offline $i');
      }
      await state.save(task: initial, title: '$prefix editada offline');
      final deleted = state.tasks.firstWhere(
        (t) => t.title == '$prefix offline 2',
      );
      await state.save(task: deleted, title: deleted.title, deleted: true);
      await state.sync.sync();
      await state.reload();
      expect(state.pending, 5);
      expect(state.tasks.where((t) => t.title.startsWith(prefix)).length, 3);
      state.dispose();
      await local.db.close();
      local = await LocalStore.open(path: 'synclab_physical_network.db');
      state = AppState(local, SyncEngine(local, cloud));
      await state.start();
      expect(state.pending, 5);
      expect(state.tasks.any((t) => t.id == deleted.id), false);
      await state.sync.sync();
      // ignore: avoid_print
      print('SYNCLAB_RESTORE_NETWORK');
      await waitNetwork(true);
      // No pulsamos sincronizar: connectivity_plus o el reintento controlado lo hacen.
      for (var i = 0; i < 180; i++) {
        await state.reload();
        if (state.pending == 0 &&
            state.sync.status == ServiceStatus.available) {
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
      expect(state.pending, 0, reason: state.sync.error);
      final remote = (await cloud.fetch())
          .where((t) => t.title.startsWith(prefix))
          .toList();
      expect(remote.length, 4);
      expect(remote.map((t) => t.id).toSet().length, 4);
      expect(
        remote.singleWhere((t) => t.id == initial.id).title,
        '$prefix editada offline',
      );
      expect(remote.singleWhere((t) => t.id == deleted.id).deleted, true);
      for (final t
          in state.tasks.where((t) => t.title.startsWith(prefix)).toList()) {
        await state.save(
          task: t,
          title: t.title,
          deleted: true,
          synchronize: false,
        );
      }
      await state.sync.sync();
      expect(await local.pendingCount(), 0);
      state.dispose();
      await local.db.close();
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
