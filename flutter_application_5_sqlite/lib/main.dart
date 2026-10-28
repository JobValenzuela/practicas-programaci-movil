import 'package:flutter/material.dart';

import 'sqlite.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SQLite local',
      theme: ThemeData(colorSchemeSeed: Colors.teal),
      home: const SqlitePage(),
    );
  }
}
