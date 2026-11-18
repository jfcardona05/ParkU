# Sprint 2 · Guion de demostración y acta de aceptación

Actualizado: 18 de noviembre de 2026, America/Bogota.
Versión funcional de referencia: 2f3c3e5afdbf4f0d64b7406af103a6615f746396.
Informe relacionado: [implementación, evidencias y trazabilidad](s2-09-cierre-y-evidencias.md).

Este archivo prepara la demostración del sistema integrado. No certifica una sesión física ni contiene firmas o aceptación inventadas. Sustituye el recorrido antiguo de QR temporal y cobro al salir.

## Preparación

1. Usar una base de demostración separada y cuentas de prueba: usuario, taquilla y portería. Preparar los roles antes de la sesión.
2. Verificar tarifas vigentes: valores iniciales moto 4.000 y automóvil 5.000 COP. Identificar el commit que realmente se ejecutará.
3. Abrir ParkU mediante iniciar-parku.cmd o las instrucciones del README. Para invitados externos, usar compartir-parku.cmd y mantener PC y servicios encendidos. El enlace HTTPS es temporal.
4. Elegir dispositivo, navegador y permisos de cámara. Tener disponible entrada manual como alternativa.
5. Seleccionar un punto de taquilla disponible y abrir caja. Sin caja válida no se pueden registrar nuevas recargas.
6. No usar datos personales reales ni publicar contraseñas, tokens o el enlace temporal en las capturas.

## Recorrido de demostración

| Paso | Acción | Resultado esperado |
|---|---|---|
| 1 | Explicar propuesta, arquitectura y roles | Distinguir usuario, taquilla, portería y administración |
| 2 | Mostrar interfaz en PC y celular/tablet | Diseño Figma y navegación responsive |
| 3 | Usuario registra vehículo y consulta tarifa sin saldo | Consulta gratuita; generación rechazada sin fondos y sin pase |
| 4 | Taquilla abre caja con base de prueba y acredita 20.000 COP al usuario | Caja y abono registrados; saldo e historial actualizados |
| 5 | Usuario confirma generar QR diario para automóvil | Se descuenta la tarifa confirmada; con 5.000 COP queda en 15.000 |
| 6 | Consultar nuevamente el QR del mismo vehículo | Mismo pase y saldo; no hay otro cobro |
| 7 | Portería escanea o introduce el enlace, valida y confirma ingreso | Vehículo dentro; la lectura no confirma sola |
| 8 | Confirmar salida con el pase diario vigente | Vehículo fuera y sin segundo cobro |
| 9 | Abrir ficha desde cámara/navegador de otro teléfono | Nombre, placa y tipo; no afirmar que incluye importe/referencia del pago |
| 10 | Transferir 3.000 COP a una segunda cuenta registrada | Confirmación, saldo remitente reducido, destinatario aumentado e historial de ambos |
| 11 | Taquilla consulta Reportes por día, semana y mes y busca al beneficiario | Aparece la recarga y sus totales; no se mezcla transferencia ni débito QR |
| 12 | Cerrar caja con contado y retención para devueltas | Esperado, diferencia y dinero a entregar correctos; explicación si hay diferencia |
| 13 | Consultar y descargar comprobante de cierre desde Reportes | HTML imprimible/Guardar PDF; caja cerrada no acepta otro abono |
| 14 | Mostrar cupos y explicar acceso público | Próximamente; enlace temporal depende del PC encendido |
| 15 | Mostrar PR y verificaciones y explicar límites | Evidencias técnicas identificadas y pendientes declarados |

El pase expira a medianoche colombiana, no a las 24 horas de generarlo. Si cambia el día durante la sesión, se necesita un nuevo pase y confirmar su nuevo cobro. La demo de caja usa un punto/día disponible; un punto cerrado no se reabre el mismo día. No manipular el historial para repetirla: preparar el escenario en una base de demostración.

## Registro de pruebas físicas

| Caso | Criterio | Resultado y evidencia |
|---|---|---|
| PC/tablet/celular | Navegación y formularios utilizables | PENDIENTE |
| Cámara autorizada | Lectura real y vista previa sin confirmar sola | PENDIENTE |
| Cámara denegada | Mensaje y alternativa manual | PENDIENTE |
| QR diario y saldo | Un cobro tras confirmar; consulta repetida gratuita | PENDIENTE |
| Ingreso/salida | Registros coherentes y salida diaria sin otro cobro | PENDIENTE |
| Ficha desde otro celular | Nombre, placa y tipo visibles mediante URL alcanzable | PENDIENTE |
| Transferencia | Mismos importes en ambos historiales | PENDIENTE |
| Caja y reportes | Apertura, recarga, cierre, retención y comprobante coherentes | PENDIENTE |
| Acceso HTTPS externo | Login y operación desde datos móviles | PENDIENTE |
| APK, si se exige | Compilación, instalación y flujo en Android identificado | PENDIENTE |

Las pruebas automatizadas ya enlazadas en el informe no rellenan estos resultados físicos. Adjuntar capturas reales en docs/evidencias/ solo cuando existan, ocultando datos sensibles. Registrar incidencias y reintentos observados, sin presentar mocks como operaciones reales.

## Acta por completar

| Campo | Valor |
|---|---|
| Proyecto | ParkU · Sprint 2 y evolución integrada |
| Participantes previstos | Juan Felipe Cardona y Ronaldo Mosquera |
| Fecha/hora de demostración | PENDIENTE |
| Commit realmente demostrado | PENDIENTE |
| Dispositivo, sistema y navegador | PENDIENTE |
| Entorno y base de demostración sin claves | PENDIENTE |
| Tarifas, punto y caja utilizados | PENDIENTE |
| Resultados y capturas físicas | PENDIENTE |
| Incidencias y acciones | PENDIENTE |
| Confirmación explícita de Juan | PENDIENTE |
| Confirmación explícita de Ronaldo | PENDIENTE |
| Decisión de aceptación/cierre | PENDIENTE |

La aprobación de este cambio documental confirma su revisión; no sustituye la demostración ni la aceptación personal del producto.
