# S2-05 · Adelanto de portería

PR independiente de S2-04. Demo: `flutter run -d chrome --dart-define=PARKU_QR_DEMO=true`, entrar como operador de taquilla y pulsar Demo portería. Roles reales propuestos `guard` y `admin`: S2-00 debe confirmarlos; el frontend no concede permisos de servidor.

Cámara solo al pulsar Escanear; error de permisos con alternativa de lector externo/entrada manual. En web requiere localhost o HTTPS y permiso del navegador. Android declara CAMERA; compilación APK y cámara física pendientes.

Validar → confirmar explícitamente → resultado. Bloqueo mientras procesa, una sola devolución de cámara y misma clave al reintentar confirmación. Un adaptador real debe enviar esa clave al servidor con garantía transaccional/idempotente. No se ha inventado un endpoint. Por defecto el servicio real informa indisponibilidad.

Demo en memoria: `PARKU-DEMO:7:EXPIRACION_UNIX_MILISEGUNDOS` (también compatible con QR demo S2-04). Validar caducidad, reutilización, doble ingreso y salida sin ingreso. No persiste, no descuenta saldo ni representa seguridad real. El modo demo solo sirve para revisar UX.

Pendiente Ronaldo: acordar contrato S2-00, roles, conectar S2-01/02, validar autorización en servidor y concurrencia, tarifa S2-03. Este adelanto no cierra #22.
