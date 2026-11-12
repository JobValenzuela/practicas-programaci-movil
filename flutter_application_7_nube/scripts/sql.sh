#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
docker compose exec db sh -c 'MYSQL_PWD="$MYSQL_PASSWORD" exec mysql -u tienda mi_tienda'
