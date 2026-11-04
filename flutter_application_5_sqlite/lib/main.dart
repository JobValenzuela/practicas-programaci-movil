// Uso Material para los componentes visuales de la aplicación.
import 'package:flutter/material.dart';

// Aquí importo la pantalla que guarda y consulta las lecturas en SQLite.
import 'sqlite.dart';

// Este es el punto donde empieza la aplicación.
void main() {
  // Preparo Flutter antes de mostrar la pantalla principal.
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

// Aquí configuro el nombre, el tema y la pantalla inicial de la app.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // Quito la etiqueta de depuración que aparece en la esquina.
      debugShowCheckedModeBanner: false,
      title: 'SQLite local',
      theme: ThemeData(colorSchemeSeed: Colors.teal),
      home: const SqlitePage(),
    );
  }
}
