import 'dart:js_interop';

@JS('window.localStorage')
external BrowserStorage get _localStorage;

@JS('document.createElement')
external DownloadLink _createElement(String tag);

extension type DownloadLink(JSObject _) implements JSObject {
  external set href(String value);
  external set download(String value);
  external void click();
}

extension type BrowserStorage(JSObject _) implements JSObject {
  external void setItem(String key, String value);
  external String? getItem(String key);
}

Future<void> writeText(String filename, String text) async {
  _localStorage.setItem('encrypted_json:$filename', text);
  // Descargar un archivo real con el mismo contenido cifrado.
  final link = _createElement('a');
  link.href =
      'data:application/octet-stream;charset=utf-8,${Uri.encodeComponent(text)}';
  link.download = filename;
  link.click();
}

Future<String?> readText(String filename) async {
  return _localStorage.getItem('encrypted_json:$filename');
}
