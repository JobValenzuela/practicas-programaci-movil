<?php
require_once __DIR__ . '/conexion.php';
permitir_metodos(['POST', 'DELETE']);
$id = validar_id(leer_json());
$stmt = $conn->prepare('DELETE FROM productos WHERE id = :id');
$stmt->execute(['id' => $id]);
if ($stmt->rowCount() === 0) {
    responder(['status' => 'error', 'message' => 'El producto ya no existe.'], 404);
}
responder(['status' => 'success', 'message' => 'Producto eliminado.']);
