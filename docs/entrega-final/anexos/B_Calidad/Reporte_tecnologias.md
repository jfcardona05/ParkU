# Reportes de análisis y calidad Java y Dart
La guía menciona PHPStan. ParkU no implementa un backend PHP: usa Java 21/Spring Boot, Flutter/Dart y PostgreSQL. Por instrucción del equipo se presenta la evidencia correspondiente a estas tecnologías.

Spotless comprueba el formato Java; flutter analyze realiza análisis estático Dart; dart format comprueba formato Dart. Las pruebas Java/Flutter verifican comportamiento y no se presentan como análisis estático. Spotless no es equivalente funcional completo de PHPStan, que tampoco se ejecutó en este proyecto.

## Cortes localizados
1. Sprint 1, 28 de octubre de 2026: docs/verificacion.md registra Spotless aprobado y análisis Flutter sin incidencias. Es un informe histórico, no un log original de PHPStan.
2. Sprint 2, corte inicial 10 de noviembre de 2026: docs/s2-09-cierre-y-evidencias.md de main conserva referencias a CI 42934524319 y a sus verificaciones. Ahora se adjuntan los logs originales descargados y contrastados con los jobs de GitHub Actions.
3. Versión funcional actual 2f3c3e5afdbf4f0d64b7406af103a6615f746396: CI 44230579477, backend y Flutter aprobados; análisis Flutter sin incidencias, formato y build web correctos. Backend: 58 pruebas sin fallos. CI 44227787873: suite Flutter 106 aprobadas y 2 optativas omitidas en ejecución normal; las dos pruebas live se ejecutan aparte y aprobaron. Los extractos descargados constan en evidencias/.

## Semanas académicas
No se dispone de la fecha inicial del curso ni del calendario que asigne las semanas 10, 13 y 16. Estos tres cortes no se etiquetan retroactivamente como esas semanas. Completar la correspondencia de fechas y adjuntar los reportes exigidos; un reporte actual no prueba ejecución histórica en las tres semanas.

Verificación técnica de referencia: https://github.com/jfcardona05/ParkU/actions/runs/44230579477 y https://github.com/jfcardona05/ParkU/actions/runs/44227787873.

## Ampliación documental
Se recuperaron logs originales para CI 40820227912 y 42927542050, además del corte actual 44230579477. Consultar los tres reportes nuevos y evidencias/historico_*.txt. La asociación con semanas académicas sigue dependiendo de las fechas del curso.
