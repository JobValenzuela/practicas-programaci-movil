#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
if ! command -v flutter >/dev/null 2>&1; then
  echo 'Flutter no está en PATH. Instálalo/configúralo y vuelve a ejecutar el script.' >&2
  exit 1
fi
flutter create --platforms=android --project-name geonfc_lab .
flutter pub add 'geolocator:^14.1.2' 'nfc_manager:^4.2.1'
python3 - <<'PY'
from pathlib import Path
manifest=Path('android/app/src/main/AndroidManifest.xml')
s=manifest.read_text()
permissions='''    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
    <uses-permission android:name="android.permission.NFC" />
    <uses-feature android:name="android.hardware.nfc" android:required="false" />
'''
if 'android.permission.NFC' not in s:
    s=s.replace('    <application', permissions+'    <application', 1)
manifest.write_text(s)
PY
flutter pub get
echo 'Proyecto preparado. Conecta un Android y ejecuta: flutter run'
