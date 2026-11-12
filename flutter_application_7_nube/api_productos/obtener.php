<?php
require_once __DIR__ . '/conexion.php';
permitir_metodos(['GET']);
$stmt = $conn->query('SELECT id, nombre, precio, creado_en FROM productos ORDER BY id DESC');
responder($stmt->fetchAll());
