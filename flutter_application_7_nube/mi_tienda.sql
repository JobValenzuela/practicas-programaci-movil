-- Ejecutar en phpMyAdmin o en la consola de MySQL.
-- Puede ejecutarse nuevamente sin borrar los productos existentes.
CREATE DATABASE IF NOT EXISTS mi_tienda
  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE mi_tienda;

CREATE TABLE IF NOT EXISTS productos (
  id INT AUTO_INCREMENT PRIMARY KEY,
  nombre VARCHAR(100) NOT NULL,
  precio DECIMAL(10, 2) NOT NULL,
  creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
