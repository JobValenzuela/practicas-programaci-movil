class Producto {
  final String id;
  final String nombre;
  final String precio;
  const Producto({
    required this.id,
    required this.nombre,
    required this.precio,
  });
  factory Producto.fromJson(Map<String, dynamic> json) => Producto(
    id: json['id'].toString(),
    nombre: json['nombre'] as String,
    precio: json['precio'].toString(),
  );
}
