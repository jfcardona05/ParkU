# Rediseño completo de Flutter · revisión de Ronaldo

Referencia: [Figma ParkU](https://www.figma.com/design/4kwEh0chOP7Gr5xL5IXVyz/ParkU-%E2%80%94-Propuesta-responsive-%C2%B7-Desktop-y-Mobile?node-id=0-1).
Tarea #38, PR #39. Sustituye la interfaz anterior; no cambia el backend, servicios HTTP ni reglas de negocio.

## Pantallas y navegación

- Login, inicio, vehículos, QR, saldo, parqueadero y portería siguen las siete capturas suministradas.
- Registro, agregar vehículo, taquilla, comprobantes y estados vacíos/error continúan el mismo estilo claro/amarillo.
- Escritorio: lateral completa desde 1100 px; tablet: rail desde 760 px; móvil: navegación inferior.
- Columnas se apilan según el espacio disponible del contenido, no según el nombre del dispositivo.
- QR real predeterminado, confirmación explícita, claves estables de reintento y autorización del servidor conservadas.
- Cantidades y estados de producción proceden de la API. Los datos de referencia solo existen en fixtures de tests.

## Recursos y fidelidad

Se usaron las capturas visibles como referencia. El archivo Figma no pudo leerse directamente.
La ilustración de vehículo es una recreación vectorial local; no es el recurso original del diseñador.
No hay solicitudes externas de imágenes ni nuevas fuentes remotas. Sustituir por el recurso original
si el equipo lo aporta y exige coincidencia gráfica exacta. Colores, tarjetas y navegación implementados
deben compararse visualmente con Figma antes de aprobar: los tests de layout no certifican fidelidad píxel a píxel.

## Verificación remota

La sesión local de ejecución está indisponible. Los commits se publican mediante GitHub y se prueban con Actions.
El workflow de frontend verifica diez vistas en móvil (390), tablet (834) y desktop (1440 px),
y publica PNG y una hoja de revisión en el artefacto `parku-responsive-previews`.
La hoja usa exclusivamente datos ficticios de tests; ningún código mostrado concede acceso real.

Revisar el último commit del PR y los dos workflows, no resultados de versiones anteriores.
La corrección automática de estilo en el workspace de Actions sirve para devolver el formato al repositorio;
el workflow original mantiene su comprobación estricta de formato sobre el código publicado.

## Revisión humana

1. Abrir PR #39 y confirmar que no hay cambios en backend ni contratos.
2. Revisar las capturas del artefacto para las tres anchuras y contrastarlas con el prototipo.
3. Ejecutar con API real sobre base de pruebas: login, alta/eliminación de vehículo, QR y regeneración,
   ingreso/salida, rechazo de fondos insuficientes, recarga autorizada, saldo/historial y paginación.
4. Comprobar teclado y cámara/permisos en dispositivo físico; no se presentan como probados desde Actions.
5. Ronaldo registra Approve o Request changes desde su cuenta. No hay aprobación ni merge automáticos.

GitHub Projects no está expuesto en esta sesión y no hay navegador para operarlo.
El estado lógico y las evidencias se registran en #38; la tarjeta requiere actualización mediante acceso a Projects.
