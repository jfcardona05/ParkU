# Sprint 2 · Integración Flutter con la API

La app usa la API autenticada para emitir QR, inspeccionar y confirmar operaciones,
consultar el saldo y sus movimientos, el estado de los vehículos, la ocupación,
las tarifas vigentes y el historial paginado de accesos.

## Preparar la revisión

1. Usar una base de pruebas separada y aplicar las migraciones al arrancar la API.
2. Preparar cuentas de estudiante, taquilla y guard/admin. El aprovisionamiento
   autorizado de roles se describe en `docs/s2-03-api.md`.
3. Configurar una capacidad de pruebas mediante la API de admin antes del ingreso.
   No existe un valor de capacidad oficial predeterminado.
4. Ejecutar Flutter con `API_BASE_URL` apuntando a esa API. El QR real es el modo
   predeterminado. `PARKU_QR_DEMO=true` conserva la demostración explícita.

## Recorrido de revisión

- Estudiante inicia sesión, abre Mis Vehículos y muestra un QR.
- Guard/admin inicia sesión en otro navegador/dispositivo y abre Portería.
- Escanea o introduce el código. La API determina si corresponde ingreso o salida.
- Confirma explícitamente. Una respuesta incierta permite reintentar con la misma
  clave y recuperar el recibo aunque el QR haya vencido después del primer intento.
- Para salir, el estudiante genera un QR nuevo. Si falta saldo, la app muestra el
  rechazo del servidor. Tras recargar, se puede reintentar; un QR vencido exige otro.
- El guard ve el cobro, saldo posterior y tarifa del recibo del servidor.
- El estudiante actualiza Saldo y movimientos para ver el débito y su tarifa.
  Desde Inicio abre Consultar cupos, tarifas y accesos para revisar estado e historial.
- Revisar permisos de cámara y el lector manual. Cámara física y APK requieren
  verificación en el dispositivo y registro de evidencia.

## Comprobaciones

Desde `mobile/`:

```text
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build web
```

La prueba `test/parking_live_test.dart` ejecuta los adaptadores Flutter contra
Spring Boot y PostgreSQL reales. Requiere una base demo exclusiva y cuentas nuevas
de pruebas, incluida una cuenta de guard y otra de admin aprovisionadas por el responsable.
La cuenta de estudiante debe comenzar sin saldo y sin vehículos. No ejecutarla sobre
una base con operaciones reales. Las credenciales se suministran al ejecutar:

```text
flutter test test/parking_live_test.dart --dart-define=LIVE_PARKING_API=true --dart-define=API_BASE_URL=http://localhost:8000 --dart-define=LIVE_STUDENT_EMAIL=cuenta-de-prueba --dart-define=LIVE_GUARD_EMAIL=guard-de-prueba --dart-define=LIVE_ADMIN_EMAIL=admin-de-prueba --dart-define=LIVE_TEST_PASSWORD=clave-de-pruebas
```

La prueba configura 2 cupos únicamente para su escenario desechable, crea un vehículo,
verifica revocación y permisos, ingresa, rechaza una salida sin saldo, recarga por taquilla,
confirma la salida y repite la confirmación. Comprueba un solo débito, saldo, tarifa,
ocupación, estado e historial aislado. Las cuentas se cierran al terminar.

## Resultado de esta revisión

- Formato Dart y `flutter analyze`: correctos.
- `flutter test`: 30 pruebas aprobadas; dos omitidas (API real optativa y reloj
  de vencimiento omitido previamente).
- `flutter build web`: compilación correcta.
- Prueba optativa real: aprobada contra Spring Boot 3.5.13 y PostgreSQL en una
  base desechable, con cuentas nuevas. Se comprobaron revocación, permisos,
  ingreso idempotente, rechazo por saldo insuficiente, recarga, salida, un solo
  débito, tarifa, saldo, ocupación, estado e historial aislado.
- `spotless:check` pasó. La suite Maven local no pudo ejecutarse porque faltó
  descargar dependencias de Surefire 3.5.5. Para la prueba real se inició la API
  desde las clases compiladas y las dependencias locales; esto no sustituye la
  suite backend de GitHub Actions.
- Pendientes: aprobación de Ronaldo, merge, cámara física, permisos y APK.
