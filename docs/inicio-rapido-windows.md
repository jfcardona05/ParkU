# Inicio rápido en Windows

Requisitos: Docker Desktop con Compose v2 y soporte de `--wait`, Java 21, Flutter con soporte web y Google Chrome. Docker, Java y Flutter deben estar instalados antes de usar el archivo.

1. Abre Docker Desktop y espera a que indique **Engine running**.
2. Haz doble clic en `iniciar-parku.cmd`, en la raíz del repositorio junto a `compose.yaml`.
3. Espera: primero se inicia PostgreSQL y se verifica `healthy`, después se abre el backend y finalmente Flutter abre Chrome. La primera compilación puede tardar varios minutos.
4. Mantén Docker y las ventanas **ParkU - Backend** y **ParkU - Frontend** abiertas. No ejecutes el archivo otra vez mientras esté funcionando.

El script usa la carpeta donde está guardado, por lo que funciona también con rutas que contienen espacios. Comprueba las herramientas y Docker antes de arrancar y se detiene si el puerto 8000 ya está ocupado. Si hay un error, muestra el motivo y mantiene visible el mensaje. Si el backend no arranca en cinco minutos, revisa su ventana: no se abre Flutter y el backend no se cierra automáticamente.

## Configuración local

Se respetan las variables de entorno existentes. Cuando faltan, se usan `DB_URL=jdbc:postgresql://127.0.0.1:5432/parku`, `DB_USER=parku`, `DB_PASSWORD=parku_local` y `PARKU_DEMO=true`. Esto habilita cuentas de demostración exclusivamente para desarrollo local; no uses este lanzador en un despliegue público.

Se utiliza `JAVA_HOME` si apunta a un ejecutable existente. Si no está configurado o es inválido, se busca un JDK 21 en `%ProgramFiles%\Eclipse Adoptium\jdk-21*`; si no se encuentra, se usa Java de PATH. La versión utilizada aparece en pantalla y debe ser Java 21. El frontend se conecta a `http://localhost:8000`.

## Detener y actualizar

Para detener la aplicación, pulsa `Ctrl+C` en cada ventana del backend y Flutter y confirma si Windows lo solicita. Para detener también PostgreSQL, abre una terminal en la raíz y ejecuta `docker compose stop db`. Los datos se conservan; el lanzador no elimina volúmenes.

Después de que el PR esté integrado en `main`, actualiza tu copia clonada con `git pull origin main`. No necesitas descargar otro ZIP.

## Comprobación manual en Windows

- Con Docker cerrado: debe pedir abrir Docker y detenerse.
- Con Docker listo: debe esperar PostgreSQL y abrir backend y Flutter, en ese orden.
- Con ParkU ya ejecutándose: debe advertir que el puerto 8000 está ocupado.
- Probar desde una ruta con espacios y entrar con una cuenta demo.

El archivo se revisó estáticamente. La ejecución completa por doble clic requiere validación en Windows.
