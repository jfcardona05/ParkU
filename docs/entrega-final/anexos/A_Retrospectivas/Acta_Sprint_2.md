# Retrospectiva documental Sprint 2
Proyecto: ParkU. Integrantes: Juan Felipe Cardona y Ronaldo Mosquera.
Elaboración documental: 18/11/2026. Período examinado: 03/11/2026 a 17/11/2026 (Colombia).
Naturaleza: reconstrucción analítica basada en evidencias del repositorio. No certifica que una reunión ocurriera en esas fechas ni atribuye opiniones personales a los integrantes.

## Resultados
El corte backend inicial aprobado en CI 42927542050 contiene 24 pruebas. El producto evolucionó a 58 pruebas con QR diario, transferencia, reportes y caja, con análisis Flutter aprobado. Los PR del alcance inicial y las ampliaciones constan integrados. Se sustituyó toda la interfaz conforme al prototipo Figma.

## Qué funcionó según las evidencias
Se conservó la integración API/PostgreSQL y se comprobaron reintentos, permisos y concurrencia. Los PR 36, 37, 39 y 44 registran aprobación de Ronaldo; 46, 47 y 49 registran aprobación de Juan. El diseño responsive y el control transaccional se mantuvieron al agregar las reglas financieras.

## Dificultades verificadas
Hubo cambios de alcance y de regla comercial: QR temporal y cobro al salir evolucionaron a pase diario cobrado al generarlo. Los documentos antiguos quedaron desactualizados y se consolidaron en PR 50. El acceso público fallaba al iniciar sesión desde el proxy y se corrigió en PR 49. El tablero no es legible sin sesión en la comprobación realizada. La aprobación de PR 48 está sobre 9890070, anterior al último commit de su rama; no demuestra revisión específica de cada cambio posterior.

## Lecciones y acciones derivadas
Versionar las reglas del producto y actualizar documentos/guiones cuando cambien. Separar recaudación de efectivo, saldo de billetera y consumos. Conservar referencia de reintentos y comprobar operaciones concurrentes. Una vista pública temporal depende del PC encendido y no sustituye alojamiento permanente.

## Compromisos propuestos para ratificar
| Acción | Responsable propuesto | Plazo de referencia | Seguimiento al corte |
|---|---|---|---|
| Completar evidencias físicas y acta de aceptación | Juan y Ronaldo | Antes de entrega física | Pendiente de evidencia |
| Resolver acceso de lectura al tablero | Propietario del tablero | Antes de radicar | 404 sin sesión; no se cambió visibilidad |
| Obtener cuatro respuestas reales | Equipo | Antes de radicar | Formulario preparado; no hay respuestas recibidas |
| Ampliar ficha pública de pago si lo exige la entrega | Equipo | Plan posterior | Ficha actual contiene nombre, placa y tipo |

## Trazabilidad de entregas
- PR #27: [S2-04] QR del vehículo: frontend y demo para revisión. Integrado 10/11/2026 18:07 Colombia. Commit de rama b393de465ec4205b55b7c1e01f870f3212abaa54; merge ccf16b595fc66d82eacbc6e88310d503cecbe8a6. https://github.com/jfcardona05/ParkU/pull/27
- PR #28: [S2-05] Portería: escáner, confirmación y demo para revisión. Integrado 10/11/2026 18:08 Colombia. Commit de rama 111b883eeb01d335f826128d22d02a31c0c892f7; merge a50e1317ad3ca92bcb58290826d0a39d9eb8d208. https://github.com/jfcardona05/ParkU/pull/28
- PR #29: [S2-06] Saldo, cobros e historial en Flutter. Integrado 10/11/2026 18:08 Colombia. Commit de rama 63cdbc6d7d311b3310b1a22f829b5569ea95bd48; merge 19877362d74034811477ee7990e3afedf788646f. https://github.com/jfcardona05/ParkU/pull/29
- PR #30: [S2-08] Ensayo Flutter de QR, portería y saldo. Integrado 10/11/2026 18:09 Colombia. Commit de rama 1541d792901a4354056f6f559d1a16fe153b7e03; merge 30fd3d291a43d89ae289a42f70dae6cf6b62c47f. https://github.com/jfcardona05/ParkU/pull/30
- PR #31: [S2-00] Contrato API, tarifas autorizadas y administración configurable. Integrado 10/11/2026 19:18 Colombia. Commit de rama 82484b5c24030124fec839045f44028d9ebbba7c; merge fb3b36135d9975c180d46fdf48b0dfd97a51622f. https://github.com/jfcardona05/ParkU/pull/31
- PR #32: [S2-01] QR seguro por vehículo con propiedad, vigencia y regeneración. Integrado 10/11/2026 19:19 Colombia. Commit de rama 33d61a1c1bada71162e09cc6ca2e2ba83f0559ea; merge 69581d611d490af14c2732e71b91fcc78aac1b94. https://github.com/jfcardona05/ParkU/pull/32
- PR #33: [S2-02] Portería idempotente y control concurrente de ingreso. Integrado 10/11/2026 19:20 Colombia. Commit de rama 3b1598c040023ab9387b2a62e6cd8d2f45c3e664; merge 11e33affe0a76ee567c8e717dbbad37d5295107f. https://github.com/jfcardona05/ParkU/pull/33
- PR #34: [S2-03] Cobro atómico y tarifas modificables por administrador. Integrado 10/11/2026 19:22 Colombia. Commit de rama 758b738fbe81a6af0b24bdb711ab89bd7ef581ee; merge d0cc2408ada48285cb183e6a6a573c3e4251ff74. https://github.com/jfcardona05/ParkU/pull/34
- PR #35: [S2-07] Ocupación e historial aislado con pruebas de regresión y concurrencia. Integrado 10/11/2026 19:23 Colombia. Commit de rama 7c74e478e5470f6c421817c0a4f57a96ba7eb0ff; merge 7751ca03ed02202e94d46b70ae19647b40e971fc. https://github.com/jfcardona05/ParkU/pull/35
- PR #36: S2-08: integrar Flutter con la API real de QR, portería y cobros. Integrado 10/11/2026 20:36 Colombia. Commit de rama 777ded047d8304d5e96ad2793d5a15811197b90e; merge 470d50a73667438412cdc2e58f9bc3cab0ef7228. https://github.com/jfcardona05/ParkU/pull/36
- PR #37: S2-00/S2-09: compatibilidad Flutter y preparación del cierre compartido. Integrado 10/11/2026 20:37 Colombia. Commit de rama 879549bd900268255977a1d6374aad233bbe9727; merge d29b5f678a840d5072165db0acb3c85252502147. https://github.com/jfcardona05/ParkU/pull/37
- PR #39: Frontend: reemplazo completo por diseño Figma responsive. Integrado 16/11/2026 19:23 Colombia. Commit de rama 9e8e3dd4e27468af52b7ebaabc9b9f9f270c5a5b; merge 445fa036eb3e4278e07fec18320eac5d63546f9f. https://github.com/jfcardona05/ParkU/pull/39
- PR #44: QR diario, transferencias e historial de recargas para taquilla. Integrado 17/11/2026 20:11 Colombia. Commit de rama 97dc4c088738364051da61623818a732da0ce2f0; merge 18b85ba8038d781e29162b74b4a24cf89ed84b8c. https://github.com/jfcardona05/ParkU/pull/44
- PR #46: Taquilla: panel operativo, navegación propia e indicadores de recargas. Integrado 17/11/2026 20:46 Colombia. Commit de rama a9a8092cf253ed2997ff391803211de058518c37; merge 17b6f8d11b6bcc7c10309895527adb0a1da59cae. https://github.com/jfcardona05/ParkU/pull/46
- PR #47: Inicio rápido de ParkU con doble clic en Windows. Integrado 17/11/2026 21:01 Colombia. Commit de rama 21da6e5ca6383caa84a8179a8185e66bc7a0aa22; merge 2174153374260cce5dd4cbfca28dc882f964b0dd. https://github.com/jfcardona05/ParkU/pull/47
- PR #48: Caja diaria con base de devueltas, comprobantes y vista pública temporal. Integrado 17/11/2026 21:45 Colombia. Commit de rama a5036268afbf6ec9c95a610422b5cf31b7b1cbfa; merge fa19b9ce8a980dbdd9ec5f68ba41c5f1b1d40098. https://github.com/jfcardona05/ParkU/pull/48
- PR #49: Corregir login desde celulares en el enlace HTTPS público. Integrado 17/11/2026 22:27 Colombia. Commit de rama d68628a900ad130b502cc6c64185abe15a8a1597; merge 2f3c3e5afdbf4f0d64b7406af103a6615f746396. https://github.com/jfcardona05/ParkU/pull/49

## Discusión real recuperada
Ronaldo registró en #17 (10/11/2026) decisiones de precios 4000/5000, roles guard/admin, tarifas configurables y pendientes de plataforma. En #26 registró 24 pruebas y luego CI aprobado, conservando pendientes de cámara y demo. Consultar los comentarios originales en https://github.com/jfcardona05/ParkU/issues/17 y https://github.com/jfcardona05/ParkU/issues/26. Estos comentarios son una discusión técnica, no firmas de esta retrospectiva.

## Suscripción pendiente de los integrantes
Fecha y medio de revisión conjunta de esta acta: ____________________.
Comentarios o correcciones de Juan: ____________________.
Comentarios o correcciones de Ronaldo: ____________________.
Juan Felipe Cardona — firma y fecha: ____________________.
Ronaldo Mosquera — firma y fecha: ____________________.
No hay firmas insertadas ni aceptación personal presumida. El contenido documental está completado; la suscripción requiere a los autores.
