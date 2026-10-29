# ParkU

Prototipo del Sprint 1: aplicación Flutter/Dart, API Java 21 con Spring Boot y PostgreSQL 17. Incluye HU-01 (autenticación), HU-06 (vehículos propios) y HU-02 (saldo y recargas presenciales). Los QR y los descuentos en portería corresponden al Sprint 2.

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

## Cuentas de demostración

| Cuenta | Contraseña | Rol |
|---|---|---|
| ronaldo.mosquera@usantotomas.edu.co | pass123 | estudiante |
| juan.cardona@usantotomas.edu.co | pass123 | estudiante |
| maria.gomez@usantotomas.edu.co | usta2026 | estudiante |
| taquilla@usantotomas.edu.co | caja123 | operador |

Los saldos iniciales demo son 15000, 8000 y 0 COP. Iniciar sesión como operador abre taquilla: elegir destinatario, punto e importe; solo esa cuenta puede acreditar saldo. El usuario consulta su saldo y referencia en el historial. Las tarifas mostradas son propuestas del prototipo, no valores confirmados por la universidad.

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
Tablero: https://trello.com/b/sYfs1JCN/parku