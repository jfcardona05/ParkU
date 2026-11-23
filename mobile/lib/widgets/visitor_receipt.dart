import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart';

import '../services/api_service.dart';
import '../exports/download_receipt.dart';
import '../ui/park_widgets.dart';

class VisitorReceipt extends StatefulWidget {
  final ApiService api;
  final Map<String, dynamic> receipt;
  const VisitorReceipt({super.key, required this.api, required this.receipt});
  @override
  State<VisitorReceipt> createState() => _VisitorReceiptState();
}

class _VisitorReceiptState extends State<VisitorReceipt> {
  bool _busy = false;
  String? _error;
  Future<void> _print() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final url = widget.api.qrScanUrl(widget.receipt['token'] as String);
      final bytes = await QrPainter(
        data: url,
        version: QrVersions.auto,
        eyeStyle: const QrEyeStyle(
          eyeShape: QrEyeShape.square,
          color: Colors.black,
        ),
        dataModuleStyle: const QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.square,
          color: Colors.black,
        ),
        gapless: true,
      ).toImageData(800, format: ui.ImageByteFormat.png);
      if (bytes == null) throw const ApiException('No se pudo preparar el QR.');
      final row = widget.receipt;
      String esc(dynamic x) => const HtmlEscape().convert('${x ?? ''}');
      final money = NumberFormat.decimalPattern('es_CO').format(row['amount']);
      final html =
          '''<!doctype html><html lang="es"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>ParkU · Pase diario</title><style>*{box-sizing:border-box}body{margin:32px auto;padding:24px;max-width:520px;background:#f7f7f4;color:#171725;font:16px system-ui}article{padding:28px;border-radius:24px;background:white;border-top:10px solid #ffdb4d}h1{font-size:30px}img{width:260px;max-width:100%;display:block;margin:24px auto}dt{font-size:13px;color:#666;margin-top:16px}dd{margin:4px 0;overflow-wrap:anywhere}button{padding:14px;background:#ffdb4d;border:0;border-radius:12px}@media print{body{margin:0;background:white}button{display:none}}</style></head><body><article><strong>ParkU · Pase diario visitante</strong><h1>${esc(row['plate'])}</h1><p>Pagado en efectivo · $money COP</p><img alt="QR del pase" src="data:image/png;base64,${base64Encode(bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes))}"><dl><dt>Visitante</dt><dd>${esc(row['visitor_name'])}</dd><dt>Vehículo</dt><dd>${row['vehicle_type'] == 'moto' ? 'Moto' : 'Automóvil'}</dd><dt>Día de validez · Colombia</dt><dd>${esc(row['service_date'])} · Hasta las 23:59</dd><dt>Punto de pago</dt><dd>${esc(row['point_name'])}</dd><dt>Referencia</dt><dd>${esc(row['reference'])}</dd></dl><p>Entrega este comprobante a portería para registrar ingreso y salida. El pase ya está pagado.</p><p>Comprobante de pago. No es factura electrónica.</p><button onclick="window.print()">Imprimir / Guardar PDF</button></article></body></html>''';
      final ok = await downloadCashReceipt(
        html,
        'ParkU-pase-${row['plate']}-${row['service_date']}.html',
      );
      if (!ok) {
        throw const ApiException(
          'La impresión está disponible en la versión web.',
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Abre el comprobante descargado y pulsa Imprimir / Guardar PDF.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final row = widget.receipt;
    return Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: ParkCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const ParkBadge('Pase diario visitante · Pagado', success: true),
              const SizedBox(height: 20),
              Text(
                '${row['plate']}',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              Text(
                '${row['visitor_name']} · ${row['vehicle_type'] == 'moto' ? 'Moto' : 'Automóvil'}',
              ),
              const SizedBox(height: 16),
              Center(
                child: QrImageView(
                  data: widget.api.qrScanUrl(row['token'] as String),
                  size: 220,
                  backgroundColor: Colors.white,
                ),
              ),
              Text(
                'Recibido: ${NumberFormat.decimalPattern('es_CO').format(row['amount'])} COP',
              ),
              Text('Válido: ${row['service_date']} · Colombia'),
              Text('Referencia: ${row['reference']}'),
              const SizedBox(height: 16),
              if (_error != null) ParkNotice(_error!),
              FilledButton.icon(
                onPressed: _busy ? null : _print,
                icon: const Icon(Icons.print_outlined),
                label: Text(_busy ? 'Preparando…' : 'Descargar para imprimir'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
