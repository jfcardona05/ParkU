# S2-02 portería e idempotencia

Depende de S2-01. POST /api/gate/operations con Bearer guard/admin:
`{"token":"<qr>","action":"entry","request_id":"<clave estable>"}`.
201 devuelve success, operation_id, visit_id, vehicle_id, action, parking_state,
occurred_at, replayed:false y message. Reintento idéntico → 200, replayed:true.
Clave de 1–100 caracteres compatible con Flutter actual. Misma clave/cuerpo diferente
→ 409 IDEMPOTENCY_CONFLICT; otra clave con QR consumido → QR_USED.
Inspección ahora incluye parking_state y allowed_action. Cada operación revalida QR.

Capacidad inicialmente sin configurar (503 PARKING_NOT_CONFIGURED). Configuración
administrativa llega en S2-03. En esta entrega aislada, salida devuelve 503 BILLING_NOT_READY:
no se libera cupo ni consume QR, ni se registra éxito sin cobrar. S2-03 completa salida.
No presentar esta rama aislada como flujo completo ni fusionarla para una demo final.

Restricciones: ingreso único activo por vehículo; registro persistente de recibo;
bloqueos PostgreSQL compartidos entre instancias, orden settings → vehículo → saldo.
El bloqueo global prioriza corrección del prototipo sobre rendimiento a gran escala.
Eliminar vehículo activo → 409 VEHICLE_IN_USE. Historial conserva placa/tipo al eliminarlo fuera.
