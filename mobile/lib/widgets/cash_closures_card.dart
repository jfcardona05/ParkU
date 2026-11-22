import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/api_service.dart';
import '../exports/cash_receipt.dart';
import '../exports/download_receipt.dart';
import '../ui/park_widgets.dart';
import '../ui/park_theme.dart';

class CashClosuresCard extends StatefulWidget {
  final ApiService api;
  const CashClosuresCard({super.key, required this.api});
  @override
  State<CashClosuresCard> createState() => _CashClosuresCardState();
}

class _CashClosuresCardState extends State<CashClosuresCard> {
  final _money = NumberFormat.decimalPattern('es_CO');
  DateTime? _date;
  int _page = 0;
  late Future<Map<String, dynamic>> _data;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _data = widget.api.request(
      'GET',
      '/api/cash/history?page=$_page${_date == null ? '' : '&date=${DateFormat('yyyy-MM-dd').format(_date!)}'}',
    );
  }

  void _refresh() {
    setState(() {
      _page = 0;
      _load();
    });
  }

  Future<void> _chooseDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _date ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (selected != null && mounted) {
      setState(() {
        _date = selected;
        _page = 0;
        _load();
      });
    }
  }

  Future<void> _receipt(Map<String, dynamic> row) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Comprobante diario de cierre'),
        scrollable: true,
        content: SizedBox(
          width: 560,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableText(
                'Referencia: ${row['reference']}\nDía de caja: ${row['business_date']}\nPunto: ${row['point_name']}\nOperador: ${row['operator_name']}',
              ),
              const SizedBox(height: 20),
              for (final field in {
                'opening_amount': 'Base inicial',
                'recharge_total': 'Recaudo en efectivo',
                'expected_cash': 'Efectivo esperado',
                'counted_cash': 'Efectivo contado',
                'retained_cash': 'Base para devueltas',
                'remitted_cash': 'Efectivo a entregar',
                'difference': 'Diferencia',
              }.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    '${field.value}: ${_money.format(row[field.key])} COP',
                  ),
                ),
              Text(
                'Ingresos: ${row['recharge_count']}\nObservaciones: ${row['notes'] ?? ""}',
              ),
              const SizedBox(height: 12),
              const Text(
                'Comprobante interno de caja. No es una factura electrónica.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Volver'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.download_outlined),
            onPressed: () async {
              final saved = await downloadCashReceipt(
                cashReceiptHtml(row),
                'ParkU-cierre-${row['business_date']}-${row['id']}.html',
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      saved
                          ? 'Comprobante descargado. Ábrelo para imprimir o guardar como PDF.'
                          : 'La descarga está disponible en ParkU web desde Chrome.',
                    ),
                  ),
                );
              }
            },
            label: const Text('Descargar comprobante'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ParkCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'Cierres de caja',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            TextButton.icon(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Actualizar cierres'),
            ),
          ],
        ),
        const Text(
          'Comprobantes definitivos por día, punto y operador. Incluyen la base reservada para la siguiente apertura.',
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: ParkColors.ink),
              onPressed: _chooseDate,
              icon: const Icon(Icons.calendar_today_outlined),
              label: Text(
                _date == null
                    ? 'Filtrar día de caja'
                    : DateFormat('dd/MM/yyyy').format(_date!),
              ),
            ),
            if (_date != null)
              TextButton(
                onPressed: () {
                  _date = null;
                  _refresh();
                },
                child: const Text('Ver todos los cierres'),
              ),
          ],
        ),
        const SizedBox(height: 16),
        FutureBuilder<Map<String, dynamic>>(
          future: _data,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const LinearProgressIndicator();
            }
            if (snapshot.hasError) {
              return ParkNotice('${snapshot.error}', retry: _refresh);
            }
            final rows = (snapshot.requireData['sessions'] as List)
                .cast<Map<String, dynamic>>();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (rows.isEmpty)
                  const Text('No hay cierres registrados para este filtro.'),
                for (final row in rows)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: ParkCard(
                      color: ParkColors.background,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${row['business_date']} · ${row['point_name']}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text('Operador: ${row['operator_name']}'),
                          Text(
                            'Recaudo: ${_money.format(row['recharge_total'])} COP',
                          ),
                          Text(
                            'A entregar: ${_money.format(row['remitted_cash'])} COP',
                          ),
                          Text(
                            'Base retenida: ${_money.format(row['retained_cash'])} COP',
                          ),
                          Text(
                            'Diferencia: ${_money.format(row['difference'])} COP',
                          ),
                          TextButton.icon(
                            onPressed: () => _receipt(row),
                            icon: const Icon(Icons.receipt_long_outlined),
                            label: const Text('Ver comprobante de cierre'),
                          ),
                        ],
                      ),
                    ),
                  ),
                Wrap(
                  spacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    TextButton(
                      onPressed: _page > 0
                          ? () => setState(() {
                              _page--;
                              _load();
                            })
                          : null,
                      child: const Text('Cierres anteriores'),
                    ),
                    Text('Página ${_page + 1}'),
                    TextButton(
                      onPressed: snapshot.requireData['has_more'] == true
                          ? () => setState(() {
                              _page++;
                              _load();
                            })
                          : null,
                      child: const Text('Más cierres'),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ],
    ),
  );
}
