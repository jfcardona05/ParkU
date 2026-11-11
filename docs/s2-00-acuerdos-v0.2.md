# Sprint 2 contrato operativo versión 0.2

Complementa y prevalece sobre la propuesta v0.1 en los puntos siguientes.
Ronaldo autorizó continuar la implementación el 10/11/2026 y confirmó precios iniciales:
**moto 4000 COP, automovil 5000 COP**, modificables por administrador.
Juan conserva la revisión humana de compatibilidad y merge. No se presume su aprobación.

## Reglas de implementación revisables

- Roles `guard` y `admin`; ambos pueden operar portería, solo admin cambia tarifas/capacidad.
  `operador` conserva taquilla. Registro público siempre crea estudiante.
- QR opaco de 256 bits, 120 segundos, regenerar revoca anterior, uso único al confirmar.
- Como supuesto operativo se adopta hora iniciada, mínimo un bloque; administrador puede
  configurar segundos del bloque, mínimo de bloques y precio. La unidad de tiempo no fue
  especificada por Ronaldo ni se presenta como regla oficial de la universidad.
- Cambios de tarifa crean una versión nueva; una estancia conserva la tarifa del ingreso.
- Sin fondos no hay salida, consumo ni descuento. Reintento exitoso con misma clave nunca cobra dos veces.
- No se inventa capacidad: admin debe configurarla antes del primer ingreso; de lo contrario 503.
- `request_id` acepta cadena de 1–100 caracteres, compatible con `UniqueKey().toString()` actual
  de Flutter; se recomienda UUID. Misma clave por operador y mismo cuerpo reproduce recibo.
  Esto reemplaza el requisito de UUID estricto de v0.1.
- Estado físico OUTSIDE/INSIDE; saldo insuficiente es error financiero. entry/exit en JSON.
- Cámara/APK y confirmación universitaria de políticas siguen pendientes.

## Nuevas API administrativas

GET /api/parking/rates (autenticado): tarifas vigentes.
POST /api/admin/parking/rates (admin):
`{"vehicle_type":"moto","amount":4000,"block_seconds":3600,"minimum_blocks":1}`.
Devuelve 201 con `rate` y versión `id`. No modifica estancias existentes.
GET /api/admin/parking/settings (admin) devuelve capacidad (null si no se configuró).
POST /api/admin/parking/settings (admin): `{"capacity":100}`; 100 es ejemplo, no capacidad acordada.
No admite reducir capacidad por debajo de la ocupación actual.

Las ramas son acumulativas por dependencia, con un commit de implementación por tarea y PR
hacia main. Los PR posteriores muestran temporalmente commits anteriores: revisar/mergear
S2-01 → S2-02 → S2-03 → S2-07, sincronizar ramas tras cada merge y comprobar el diff restante.
S2-02 rechaza salida con 503 hasta integrar S2-03; nunca permite una salida gratuita provisional.
No fusionar S2-02 aisladamente como entrega final del flujo. No marcar Done sin prueba funcional.
