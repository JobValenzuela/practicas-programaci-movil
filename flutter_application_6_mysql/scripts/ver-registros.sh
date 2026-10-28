#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
docker compose exec -T db sh -c 'MYSQL_PWD="$MYSQL_PASSWORD" mysql --table -u tienda mi_tienda -e "SELECT id, nombre, precio, creado_en FROM productos ORDER BY id DESC;"'
