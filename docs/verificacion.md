# Verificación local

Comprobaciones ejecutadas el 28 de octubre de 2026 con Java 21, PostgreSQL 17, Flutter 3.47.8 y Dart 3.13.7:

| Comprobación | Resultado |
|---|---|
| Backend: pruebas HTTP sobre base parku_test independiente | 8 aprobadas, 0 fallos |
| Backend: formato Spotless | Aprobado |
| Flutter: análisis estático | Sin incidencias |
| Flutter: formato lib/test | Aprobado |
| Flutter: pruebas de cliente HTTP y formulario de login | 7 aprobadas |
| Flutter: integración real con API Spring Boot y PostgreSQL demo | 1 aprobada |
| Flutter: compilación web | Aprobada |

La prueba real Flutter creó una cuenta y un vehículo, inició sesión como operador, registró una recarga de 10000 COP y verificó saldo e historial desde la cuenta beneficiaria.

Las carpetas Android están generadas y el permiso de Internet está configurado. No se compiló ni probó un APK porque no hay SDK Android disponible en el entorno. La compilación web verifica Flutter, pero no acredita la ejecución en un dispositivo Android.

La ejecución de GitHub Actions y las aprobaciones humanas se verifican por separado en los PR. Este informe no certifica movimientos del tablero ni revisiones que todavía no hayan ocurrido.