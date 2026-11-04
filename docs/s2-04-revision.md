# S2-04 · Adelanto Flutter para revisión

Desde Mis Vehículos → Mostrar QR. Sin API acordada se informa indisponibilidad; nunca se inventa autorización. Demo explícita: `flutter run -d chrome --dart-define=PARKU_QR_DEMO=true`. El QR de demostración no sirve para acceso real.

La fuente inyectable permite probar carga, error, caducidad y rechazo de un vehículo incorrecto. El QR desaparece al vencer; se puede regenerar. No se escribe en backend ni se almacenan tokens.

Pendiente con Ronaldo: confirmar contrato S2-00 y conectar un adaptador real a S2-01 con autenticación/propiedad del lado servidor. Revisar antes de aprobar; este avance no cierra el issue #21.
