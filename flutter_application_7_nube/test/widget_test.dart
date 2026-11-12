import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter_application_6_mysql/data/local_store.dart';
import 'package:flutter_application_6_mysql/main.dart';
import 'package:flutter_application_6_mysql/services/sync_engine.dart';
import 'package:flutter_application_6_mysql/state/app_state.dart';

import 'sync_test.dart' show FakeCloud;

void main() {
  testWidgets(
    'Pantalla pequeña valida formulario, guarda local y muestra diagnóstico',
    (tester) async {
      sqfliteFfiInit();
      final local = await LocalStore.open(
        factory: databaseFactoryFfiNoIsolate,
        path: inMemoryDatabasePath,
      );
      final cloud = FakeCloud()..offline = true;
      final state = AppState(local, SyncEngine(local, cloud));
      await state.start(automatic: false);
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(() async {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        state.dispose();
        await local.db.close();
      });
      await tester.pumpWidget(SyncLabApp(state: state));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nueva tarea'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar tarea'));
      await tester.pumpAndSettle();
      expect(find.text('Escribe un título.'), findsOneWidget);
      await tester.enterText(
        find.byType(TextFormField).first,
        'Mi tarea offline',
      );
      await tester.tap(find.text('Guardar tarea'));
      await tester.pumpAndSettle();
      expect(find.text('Mi tarea offline'), findsOneWidget);
      expect(state.pending, 1);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Diagnóstico'));
      await tester.pumpAndSettle();
      expect(find.text('SQLite · operaciones pendientes'), findsOneWidget);
      await tester.drag(find.byType(ListView).last, const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(find.text('Consultar datos de la nube'), findsOneWidget);
    },
  );
}
