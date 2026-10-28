# Práctica: Flutter + PHP + MySQL

Integración del CRUD de productos del PDF. Flujo: Flutter → HTTP/JSON → Apache/PHP (PDO) → MySQL.

## Ejecutar por HTTP desde Android sin cable

La API escucha en el puerto 8080 de la IP indicada por `API_BIND_IP` en `.env`.
Para Wi-Fi configura `API_BIND_IP=10.10.214.93`. Conecta el teléfono y la
computadora a la misma red Wi-Fi. La IP actual de la computadora es
`10.10.214.93`; la URL de consulta es
`http://10.10.214.93:8080/api_productos/obtener.php`.

```bash
docker compose up -d --build --wait
flutter build apk --debug --dart-define=API_BASE_URL=http://10.10.214.93:8080/api_productos
```

Instala este APK en Android. No necesita `adb reverse`: el tráfico HTTP pasa por
Wi-Fi y puedes desconectar el USB después de instalar. Mantén la computadora y
Docker encendidos. Si cambia la IP de la computadora, recompila con la nueva IP
e instala otra vez; actualiza también `API_BIND_IP` y ejecuta `docker compose up -d`.
Una reserva DHCP en el router permite mantener esa IP.
La API de esta práctica no tiene autenticación: úsala en una red de confianza.
MySQL permanece accesible desde la computadora en `127.0.0.1:3307` para DBeaver.

## Alternativa: ejecutar con Docker y Android por USB

Para esta alternativa cambia `API_BIND_IP=127.0.0.1` en `.env` antes de arrancar
los servicios. Usa el APK compilado con la URL local indicada abajo. La versión
Wi-Fi descrita arriba utiliza la IP de la computadora y no depende del USB.

Requisitos: Docker Compose, Flutter, Android SDK y depuración USB autorizada.

1. Si no existe `.env`, copia `.env.example` a `.env` y cambia sus dos contraseñas.
2. Arranca los servicios:

```bash
docker compose up -d --build --wait
curl http://127.0.0.1:8080/api_productos/obtener.php
```

MySQL importa `mi_tienda.sql` en el primer arranque y conserva los productos en
el volumen `mysql_data`. Apache/PHP sirve la API en el puerto local 8080.
MySQL también está disponible en `127.0.0.1:3307` para DBeaver en esta computadora.

### Consultar registros y conectar DBeaver

Desde la carpeta del proyecto, sin introducir manualmente la contraseña:

```bash
bash scripts/ver-registros.sh
bash scripts/sql.sh
```

El segundo comando abre la consola SQL. Puedes ejecutar
`SELECT * FROM productos;` y salir con `exit`.
Si Docker indica `permission denied` al acceder a `/var/run/docker.sock`,
ejecuta los scripts con `sudo bash` o abre una sesión que tenga activo el grupo
`docker`.

En DBeaver crea una conexión MySQL con host `127.0.0.1`, puerto `3307`,
base `mi_tienda`, usuario `tienda` y la contraseña `MYSQL_PASSWORD` de `.env`.
El puerto ya está configurado en `compose.yaml`. En el editor SQL ejecuta:

```sql
SELECT * FROM mi_tienda.productos ORDER BY id DESC;
```

3. Conecta el teléfono y ejecuta (sustituye SERIAL por el de `adb devices`):

```bash
export PATH="$PATH:$HOME/Android/Sdk/platform-tools"
adb devices
adb -s SERIAL reverse tcp:8080 tcp:8080
flutter pub get
flutter run -d SERIAL --dart-define=API_BASE_URL=http://127.0.0.1:8080/api_productos
```

La redirección USB permite que `127.0.0.1:8080` del teléfono llegue al servidor
de la computadora. Repítela al reconectar o reiniciar el teléfono. La computadora
y los contenedores deben permanecer encendidos para consultar y guardar datos.

Para generar e instalar el APK sin mantener `flutter run` abierto:

```bash
flutter build apk --debug --dart-define=API_BASE_URL=http://127.0.0.1:8080/api_productos
adb -s SERIAL install -r build/app/outputs/flutter-apk/app-debug.apk
adb -s SERIAL shell am start -n com.example.flutter_application_6_mysql/.MainActivity
```

Estado y registros: `docker compose ps` y `docker compose logs --tail=100`.
Para detener los servicios conservando los productos: `docker compose down`.
No agregues `-v` si quieres conservar los datos.

## Qué hace el código

- `lib/main.dart`: lista, formulario validado, edición, confirmación de eliminación
  y mensajes de errores. Evita envíos repetidos mientras guarda.
- `lib/producto.dart`: modelo de producto recibido como JSON.
- `lib/producto_api.dart`: cliente HTTP con tiempo límite de 15 segundos y URL
  configurable con `API_BASE_URL`.
- `api_productos/conexion.php`: conexión PDO, validación de JSON, nombre, precio e
  ID, respuestas JSON y configuración de conexión mediante variables de entorno.
- Los otros cuatro PHP consultan, crean, actualizan y eliminan con consultas
  preparadas. `mi_tienda.sql` crea la tabla con precio decimal y fecha de creación.
- `test/widget_test.dart`: verifica la validación del formulario y que un error
  del servidor no borre los datos ingresados.

Las instrucciones siguientes son la alternativa manual con XAMPP.

## 1. Crear la base de datos

Inicia MySQL en XAMPP e importa **mi_tienda.sql** desde phpMyAdmin (pestaña Importar).
También puedes abrir el archivo en MySQL Workbench y ejecutarlo completo.

Crea la base **mi_tienda** y la tabla **productos** con id, nombre, precio y creado_en.
No borra datos al ejecutarlo nuevamente y comienza sin productos de ejemplo.

## 2. Montar la API

1. Copia la carpeta **api_productos** de este proyecto a **C:\\xampp\\htdocs\\api_productos**.
2. Ajusta host, puerto, usuario y contraseña en **api_productos/conexion.php** en el servidor. Por defecto usa localhost:3306, root y contraseña vacía para XAMPP local.
3. Inicia Apache y MySQL. PHP debe tener habilitado **pdo_mysql**.
4. Abre **http://localhost/api_productos/obtener.php**. Debe mostrar **[]** si la tabla está vacía.

Archivos: conexion.php, obtener.php, crear.php, actualizar.php y eliminar.php.
Las escrituras reciben JSON. Crear usa POST; actualizar admite POST/PUT; eliminar admite POST/DELETE.
La API valida los datos y utiliza consultas preparadas. Permite precio cero.
Es una práctica sin autenticación: úsala en el entorno de clase o una red de confianza.

## 3. Ejecutar Flutter

Desde la carpeta del proyecto:

```powershell
flutter pub get
flutter run
```

La URL por defecto es **http://10.0.2.2/api_productos**, para el emulador estándar de Android Studio.

Para un teléfono físico conectado a la misma red, consulta la IPv4 de tu PC con **ipconfig** y sustituye la IP del ejemplo:

```powershell
flutter run --dart-define=API_BASE_URL=http://192.168.1.50/api_productos
```

Para Chrome o Windows en la misma PC donde corre Apache:

```powershell
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost/api_productos
```

Si Apache usa otro puerto, inclúyelo, por ejemplo **http://192.168.1.50:8080/api_productos**.
Si usas un servidor remoto, proporciona la URL de ese servidor.
Reinicia la ejecución al cambiar **API_BASE_URL**; hot reload no cambia esta constante.
Android tiene permiso de Internet y HTTP habilitado para esta práctica local.
Desde un teléfono, localhost apunta al propio teléfono. Apache debe ser accesible desde la red y el firewall debe permitir su puerto.

## Uso y verificación mínima

- Pulsa **+** para crear un producto con nombre y precio (máximo dos decimales).
- Usa el lápiz para editar y la papelera para eliminar con confirmación.
- Pulsa actualizar para volver a consultar la base.
- Si falla el guardado, el formulario conserva los datos y muestra el error.

Comprobaciones locales:

```powershell
flutter analyze
flutter test
```

La prueba usa una API simulada; no necesita MySQL. Con el servidor configurado, verifica una sola secuencia: crear un producto, editarlo y eliminarlo. La conexión real requiere importar el SQL y montar la API.
