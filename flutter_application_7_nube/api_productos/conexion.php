<?php
// Docker proporciona estas variables; los valores por defecto permiten XAMPP.
$host = getenv('DB_HOST') ?: 'localhost';
$port = getenv('DB_PORT') ?: '3306';
$db_name = getenv('DB_NAME') ?: 'mi_tienda';
$username = getenv('DB_USER') ?: 'root';
$password = getenv('DB_PASSWORD') ?: '';

header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Headers: Content-Type');
header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
header('Content-Type: application/json; charset=UTF-8');

function responder($data, $codigo = 200) {
    http_response_code($codigo);
    echo json_encode($data, JSON_UNESCAPED_UNICODE);
    exit;
}

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204);
    exit;
}

set_exception_handler(function ($error) {
    error_log((string) $error);
    responder(['status' => 'error', 'message' => 'Error del servidor. Revisa MySQL y conexion.php.'], 500);
});

function permitir_metodos($metodos) {
    if (!in_array($_SERVER['REQUEST_METHOD'], $metodos, true)) {
        header('Allow: ' . implode(', ', $metodos));
        responder(['status' => 'error', 'message' => 'Método no permitido.'], 405);
    }
}

function leer_json() {
    $data = json_decode(file_get_contents('php://input'), true);
    if (json_last_error() !== JSON_ERROR_NONE || !is_array($data)) {
        responder(['status' => 'error', 'message' => 'El cuerpo debe contener JSON válido.'], 400);
    }
    return $data;
}

function validar_id($data) {
    $id = filter_var($data['id'] ?? null, FILTER_VALIDATE_INT, ['options' => ['min_range' => 1]]);
    if ($id === false) {
        responder(['status' => 'error', 'message' => 'ID inválido.'], 400);
    }
    return $id;
}

function validar_producto($data) {
    $nombre = is_string($data['nombre'] ?? null) ? trim($data['nombre']) : '';
    if ($nombre === '' || preg_match_all('/./us', $nombre) > 100) {
        responder(['status' => 'error', 'message' => 'El nombre debe tener de 1 a 100 caracteres.'], 400);
    }
    $valor = $data['precio'] ?? null;
    if (!is_string($valor) && !is_int($valor) && !is_float($valor)) {
        responder(['status' => 'error', 'message' => 'Precio inválido.'], 400);
    }
    $precio = str_replace(',', '.', trim((string) $valor));
    if (!preg_match('/^[0-9]{1,8}(\\.[0-9]{1,2})?$/D', $precio)) {
        responder(['status' => 'error', 'message' => 'Precio de 0 a 99999999.99, con hasta 2 decimales.'], 400);
    }
    return [$nombre, $precio];
}

$conn = new PDO(
    "mysql:host=$host;port=$port;dbname=$db_name;charset=utf8mb4",
    $username,
    $password,
    [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        PDO::ATTR_EMULATE_PREPARES => false,
    ]
);
