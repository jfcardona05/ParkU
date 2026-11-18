# Caja diaria y vista pública de ParkU

## Flujo de taquilla

**Panel de caja** contiene apertura, cierre y registro de recargas. **Reportes** contiene exclusivamente el historial de recargas y el historial de cierres, con filtros, paginación y comprobantes descargables.

1. El operador elige un punto y registra la base inicial en COP enteros. Si ese punto ya tiene un cierre anterior, la base se toma del efectivo retenido en ese cierre y no se puede cambiar.
2. Cada nueva recarga requiere una caja abierta del mismo operador, punto y día de Colombia. La recarga queda ligada a la caja en la misma transacción de base de datos que acredita el saldo.
3. Al cerrar, se cuenta **todo** el efectivo, incluida la base inicial. Se ingresa cuánto se retiene para las devueltas de la siguiente apertura. Esta cantidad no puede superar lo contado.
4. Si lo contado no coincide con lo esperado, se exige una explicación. Se muestra una confirmación antes de guardar el cierre definitivo.
5. El comprobante permanece en Reportes. Su descarga es un HTML autocontenido; al abrirlo en Chrome se puede **Imprimir / Guardar PDF**. Es un comprobante interno, no una factura electrónica.

### Cálculos

| Concepto | Cálculo |
|---|---|
| Recaudo del día | Suma de recargas presenciales vinculadas a esa caja |
| Efectivo esperado | Base inicial + recaudo |
| Diferencia | Efectivo contado − efectivo esperado |
| Dinero a entregar | Efectivo contado − base retenida |
| Base de la siguiente apertura | Base retenida del último cierre del mismo punto |

Ejemplo: base inicial 50.000, recargas 200.000 y contado 250.000 COP. Si se retienen 40.000 para devueltas, se entregan 210.000; la diferencia es cero. **El recaudo sigue siendo 200.000**, porque entregar parte de la base inicial no es un ingreso nuevo.

No se suman transferencias entre usuarios ni débitos del saldo por parqueadero: esos movimientos no son efectivo recibido por el operador.

### Reglas

- Un punto solo puede tener una caja abierta y un operador solo puede tener una caja abierta a la vez.
- Hay una apertura y un cierre por punto y día, según `America/Bogota`. Tras cerrar, no se reabre ese punto el mismo día.
- Si se deja abierta hasta después de medianoche, se debe cerrar la caja anterior antes de abrir la de hoy. Las recargas nuevas quedan bloqueadas hasta hacerlo.
- El cierre guarda una instantánea definitiva. Repetir exactamente una apertura o cierre confirmado devuelve el mismo registro; no duplica el cierre. Cambiar un cierre ya guardado se rechaza.
- El cierre y las recargas bloquean la misma fila: una recarga concurrente entra antes del cierre y se incluye, o se rechaza si el cierre ganó el bloqueo.
- Los registros anteriores a la migración V9 se conservan en el historial de recargas, pero no se inventan cierres retroactivos.
- El rol de taquilla sigue siendo `operador`; esta función no concede permisos de `admin`.

## API nueva

Todas las rutas requieren sesión de operador.

| Método y ruta | Uso |
|---|---|
| `GET /api/cash/current` | Caja abierta propia y base/disponibilidad de los puntos |
| `POST /api/cash/open` | `point_name`, `opening_amount` |
| `POST /api/cash/{id}/close` | `counted_cash`, `retained_cash`, `notes` |
| `GET /api/cash/history?date=YYYY-MM-DD&page=0` | Cierres de todos los puntos; fecha opcional, 20 por página |

`POST /api/wallet/recharge` conserva sus campos, pero ahora exige una apertura válida. Las integraciones deben abrir caja antes de recargar. Los importes deben ser COP enteros; no se truncan decimales.

## Compartir desde tu computador

Se necesita Windows, Docker Desktop, Flutter, Java 21, Chrome y conexión a Internet. No se requiere instalar Caddy o cloudflared: Docker descarga sus imágenes oficiales.

1. Actualiza la rama del proyecto y abre Docker Desktop.
2. Haz doble clic en **`compartir-parku.cmd`**. Si el backend no está iniciado, el script invoca `iniciar-parku.cmd`.
3. Espera a que compile la web y aparezca **ENLACE PARKU**. Se copia al portapapeles y se guarda temporalmente en `.local/enlace-publico.txt`.
4. Envía **el enlace completo**, incluida su ruta de acceso, a las personas invitadas. Pueden abrirlo en Chrome desde un celular con datos móviles o desde otro PC, sin descargar el proyecto.
5. Mantén tu computador encendido, Docker, backend y la ventana del túnel abiertos. Las personas deben iniciar sesión en ParkU con su cuenta.
6. Para terminar la vista pública, pulsa `Ctrl+C`. También puedes ejecutar **`cerrar-enlace-publico.cmd`**, que detiene y elimina únicamente los contenedores de vista pública, sin tocar PostgreSQL ni sus datos.

El enlace HTTPS es temporal y cambia en cada inicio. Contiene una ruta aleatoria de acceso que debe compartirse solo con los invitados. La raíz sin esa ruta devuelve 404. La ruta protege también las API y las fichas QR; el login y los permisos de ParkU siguen siendo necesarios. No se abren puertos del router ni se publica el puerto de PostgreSQL. El acceso local del gateway se limita a `127.0.0.1:8080`.

La web y la API se sirven bajo el mismo enlace: un celular no usa `localhost:8000`, que apuntaría al propio celular. El launcher compila Flutter con un prefijo relativo y configura Caddy para reenviar la API al backend de Windows. Los QR preservan ese prefijo.

Si el puerto 8080 está ocupado por una vista anterior, usa `cerrar-enlace-publico.cmd` antes de repetir. Si cloudflared no muestra un enlace, revisa los logs; los Quick Tunnels requieren salida a Internet y pueden estar bloqueados por la red. Este mecanismo es para demostraciones temporales, no alojamiento permanente. Antes de invitar personas, usa datos y cuentas de prueba que quieras compartir; el enlace da acceso a tu instancia local a quienes lo reciban.

Referencias técnicas: [Cloudflare Quick Tunnels](https://developers.cloudflare.com/tunnel/get-started/quick-tunnels/) y [Caddy reverse proxy](https://caddyserver.com/docs/caddyfile/directives/reverse_proxy).
