# Revisión de los cuatro commits nuevos

Conservar el historial remoto existente. Los cuatro commits de esta reconstrucción son nuevos; los anteriores no se cuentan como trabajo de esta entrega. No crear commits vacíos ni cambiar fechas para simular una sesión previa.

1. Ronaldo: `feat(HU-01,HU-06): API Spring Boot con autenticacion y vehiculos`.
2. Cardona: `feat(HU-01,HU-06): app Flutter conectada con sesion y vehiculos`.
3. Ronaldo: `feat(HU-02): recargas PostgreSQL y pruebas HTTP del sprint`.
4. Cardona: `test(HU-02): integrar Flutter con taquilla y documentar entrega`.

Cada commit tiene una rama feature propia sobre el anterior. El responsable verifica el cambio preparado con asistencia antes de presentarlo como trabajo aceptado. Cada PR debe ser revisado por el otro integrante desde su cuenta de GitHub: Cardona revisa 1 y 3; Ronaldo revisa 2 y 4.

Revisión T01: ejecutar API sobre base demo; login válido e inválido; consulta sin token; registrar vehículo; iniciar otra sesión y comprobar aislamiento. Revisar migración y que las contraseñas no se almacenen en texto plano.

Revisión T02: iniciar Flutter; comprobar que un estudiante entra al dashboard y operador a taquilla; guardar un vehículo válido y rechazar placa vacía; comprobar mensajes ante API desconectada.

Revisión T03: ejecutar pruebas Java sobre base separada; registrar recarga como operador y comprobar saldo exacto; probar cero/negativo y estudiante; comprobar aislamiento del historial. Verificar transacción y bloqueo de fila.

Revisión T04: ejecutar formato, análisis, pruebas Flutter, compilación y prueba de integración con API demo. Revisar comprobante, persistencia y guía de ejecución desde cero.

Para conservar exactamente cuatro commits nuevos no usar merge commits. Integrar mediante avance rápido después de las aprobaciones verificadas. Publicar el mismo historial aprobado en develop y main sin crear commits adicionales. No afirmar que un PR fue aprobado hasta que exista la aprobación del compañero.
Los PR de Ronaldo deben abrirse desde ronaldomosg para que Cardona pueda aprobarlos; los PR de Cardona deben abrirse desde jfcardona05 para que Ronaldo pueda aprobarlos. La autoría del commit y la cuenta que abre el PR son datos diferentes. Un PR creado por Cardona no permite que Cardona lo apruebe.

Las ramas se encadenan para aislar cada cambio: T01 desde develop; T02 desde T01; T03 desde T02; T04 desde T03. Después de aprobar e integrar cada cambio por avance rápido, actualizar la base del siguiente PR a develop antes de su integración. No pulsar Merge sin verificar el método y el número de commits resultante.