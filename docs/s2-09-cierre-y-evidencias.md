# Sprint 2 · Informe actualizado de implementación, evidencias y trazabilidad

Corte documental: 18 de noviembre de 2026, America/Bogota.
Proyecto: ParkU · Universidad Santo Tomás, Seccional Villavicencio.
Integrantes: Juan Felipe Cardona y Ronaldo Mosquera.
Versión funcional examinada: [main, 2f3c3e5](https://github.com/jfcardona05/ParkU/commit/2f3c3e5afdbf4f0d64b7406af103a6615f746396).

Este informe actualiza el corte del 10 de noviembre y consolida Sprint 2 y los ajustes posteriores incluidos en la entrega. Describe código integrado y evidencia verificable; no sustituye el documento académico final, la demostración física ni un acta firmada. Los contratos y guiones anteriores conservan valor histórico, pero sus reglas de QR temporal, cobro por horas y ocupación no describen el nuevo flujo diario.

## 1. Propósito y alcance

ParkU organiza el parqueadero universitario mediante una billetera prepago, vehículos vinculados a su propietario y pases QR. Separa al usuario, que administra su saldo y vehículo; taquilla, que recibe efectivo y registra abonos; portería, que confirma accesos; y administración, que configura tarifas mediante API.

Sobre autenticación, vehículos y recargas de Sprint 1, Sprint 2 incorporó QR, portería, tarifas, movimientos e integración real. La evolución posterior sustituyó completamente el frontend según Figma e incorporó pase diario, transferencias, reportes y control de caja.

Arquitectura: frontend Flutter/Dart, API Java 21/Spring Boot y PostgreSQL 17. Las migraciones Flyway versionan el esquema. Flutter consulta la API; el servidor aplica permisos, reglas y transacciones; PostgreSQL conserva cuentas, vehículos, saldos, pases, accesos y registros de caja.

## 2. Funcionalidades actuales integradas

| Módulo | Comportamiento actual | Evidencia principal |
|---|---|---|
| Identidad y roles | Registro, login y logout; registro público crea estudiante y no concede privilegios | IdentityController / IdentityService |
| Vehículos | Registro de moto/automóvil, consulta propia y eliminación controlada; un vehículo con visita o pase diario vigente no se elimina | VehicleController |
| Inicio y saldo | Resumen del usuario, billetera y movimientos personales procedentes de la API | DashboardScreen / WalletScreen |
| Rediseño completo | Interfaz clara/amarilla, recursos Figma y adaptación a celular, tablet y escritorio | PR #39; frontend-figma-responsive.md |
| Pase QR diario | Un pase por usuario y fecha colombiana, vinculado al vehículo confirmado; cobro único al generarlo | PR #44; DailyPassService |
| Portería | Lectura por cámara o código/enlace pegado, validación previa y confirmación explícita de ingreso/salida | VehicleQrService / GateService / GateScreen |
| Transferencias | Envío por correo a otra cuenta, confirmación, débito/crédito atómicos e historial para ambos | PR #44; WalletTransferService |
| Recargas y reportes | Abonos presenciales, búsqueda por usuario, períodos día/semana/mes y totales | RechargeHistoryController / TaquillaReportsScreen |
| Caja diaria | Apertura, base inicial, cierre con conteo y retención para devueltas; vínculo entre recarga y caja | PR #48; CashService |
| Comprobantes de caja | Historial de cierres y descarga HTML autocontenida; impresión/Guardar PDF desde navegador | caja-y-vista-publica.md |
| Disponibilidad | Inicio y Parqueadero muestran Próximamente; no presentan conteos como medición física | PR #44 |
| Inicio local y acceso temporal | Lanzador Windows y enlace HTTPS con proxy para invitados | PR #47–49; scripts y compose.public.yaml |

### 2.1. Regla vigente de QR y descuento

1. El usuario consulta el vehículo y la tarifa sin cobrar.
2. Confirma Generar QR diario con importe y fecha de servicio.
3. El servidor comprueba propiedad y fondos y registra, en una sola transacción, descuento, movimiento y pase.
4. Consultar o reintentar devuelve el mismo pase del día sin un segundo cobro. Solicitudes simultáneas no generan pases ni débitos duplicados.
5. El pase queda asociado a un solo vehículo por usuario ese día; no permite elegir otro hasta el día siguiente.
6. Vence al comenzar el siguiente día calendario de America/Bogota, no 24 horas después de comprarlo.
7. Portería confirma ingreso y salida; el pase diario ya pagado no cobra de nuevo al salir.

Valores iniciales configurados: moto 4.000 COP y automóvil 5.000 COP por pase diario; las tarifas pueden cambiar mediante API administrativa. Si cambian día o precio entre consulta y confirmación, se requiere una nueva confirmación. Fondos insuficientes no producen pase ni descuento parcial.

Se conserva compatibilidad para cerrar estancias antiguas sin pase diario con su regla histórica. El flujo anterior de QR de 120 segundos y cobro horario no debe presentarse como el flujo nuevo.

### 2.2. Transferencias

Se introduce correo y monto entero en COP y se confirma. Se rechazan destinatario inexistente, autoenvío, fondos insuficientes y montos inválidos. La referencia de solicitud permite repetir la misma operación sin duplicarla y la transacción conserva ambos saldos e historiales.

La interfaz conserva el envío pendiente ante una respuesta incierta durante la sesión. Esa referencia no persiste después de cerrar o recargar completamente la aplicación: antes de iniciar un nuevo envío tras esa situación, consultar el historial.

### 2.3. Taquilla, caja y reportes

Taquilla dispone de navegación propia y separa Panel de caja de Reportes. Una recarga nueva exige una apertura válida del mismo operador, punto y día colombiano.

- Una caja abierta por punto y una por operador; una apertura y cierre por punto/día.
- La primera apertura registra base inicial. Después se hereda la base retenida del último cierre del punto.
- Recaudo = recargas presenciales ligadas a esa caja.
- Efectivo esperado = base inicial + recaudo.
- Diferencia = efectivo contado − esperado; una diferencia exige explicación.
- Dinero a entregar = efectivo contado − base retenida para devueltas.
- La base retenida debe ser positiva y no superar el efectivo contado.
- El cierre requiere confirmación y permanece definitivo en los reportes.
- Una caja que quedó abierta de un día anterior debe cerrarse antes de abrir la actual.
- Recargas y cierre comparten bloqueo: el abono se incluye antes del cierre o se rechaza si la caja ya cerró.
- Las recargas históricas se conservan; no se inventan cierres retroactivos para movimientos anteriores a V9.

Los reportes permiten revisar recargas por día, semana (lunes a domingo) o mes calendario, elegir fechas y buscar nombre/correo. Presentan usuario, valor, hora colombiana, operador, punto y referencia; el total corresponde a todo el período filtrado, no solo a una página. Excluyen transferencias y débitos por parqueadero porque no son efectivo recibido por taquilla.

Ejemplo de cierre: base 50.000 + recargas 200.000 = esperado 250.000. Con contado 250.000 y retención 40.000, la diferencia es cero y se entregan 210.000. El recaudo sigue siendo 200.000.

Los comprobantes descargables de taquilla/cierre son documentos internos HTML imprimibles; no se presentan como factura electrónica.

### 2.4. QR público y acceso por Internet

El QR enlaza a una ficha responsive con nombre, placa y tipo de vehículo. Consultarla no cobra ni registra accesos. Su código vigente debe ser alcanzable desde el teléfono.

Esta ficha aún no incorpora todos los datos del comprobante de pago solicitado (importe, fecha, vigencia y referencia). No confundirla con los comprobantes descargables de caja.

El lanzador compartir-parku.cmd compila la web y publica temporalmente web/API bajo un mismo enlace HTTPS mediante Caddy y Cloudflare Quick Tunnel. Mantiene un prefijo de acceso aleatorio y los permisos del sistema. El enlace cambia al reiniciar y requiere conservar encendidos el PC, backend, Docker y túnel. No constituye alojamiento permanente. cerrar-enlace-publico.cmd detiene la vista pública sin borrar PostgreSQL.

PR #49 corrige el login a través del proxy. La CI comprueba autenticación y autorización pasando por ese proxy; no acredita por sí sola el recorrido completo por un túnel externo o la cámara física.

## 3. Evolución y trazabilidad

| Etapa | PR | Resultado |
|---|---|---|
| QR, portería, saldo y ensayos Flutter | [#27](https://github.com/jfcardona05/ParkU/pull/27), [#28](https://github.com/jfcardona05/ParkU/pull/28), [#29](https://github.com/jfcardona05/ParkU/pull/29), [#30](https://github.com/jfcardona05/ParkU/pull/30) | Integrados; antecedentes del Sprint 2 |
| Contrato y backend de QR, accesos, tarifas y consultas | [#31](https://github.com/jfcardona05/ParkU/pull/31) a [#35](https://github.com/jfcardona05/ParkU/pull/35) | Integrados |
| Integración Flutter/API real y cierre documental inicial | [#36](https://github.com/jfcardona05/ParkU/pull/36), [#37](https://github.com/jfcardona05/ParkU/pull/37) | Integrados; aprobaciones de Ronaldo verificadas |
| Sustitución del frontend según Figma | [#39](https://github.com/jfcardona05/ParkU/pull/39) | Integrado; aprobación de Ronaldo verificada |
| QR diario, transferencias, historial de recargas y cupos Próximamente | [#44](https://github.com/jfcardona05/ParkU/pull/44) | Integrado; aprobación de Ronaldo sobre 97dc4c0 |
| Panel y navegación de taquilla | [#46](https://github.com/jfcardona05/ParkU/pull/46) | Integrado; aprobación de Juan sobre a9a8092 |
| Inicio rápido Windows | [#47](https://github.com/jfcardona05/ParkU/pull/47) | Integrado; aprobación de Juan sobre 21da6e5 |
| Caja, comprobantes y acceso temporal | [#48](https://github.com/jfcardona05/ParkU/pull/48) | Integrado; aprobación de Juan registrada sobre 9890070; la rama terminó en a503626 |
| Corrección del login público | [#49](https://github.com/jfcardona05/ParkU/pull/49) | Integrado; aprobación de Juan sobre d68628a |

Los enlaces y registros corresponden a GitHub, no a firmas generadas. Una aprobación registrada sobre un commit anterior no demuestra revisión específica de todos los cambios posteriores; por eso se identifica esa diferencia en #48. El presente ajuste documental requiere su propia revisión.

Las tareas S2-00 a S2-09 y las HU de Sprint 1 mantienen su trazabilidad histórica. Los ajustes posteriores se añaden como evolución del alcance; no se inventan fechas, puntos de historia, estimaciones, sprints ni autorías para hacerlos coincidir con la planificación original.

## 4. Verificación y evidencia

| Comprobación | Evidencia verificada | Alcance |
|---|---|---|
| Backend actual | [CI main #44230579477](https://github.com/jfcardona05/ParkU/actions/runs/44230579477), job backend | 58 pruebas, 0 fallos, 0 errores, 0 omitidas; Spotless aprobado; PostgreSQL de pruebas |
| Frontend actual | Mismo CI, job flutter | Formato, análisis sin incidencias, suite Flutter y compilación web aprobados |
| Responsive e integración | [CI #44227787873](https://github.com/jfcardona05/ParkU/actions/runs/44227787873), commit d68628a del PR #49 | Jobs responsive y api-integration aprobados; capturas y web build |
| API/BD reales | Job api-integration anterior | Registro, vehículos, apertura/recarga, saldo, reportes, QR diario, accesos, permisos y transferencias |
| Proxy de acceso público | Paso Check public proxy with HTTPS browser Origin | Login real, sesión Bearer y rechazo de estudiante en caja; prueba sin túnel externo |
| Cámara, permisos, APK y demostración conjunta | Registro en s2-09-demo-y-acta.md | No acreditados por los checks; completar evidencia física |

Las 58 pruebas backend se distribuyen en CashApiTest (6), RechargeHistoryApiTest (6), SprintOneApiTest (8), SprintTwoApiTest (14), DailyWalletApiTest (22) y ParkingPriceTest (2). Incluyen concurrencia, rollback, aislamiento de usuarios, cobros únicos y migraciones.

Las suites Flutter incluyen datos simulados para widgets/layout y pruebas optativas contra API real, activadas separadamente en CI. Las capturas de fixtures son evidencia del diseño, no comprobantes de operaciones personales ni fotografías de una prueba física.

Las cifras de 8 pruebas de Sprint 1, 24/30 de cortes anteriores y 52/83 del PR #44 son históricas. No deben mezclarse ni sumarse como un conteo del producto actual.

## 5. Reproducibilidad

Consultar README y [inicio rápido Windows](inicio-rapido-windows.md). Para el acceso temporal, seguir [caja y vista pública](caja-y-vista-publica.md). El entorno requiere Java 21, Flutter, PostgreSQL o Docker y navegador compatible.

Las pruebas backend vacían tablas: ejecutarlas exclusivamente contra una base separada de pruebas. Reproducir CI con PostgreSQL de pruebas, spotless:check test en backend y formato, flutter analyze, flutter test y flutter build web en mobile. Las pruebas reales requieren cuentas de prueba y apertura de caja antes de recargar; usar el workflow vigente como referencia completa.

No guardar tokens, contraseñas productivas o enlaces temporales de invitación en las evidencias. El modo demo es para pruebas.

## 6. Limitaciones y trabajo pendiente

- Registrar demostración en dispositivos físicos: cámara autorizada/denegada, alternativa manual y navegación.
- Completar acta de aceptación y evidencias reales por Juan y Ronaldo; integración técnica no equivale a esa aceptación.
- Comprobar APK únicamente si lo exige la entrega; web build no certifica una instalación Android.
- Ampliar la ficha pública del QR al comprobante completo del pago.
- Implementar medición de cupos cuando exista el mecanismo de ingreso; actualmente Próximamente.
- Incorporar pantalla administrativa de tarifas/configuración si se requiere; hoy esas operaciones están en API.
- Publicar alojamiento permanente si se exige disponibilidad con el PC apagado; el túnel actual es temporal.
- Ajustar el documento académico final a la rúbrica que entregue el docente.

## 7. Documentos relacionados

- [Sprint 1: tablero y criterios](trello.md), [revisiones](revision.md), [verificación histórica](verificacion.md).
- [Contrato inicial S2 v0.2, histórico](s2-00-acuerdos-v0.2.md).
- [Integración inicial, histórica](s2-08-integracion-real.md).
- [Rediseño Figma](frontend-figma-responsive.md).
- [QR diario, transferencias y reportes](qr-diario-y-transferencias.md).
- [Caja y acceso temporal](caja-y-vista-publica.md).
- [Guion y acta actualizados](s2-09-demo-y-acta.md).

Este documento consolida lo implementado y comprobado hasta el corte. Los campos de aceptación física permanecen pendientes hasta que los participantes aporten resultados y confirmación explícita.
