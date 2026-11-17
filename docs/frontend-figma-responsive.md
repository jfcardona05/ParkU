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

El archivo original ya es accesible. Se leyeron las catorce pantallas desktop/mobile con contexto de diseño.
Se incorporan localmente el PNG original del automóvil, las variantes SVG de los iconos y la fuente Manrope
con su licencia OFL. Colores, lateral de 236 px, márgenes y proporciones se ajustaron a esos nodos.
Los SVG conservan las dimensiones raíz originales; el automóvil usa BoxFit.contain en su slot de diseño.
El QR de acceso sigue siendo dinámico y procede del servidor, nunca del QR ilustrativo de Figma.
La representación de motos y las acciones adicionales sin diseño siguen siendo componentes nativos.
No hay URLs temporales de Figma ni descargas de fuentes en tiempo de ejecución.

Las capturas permiten revisar la implementación en tres anchuras. Los tests de layout verifican que
las vistas no desbordan; no certifican por sí solos coincidencia píxel a píxel ni interacción física.

## Verificación remota

La sesión local de ejecución está indisponible. Los commits se publican mediante GitHub y se prueban con Actions.
El workflow de frontend verifica diez vistas en móvil (390), tablet (834) y desktop (1440 px),
y publica PNG y una hoja de revisión en el artefacto `parku-responsive-previews`.
La hoja usa exclusivamente datos ficticios de tests; ningún código mostrado concede acceso real.

Revisar el último commit del PR y los dos workflows, no resultados de versiones anteriores.
Ambos workflows comprueban estrictamente el formato del código publicado; no se corrige ni oculta
un fallo de formato al validar la entrega.

## Revisión humana

1. Abrir PR #39 y confirmar que no hay cambios en backend ni contratos.
2. Revisar las capturas del artefacto para las tres anchuras y contrastarlas con el prototipo.
3. Ejecutar con API real sobre base de pruebas: login, alta/eliminación de vehículo, QR y regeneración,
   ingreso/salida, rechazo de fondos insuficientes, recarga autorizada, saldo/historial y paginación.
4. Comprobar teclado y cámara/permisos en dispositivo físico; no se presentan como probados desde Actions.
5. Ronaldo registra Approve o Request changes desde su cuenta. No hay aprobación ni merge automáticos.

GitHub Projects no está expuesto en esta sesión y no hay navegador para operarlo.
El estado lógico y las evidencias se registran en #38; la tarjeta requiere actualización mediante acceso a Projects.
