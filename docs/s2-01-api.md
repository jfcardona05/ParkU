# S2-01 QR de vehículo

POST /api/vehicles/7/qr con Bearer del titular → 201:
`{"success":true,"vehicle_id":7,"token":"<opaco>","expires_at":"<UTC>"}`.
POST /api/gate/inspect con Bearer guard/admin y `{"token":"<opaco>"}` → 200:
`{"success":true,"vehicle_id":7,"plate":"ABC123","expires_at":"<UTC>"}`.
Inspeccionar no consume. S2-02 agrega estado físico y consumo transaccional.

Errores: 401 sesión, 403 permiso, 404 vehículo ajeno/inexistente; 422 QR_INVALID,
410 QR_EXPIRED, 409 QR_REVOKED/QR_USED. `message` es legible por Flutter;
`code` identifica errores de QR. No aceptar token demo ni usar QR como sesión.
120 segundos, regeneración serializada revoca QR anterior; hash SHA-256 en BD.
Roles se aprovisionan por operador de BD autorizado; registro público no los asigna.
No se crean cuentas privilegiadas ni contraseñas predeterminadas.

Validación y evidencias se registran en el PR. Revisión humana: Juan.
