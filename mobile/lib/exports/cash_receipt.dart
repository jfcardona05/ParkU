import 'dart:convert';

import 'package:intl/intl.dart';

String cashReceiptHtml(Map<String, dynamic> row) {
  String esc(dynamic value) => const HtmlEscape().convert('${value ?? ""}');
  final money = NumberFormat.decimalPattern('es_CO');
  String amount(String key) => '${money.format(row[key] ?? 0)} COP';
  String date(dynamic value) {
    if (value == null) return '';
    return '${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse('$value').toUtc().subtract(const Duration(hours: 5)))} · Colombia';
  }

  final lines = <String, String>{
    'Día de caja': '${row['business_date']}',
    'Punto': '${row['point_name']}',
    'Operador': '${row['operator_name'] ?? row['operator_id']}',
    'Apertura': date(row['opened_at']),
    'Cierre': date(row['closed_at']),
    'Base inicial': amount('opening_amount'),
    'Recargas registradas': '${row['recharge_count']}',
    'Recaudo en efectivo': amount('recharge_total'),
    'Efectivo esperado': amount('expected_cash'),
    'Efectivo contado': amount('counted_cash'),
    'Base retenida para devueltas': amount('retained_cash'),
    'Efectivo a entregar': amount('remitted_cash'),
    'Diferencia (contado − esperado)': amount('difference'),
    'Observaciones': '${row['notes'] ?? ""}',
  };
  return '''<!doctype html><html lang="es"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>ParkU · Cierre ${esc(row['reference'])}</title>
<style>body{font:16px system-ui;color:#171725;max-width:760px;margin:32px auto;padding:20px}h1{border-bottom:8px solid #ffdb4d;padding-bottom:16px}table{border-collapse:collapse;width:100%}th,td{text-align:left;padding:12px;border-bottom:1px solid #ddd;overflow-wrap:anywhere}th{width:48%}p{overflow-wrap:anywhere}button{padding:12px;background:#ffdb4d;border:0;border-radius:10px}@media print{button{display:none}body{margin:0}}</style></head><body>
<h1>ParkU · Comprobante diario de cierre</h1><p>Referencia: ${esc(row['reference'])}</p><table>${lines.entries.map((e) => '<tr><th>${esc(e.key)}</th><td>${esc(e.value)}</td></tr>').join()}</table>
<p>Base inicial + recaudo = efectivo esperado. Contado − base retenida = efectivo a entregar.</p>
<p>La base retenida queda para la próxima apertura del mismo punto. Este reporte incluye únicamente recargas presenciales de esta caja; no incluye transferencias ni cobros al saldo.</p>
<p>Comprobante interno de control de caja. No es una factura electrónica.</p><button onclick="window.print()">Imprimir / Guardar PDF</button></body></html>''';
}
