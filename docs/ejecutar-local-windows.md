# Abrir ParkU completo en Windows

Requisitos instalados: Docker Desktop iniciado con contenedores Linux, JDK 21, Flutter estable y Google Chrome.
Java y Flutter deben estar en PATH. No necesitas instalar Maven: se usa el wrapper del repositorio.

Desde PowerShell en la raiz de ParkU:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Start-ParkU.ps1
```

ExecutionPolicy Bypass se aplica unicamente al proceso del lanzador, sin cambiar la politica de Windows.

El lanzador comprueba requisitos y puertos, inicia PostgreSQL con Docker Compose y espera su healthcheck,
resuelve las dependencias de Flutter y abre dos ventanas: backend y frontend.
Espera una respuesta 401 del endpoint protegido de ParkU antes de iniciar Flutter.
El primer arranque puede tardar varios minutos por las descargas de Maven/Flutter.
Chrome se abre cuando termina la compilacion. Frontend: http://127.0.0.1:5173 ; API: http://127.0.0.1:8000.

Si 5173 esta ocupado:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Start-ParkU.ps1 -WebPort 5174
```

El puerto 8000 debe estar libre. No se finalizan otros procesos automaticamente.
Si ya hay una instancia de ParkU, detenla con Ctrl+C antes de volver a iniciar.
Si PostgreSQL no arranca, revisa Docker Desktop y si otra base ocupa el puerto 5432.
Para una base local configurada con otra contrasena, define DB_PASSWORD en esta consola antes de ejecutar el script.
La base debe corresponder a los datos de compose.yaml (parku / usuario parku).

## Cuentas locales

PARKU_DEMO se habilita solo para este backend local, enlazado a 127.0.0.1.
No se borran volumenes ni datos y no se restablecen contrasenas de cuentas existentes.

| Uso | Correo | Contrasena inicial |
|---|---|---|
| Juan | juan.cardona@usantotomas.edu.co | pass123 |
| Ronaldo | ronaldo.mosquera@usantotomas.edu.co | pass123 |
| Taquilla | taquilla@usantotomas.edu.co | caja123 |

El seed actual crea estudiantes y operador, no guardias ni administradores.
Para revisar porteria, usa una cuenta local guard/admin que ya este configurada.
La capacidad del parqueadero debe configurarse por administracion antes de registrar ingresos;
este lanzador no cambia roles, tarifas ni capacidad de una base existente.
No se ejecutan las pruebas del backend sobre esta base: esas pruebas vacian tablas y requieren una BD separada.

## Detener

Pulsa Ctrl+C en las ventanas ParkU - Backend y ParkU - Frontend.
Desde la raiz puedes detener PostgreSQL conservando datos:

```powershell
docker compose stop db
```

Si falla un proceso, su ventana queda abierta para consultar el error.
El lanzador no instala herramientas faltantes. Ejecuta flutter doctor si Flutter no detecta Chrome.

## Alcance de verificacion

GitHub Actions valida sintaxis con Windows PowerShell. El arranque completo, Docker Desktop,
Chrome y las interacciones fisicas se comprueban en el PC donde se ejecute.
