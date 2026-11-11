# S2-09 · Evidencias y trazabilidad del Sprint 2

Corte: 10 de noviembre de 2026, America/Bogota. Documento para revisión, no acta de
aceptación final. Responsables compartidos: Juan Cardona y Ronaldo Mosquera.

## Estado de entrega

Backend y adelantos de Flutter integrados en `main` (`7751ca0`). La integración real
está publicada en [PR #36](https://github.com/jfcardona05/ParkU/pull/36), commit
`777ded047d8304d5e96ad2793d5a15811197b90e`, con revisión solicitada a Ronaldo.
Todos sus checks están aprobados; falta aprobación humana y merge.
Una prueba de adaptadores contra HTTP/PostgreSQL no equivale a una demo manual con cámara.

## Matriz de pruebas con resultados reales

| ID | Escenario | Evidencia | Resultado y límite |
| --- | --- | --- | --- |
| E01 | Regresión y reglas backend | [CI #36](https://github.com/jfcardona05/ParkU/actions/runs/42934524319), job backend | `spotless:check test` aprobado con PostgreSQL de pruebas |
| E02 | Formato, análisis y pruebas Flutter | Mismo CI, job flutter; ejecución local del PR #36 | 30 pruebas aprobadas, 2 omitidas por activación optativa |
| E03 | Compilación web | Mismo CI y ejecución local | Correcta; no certifica cámara ni APK |
| E04 | QR real: revocación y permisos | `mobile/test/parking_live_test.dart` del PR #36 contra API real | QR anterior rechazado al regenerar; estudiante no puede inspeccionar |
| E05 | Ingreso, estado y cupos | Misma prueba real | Ingreso confirmado; reintento reproduce éxito; estado dentro y ocupación 1 |
| E06 | Saldo insuficiente | Misma prueba real | Salida rechazada; saldo 0, sin movimiento y vehículo dentro |
| E07 | Recarga y cobro único | Misma prueba real | Recarga por taquilla; salida y reintento; un solo débito, saldo y tarifa correctos |
| E08 | Consultas e historial aislado | Misma prueba real | Estado fuera, ocupación 0, salida/ingreso y otro titular sin accesos propios |
| E09 | Respuesta perdida y QR vencido | `gate_api_test.dart` del PR #36 | Widget conserva clave y recupera confirmación; gateway de prueba, no corte real de red |
| E10 | Saldo, tarifa y recargas anteriores | `parking_wallet_api_test.dart` | Muestra débito y tarifa, refresca estado y conserva compatibilidad con recargas |
| E11 | Paginación y fallo parcial | `parking_screen_test.dart` | Error de cupos no bloquea tarifas; reintento de página conserva cursor |
| E12 | QR vencido en interfaz | `vehicle_qr_test.dart`, `gate_api_test.dart` | No muestra QR vencido y conserva código de error del servidor |
| E13 | Concurrencia, rollback y límites | Backend: `docs/s2-07-api-y-pruebas.md`, [CI #35](https://github.com/jfcardona05/ParkU/actions/runs/42927542050) y CI #36 | Suite backend aprobada; detalle de 24 casos reportado por Ronaldo en #26 |
| E14 | Cámara, permiso aceptado/denegado, lector manual físico | Registro pendiente en `s2-09-demo-y-acta.md` | Pendiente de dispositivo real |
| E15 | APK y demo manual conjunta | Mismo registro pendiente | No compilados/verificados como parte de esta evidencia |

Las dos pruebas omitidas de la ejecución normal son `api_live_test.dart` (S1,
`LIVE_API`) y `parking_live_test.dart` (S2, `LIVE_PARKING_API`). La prueba S2 se ejecutó
por separado y pasó; no se atribuye una nueva ejecución de la optativa S1. La referencia
anterior a un reloj de vencimiento omitido en la guía del PR #36 era incorrecta: el
caso de QR vencido no está omitido.

La prueba real S2 utilizó Java 21, Spring Boot 3.5.13 y PostgreSQL en una base
desechable, tres cuentas nuevas y la cuenta de taquilla demo. Configuró 2 cupos
solo para el escenario. Nunca se usaron datos productivos. Maven local no descargó
Surefire 3.5.5; se arrancó la API desde clases compiladas y dependencias disponibles.
La suite backend completa sí pasó después en GitHub Actions sobre el commit publicado.

## Reproducir y revisar

1. Revisar el PR #36, su commit y sus checks. Para reproducir antes de su merge,
   usar su rama `feature/s2-08-live-integration`; `main` aún contiene adaptadores anteriores.
2. Seguir `docs/s2-08-integracion-real.md` en esa rama. La prueba requiere una base
   exclusiva, vacía, con capacidad sin operaciones previas y cuentas de pruebas preparadas.
3. Ejecutar formato, análisis, pruebas y compilación según README. Activar la prueba
   S2 por separado con los parámetros indicados en su guía; no guardar claves en GitHub.
4. Registrar dispositivo y evidencia manual en `s2-09-demo-y-acta.md`.

## Trazabilidad funcional

| Tarea | Implementación / evidencia | Dependencia pendiente en este corte |
| --- | --- | --- |
| S2-00 #17 | PR #31, contrato v0.2; `s2-00-compatibilidad-flutter.md` | Revisión del complemento y decisiones del equipo |
| S2-01 #18 | PR #32; generación/validación de QR | Integración Flutter en #36 |
| S2-02 #19 | PR #33; registro de operaciones | Integración Flutter en #36 |
| S2-03 #20 | PR #34; tarifas y cobro | Configuración de demo y uso desde Flutter |
| S2-04 #21 | PR #27 y #36; QR de vehículo | Revisión/merge #36 y evidencia física aplicable |
| S2-05 #22 | PR #28 y #36; escáner/portería | Revisión/merge #36, cámara y permisos |
| S2-06 #23 | PR #29 y #36; saldo y movimientos | Revisión/merge #36 y demo manual |
| S2-07 #24 | PR #35; consultas y pruebas | Validación conjunta en demo |
| S2-08 #25 | PR #30 y #36; ensayo y conexión real | Revisión/merge #36 y plataforma física |
| S2-09 #26 | Este paquete documental | Revisión de Ronaldo, capturas, acta y demostración |

## Reparto del trabajo restante

| Responsable | Trabajo concreto |
| --- | --- |
| Juan, preparado en este PR | Revisión técnica del contrato, matriz, trazabilidad, README, guion y borrador de acta |
| Ronaldo | Revisar PR #36 y documentación; confirmar configuración/cuentas del backend y observaciones |
| Juan y Ronaldo | Fijar capacidad de demo y plataforma, resolver políticas pendientes, ejecutar cámara/demo, adjuntar capturas y aceptar entrega |

S2-00 y S2-09 permanecen abiertas. La documentación puede estar In Review mientras
la tarea conserva pendientes. Done requiere criterios completos, aprobación humana,
checks correctos, merge y evidencia funcional; no se simulan firmas ni revisiones.

## Registro de PR, commits y revisiones verificadas

Los enlaces de revisión muestran las revisiones reales de GitHub. Corte indicado arriba;
consultar el PR para cambios posteriores. Que un PR esté fusionado no demuestra por sí
solo revisión formal: #30 no tiene una revisión registrada en este corte.

| PR | Commit de la rama revisada | Revisión registrada | Estado | CI |
| --- | --- | --- | --- | --- |
| [#27](https://github.com/jfcardona05/ParkU/pull/27) | [b393de4](https://github.com/jfcardona05/ParkU/commit/b393de465ec4205b55b7c1e01f870f3212abaa54) | ronaldomosg: APPROVED · [ver](https://github.com/jfcardona05/ParkU/pull/27/files) | Integrado | [Correcto](https://github.com/jfcardona05/ParkU/actions/runs/41765878054) |
| [#28](https://github.com/jfcardona05/ParkU/pull/28) | [111b883](https://github.com/jfcardona05/ParkU/commit/111b883eeb01d335f826128d22d02a31c0c892f7) | ronaldomosg: APPROVED · [ver](https://github.com/jfcardona05/ParkU/pull/28/files) | Integrado | [Correcto](https://github.com/jfcardona05/ParkU/actions/runs/41765932256) |
| [#29](https://github.com/jfcardona05/ParkU/pull/29) | [63cdbc6](https://github.com/jfcardona05/ParkU/commit/63cdbc6d7d311b3310b1a22f829b5569ea95bd48) | ronaldomosg: APPROVED · [ver](https://github.com/jfcardona05/ParkU/pull/29/files) | Integrado | [Correcto](https://github.com/jfcardona05/ParkU/actions/runs/42737296705) |
| [#30](https://github.com/jfcardona05/ParkU/pull/30) | [1541d79](https://github.com/jfcardona05/ParkU/commit/1541d792901a4354056f6f559d1a16fe153b7e03) | Sin revisión registrada · [ver](https://github.com/jfcardona05/ParkU/pull/30/files) | Integrado | [Correcto](https://github.com/jfcardona05/ParkU/actions/runs/42737411533) |
| [#31](https://github.com/jfcardona05/ParkU/pull/31) | [82484b5](https://github.com/jfcardona05/ParkU/commit/82484b5c24030124fec839045f44028d9ebbba7c) | jfcardona05: APPROVED · [ver](https://github.com/jfcardona05/ParkU/pull/31/files) | Integrado | [Correcto](https://github.com/jfcardona05/ParkU/actions/runs/42927179176) |
| [#32](https://github.com/jfcardona05/ParkU/pull/32) | [33d61a1](https://github.com/jfcardona05/ParkU/commit/33d61a1c1bada71162e09cc6ca2e2ba83f0559ea) | jfcardona05: APPROVED · [ver](https://github.com/jfcardona05/ParkU/pull/32/files) | Integrado | [Correcto](https://github.com/jfcardona05/ParkU/actions/runs/42927319950) |
| [#33](https://github.com/jfcardona05/ParkU/pull/33) | [3b1598c](https://github.com/jfcardona05/ParkU/commit/3b1598c040023ab9387b2a62e6cd8d2f45c3e664) | jfcardona05: APPROVED · [ver](https://github.com/jfcardona05/ParkU/pull/33/files) | Integrado | [Correcto](https://github.com/jfcardona05/ParkU/actions/runs/42927383831) |
| [#34](https://github.com/jfcardona05/ParkU/pull/34) | [758b738](https://github.com/jfcardona05/ParkU/commit/758b738fbe81a6af0b24bdb711ab89bd7ef581ee) | jfcardona05: APPROVED · [ver](https://github.com/jfcardona05/ParkU/pull/34/files) | Integrado | [Correcto](https://github.com/jfcardona05/ParkU/actions/runs/42927452782) |
| [#35](https://github.com/jfcardona05/ParkU/pull/35) | [7c74e47](https://github.com/jfcardona05/ParkU/commit/7c74e478e5470f6c421817c0a4f57a96ba7eb0ff) | jfcardona05: APPROVED · [ver](https://github.com/jfcardona05/ParkU/pull/35/files) | Integrado | [Correcto](https://github.com/jfcardona05/ParkU/actions/runs/42927542050) |
| [#36](https://github.com/jfcardona05/ParkU/pull/36) | [777ded0](https://github.com/jfcardona05/ParkU/commit/777ded047d8304d5e96ad2793d5a15811197b90e) | Sin revisión registrada · [ver](https://github.com/jfcardona05/ParkU/pull/36/files) | Abierto, revisión solicitada a Ronaldo | [Correcto](https://github.com/jfcardona05/ParkU/actions/runs/42934524319) |

