import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'producto.dart';

class ProductoApi {
  // Cambiar con --dart-define=API_BASE_URL=http://IP/api_productos
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2/api_productos',
  );
  final http.Client client;
  ProductoApi({http.Client? client}) : client = client ?? http.Client();

  Future<dynamic> _request(String endpoint, [Map<String, String>? data]) async {
    final uri = Uri.parse(
      '${baseUrl.replaceFirst(RegExp(r'/+$'), '')}/$endpoint',
    );
    try {
      final response =
          await (data == null
                  ? client.get(uri)
                  : client.post(
                      uri,
                      headers: {'Content-Type': 'application/json'},
                      body: jsonEncode(data),
                    ))
              .timeout(const Duration(seconds: 15));
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          (body is Map && body['status'] == 'error')) {
        throw Exception(
          body is Map
              ? body['message'] ?? 'Error del servidor.'
              : 'Error del servidor.',
        );
      }
      return body;
    } on TimeoutException {
      throw Exception(
        'El servidor no responde. Revisa Apache y la URL de la API.',
      );
    } on http.ClientException {
      throw Exception('No se pudo conectar. Revisa la URL, la red y Apache.');
    } on FormatException {
      throw Exception(
        'La API no devolvió JSON válido. Revisa la URL y los archivos PHP.',
      );
    }
  }

  Future<List<Producto>> obtener() async {
    final data = await _request('obtener.php');
    if (data is! List) throw Exception('Respuesta de productos inválida.');
    return data
        .map((item) => Producto.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> guardar({
    String? id,
    required String nombre,
    required String precio,
  }) async {
    await _request(id == null ? 'crear.php' : 'actualizar.php', {
      'id': ?id,
      'nombre': nombre,
      'precio': precio,
    });
  }

  Future<void> eliminar(String id) async {
    await _request('eliminar.php', {'id': id});
  }

  void close() => client.close();
}
