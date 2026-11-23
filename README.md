# ParkU

Aplicación ParkU: Flutter/Dart, API Java 21 con Spring Boot y PostgreSQL 17. Incluye HU-01 (autenticación), HU-06 (vehículos propios) y HU-02 (saldo y recargas presenciales). El Sprint 2 incorpora QR, portería y cobros con conexión Flutter/API.

## Ejecutar

Requisitos: Java 21, Flutter estable, PostgreSQL 17 (o Docker). Maven se descarga mediante el wrapper incluido.

1. Iniciar PostgreSQL: `docker compose up -d db`. Si ya tienes PostgreSQL, crea una base `parku` y configura DB_URL, DB_USER y DB_PASSWORD.
2. Abrir PowerShell en `backend`:

```powershell
$env:DB_URL='jdbc:postgresql://localhost:5432/parku'
$env:DB_USER='parku'
$env:DB_PASSWORD='parku_local'
$env:PARKU_DEMO='true'
.\mvnw.cmd spring-boot:run
```

Flyway aplica las migraciones al arrancar. La API escucha en el puerto 8000. Las cuentas demo se crean únicamente con PARKU_DEMO=true; no debe habilitarse en un despliegue público.

3. Abrir otra terminal en `mobile`:

```powershell
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8000
```

Para el emulador Android: `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000`. El manifiesto de depuración permite HTTP local; para una aplicación distribuida se debe usar HTTPS.

## Caja diaria y compartir la web

Taquilla puede abrir caja, registrar recargas y cerrar dejando una base para devueltas.
Los históricos y comprobantes definitivos se consultan únicamente en Reportes.
Las nuevas recargas requieren una apertura del operador en el punto y día correspondientes.
Consulta los [cálculos, reglas y API de caja](docs/caja-y-vista-publica.md).

En Windows, `iniciar-parku.cmd` arranca el entorno local. `compartir-parku.cmd` prepara
una vista web con enlace HTTPS temporal para celulares y otros computadores;
`cerrar-enlace-publico.cmd` termina esa vista sin borrar los datos.
El enlace se genera en tu PC al ejecutar el archivo y requiere mantenerlo encendido.

## Cuentas de demostración

| Cuenta | Contraseña | Rol |
|---|---|---|
| ronaldo.mosquera@usantotomas.edu.co | pass123 | estudiante |
| juan.cardona@usantotomas.edu.co | pass123 | estudiante |
| maria.gomez@usantotomas.edu.co | usta2026 | estudiante |
| taquilla@usantotomas.edu.co | caja123 | operador |

Los saldos iniciales demo son 15000, 8000 y 0 COP. Iniciar sesión como operador abre taquilla: elegir destinatario, punto e importe; solo esa cuenta puede acreditar saldo. El usuario consulta su saldo y referencia en el historial. Los valores configurados son parte del proyecto; no constituyen una certificación de tarifas oficiales de la universidad.

## Verificar

Las pruebas de backend usan PostgreSQL real y vacían sus tablas antes de cada caso. **Usar exclusivamente una base de pruebas separada**, por ejemplo `parku_test`.

```powershell
# Desde backend, con una base de pruebas creada y credenciales configuradas:
$env:DB_URL='jdbc:postgresql://localhost:5432/parku_test'
.\mvnw.cmd spotless:check test
# Desde mobile:
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build web
# Con API iniciada sobre una base demo desechable:
flutter test test/api_live_test.dart --dart-define=LIVE_API=true
```

Las pruebas de integración Flutter crean una cuenta y una recarga reales en la base demo de pruebas. Las pruebas HTTP de Java comprueban CP-01 a CP-05, permisos, cierre de sesión y recargas concurrentes. Las pruebas Flutter comprueban encabezados de sesión, errores y llamadas de taquilla. No sustituyen la revisión humana del compañero.

## Organización

- `backend/`: API y migraciones SQL versionadas.
- `mobile/`: aplicación Flutter y pruebas.
- `docs/trello.md`: tarjetas y política del tablero.
- `docs/revision.md`: pasos para revisar e integrar los cuatro commits nuevos.

Repositorio: https://github.com/jfcardona05/ParkU
Tablero Sprint 2: https://github.com/users/jfcardona05/projects/2

## Sprint 2 y evolución integrada

El QR, portería, integración real, rediseño Figma, pase diario, transferencias y reportes
están integrados. También están integrados el panel de taquilla, apertura/cierre de caja,
base para devueltas, comprobantes descargables, inicio Windows y enlace HTTPS temporal.
Los PR #36, #37, #39, #44 y #46–49 ya no deben describirse como pendientes de merge.

- [Informe actualizado de implementación, pruebas y trazabilidad](docs/s2-09-cierre-y-evidencias.md).
- [Guion y acta de demostración por completar](docs/s2-09-demo-y-acta.md).
- [Pase diario y transferencias](docs/qr-diario-y-transferencias.md).
- [Caja, reportes, comprobantes y vista pública temporal](docs/caja-y-vista-publica.md).
- [Inicio rápido en Windows](docs/inicio-rapido-windows.md).

Regla actual: al confirmar Generar QR diario se cobra una vez la tarifa del vehículo.
Hay un pase por usuario y día colombiano, vinculado al vehículo elegido, válido hasta
medianoche. Consultarlo o repetir la solicitud no vuelve a cobrar; la salida del pase
diario no aplica otro cobro. Valores iniciales: moto 4.000 COP y automóvil 5.000 COP.
Las estancias anteriores sin pase diario conservan su regla histórica.
Solo admin puede versionar tarifas/configuración mediante API; falta una pantalla
administrativa específica. Los cupos aparecen como Próximamente, sin medición física.

Las nuevas recargas requieren apertura válida de caja. Panel de caja y Reportes
separan la operación diaria de los históricos y comprobantes.
El enlace público es temporal y requiere el computador encendido; no equivale
a alojamiento permanente. La ficha QR actual muestra nombre, placa y tipo,
y queda pendiente ampliarla al comprobante completo del pago.

La CI verifica backend, Flutter y compilación web. Cámara física, APK si se exige,
demostración conjunta y acta requieren evidencia separada.
Los contratos S2 iniciales y los informes de octubre/10 de noviembre son históricos:
sus cifras de pruebas, QR de 120 segundos y cobro por horas no describen el nuevo flujo diario.

### Pases de visitantes, identidad y perfil

Taquilla registra **Recarga usuario** o **Pase diario visitante** desde Panel de caja.
Ambos conceptos aparecen juntos en Reportes y suman al recaudo y cierre de la caja
abierta del operador. Las transferencias y los descuentos del saldo no son efectivo
recibido y no se suman al cierre. La tarifa del visitante se consulta según moto o
automóvil y se confirma con el efectivo recibido antes de emitir el pase.

El visitante no necesita cuenta: taquilla registra nombre, placa y vehículo,
entrega el comprobante con QR (descargar HTML y pulsar Imprimir / Guardar PDF).
Puede reimprimir el mismo pase desde Reportes. El QR abre una ficha pública
sin inicio de sesión; portería usa su lector para confirmar ingreso y salida sin
volver a cobrar. Es un pase para una placa durante el día colombiano de emisión,
con una entrada y una salida. No se emiten dos pases para la misma placa y fecha.
Los reintentos con la misma referencia recuperan el original, incluso tras cerrar caja.
Para escanear desde otro teléfono, la URL pública de la API debe ser accesible por
ese teléfono; localhost solo funciona en el propio equipo.

El registro solicita CC o TI y número (5–15 dígitos, sin puntos). Las cuentas
existentes conservan acceso y pueden completar sus datos en **Usuario**.
La transferencia solicita tipo y número de documento del destinatario, conserva
su referencia en reintentos y se registra en ambas billeteras. Un documento no
puede repetirse con el mismo tipo. Esta validación no consulta registros oficiales.
**Usuario** está disponible para todos los roles salvo taquilla y permite cambiar
nombre, correo, documento y contraseña con confirmación de la contraseña actual.
Cambiar correo o contraseña invalida las otras sesiones y conserva la actual.

La migración V10 añade estos datos sin inventar documentos para cuentas antiguas
ni modificar sus saldos. Los cierres históricos permanecen como fueron registrados.
