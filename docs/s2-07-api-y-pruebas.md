# S2-07 ocupación historial y verificación

Depende de S2-01/02/03. Todas las rutas requieren Bearer de sesión.

| GET | Respuesta 200 | Permisos |
| --- | --- | --- |
| /api/parking/occupancy | success, capacity, occupied, available | Agregado autenticado sin placas ni titulares |
| /api/vehicles/7/parking | success, vehicle_id, parking_state, visit_id, entered_at | Solo propietario; 404 si ajeno |
| /api/parking/history?limit=20&before_id=100 | success, operations, next_before_id | Solo titular de estancia, incluso para guard/admin |

Sin capacidad configurada, ocupación devuelve 503 PARKING_NOT_CONFIGURED.
Estado OUTSIDE tiene visit_id y entered_at nulos. Historial por operation_id descendente;
limit entre 1 y 100, cursor exclusivo. Cada operación incluye plate, action, occurred_at,
charge (null en ingreso), visit_id y vehicle_id. next_before_id=null si terminó la lista.
Antes de borrar un vehículo con estancia activa se devuelve 409; fuera del parqueadero
puede borrarse y se conservan su placa histórica y los movimientos del titular.

Ejemplo:
```json
{"success":true,"capacity":100,"occupied":1,"available":99}
```
100 es ejemplo, no capacidad oficial. Un cursor ajeno nunca cambia el filtro de usuario.
Errores de parámetros: 400 INVALID_REQUEST; sesión ausente: 401 UNAUTHORIZED.

## Resultados reales del entorno de desarrollo

Java JDK 21, PostgreSQL 17.6 local desechable, base exclusiva parku_test.
24 pruebas aprobadas (14 API Sprint 2, 2 cálculo de precio, 8 regresión Sprint 1).
Ejecutar la comprobación final antes de publicar:
`./mvnw spotless:check test` con DB_URL apuntando exclusivamente a una base terminada en _test.
Los tests truncan tablas y verifican el nombre antes de hacerlo. No usar base con datos reales.
El modo Mockito subclass permite verificar sin el autoattach del agente en entornos restringidos;
no hay mocks de transacciones, DB o HTTP: las pruebas son HTTP real contra PostgreSQL.

Casos cubiertos: propiedad, roles, QR inválido/vencido/revocado/reutilizado, regeneración
concurrente, doble ingreso, salida sin ingreso, cupo concurrente, mismo recibo concurrente,
reintento de salida luego de vencer el QR, saldo insuficiente sin efectos, dos vehículos
compartiendo saldo, recarga durante salida, cambios de tarifa sin revalorizar estancias,
redondeo al límite exacto y fracción de segundo, permisos administrativos, capacidad inválida,
aislamiento de consultas, paginación, borrado e historial, y rollback inyectando fallo en
el registro del recibo después del débito. La inyección se crea y retira solo dentro del test.

## Limitaciones y cierre

La cámara física, adaptación Flutter, pantalla de tarifas y flujo real desde el dispositivo
siguen siendo trabajo de integración de Juan y cierre conjunto #26. No se afirma Done.
No se crearon cuentas admin/guard automáticamente; aprovisionarlas conforme a s2-03-api.md.
Capacidad pendiente del administrador. Las reglas operativas son revisables en S2-00 v0.2.
El bloqueo global de portería reduce rendimiento pero serializa correctamente el prototipo
entre instancias. No se hizo prueba de carga ni auditoría de seguridad externa.
PR hacia main acumulativos: integrar en orden de dependencias, sin aprobación ficticia.
