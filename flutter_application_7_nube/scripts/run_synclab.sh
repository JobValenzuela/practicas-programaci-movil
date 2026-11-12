#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
# La instalación de Java del sistema puede ser solo un JRE.
if [[ -x /snap/android-studio/current/jbr/bin/javac ]]; then
  export JAVA_HOME=/snap/android-studio/current/jbr
fi
exec flutter run --dart-define-from-file=config/supabase.json "$@"
