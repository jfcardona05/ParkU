# S2-00 · Verificación técnica de Flutter

Corte: 10 de noviembre de 2026, America/Bogota. Preparado para revisión de Juan
Cardona y Ronaldo Mosquera. Relacionado con #17 y PR #36.

## Bases revisadas y alcance

- Backend en `main`: `7751ca03ed02202e94d46b70ae19647b40e971fc`, PR #31–35 integrados.
- Flutter real del PR #36: `777ded047d8304d5e96ad2793d5a15811197b90e`.
- Prevalece `s2-00-acuerdos-v0.2.md` sobre la propuesta histórica v0.1.
- El PR #31 tiene aprobación registrada de Juan. Esta comprobación técnica no
  añade una aprobación humana ni confirma políticas de la universidad.
- Las funciones del PR #36 todavía no están en `main` en este corte.

## Correspondencia comprobada

| Función | API y representación | Adaptación Flutter del PR #36 | Evidencia |
| --- | --- | --- | --- |
| Sesión | Bearer de sesión; 401 revoca sesión local | `ApiService.request`, conserva `code` y `message` | `vehicle_qr_api_test.dart` y prueba real |
| Emitir QR | POST `/api/vehicles/{id}/qr`; `vehicle_id`, `token`, `expires_at` | `ApiVehicleQrSource`; valida vehículo y fecha; modo real predeterminado | `vehicle_qr_api_test.dart`, `parking_live_test.dart` |
| Inspeccionar | POST `/api/gate/inspect`; `OUTSIDE`/`INSIDE`, `entry`/`exit` | `ApiGateGateway`; el servidor decide acción; vista previa sin confirmar | `gate_api_test.dart`, prueba real |
| Confirmar | POST `/api/gate/operations`; `token`, `action`, `request_id` | Clave aleatoria estable por intento; misma clave y cuerpo en reintento incierto | `gate_api_test.dart`, prueba real |
| Cobro | `charge.amount`, `balance_after`, `parking_rate_label` | Muestra recibo del servidor, sin calcular tarifa ni pedir débitos arbitrarios | `gate_api_test.dart`, `parking_wallet_api_test.dart` |
| Saldo e historial | GET `/api/wallet/balance`, `/api/wallet/history` | Importe positivo; `COBRO_ESTACIONAMIENTO` se presenta como débito; tarifa opcional para recargas antiguas | `parking_wallet_api_test.dart`, prueba real |
| Estado | GET `/api/vehicles/{id}/parking` | Consulta vehículos propios; saldo indica ingreso activo si alguno está dentro | `ParkingService`, pruebas de saldo y prueba real |
| Cupos y tarifas | GET `/api/parking/occupancy`, `/api/parking/rates` | Secciones independientes; una falla no impide consultar las otras | `parking_screen_test.dart`, prueba real |
| Accesos | GET `/api/parking/history?limit=20&before_id=…` | Cursor del servidor, fin de lista y reintento de página | `parking_screen_test.dart`, `parking_wallet_api_test.dart` |

## Diferencias resueltas frente a la propuesta histórica

- El backend admite `guard` y `admin` en portería; `operador` conserva taquilla.
- `request_id` admite 1–100 caracteres. Flutter usa 24 bytes aleatorios en base64url;
  no requiere UUID. Se conserva durante reintentos de una confirmación incierta.
- Un QR confirmado se consume; para salir se emite otro. Regenerar revoca el anterior.
- Tras saldo insuficiente no hay salida ni débito. La prueba real recarga y reintenta
  con la misma clave del rechazo, que no se había almacenado como éxito.
- `parking_rate_label` se lee y se presenta. Se retiraron referencias fijas por día.
- El recibo persistido permite recuperar una confirmación exitosa aunque su QR haya vencido.

## Reglas implementadas y decisiones aún pendientes

| Tema | Hecho verificable | Pendiente del equipo |
| --- | --- | --- |
| Roles | Registro público no concede privilegios; backend controla permisos | Aprovisionar cuentas reales por responsable autorizado; no publicar claves |
| QR | Vigencia 120 s, revocación al regenerar y un uso exitoso | Prueba de cámara física y permisos |
| Precio | Ronaldo registró 4000 COP moto y 5000 COP automóvil; versiones editables por admin | Confirmar política académica; no afirmar tarifa universitaria oficial |
| Tiempo | Bloque inicial 3600 s, mínimo 1, redondeo hacia arriba; tarifa fijada al ingreso | Ratificar o ajustar este supuesto operativo configurable |
| Fondos | Saldo insuficiente mantiene vehículo dentro, sin cobro parcial | Acordar con docentes cualquier excepción operativa exigida |
| Capacidad | Global, sin valor predeterminado; 503 mientras falta configuración | Indicar capacidad de demo/entrega y configurarla; los 2 cupos de prueba no son un acuerdo |
| Plataforma | Compilación web y prueba automatizada con API real correctas | Elegir dispositivo y verificar cámara, permisos y necesidad de APK |
| Administración | API permite cambiar tarifas y capacidad; Flutter consulta tarifas | No existe formulario administrativo Flutter; confirmar si la rúbrica lo exige |

## Cierre de S2-00

La compatibilidad técnica está documentada y probada sobre el PR #36. Ronaldo debe
revisar esta evidencia; ambos deben registrar las decisiones pendientes. No marcar
Done solo por esta documentación. Véase `s2-09-cierre-y-evidencias.md` para resultados
y `s2-09-demo-y-acta.md` para el trabajo presencial pendiente.
