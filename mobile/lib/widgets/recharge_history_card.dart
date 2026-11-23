import 'package:flutter/material.dart';

import 'visitor_receipt.dart';

import 'package:intl/intl.dart';

import '../models/recharge_history.dart';
import '../services/api_service.dart';
import '../ui/park_theme.dart';
import '../ui/park_widgets.dart';

class RechargeHistoryCard extends StatefulWidget {
  final ApiService api;
  final int refreshVersion;
  const RechargeHistoryCard({
    super.key,
    required this.api,
    this.refreshVersion = 0,
  });
  @override
  State<RechargeHistoryCard> createState() => _RechargeHistoryCardState();
}

class _RechargeHistoryCardState extends State<RechargeHistoryCard> {
  final _searchController = TextEditingController();
  final _money = NumberFormat.decimalPattern('es_CO');
  String _period = 'day';
  String _search = '';
  int _page = 0;
  late DateTime _date;
  late Future<RechargeHistoryPage> _history;
  String get _dateKey => DateFormat('yyyy-MM-dd').format(_date);
  @override
  void initState() {
    super.initState();
    final now = DateTime.now().toUtc().subtract(const Duration(hours: 5));
    _date = DateTime(now.year, now.month, now.day);
    _load();
  }

  @override
  void didUpdateWidget(covariant RechargeHistoryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshVersion != widget.refreshVersion ||
        oldWidget.api != widget.api) {
      _page = 0;
      _load();
    }
  }

  void _load() {
    _history = widget.api.getRechargeHistory(
      period: _period,
      date: _dateKey,
      search: _search,
      page: _page,
    );
  }

  void _refresh() {
    setState(() {
      _page = 0;
      _load();
    });
  }

  void _applySearch() {
    setState(() {
      _search = _searchController.text.trim();
      _page = 0;
      _load();
    });
  }

  Future<void> _chooseDate() async {
    final chosen = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100, 12, 31),
      helpText: 'Fecha del período a consultar',
      cancelText: 'Cancelar',
      confirmText: 'Consultar',
    );
    if (chosen == null || !mounted) return;
    setState(() {
      _date = chosen;
      _page = 0;
      _load();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Widget _metric(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) => ParkCard(
    color: ParkColors.background,
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 24),
        const SizedBox(height: 12),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: Theme.of(context).textTheme.titleLarge),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => ParkCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            Text(
              'Historial de ingresos',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            TextButton.icon(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Actualizar historial'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Recargas de usuarios y pases diarios de visitantes, en un mismo registro. Hora de Colombia · Semana de lunes a domingo.',
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final period in {
              'day': 'Día',
              'week': 'Semana',
              'month': 'Mes',
            }.entries)
              ChoiceChip(
                label: Text(period.value),
                selected: _period == period.key,
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      _period = period.key;
                      _page = 0;
                      _load();
                    });
                  }
                },
              ),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: ParkColors.ink),
              onPressed: _chooseDate,
              icon: const Icon(Icons.calendar_today_outlined),
              label: Text('Fecha: ${DateFormat('dd/MM/yyyy').format(_date)}'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _searchController,
          maxLength: 200,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _applySearch(),
          decoration: InputDecoration(
            labelText: 'Nombre o correo del usuario',
            counterText: '',
            suffixIcon: IconButton(
              tooltip: 'Limpiar búsqueda',
              onPressed: () {
                _searchController.clear();
                _applySearch();
              },
              icon: const Icon(Icons.clear),
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _applySearch,
            icon: const Icon(Icons.search),
            label: const Text('Buscar ingresos'),
          ),
        ),
        const SizedBox(height: 12),
        FutureBuilder<RechargeHistoryPage>(
          future: _history,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError) {
              return ParkNotice(
                snapshot.error is ApiException
                    ? (snapshot.error as ApiException).message
                    : 'No se pudo consultar el historial de recargas.',
                retry: _refresh,
              );
            }
            final data = snapshot.requireData;
            final range =
                '${DateFormat('dd/MM/yyyy').format(DateTime.parse(data.from))} — ${DateFormat('dd/MM/yyyy').format(DateTime.parse(data.through))}';
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ParkCard(
                  color: ParkColors.yellow,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _search.isEmpty
                            ? 'Total recaudado en el período'
                            : 'Total recaudado · usuario filtrado',
                      ),
                      const SizedBox(height: 8),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '\$${_money.format(data.totalAmount)} COP',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$range\n${data.count} ingresos · ${data.userCount} destinatarios',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ParkColumns(
                  breakpoint: 600,
                  gap: 12,
                  children: [
                    _metric(
                      context,
                      Icons.receipt_long_outlined,
                      'Ingresos registrados',
                      '${data.count}',
                    ),
                    _metric(
                      context,
                      Icons.people_outline,
                      'Destinatarios atendidos',
                      '${data.userCount}',
                    ),
                    _metric(
                      context,
                      Icons.analytics_outlined,
                      'Promedio por ingreso',
                      data.count == 0
                          ? 'Sin ingresos'
                          : '\$${_money.format(data.totalAmount / data.count)} COP',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Indicadores del período y búsqueda seleccionados, incluyendo todas las páginas. Incluyen pases de visitante pagados en efectivo. No incluyen transferencias ni descuentos del saldo.',
                  style: TextStyle(fontSize: 12, color: ParkColors.muted),
                ),
                const SizedBox(height: 16),
                if (data.recharges.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Text(
                      'No hay ingresos para los filtros seleccionados.',
                    ),
                  ),
                for (final record in data.recharges) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                record.userName,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '+\$${_money.format(record.amount)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: ParkColors.green,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          record.incomeType == 'PASE_DIARIO_VISITANTE'
                              ? 'Pase diario visitante · ${record.plate}'
                              : 'Recarga usuario · ${record.userEmail}',
                        ),
                        if (record.visitorPassId != null)
                          TextButton.icon(
                            icon: const Icon(Icons.print_outlined),
                            label: const Text('Reimprimir pase'),
                            onPressed: () async {
                              try {
                                final data = await widget.api.request(
                                  'GET',
                                  '/api/admin/visitor-passes/${record.visitorPassId}',
                                );
                                if (!context.mounted) return;
                                await showDialog<void>(
                                  context: context,
                                  builder: (ctx) => Dialog(
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 520,
                                      ),
                                      child: SingleChildScrollView(
                                        child: Column(
                                          children: [
                                            Align(
                                              alignment: Alignment.centerRight,
                                              child: IconButton(
                                                onPressed: () =>
                                                    Navigator.pop(ctx),
                                                icon: const Icon(Icons.close),
                                              ),
                                            ),
                                            VisitorReceipt(
                                              api: widget.api,
                                              receipt:
                                                  data['pass']
                                                      as Map<String, dynamic>,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(e.toString())),
                                  );
                                }
                              }
                            },
                          ),
                        const SizedBox(height: 8),
                        Text(
                          '${DateFormat('dd/MM/yyyy · HH:mm').format(record.createdAt.subtract(const Duration(hours: 5)))} · Colombia',
                        ),
                        Text('Operador: ${record.operatorName}'),
                        Text('Punto: ${record.pointName}'),
                        const SizedBox(height: 4),
                        SelectableText(
                          'Referencia: ${record.reference}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                ],
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: ParkColors.ink,
                      ),
                      onPressed: _page > 0
                          ? () {
                              setState(() {
                                _page--;
                                _load();
                              });
                            }
                          : null,
                      child: const Text('Anterior'),
                    ),
                    Text('Página ${_page + 1}'),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: ParkColors.ink,
                      ),
                      onPressed: data.hasMore
                          ? () {
                              setState(() {
                                _page++;
                                _load();
                              });
                            }
                          : null,
                      child: const Text('Siguiente'),
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
