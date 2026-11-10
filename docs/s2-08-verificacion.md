# S2-08 · Verificación del flujo Flutter

Esta rama combina los adelantos de QR, portería y saldo para probarlos juntos. La prueba de widgets usa la pantalla de inicio de sesión, un cliente HTTP de pruebas, el QR de demostración, la entrada manual de portería y la pantalla de saldo. El adaptador de prueba devuelve un cobro fijo tras confirmar la salida. La API de ParkU no participa en ese cobro.

Desde `mobile/`:

```text
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build web
```

Con el contrato S2-00 y las API S2-01/02/03/07 disponibles, conectar los adaptadores Flutter y repetir sobre una base de pruebas separada:

| Caso | Resultado esperado con la API real |
| --- | --- |
| Sesión y vehículo propio | Solo el titular autorizado puede pedir su QR. |
| Ingreso por portería | Un operador autorizado confirma un solo ingreso activo. |
| QR inválido, vencido o consumido | Portería muestra el error y el servidor no registra un evento. |
| Salida con saldo suficiente | La tarifa y el débito vienen del servidor. La salida y el movimiento aparecen una sola vez, incluso si se reintenta la confirmación. |
| Salida con saldo insuficiente | El mensaje explica el motivo, no aparece un cobro exitoso y el estado corresponde a la regla acordada. |
| Saldo, historial y ocupación | Los datos se actualizan tras la operación. Otra cuenta no puede consultar movimientos ajenos. |
| Cámara en la plataforma acordada | Se valida cámara física, permisos y alternativa manual. Para Android, registrar también la instalación y ejecución del APK. |

Registrar el commit, los resultados por caso y las limitaciones en el PR antes de cerrar #25.
