import 'package:flutter/material.dart';
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
              'Historial de recargas',
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
          'Recargas presenciales de todos los usuarios y puntos de taquilla. Hora de Colombia · Semana de lunes a domingo.',
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
            label: const Text('Buscar recargas'),
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
                            ? 'Total recargado en el período'
                            : 'Total recargado · usuario filtrado',
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
                        '$range\n${data.count} recargas · ${data.userCount} usuarios',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (data.recharges.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Text(
                      'No hay recargas para los filtros seleccionados.',
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
                        Text(record.userEmail),
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
