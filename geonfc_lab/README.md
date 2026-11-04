# GeoNFC Lab — demo Flutter para exposición

## ¿Qué demuestra?
- **GPS real:** solicita permisos, obtiene latitud/longitud y precisión; permite marcar el punto actual y estimar la distancia a él (geocerca de 100 m).
- **NFC real (sin etiquetas):** comprueba si el equipo es compatible y si NFC está encendido. Si existe una etiqueta física compatible, el botón inicia la sesión y confirma su detección. **No interpreta el contenido de la etiqueta**.
- **NFC simulado:** tres tarjetas virtuales (producto, empleado, entrega) disparan el mismo flujo de registro. Esto **NO** es lectura NFC por radio.
- **Historial temporal:** guarda en memoria los eventos, hora y ubicación GPS que estaba disponible. Se pierde al cerrar la app.

## Inicio rápido en Ubuntu (recomendado)
Prerequisitos: Flutter SDK, Android SDK, emulador o teléfono Android (con USB debugging), conexión a Internet para resolver paquetes.

En una terminal dentro de esta carpeta:

```bash
bash setup.sh
flutter devices
flutter run
```

El script crea el andamiaje Android en esta misma carpeta, agrega las dependencias a `pubspec.yaml` y añade permisos al AndroidManifest. **No sustituye** `lib/main.dart`.

## Método manual si ya tienes un proyecto

```bash
flutter pub add geolocator:^14.1.2 nfc_manager:^4.2.1
```

Copia `lib/main.dart` a tu proyecto, y antes de `<application>` en `android/app/src/main/AndroidManifest.xml` añade:

```xml
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.NFC" />
<uses-feature android:name="android.hardware.nfc" android:required="false" />
```

Cambia compilación de Android a `compileSdk >= 35` si tu plantilla tiene uno inferior.

## Guion de demostración en 4 minutos
1. GPS → Obtener ubicación → enseña coordenadas y precisión; marca el punto.
2. NFC → Verificar NFC → demuestra consulta del hardware (el estado depende del dispositivo).
3. NFC → Selecciona producto, empleado y sucursal; explícales que son **etiquetas simuladas**.
4. Historial → muestra el evento, origen (simulado o real), hora y ubicación.
5. Regresa a GPS → refresca coordenadas y observa distancia al punto marcado.

## Limitaciones
- No se probó la compilación aquí, porque este entorno no dispone del SDK de Flutter/Android. Las API utilizadas se basan en las documentaciones actuales de pub.dev (noviembre 2026).
- GPS requiere un dispositivo con servicios de ubicación y permisos. En un emulador puedes inyectar coordenadas de prueba desde sus controles.
- Lectura NFC física requiere un dispositivo Android/iOS compatible y una etiqueta real compatible. El emulador Android no sustituye una etiqueta real.
- El soporte de NFC físico en iOS requiere además configuración de entitlements/Info.plist. Esta demo se prepara para **Android**.
- La geocerca es didáctica: no valida identidad, geofencing en background ni ubicación fiable para casos de seguridad.

## Referencias técnicas
- https://pub.dev/packages/geolocator
- https://pub.dev/packages/nfc_manager
- https://developer.android.com/develop/connectivity/nfc/hce
