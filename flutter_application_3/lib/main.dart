import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'encrypted_json_storage.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: StorageView(),
    );
  }
}

class StorageView extends StatefulWidget {
  const StorageView({super.key});

  @override
  State<StorageView> createState() => _StorageViewState();
}

class _StorageViewState extends State<StorageView> {
  final _storage = EncryptedJsonStorage();
  final _controller = TextEditingController();
  String _message = '';
  bool _busy = false;

  Future<void> _saveOrRead({required bool save}) async {
    setState(() => _busy = true);
    try {
      String message;
      if (save) {
        await _storage.saveEncryptedJson('datos.enc', {
          'texto': _controller.text,
        });
        message = kIsWeb
            ? 'Texto cifrado. Descarga de datos.enc iniciada; revisa las descargas de Chrome.'
            : 'Texto guardado y cifrado.';
      } else {
        final data = await _storage.readEncryptedJson('datos.enc');
        if (!mounted) return;
        if (data != null) {
          _controller.text = data['texto'] as String? ?? '';
        }
        message = data == null
            ? 'No hay datos guardados o no se pudieron leer.'
            : 'Texto leído y descifrado.';
      }
      if (!mounted) return;
      setState(() => _message = message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _message = 'No se pudo completar la operación: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('JSON cifrado')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: 'Texto para guardar',
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _busy ? null : () => _saveOrRead(save: true),
              child: const Text('Guardar'),
            ),
            OutlinedButton(
              onPressed: _busy ? null : () => _saveOrRead(save: false),
              child: const Text('Leer'),
            ),
            const SizedBox(height: 16),
            Text(_message),
          ],
        ),
      ),
    );
  }
}
