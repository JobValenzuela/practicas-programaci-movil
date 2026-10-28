import 'package:flutter/material.dart';

import 'producto.dart';
import 'producto_api.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'CRUD MySQL Flutter',
    theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
    home: const ProductoListScreen(),
  );
}

class ProductoListScreen extends StatefulWidget {
  final ProductoApi? api;
  const ProductoListScreen({super.key, this.api});
  @override
  State<ProductoListScreen> createState() => _ProductoListScreenState();
}

class _ProductoListScreenState extends State<ProductoListScreen> {
  late final ProductoApi _api;
  late Future<List<Producto>> _productos;
  bool _eliminando = false;

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? ProductoApi();
    _productos = _api.obtener();
  }

  @override
  void dispose() {
    if (widget.api == null) _api.close();
    super.dispose();
  }

  void _recargar() {
    final productos = _api.obtener();
    setState(() {
      _productos = productos;
    });
  }
  void _mensaje(Object message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message.toString().replaceFirst('Exception: ', '')),
      ),
    );
  }

  Future<void> _showFormDialog({Producto? producto}) async {
    final guardado = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ProductoForm(api: _api, producto: producto),
    );
    if (guardado == true && mounted) {
      _recargar();
      _mensaje(producto == null ? 'Producto creado.' : 'Producto actualizado.');
    }
  }

  Future<void> _deleteProducto(Producto producto) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar producto'),
        content: Text('¿Eliminar "${producto.nombre}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;
    setState(() => _eliminando = true);
    try {
      await _api.eliminar(producto.id);
      if (!mounted) return;
      _recargar();
      _mensaje('Producto eliminado.');
    } catch (error) {
      _mensaje(error);
    } finally {
      if (mounted) setState(() => _eliminando = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Productos (MySQL + Apache)'),
      actions: [
        IconButton(
          onPressed: _recargar,
          tooltip: 'Actualizar',
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: FutureBuilder<List<Producto>>(
      future: _productos,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    snapshot.error.toString().replaceFirst('Exception: ', ''),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _recargar,
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          );
        }
        final productos = snapshot.data ?? [];
        if (productos.isEmpty) {
          return const Center(child: Text('No hay productos registrados.'));
        }
        return ListView.separated(
          itemCount: productos.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final prod = productos[index];
            return ListTile(
              title: Text(prod.nombre),
              subtitle: Text('\$${prod.precio}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Editar',
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    onPressed: _eliminando
                        ? null
                        : () => _showFormDialog(producto: prod),
                  ),
                  IconButton(
                    tooltip: 'Eliminar',
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: _eliminando ? null : () => _deleteProducto(prod),
                  ),
                ],
              ),
            );
          },
        );
      },
    ),
    floatingActionButton: FloatingActionButton(
      onPressed: _eliminando ? null : () => _showFormDialog(),
      tooltip: 'Agregar producto',
      child: const Icon(Icons.add),
    ),
  );
}

class _ProductoForm extends StatefulWidget {
  final ProductoApi api;
  final Producto? producto;
  const _ProductoForm({required this.api, this.producto});
  @override
  State<_ProductoForm> createState() => _ProductoFormState();
}

class _ProductoFormState extends State<_ProductoForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombre;
  late final TextEditingController _precio;
  bool _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nombre = TextEditingController(text: widget.producto?.nombre);
    _precio = TextEditingController(text: widget.producto?.precio);
  }

  @override
  void dispose() {
    _nombre.dispose();
    _precio.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await widget.api.guardar(
        id: widget.producto?.id,
        nombre: _nombre.text.trim(),
        precio: _precio.text.trim().replaceAll(',', '.'),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_guardando,
    child: AlertDialog(
      title: Text(
        widget.producto == null ? 'Nuevo Producto' : 'Editar Producto',
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nombre,
                enabled: !_guardando,
                maxLength: 100,
                decoration: const InputDecoration(labelText: 'Nombre'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Escribe el nombre.'
                    : null,
              ),
              TextFormField(
                controller: _precio,
                enabled: !_guardando,
                decoration: const InputDecoration(
                  labelText: 'Precio',
                  prefixText: '\$ ',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (value) {
                  final text = (value ?? '').trim().replaceAll(',', '.');
                  if (!RegExp(r'^\d{1,8}(\.\d{1,2})?$').hasMatch(text)) {
                    return 'Precio de 0 a 99999999.99 (hasta 2 decimales).';
                  }
                  return null;
                },
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _guardando ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _guardando ? null : _guardar,
          child: Text(_guardando ? 'Guardando...' : 'Guardar'),
        ),
      ],
    ),
  );
}
