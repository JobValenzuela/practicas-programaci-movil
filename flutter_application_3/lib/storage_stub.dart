// Estas funciones solo se usan en web; Android utiliza los archivos de dart:io.
Future<void> writeText(String filename, String text) async {
  throw UnsupportedError('El almacenamiento del navegador solo existe en web.');
}

Future<String?> readText(String filename) async {
  throw UnsupportedError('El almacenamiento del navegador solo existe en web.');
}
