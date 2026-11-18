# Retrospectiva documental Sprint 1
Proyecto: ParkU. Integrantes: Juan Felipe Cardona y Ronaldo Mosquera.
Elaboración documental: 18/11/2026. Período examinado: 28/10/2026 a 28/10/2026 (Colombia).
Naturaleza: reconstrucción analítica basada en evidencias del repositorio. No certifica que una reunión ocurriera en esas fechas ni atribuye opiniones personales a los integrantes.

## Resultados
Se completaron API e interfaz de autenticación/vehículos y API e interfaz de recargas. El CI original 40820227912 aprobó ocho pruebas backend, Spotless, flutter analyze y compilación web. Las cuatro integraciones se produjeron el 28 de octubre en hora de Colombia.

## Qué funcionó según las evidencias
La división API/Flutter permitió entregar autenticación, propiedad de vehículos y billetera en componentes verificables. Las pruebas comprobaron rechazo de credenciales inválidas, autorización de recargas y consistencia del saldo. Se dispone de fuente y resultado originales, no solo de una descripción de funcionalidades.

## Dificultades verificadas
Los issues retrospectivos de las HU (#14–16) se crearon el 3 de noviembre y continúan abiertos aunque el código ya se había integrado. Por tanto, su cierre no sirve para reconstruir el avance de octubre. Tampoco se localizaron revisiones formales APPROVED en los PR 8, 9, 10, 11 y 13 consultados; su merge no debe presentarse como una aprobación formal inexistente. La guía de revisión y los criterios técnicos sí están documentados.

## Lecciones y acciones derivadas
Registrar desde el inicio las historias y su estado, enlazar cada historia con los PR de API e interfaz, conservar logs y registrar la revisión formal antes de integrar. La estimación de 11 puntos corresponde a HU 01 (3), HU 06 (3) y HU 02 (5), no a cuatro tareas multiplicadas por esos puntos.

## Compromisos propuestos para ratificar
| Acción | Responsable propuesto | Plazo de referencia | Seguimiento al corte |
|---|---|---|---|
| Conciliar HU #14–16 con sus PR integrados | Juan y Ronaldo | Antes de radicar | Aún abiertas; no se alteran fechas pasadas |
| Conservar revisión cruzada formal | Ambos | Siguientes PR | Propuesta; contrastar revisiones efectivamente registradas |
| Registrar evidencia de dispositivo | Ambos | Próxima demostración | Sin ejecución física acreditada |

## Trazabilidad de entregas
- PR #11: feat(HU-01,HU-06): API Spring Boot con autenticacion y vehiculos. Integrado 28/10/2026 23:45 Colombia. Commit de rama a6b0de3fb7a3acdac69787cface4a0c670343423; merge 2e818c7b994a174f57ce23b3a3eb7dc9b965dcb6. https://github.com/jfcardona05/ParkU/pull/11
- PR #8: T02 · HU-01/HU-06: Flutter conectado con sesión y vehículos. Integrado 28/10/2026 23:47 Colombia. Commit de rama 01ce24c84a96467ce4a5f0c5c0da827962106068; merge 072321f7bc53aae154797b7fe497e9591c6b2544. https://github.com/jfcardona05/ParkU/pull/8
- PR #10: Feature/t03 api recargas. Integrado 28/10/2026 23:48 Colombia. Commit de rama 2d305c1d3a9847f83dca76061936f683a0010e70; merge 55852ea127d429d2fb065d73af50cb97500ee55b. https://github.com/jfcardona05/ParkU/pull/10
- PR #13: test(HU-02): integrar Flutter con taquilla y documentar entrega. Integrado 28/10/2026 23:53 Colombia. Commit de rama 2fc03361975492ca34c9d3f4346901a9098d2047; merge befdfa4b35e1b1e98bf8573f2f771b5271153674. https://github.com/jfcardona05/ParkU/pull/13

## Suscripción pendiente de los integrantes
Fecha y medio de revisión conjunta de esta acta: ____________________.
Comentarios o correcciones de Juan: ____________________.
Comentarios o correcciones de Ronaldo: ____________________.
Juan Felipe Cardona — firma y fecha: ____________________.
Ronaldo Mosquera — firma y fecha: ____________________.
No hay firmas insertadas ni aceptación personal presumida. El contenido documental está completado; la suscripción requiere a los autores.
