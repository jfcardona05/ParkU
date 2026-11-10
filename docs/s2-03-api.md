# S2-03 tarifas y cobro atómico

Precios iniciales autorizados por Ronaldo: moto 4000 COP, automovil 5000 COP.
Supuesto operativo revisable: hora iniciada, mínimo una hora. Valores de bloque y mínimo
se pueden cambiar en la API de administración; no es una tarifa universitaria certificada.
No se cambia retrospectivamente la tarifa de una estancia en curso.

## Administración

Solo admin puede modificar configuración y tarifas. guard/admin operan portería;
operador conserva recargas, sin conceder privilegios por enviar un rol al registro.
Un responsable con acceso autorizado a PostgreSQL debe asignar roles a cuentas ya creadas;
no existe autoasignación ni contraseña de administrador predeterminada:

```sql
-- psql: \set email 'correo-de-la-cuenta-registrada'
UPDATE users SET role='admin' WHERE email=:'email';
-- Para otra cuenta de portería, asignar guard con el mismo procedimiento.
```

GET /api/parking/rates con Bearer autenticado → 200 `{"success":true,"rates":[...]}`.
POST /api/admin/parking/rates con Bearer admin:
`{"vehicle_type":"moto","amount":4000,"block_seconds":3600,"minimum_blocks":1}`
→ 201 `{"success":true,"rate":{"id":3,"vehicle_type":"moto","amount":4000,"block_seconds":3600,"minimum_blocks":1,"created_at":"<UTC>"}}`.

GET /api/admin/parking/settings → 200 `{"success":true,"settings":{"capacity":null}}`
antes de configurar. POST a la misma ruta `{"capacity":100}` configura 100 cupos
(ejemplo, NO capacidad acordada); 200 devuelve settings.capacity. Rechaza reducir
por debajo de ocupación con 409 CAPACITY_BELOW_OCCUPANCY. Capacidad mínima 1.
Precios 1–1000000000 COP; bloque 1–86400 segundos, mínimo 1–100000 bloques.
Versiones de tarifa inmutables; created_by audita qué administrador las cambió.

## Salida

POST /api/gate/operations con Bearer guard/admin:
`{"token":"<qr nuevo>","action":"exit","request_id":"<clave estable>"}` → 201:

```json
{"success":true,"operation_id":2,"visit_id":1,"vehicle_id":7,"action":"exit","parking_state":"OUTSIDE","occurred_at":"<UTC>","replayed":false,"message":"Salida registrada","charge":{"amount":4000,"currency":"COP","balance_after":6000,"transaction_id":1,"rate_version":1,"blocks":1,"parking_rate_label":"4000 COP / 3600 s iniciados; mínimo 1"}}
```

El servidor calcula, descuenta y registra movimiento, salida, consumo del QR y recibo
bajo la misma transacción. Ningún monto procede del cliente. Las recargas simultáneas
bloquean la misma fila users; saldo no negativo y visita con un único movimiento de cobro.
409 INSUFFICIENT_BALANCE mantiene ingreso y QR; recargar, luego reintentar explícitamente.
Misma clave/cuerpo de un éxito → 200 sin otro descuento, aun si el QR venció después.

GET /api/wallet/history conserva transactions, con COBRO_ESTACIONAMIENTO y campos
visit_id/parking_rate_label adicionales; amount siempre positivo, type determina débito.
Juan debe leer parking_rate_label en TransactionModel y crear pantalla administrativa
si se requiere cambiar precios desde Flutter: esta entrega ofrece API, no pantalla nueva.

Pruebas cubren tarifa capturada al ingreso, permisos administrativos, capacidad, fondos,
reintentos concurrentes de salida, dos vehículos compartiendo saldo y recarga simultánea.
