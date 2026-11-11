# S2-09 · Guion de demostración y acta por completar

Preparación de Juan para revisión conjunta. Este archivo no certifica que la demo
presencial haya ocurrido. Usar una base de demostración separada, sin datos personales reales.

## Preparación

- Integrar #36 tras revisión y checks; si se ensaya antes, identificar su rama y commit.
- Ronaldo verifica API, migraciones y conexión PostgreSQL. Preparar estudiante,
  `guard`/`admin` y `operador` de taquilla; aprovisionar privilegios conforme a
  `s2-03-api.md`. No publicar contraseñas, sesiones ni tokens QR vigentes.
- Configurar explícitamente capacidad y comprobar tarifas vía API administrativa.
  Acordar el valor de la demo; no reutilizar los 2 cupos del test como política oficial.
- Juan configura `API_BASE_URL` alcanzable desde el celular; `localhost` en el
  teléfono apunta al propio teléfono. Mantener el modo real y revisar permisos.
- Confirmar dispositivo, plataforma y si la entrega requiere APK. Para web con
  cámara, usar contexto seguro admitido por el navegador; no asumir que HTTP por IP funciona.
- Revisar las decisiones abiertas de `s2-00-compatibilidad-flutter.md`.

## Guion sugerido, 6–8 minutos

| Paso | Quién presenta | Acción | Resultado a mostrar |
| --- | --- | --- | --- |
| 1 | Ambos | Explicar estudiante → QR → portería → salida → saldo | Roles y separación Flutter/API |
| 2 | Juan | Login estudiante; vehículo; saldo inicial y QR real | Placa correcta, vencimiento y regeneración |
| 3 | Ronaldo | Login guard; escanear QR; mostrar vista previa | Acción determinada por servidor, sin registrar todavía |
| 4 | Juan | Confirmar ingreso; consultar estado y cupos | Dentro del parqueadero y ocupación actualizada |
| 5 | Ambos | Solicitar QR nuevo; intentar salida sin saldo suficiente | Mensaje de rechazo; vehículo permanece dentro |
| 6 | Ronaldo | Taquilla: recargar destinatario en un punto admitido | Recibo de recarga y saldo del servidor |
| 7 | Juan | Confirmar salida con QR vigente; actualizar saldo/historial | Un débito, tarifa aplicada y saldo posterior |
| 8 | Ambos | Mostrar estado fuera, cupos e historial; explicar reintentos | Flujo completo y garantías respaldadas por pruebas |

Si el QR vence durante la explicación, emitir otro y volver a validar. No presentar
como realizada una simulación de red física: el reintento sin doble cobro está cubierto
por pruebas automatizadas y se puede explicar mostrando la evidencia.

## Registro de pruebas físicas

| Caso | Criterio de éxito | Resultado / evidencia |
| --- | --- | --- |
| Cámara autorizada | Escanea QR real y presenta vista previa sin confirmar sola | PENDIENTE |
| Cámara denegada | Error legible y alternativa manual usable | PENDIENTE |
| Entrada manual | Valida código y requiere confirmación explícita | PENDIENTE |
| Lectura repetida | No registra accesos ni cobra automáticamente | PENDIENTE |
| QR vencido/regenerado | Rechazo legible; nuevo QR funciona | PENDIENTE |
| Salida sin fondos y recuperación | Sin débito parcial; recarga y salida correctas | PENDIENTE |
| Saldo e historial | Mismo cobro, tarifa y saldo que devuelve API | PENDIENTE |
| APK, si es exigido | Compila, instala y completa flujo en dispositivo identificado | PENDIENTE |

Guardar capturas reales con nombres `s2-09-01-qr.png`, `s2-09-02-ingreso.png`,
`s2-09-03-saldo-insuficiente.png`, `s2-09-04-salida.png` y `s2-09-05-historial.png`
en `docs/evidencias/` cuando existan. No se adjuntan imágenes ficticias o marcadores
que parezcan capturas. Ocultar credenciales y códigos vigentes antes de publicar.

## Borrador de acta

| Campo | Valor |
| --- | --- |
| Proyecto / sprint | ParkU / Sprint 2 |
| Participantes previstos | Juan Cardona y Ronaldo Mosquera |
| Fecha y hora de demostración | PENDIENTE |
| Versión / commit demostrado | PENDIENTE; anotar SHA después de integrar |
| Dispositivo / sistema / navegador | PENDIENTE |
| API y base de pruebas identificadas, sin claves | PENDIENTE |
| Capacidad y tarifas efectivas | PENDIENTE |
| Casos físicos ejecutados y resultado | PENDIENTE; enlazar tabla y capturas |
| Incidencias y acciones | PENDIENTE |
| Confirmación de Juan | PENDIENTE, personal y explícita |
| Confirmación de Ronaldo | PENDIENTE, personal y explícita |
| Decisión de cierre | PENDIENTE |

Antes de cerrar #26: incorporar evidencia real, enlazar PR/checks/revisiones,
resolver incidencias y registrar aceptación. La aprobación del PR documental
confirma la revisión del documento; no reemplaza esta prueba manual.
