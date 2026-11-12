# SyncLab

CRUD de tareas Android con Material 3, SQLite como fuente de la UI y Supabase como réplica. No requiere PHP/MySQL. Los archivos de la práctica anterior se conservaron.

## Ejecutar

```bash
flutter pub get
./scripts/run_synclab.sh -d 5d88cfa1
```

`config/supabase.json` contiene exclusivamente la URL y clave pública proporcionadas. La aplicación usa `--dart-define-from-file`; no requiere `.env` ni claves administrativas. El script usa el JDK completo de Android Studio si existe, sin cambiar la configuración global. El Java del sistema detectado era solo un JRE y no podía compilar.

## Supabase

Proyecto: `pezccqtyzmfhnijzbtjx`. La tabla `tasks` fue creada tras tu intervención con el SQL preparado en `supabase/migrations/202611110001_tasks.sql`. En la sesión del Dashboard encontré Anonymous Sign-Ins activado pero pendiente de guardar; guardé ese ajuste y confirmé por API que quedó habilitado.

Se verificó realmente con dos identidades anónimas: crear, consultar, editar, reintentar sin duplicados y eliminar lógicamente. RLS impidió que el segundo usuario leyera/modificara la tarea del primero o insertara usando su propietario. Las pruebas conservan tombstones y usuarios anónimos de verificación; no se usaron ni almacenaron claves administrativas.

Para otro proyecto: ejecutar la migración una sola vez en SQL Editor y habilitar Anonymous Sign-Ins en Authentication → Sign In / Providers. La migración falla si ya existe `tasks`, en lugar de sustituir datos existentes. [Referencia de autenticación anónima](https://supabase.com/docs/reference/dart/auth-signinanonymously).

## Arquitectura e integridad

- `models/`: tareas con UUID, propietario y fechas.
- `data/`: SQLite guarda tarea + instantánea outbox en una transacción. Después actualiza la UI, sin esperar la red.
- `services/`: Supabase y motor serializado. Upsert idempotente por UUID; una respuesta perdida conserva la operación para reintentar. Solo una confirmación de la revisión vigente marca la tarea sincronizada.
- `state/`: estado ligero con ChangeNotifier. Disparadores al iniciar, guardar, recuperar conectividad, volver a primer plano, pulsar sincronizar y cada minuto mientras el proceso está vivo. Peticiones con timeout de 15 segundos; máximo 100 operaciones por ciclo, continuando en la siguiente activación.
- `screens/` y `widgets/`: CRUD, estadísticas, filtros, estados de sincronización y diagnóstico. “Consultar datos de la nube” hace una consulta directa paginada y muestra IDs, fechas y eliminaciones, separada de SQLite.

Wi-Fi no garantiza acceso: solo una operación remota exitosa confirma Supabase. La primera autenticación necesita Internet; antes se permite guardar tareas sin propietario, vinculadas a la primera sesión válida. La sesión anónima persiste. Si cambia el propietario, se bloquea sincronización para no mezclar datos.

Las descargas no sobrescriben tareas con operaciones pendientes. Se conservan tombstones localmente y en la nube para evitar resurrecciones. Conflictos entre dispositivos: cambios locales pendientes ganan al descargar; el último envío aceptado por el servidor gana. El servidor asigna `updated_at`. Esta política prioriza la práctica con un dispositivo, sin resolución colaborativa por campo. La última sincronización exitosa se guarda después de enviar y descargar; una cola mayor a 100 operaciones requiere otro ciclo y se sigue mostrando por separado.

## Pruebas ejecutadas

- `flutter doctor -v`: sin incidencias; Flutter 3.47.7 / Dart 3.13.5.
- `flutter devices` y `adb devices -l`: Android 16, modelo 25062PC34G, serie 5d88cfa1, autorizado.
- `dart format .` y `flutter analyze`: ejecutados.
- `flutter test`: **10 aprobadas**, SQLite FFI real y nube simulada. Cubren persistencia, rollback transaccional, edición durante envío, serialización, respuesta perdida, tombstones, descarga protegida y formulario en pantalla pequeña.
- `integration_test/cloud_test.dart`: **aprobada en el teléfono**, SQLite nativo y Supabase real. Incluye creación online, cola offline y reapertura de SQLite, edición/eliminación, pérdida inyectada de respuesta después de commit real, convergencia y ausencia de duplicados.
- `python3 scripts/test_physical_network.py`: **aprobada en el teléfono**. Apaga físicamente Wi-Fi y datos mediante ADB, crea tres tareas, edita y elimina offline, reabre SQLite con cinco operaciones persistidas y comprueba recuperación automática y nube real. Restaura las conexiones originales en `finally`: Wi-Fi encendido, datos apagados.
- Los primeros intentos fallaron por JRE incompleto, proveedor anónimo deshabilitado o aviso de instalación cancelado; se corrigieron y se repitieron las comprobaciones afectadas.

La reapertura de SQLite con tareas y operaciones pendientes se verificó dentro de las pruebas. En la aplicación final se forzó el cierre del proceso y se reabrió: persistieron propietario y metadatos, y volvió a sincronizar automáticamente. La base productiva estaba vacía; el cierre de proceso con tareas pendientes queda como paso de la demostración manual. `device_test.dart` queda disponible como prueba adicional con nube simulada; la integración real y la prueba física cubren su caso principal.

## Compilar e instalar

```bash
JAVA_HOME=/snap/android-studio/current/jbr flutter build apk --debug --dart-define-from-file=config/supabase.json
/home/job-valenzuela/Android/Sdk/platform-tools/adb -s 5d88cfa1 install -r build/app/outputs/flutter-apk/app-debug.apk
/home/job-valenzuela/Android/Sdk/platform-tools/adb -s 5d88cfa1 shell am start -n com.example.flutter_application_6_mysql/.MainActivity
```

El APK de demostración usa firma de depuración. El teléfono puede pedir aceptar la instalación **cada vez**, incluso si la depuración USB ya está autorizada. No se actualizaron Flutter, Gradle ni el SDK global.

## Demostración al profesor

1. Con Internet, abre Diagnóstico y sincroniza. Crea una tarea y verifica “Sincronizado”. Pulsa “Consultar datos de la nube”.
2. Activa modo avión y apaga Wi-Fi. Crea tres tareas, edita una y elimina otra: los cambios son inmediatos y la cola aumenta.
3. Fuerza el cierre y vuelve a abrir **sin borrar datos ni desinstalar**. Las tareas y la cola deben persistir.
4. Recupera Internet. La cola debe llegar a cero automáticamente. Consulta la nube para comparar títulos, UUID y `deleted = true`. La eliminada no debe reaparecer.

No borrar datos durante la práctica: eliminaría SQLite y la identidad anónima persistida.

## Estado final del teléfono

APK final instalado y aplicación iniciada, detenida con `am force-stop` y reabierta. PID distinto confirmado. Logs del proceso: **0 errores Flutter/Android**. SQLite productivo: **0 tareas y 0 operaciones pendientes**; identidad anónima y última sincronización persistidas. Última sincronización comprobada: 11 de noviembre de 2026, 23:53 (America/Chihuahua). Wi-Fi restaurado encendido y datos móviles apagados. Las pruebas usaron bases separadas y sus registros remotos de verificación pueden conservarse como tombstones.

No quedan bloqueos de configuración o instalación. Queda la limitación habitual de las identidades anónimas: desinstalar o borrar datos pierde esa identidad. La política de conflictos es deliberadamente sencilla para un dispositivo.
