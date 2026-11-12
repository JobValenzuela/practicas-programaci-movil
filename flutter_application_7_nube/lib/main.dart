import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'data/local_store.dart';
import 'services/cloud_service.dart';
import 'services/sync_engine.dart';
import 'state/app_state.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    const url = String.fromEnvironment('SUPABASE_URL');
    const key = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
    if (url.isEmpty || key.isEmpty) {
      throw StateError(
        'Ejecuta con --dart-define-from-file=config/supabase.json',
      );
    }
    final local = await LocalStore.open();
    await Supabase.initialize(url: url, publishableKey: key, debug: false);
    final state = AppState(
      local,
      SyncEngine(local, SupabaseCloud(Supabase.instance.client)),
    );
    await state.start();
    runApp(SyncLabApp(state: state));
  } catch (e) {
    runApp(
      MaterialApp(
        home: Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: SelectableText(
                'No se pudo iniciar SyncLab. Tus datos existentes se conservan.\n$e',
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SyncLabApp extends StatelessWidget {
  final AppState state;
  const SyncLabApp({super.key, required this.state});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'SyncLab',
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff5364cf)),
      scaffoldBackgroundColor: const Color(0xfff5f7fb),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xfff5f7fb),
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    ),
    home: HomeScreen(state: state),
  );
}
