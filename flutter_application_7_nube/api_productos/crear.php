<?php
require_once __DIR__ . '/conexion.php';
permitir_metodos(['POST']);
$data = leer_json();
[$nombre, $precio] = validar_producto($data);
$stmt = $conn->prepare('INSERT INTO productos (nombre, precio) VALUES (:nombre, :precio)');
$stmt->execute(['nombre' => $nombre, 'precio' => $precio]);
responder(['status' => 'success', 'message' => 'Producto creado exitosamente.', 'id' => $conn->lastInsertId()], 201);
