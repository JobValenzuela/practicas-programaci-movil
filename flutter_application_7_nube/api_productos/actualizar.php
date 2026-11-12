<?php
require_once __DIR__ . '/conexion.php';
permitir_metodos(['POST', 'PUT']);
$data = leer_json();
$id = validar_id($data);
[$nombre, $precio] = validar_producto($data);
$stmt = $conn->prepare('UPDATE productos SET nombre = :nombre, precio = :precio WHERE id = :id');
$stmt->execute(['nombre' => $nombre, 'precio' => $precio, 'id' => $id]);
// MySQL también devuelve cero filas modificadas si los valores no cambiaron.
if ($stmt->rowCount() === 0) {
    $existe = $conn->prepare('SELECT id FROM productos WHERE id = :id');
    $existe->execute(['id' => $id]);
    if (!$existe->fetch()) {
        responder(['status' => 'error', 'message' => 'El producto ya no existe.'], 404);
    }
}
responder(['status' => 'success', 'message' => 'Producto actualizado.']);
