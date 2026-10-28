# Ejemplo sencillo: SQLite local en Flutter

El codigo del modulo esta en `lib/sqlite.dart`:

- `SensorReading`: modelo y mapeo con `toMap` / `fromMap`.
- `DatabaseHelper`: singleton y DAO con insercion y consulta parametrizada.
- `insertBatchReadings`: transaccion que guarda todo el lote o lo revierte.
- `SqlitePage`: pantalla para guardar, consultar por tipo e insertar un lote.

## Ejecutar en Chrome

```sh
flutter pub get
flutter run -d chrome --web-port 8080
```

Los archivos `web/sqlite3.wasm` y `web/sqflite_sw.js` permiten ejecutar SQLite
en Chrome mediante `sqflite_common_ffi_web`. Si se actualiza ese paquete,
regenerarlos con `dart run sqflite_common_ffi_web:setup --force`.

## Donde se guarda la base

Nombre de la base: `iot_local.db`. Tabla: `readings`.

En Chrome se guarda localmente en **IndexedDB del navegador**, dentro del
origen del sitio (por ejemplo, `http://localhost:8080`). No se crea un archivo
`.db` en la carpeta del proyecto. Se puede inspeccionar el almacenamiento en
F12 > Application > Storage > IndexedDB. SQLite administra alli sus archivos;
las filas se consultan desde la app. Recargar la pagina conserva los datos.
Usar el mismo puerto y perfil de Chrome permite mantener el mismo origen.
Borrar los datos del sitio elimina la base; incognito no conserva los datos
al cerrar la sesion.

En Android/iOS, la ruta es `join(await getDatabasesPath(), 'iot_local.db')`,
dentro del almacenamiento privado de la aplicacion.

## Probar

1. Seleccionar Temperatura, escribir 24.5 y pulsar Guardar lectura.
2. Pulsar Insertar lote de ejemplo: agrega dos temperaturas y una humedad.
3. Cambiar a Humedad para consultar la lectura de 60.
4. Recargar Chrome y comprobar que las lecturas siguen guardadas.

```sh
flutter analyze
flutter test
flutter build web
```
