# Contrato propuesto de API del Sprint 2

Versión 0.1.0 · 10 de noviembre de 2026 · S2-00 / #17.
Autor: Ronaldo Mosquera (@ronaldomosg). Revisor: Juan Cardona (@jfcardona05).
Estado: PROPUESTA PARA REVISIÓN. Los endpoints nuevos de este documento aún no están implementados.
La aprobación del documento debe registrar expresamente qué decisiones se aceptan; no se presume acuerdo por publicar un PR.

## Evidencia revisada

Base: main en 30fd3d291a43d89ae289a42f70dae6cf6b62c47f.
README, issues #14–26, ramas remotas, PR #27–30, servicios y modelos Flutter,
guías docs/s2-04-revision.md, docs/s2-05-revision.md y docs/s2-08-verificacion.md.
Los cuatro PR #27–30 están fusionados; #30 ya no es borrador. Su ensayo usa
adaptadores de prueba, no acredita cobro real ni cámara física. No hay PR abiertos al inspeccionar.
Las ramas antiguas y sus PR sobre pases diarios/tarifas no representan el backend actual:
main contiene IdentityService, VehicleController y WalletController con JDBC; no se deben
copiar implementaciones históricas sin revisar su compatibilidad.

El ZIP ParkU_entrega.zip es anterior a main y no incluye los servicios QR/portería,
pantallas y pruebas nuevas. Se usa como referencia, no como base para sobrescribir el remoto.
El plan operativo compartido v1.0 exige acuerdos antes de implementar reglas dependientes.

## Hechos existentes que se conservan

- Java 21, Spring Boot, PostgreSQL 17, Flyway; Flutter/Dart.
- Sesión opaca Bearer con hash SHA-256 en sessions, expiración actual de 8 horas y logout.
- Registro público crea estudiante; el cliente no puede asignarse permisos.
- Roles actuales en BD: estudiante, docente, operador. operador autoriza recargas.
  guard y admin aparecen solo como propuestas de UI y no están admitidos por la BD actual.
- Vehículos propios, placas únicas, tipos moto y automovil.
- Dinero en enteros COP, saldo no negativo, recarga presencial serializada por usuario.
- Rutas existentes /api/auth/login, /register, /logout; /api/vehicles;
  /api/wallet/balance, /history, /recharge; /api/admin/users.
  Sus cuerpos y rutas se conservan. No se añade débito solicitado por el cliente.
- Errores actuales incluyen success:false y message. Los códigos nuevos se añaden para S2.
- Los valores de tarifas que pudiera mostrar una demo no están confirmados.

## Decisiones que deben responder Ronaldo y Juan

Todas las filas siguientes son propuestas, NO reglas universitarias confirmadas.

| Tema | Propuesta para el prototipo | Confirmación requerida |
| --- | --- | --- |
| Portería | Nuevo rol guard, aprovisionado fuera del registro público; operador sigue siendo solo taquilla. No introducir admin hasta necesitarlo. | ¿guard separado de operador? ¿Quién lo asigna y qué cuentas de prueba se usan? |
| QR | Token opaco aleatorio de 256 bits, hash en BD, vigencia 120 segundos, uno vigente por vehículo; regenerar revoca el anterior. Cada confirmación exitosa lo consume. | Aceptar duración, revocación y pedir QR nuevo para salida. |
| Tarifa | COP por bloques de 60 minutos iniciados, mínimo un bloque; valores distintos para moto/automovil configurados explícitamente, sin precio predeterminado habilitado. | Indicar valor COP por tipo, unidad, mínimo, redondeo y posibles cortesías. |
| Saldo insuficiente | Rechazar salida sin débito, mantener ingreso activo y QR sin consumir; recargar y confirmar con nueva clave. | Aceptar o definir salida con deuda/excepción y permisos. |
| Capacidad | Capacidad global configurada; cada vehículo ocupa un cupo, ingreso rechaza si está lleno. Sin capacidad configurada no habilitar ingresos. | Indicar número y si existen cupos separados por tipo. |
| Estados | OUTSIDE / INSIDE; salida rechazada por saldo no cambia INSIDE. Evento ENTRY / EXIT y estado financiero separado. | Confirmar nombres y representación Flutter. |
| Idempotencia | UUID en request_id, ámbito operador; misma clave y cuerpo reproduce recibo; cuerpo distinto da conflicto. Conservar recibos persistentes sin caducidad en el prototipo. | Confirmar ámbito y retención. |
| Plataforma | Chrome localhost/HTTPS para integración inicial; Android físico para cámara si el equipo dispone de SDK/dispositivo. | Elegir plataforma exigida y responsable de cámara/APK. |

No implementar tarifa/cobro hasta el acuerdo del issue #20. El cálculo puede especificarse
con variables: bloques=max(1,ceil(duración_en_segundos/3600)); importe=bloques*precio_por_tipo.
Duración cero cobra un bloque bajo esta propuesta. Exactamente 3600 segundos cobra uno;
3601 cobra dos. Se toma hora del servidor y se guarda la versión de tarifa al ingresar,
evitando que un cambio posterior altere el precio de esa estancia. Confirmar también esta política.

## Convenciones propuestas

Rutas nuevas bajo /api; todos los endpoints requieren Authorization: Bearer <sesion>.
JSON con snake_case, enteros para IDs y COP; fechas ISO 8601 UTC con Z.
No enviar usuario, operador, hora, precio o saldo como autoridad del cliente.
La identidad procede de la sesión. Token QR y sesión son credenciales diferentes:
el QR no permite login, recargas ni consulta de saldo. No registrar tokens en logs ni URLs.
Las respuestas con token usan Cache-Control: no-store.

Errores S2:
```json
{"success":false,"code":"QR_EXPIRED","message":"QR vencido. Solicita uno nuevo."}
```

| HTTP | code | Significado |
| --- | --- | --- |
| 400 | INVALID_REQUEST | JSON, enum, UUID o tamaño inválidos |
| 401 | UNAUTHORIZED | Sesión ausente, vencida o revocada; Flutter borra sesión |
| 403 | FORBIDDEN | Rol sin permiso |
| 404 | VEHICLE_NOT_FOUND | Vehículo inexistente o de otro titular al solicitar QR/estado |
| 422 | QR_INVALID | QR desconocido, alterado o de demostración |
| 410 | QR_EXPIRED | Fecha actual mayor o igual a expires_at |
| 409 | QR_REVOKED / QR_USED | Regenerado o consumido |
| 409 | ALREADY_INSIDE / NOT_INSIDE | Transición inválida |
| 409 | IDEMPOTENCY_CONFLICT | Clave usada con cuerpo diferente |
| 409 | INSUFFICIENT_BALANCE / PARKING_FULL | Rechazo de negocio sin mutación parcial |
| 503 | PARKING_NOT_CONFIGURED | Faltan tarifa/capacidad/acuerdos habilitados |

Sin sesión se responde 401 antes de revelar información de QR o vehículo.
Un fallo de red no prueba que la operación haya fallado: se reintenta la confirmación
con el mismo request_id y cuerpo. 401/403 siempre se verifican también en reintentos.

## S2-01 QR seguro

### POST /api/vehicles/{vehicle_id}/qr — 201

Sin cuerpo. Solo titular autenticado, aunque conozca el ID ajeno. Respuesta:
```json
{"success":true,"vehicle_id":7,"token":"<token-opaco>","expires_at":"2026-11-10T23:32:00Z"}
```
Errores: 401, 404; emisión/regeneración serializada por vehículo.
No aceptar PARKU-DEMO como token real. El token contiene suficiente entropía;
no codifica datos personales ni es un ID predecible. Guardar solo hash, propietario,
vehículo, expedición, caducidad, revocación y consumo.
La validación no consume; la confirmación exitosa consume en la misma transacción
del evento. Regenerar y confirmar compiten bajo el mismo bloqueo del vehículo.
Un reintento de emisión puede regenerar: Flutter usa únicamente el último QR recibido.

### POST /api/gate/inspect — 200

Solo guard bajo la propuesta. Entrada:
```json
{"token":"<token-opaco>"}
```
Salida:
```json
{"success":true,"vehicle_id":7,"plate":"ABC123","expires_at":"2026-11-10T23:32:00Z","parking_state":"OUTSIDE","allowed_action":"entry"}
```
Errores: 400, 401, 403, 422, 410, 409.
Vista previa sin efectos: no reserva cupo, no garantiza saldo ni consume QR.
No devolver correo, saldo o historial del titular. Revalidar todo al confirmar.

## S2-02 ingreso y salida

### POST /api/gate/operations — 201; reintento exitoso — 200

Solo guard. Usar request_id en JSON para encajar en GateGateway y evitar un nuevo
encabezado CORS. LocalCors actual permite Authorization y Content-Type.
```json
{"token":"<token-opaco>","action":"entry","request_id":"88981d20-a7e2-4e49-a5fb-237f43741027"}
```
```json
{"success":true,"operation_id":101,"visit_id":51,"vehicle_id":7,"action":"entry","parking_state":"INSIDE","occurred_at":"2026-11-10T23:30:30Z","replayed":false,"message":"Ingreso registrado"}
```
La salida usa action:"exit" y un QR nuevo. Nunca generar un UUID nuevo por un
timeout de confirmación. Clave repetida con distinto token/action: 409.

La misma clave identifica el resultado exitoso, incluso si el QR luego venció o
fue consumido. Comprobar primero sesión/rol y luego el recibo del operador.
Guardar huella del cuerpo sin token en claro. Otro operador no puede consultar ese recibo.
Los rechazos no se guardan como éxito ni consumen QR; tras corregir saldo/capacidad,
un nuevo intento explícito usa una nueva clave.

Garantías propuestas: un ingreso activo por vehículo mediante índice único parcial;
restricción única (operator_id,request_id); bloqueo de cupo global, vehículo y saldo
en orden fijo y consistente. Serializar emisión/consumo y eliminación del vehículo.
Revalidar caducidad con reloj actual después de obtener bloqueos, no solo al inicio.
Un conflicto o rollback no deja QR consumido, evento suelto, débito o cupo perdido.
El borrado de vehículo con ingreso activo se rechaza con 409 VEHICLE_IN_USE;
conservar las evidencias históricas mediante instantánea de placa/tipo y
referencias que permitan borrar un vehículo fuera del parqueadero.

## S2-03 cobro atómico

La salida calcula exclusivamente en servidor; no exponer endpoint de débito arbitrario.
En una transacción: validar QR/estado, bloquear saldo, calcular con tarifa guardada,
verificar fondos, descontar, insertar movimiento, registrar salida/recibo y consumir QR.
Recargas simultáneas usan el mismo bloqueo de users que WalletController existente.
Proteger multiplicación contra overflow y restringir valores de tarifa positivos.

Ejemplo de salida; importes ilustrativos, NO tarifa aceptada:
```json
{"success":true,"operation_id":102,"visit_id":51,"vehicle_id":7,"action":"exit","parking_state":"OUTSIDE","occurred_at":"2026-11-11T00:00:30Z","replayed":false,"message":"Salida registrada","charge":{"amount":2000,"currency":"COP","balance_after":13000,"transaction_id":91,"rate_version":"propuesta-demo-v1","blocks":1,"parking_rate_label":"Ejemplo 2000 COP por hora iniciada"}}
```
Saldo insuficiente: 409 INSUFFICIENT_BALANCE, sin salida, consumo ni movimiento.
La vista de Flutter puede mostrar insufficientBalance como resultado del error;
no confundirlo con una salida o un tercer estado físico persistido.
Una nueva clave con QR consumido se rechaza; la clave original reproduce el recibo
y no descuenta de nuevo. Dos salidas simultáneas producen un solo débito.

## S2-07 consultas

| Endpoint GET | Permiso | Respuesta 200 |
| --- | --- | --- |
| /api/parking/occupancy | Sesión autenticada, agregado sin datos personales | {"success":true,"capacity":100,"occupied":12,"available":88} |
| /api/vehicles/{id}/parking | Solo titular, 404 para ajeno | {"success":true,"vehicle_id":7,"parking_state":"INSIDE","visit_id":51,"entered_at":"2026-11-10T23:30:30Z"} |
| /api/parking/history?limit=20&before_id=102 | Solo historial propio; limit 1–100, cursor exclusivo | {"success":true,"operations":[],"next_before_id":null} |

Capacity 100 es solo un ejemplo de esquema. OUTSIDE devuelve visit_id y entered_at
nulos. El historial ordena operation_id descendente e incluye operation_id, visit_id,
vehicle_id, plate, action, occurred_at y charge (null en ingreso).
No aceptar user_id para cambiar el titular de una consulta; cursor ajeno no amplía
el filtro de propiedad. No proporcionar historial global de portería sin acuerdo adicional.

GET /api/wallet/history conserva transactions y sus campos actuales; admite adicionalmente
type:"COBRO_ESTACIONAMIENTO", amount positivo (tipo determina débito), point_name,
reference UUID, balance_after, created_at. Propuesta: añadir parking_rate_label y
visit_id para cobros; recargas siguen con sus campos y semántica actuales.
La migración debe ampliar el CHECK actual que solo permite RECARGA_PRESENCIAL.
No borrar ni recalcular recargas existentes.

## Correspondencia con Flutter y trabajo de Juan

| Interfaz actual | Adaptación prevista por Juan |
| --- | --- |
| VehicleQrSource.issue(vehicle) | POST QR, vehicle_id → vehicleId, expires_at → expiresAt; isDemo=false |
| GateGateway.inspect(token) | POST inspect, conservar token local y mapear plate/expires_at |
| GateGateway.confirm(preview,action,requestId) | POST operations; entry/exit en minúscula; generar UUID en lugar de UniqueKey().toString(); devolver message y actualizar saldo/estado |
| ApiService.getBalance/getHistory | Conservar rutas; refrescar tras salida y recarga |
| TransactionModel | Leer parking_rate_label opcional; hoy fromJson no lo asigna |
| WalletScreen.loadParkingStatus | Adaptador de estado por vehículo; acordar selección cuando hay varios vehículos |

ApiService._request es privado a su biblioteca Dart; Juan deberá exponer un método
autenticado reutilizable o colocar los adaptadores dentro de ApiService.
GateScreen actualmente usa UniqueKey().toString(), que no es UUID; Juan debe reemplazarlo
por un UUID persistido durante el intento y conservarlo en cada reintento, o acordar otro
formato de clave antes de conectar. No enviar la clave actual a una API que exija UUID.
No duplicar credenciales ni usar el QR como Bearer. Agregar lectura de code sin perder message.
La cámara no se prueba con widgets; registrar dispositivo y permiso real.
No se modifican archivos Flutter como parte de S2-00.

Ejemplos curl (variables locales, nunca pegar credenciales reales en GitHub):
```sh
curl -X POST "$BASE/api/vehicles/7/qr" -H "Authorization: Bearer $SESSION"
curl -X POST "$BASE/api/gate/inspect" -H "Authorization: Bearer $GUARD_SESSION" -H 'Content-Type: application/json' -d '{"token":"<qr>"}'
curl -X POST "$BASE/api/gate/operations" -H "Authorization: Bearer $GUARD_SESSION" -H 'Content-Type: application/json' -d '{"token":"<qr>","action":"entry","request_id":"88981d20-a7e2-4e49-a5fb-237f43741027"}'
curl "$BASE/api/parking/occupancy" -H "Authorization: Bearer $SESSION"
```

## Entregas y comprobaciones pendientes

1. S2-00: Juan revisa nombres/JSON y ambos responden la tabla de decisiones en #17.
   Actualizar versión y registrar quién confirmó cada regla antes de implementar dependientes.
2. #18: rama feature/s2-01-backend; pruebas de propiedad, roles, QR inválido,
   vencido en el límite, revocado, regeneración concurrente y no consumo al inspeccionar.
3. #19: rama feature/s2-02-backend; doble ingreso/salida sin ingreso, concurrencia
   entre claves y entre reintentos iguales, capacidad y borrado de vehículo activo.
4. #20: rama feature/s2-03-backend; salida más cobro, saldo insuficiente, rollback,
   recarga/salida simultáneas y dos vehículos con el mismo saldo. Depende de acuerdos.
5. #24: rama feature/s2-07-backend; ocupación, paginación, aislamiento y regresión S1.
6. #26: ambos registran flujo real login → vehículo → QR → ingreso → salida →
   débito → saldo/historial, cámara, PR/checks/aprobaciones y limitaciones.

Todos los PR hacia main; Juan revisa los de Ronaldo, Ronaldo los de Juan.
Para evitar diffs mezclados, integrar dependencias aprobadas antes de abrir el
siguiente PR funcional hacia main. Ninguna tarea se declara Done solo por abrir/fusionar
un adelanto: requiere criterios, checks, aprobación humana, merge y prueba funcional.

## Verificación de esta propuesta y límites

Cuenta conectada verificada: ronaldomosg; repo con pull/push/triage, sin administración.
El conector no expone Projects. El navegador sin sesión muestra 404 en el tablero
/users/jfcardona05/projects/2; CLI sin autenticación. No se confirmó acceso al tablero,
su configuración ni se movieron tarjetas. Estado lógico S2-00: In Review al publicar PR;
pendiente reflejarlo en Projects con acceso autenticado.

Prueba base intentada con Java 21 y DB_URL apuntando exclusivamente a parku_test:
`bash ./mvnw spotless:check test`. El wrapper carece de permiso ejecutable en el checkout;
se invocó con bash. Maven falló antes de compilar por resolución DNS de repo.maven.apache.org
al descargar spring-boot-starter-parent:3.5.13. No se ejecutaron Spotless ni tests.
No hay PostgreSQL/Docker disponibles en este entorno. No se tocó la BD de desarrollo.
El workflow existente Verificaciones usa PostgreSQL 17 separado (parku_test);
consultar sus resultados sobre el commit del PR y no sustituirlos por resultados antiguos.
Este documento no certifica ninguna API nueva ni las pruebas funcionales propuestas.
