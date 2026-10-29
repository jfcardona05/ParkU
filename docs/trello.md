# Tablero del Sprint 1

Crear listas: Pendiente, En proceso, En revisión, Terminado. Crear las cuatro tarjetas inicialmente en Pendiente. Cada persona mueve sus tarjetas con su propia cuenta. Registrar los movimientos cuando ocurran, sin inventar horas ni retroceder fechas.

Límite de En proceso: 2 tarjetas (una por integrante). Límite de En revisión: 4 (dos por revisor). Una tarjeta entra en proceso cuando su responsable comienza a trabajar y pasa a revisión cuando existe código remoto comprobable. Terminado requiere pruebas y revisión cruzada real.

| Tarjeta | Responsable | Revisor | Criterios |
|---|---|---|---|
| T01 · HU-01/HU-06 · API Spring Boot, autenticación y vehículos | Ronaldo | Cardona | Login válido; rechazo sin divulgar saldo; sesión requerida; registro de placa/tipo; aislamiento de vehículos |
| T02 · HU-01/HU-06 · Flutter: inicio de sesión y vehículos conectados a la API | Cardona | Ronaldo | Login; navegación según rol; alta/listado de vehículos; mensajes de error; configuración de URL API |
| T03 · HU-02 · PostgreSQL, saldo, recargas presenciales y pruebas de API | Ronaldo | Cardona | Abono exacto; rechazo de cero/negativos; solo operador; historial por usuario; consistencia ante concurrencia |
| T04 · HU-02 · Flutter: saldo y taquilla, pruebas e instrucciones de ejecución | Cardona | Ronaldo | Saldo/historial; selección de destinatario; comprobante; errores; pruebas de integración y guía de ejecución |

En cada tarjeta añadir: descripción del cambio, responsable, revisor y checklist con sus criterios. Al publicar, comentar hash real y URL del commit y PR. Al revisar, el compañero comenta qué comprobó y registra la aprobación del PR desde su cuenta. Solo entonces mover a Terminado.

Puntos por historia: HU-01=3, HU-06=3, HU-02=5. Total=11. No asignar otra vez esos puntos a cada tarjeta técnica: una historia se cierra cuando sus partes API y Flutter cumplen todos los criterios y tienen revisión. No declarar puntos cerrados porque el código esté preparado.

Definition of Ready: historia, aceptación, responsable y dependencias identificadas. Definition of Done: código remoto, compilación, formato, análisis y pruebas pertinentes correctos; migraciones versionadas; PR revisado por el compañero.

La planificación del ZIP se utiliza como requisito del producto. Su bitácora resuelta contiene hashes y horas de ejemplo sin verificar; no se incorpora como evidencia del historial real.