import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:encrypt/encrypt.dart' as encrypt;

import 'storage_stub.dart'
    if (dart.library.js_interop) 'storage_web.dart'
    as web;

class EncryptedJsonStorage {
  // Clave de 32 caracteres y IV de 16 caracteres para AES-256.
  final _key = encrypt.Key.fromUtf8('my32lengthsupersecretkey12345678');
  final _iv = encrypt.IV.fromUtf8('1234567890123456');

  Future<File> _getLocalFile(String filename) async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$filename');
  }

  // Guardar JSON cifrado; en Android se escribe primero un archivo temporal.
  Future<void> saveEncryptedJson(
    String filename,
    Map<String, dynamic> data,
  ) async {
    final jsonString = jsonEncode(data);
    final encrypter = encrypt.Encrypter(encrypt.AES(_key));
    final encryptedData = encrypter.encrypt(jsonString, iv: _iv);

    // El navegador no permite usar path_provider ni archivos de dart:io.
    if (kIsWeb) {
      await web.writeText(filename, encryptedData.base64);
      return;
    }

    final file = await _getLocalFile(filename);
    final tempFile = File('${file.path}.tmp');
    await tempFile.writeAsString(encryptedData.base64);
    await tempFile.rename(file.path);
  }

  // Leer y descifrar JSON.
  Future<Map<String, dynamic>?> readEncryptedJson(String filename) async {
    try {
      final String encryptedText;
      if (kIsWeb) {
        final text = await web.readText(filename);
        if (text == null) return null;
        encryptedText = text;
      } else {
        final file = await _getLocalFile(filename);
        if (!await file.exists()) return null;
        encryptedText = await file.readAsString();
      }

      final encrypter = encrypt.Encrypter(encrypt.AES(_key));
      final decryptedText = encrypter.decrypt64(encryptedText, iv: _iv);
      return jsonDecode(decryptedText) as Map<String, dynamic>;
    } catch (e) {
      // Archivo corrupto o clave incorrecta.
      debugPrint('Error al leer el archivo cifrado: $e');
      return null;
    }
  }
}
