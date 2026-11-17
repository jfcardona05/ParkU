# QR diario, ficha para celular y transferencias

Tareas #41, #42 y #43. Revisión cruzada: Ronaldo. No integrar sin su aprobación.

## Comportamiento

- Inicio y Parqueadero muestran los cupos como **Próximamente**. No consultan ocupación ni muestran números estimados.
- Se puede consultar la tarifa y el pase sin cobrar. **Generar QR diario** muestra una confirmación de importe y vehículo; solo al aceptarla se solicita el cobro.
- Hay un pase por usuario y día calendario en **America/Bogota**, vigente hasta la siguiente medianoche colombiana. Se vincula al vehículo elegido ese día.
- Se cobra una unidad de la tarifa vigente de ese tipo de vehículo: valores iniciales moto 4.000 COP y automóvil 5.000 COP. No se usa facturación por horas para estos pases.
- Reconsultar, repetir la generación o reintentar una respuesta perdida devuelve el mismo código y no descuenta de nuevo. Saldo insuficiente no produce QR, pase ni movimiento.
- La confirmación incluye la tarifa y el día consultados. Si cambian antes del cobro, se rechaza la solicitud y se requiere una nueva consulta/confirmación.
- El código pagado funciona durante el día en portería para ingreso/salida y no se consume con la primera lectura. No hay un segundo cobro al salir.
- Un vehículo con pase diario vigente no puede eliminarse hasta que venza. Esto mantiene utilizable el pase que ya se pagó.
- Se conservan visitas y códigos anteriores: una estancia previa sin pase diario debe cerrarse con su tarifa histórica antes de comprar el nuevo pase. No se reescriben movimientos existentes.
- En **Mi saldo → Transferir saldo** se eligen correo y monto COP y se confirma el envío. Hay comprobante e historial en ambas cuentas.
- Las transferencias usan bloqueos ordenados, débito/crédito en una sola transacción e idempotencia por cuenta/referencia. No permiten autoenvío, importes no positivos, más de 1.000.000.000 COP, saldo insuficiente ni desbordamientos de saldo.
- Si se pierde la respuesta, la interfaz conserva los datos y la referencia pendiente en la sesión API; al volver a la pantalla permite reintentar sin duplicar. La referencia pendiente no sobrevive al cierre/recarga completa de la app: antes de iniciar un envío nuevo tras recargar, consultar el historial.

## Escaneo con un celular

El QR contiene un enlace al backend `/p/{token}`. Al abrirlo se muestra una ficha responsive con **nombre, placa y tipo de vehículo**, sin correo, saldo, sesión ni historial. Solo el poseedor del código vigente puede abrirla. Está marcada no-store/noindex y el nombre se escapa como HTML.

Consultar esa ficha es de solo lectura: no cobra, no registra ingreso/salida y no sustituye la confirmación autorizada de portería. El escáner de portería acepta tanto el enlace completo como el token opaco.

Para probar en otro celular, el backend debe ser accesible desde ese celular. `localhost` apunta al teléfono, no al PC.

1. Conecta PC y celular a la misma Wi-Fi y consulta la IPv4 del PC con `ipconfig`.
2. Arranca el backend como siempre. No debe estar limitado a `SERVER_ADDRESS=127.0.0.1` si vas a acceder desde la red local.
3. Permite el puerto 8000 únicamente en tu red privada si Windows lo solicita.
4. Desde `mobile`, reemplaza la IP de ejemplo por la real del PC:

```powershell
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8000 --dart-define=QR_PUBLIC_BASE_URL=http://192.168.1.20:8000
```

En un despliegue público se usa la URL HTTPS del backend. `QR_PUBLIC_BASE_URL` es una variable de compilación del frontend; cambiarla exige recompilar. Si se omite, el enlace usa `API_BASE_URL`.

## API

- `GET /api/vehicles/{id}/qr`: consulta sin cobro; devuelve tarifa/día e `issued=false`, o el mismo pase vigente con `issued=true`.
- `POST /api/vehicles/{id}/qr`: crea/reutiliza el pase diario. La app envía `expected_amount` y `service_date`. Devuelve `charged`, `charge_amount`, `balance_after`, `amount`, `token`, `expires_at` y `transaction_id`.
- `POST /api/wallet/transfers`: `{recipient_email, amount, request_id}`. Devuelve el comprobante del remitente; nunca el saldo del destinatario.
- `GET /p/{token}`: ficha HTML pública del código vigente.
- Flyway aplica V7 al arrancar. No borra las tablas existentes.

## Verificación

Pruebas API con PostgreSQL separado (`*_test`) cubren concurrencia, cambio de día, precio, fondos, doble generación, transferencias opuestas, reintentos, rollback y ficha HTML. Widgets comprueban confirmaciones/cancelaciones, recuperación tras pérdida de respuesta y diseño en móvil/tablet/desktop. El flujo live conecta Flutter con Spring Boot y PostgreSQL. La lectura física con cámaras reales depende de accesibilidad de la red y se valida en los dispositivos del equipo.
