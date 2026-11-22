import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../services/api_service.dart';
import '../ui/park_shell.dart';
import '../ui/park_widgets.dart';
import '../ui/park_theme.dart';

class TransferScreen extends StatefulWidget {
  final ApiService apiService;
  const TransferScreen({super.key, required this.apiService});
  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  final _form = GlobalKey<FormState>();
  final _document = TextEditingController();
  String _documentType = 'CC';
  final _amount = TextEditingController();
  late Future<int> _balance;
  bool _busy = false;
  String? _error;
  Map<String, dynamic>? _receipt;
  bool get _pending => widget.apiService.pendingTransfer != null;
  final _money = NumberFormat.decimalPattern('es_CO');

  @override
  void initState() {
    super.initState();
    _balance = widget.apiService.getBalance();
    final draft = widget.apiService.pendingTransfer;
    if (draft != null) {
      _document.text = draft.documentNumber;
      _documentType = draft.documentType;
      _amount.text = draft.amount.toString();
      _error =
          'Hay una transferencia pendiente de confirmación. Reintenta para comprobar su resultado sin enviarla dos veces.';
    }
  }

  @override
  void dispose() {
    _document.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_busy) return;
    if (!_pending) {
      if (!_form.currentState!.validate()) return;
      final document = _document.text.trim();
      final amount = int.parse(_amount.text);
      final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirmar transferencia'),
          content: Text(
            'Enviar ${_money.format(amount)} COP a $_documentType $document desde tu saldo ParkU.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirmar envío'),
            ),
          ],
        ),
      );
      if (accepted != true || !mounted || _busy) return;
      final bytes = List.generate(16, (_) => Random.secure().nextInt(256));
      final key = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      widget.apiService.pendingTransfer = WalletTransferDraft(
        _documentType,
        document,
        amount,
        key,
      );
    }
    final draft = widget.apiService.pendingTransfer!;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await widget.apiService.transfer(
        recipientDocumentType: draft.documentType,
        recipientDocumentNumber: draft.documentNumber,
        amount: draft.amount,
        requestId: draft.requestId,
      );
      widget.apiService.pendingTransfer = null;
      if (mounted) {
        setState(() {
          _receipt = result;
          _balance = widget.apiService.getBalance();
        });
      }
    } catch (error) {
      if (error is ApiException &&
          error.statusCode != null &&
          error.statusCode! < 500) {
        widget.apiService.pendingTransfer = null;
      }
      if (mounted) {
        setState(
          () => _error = _pending
              ? 'No recibimos confirmación. Reintenta la misma transferencia para comprobarla sin duplicarla.'
              : error is ApiException
              ? error.message
              : 'No se pudo realizar la transferencia.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ParkShell(
    api: widget.apiService,
    selected: 2,
    breadcrumb: 'Transferir saldo',
    busy: _busy,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ParkHeading(
          'Tu saldo, compartido.',
          'Envía saldo ParkU a otro usuario por su documento de identidad.',
        ),
        ParkColumns(
          children: [
            ParkCard(
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FutureBuilder<int>(
                      future: _balance,
                      builder: (context, snapshot) => Padding(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: snapshot.hasData
                            ? Text(
                                'Saldo disponible: ${_money.format(snapshot.data)} COP',
                                style: Theme.of(context).textTheme.titleMedium,
                              )
                            : snapshot.hasError
                            ? TextButton(
                                onPressed: () => setState(
                                  () =>
                                      _balance = widget.apiService.getBalance(),
                                ),
                                child: const Text(
                                  'Reintentar consulta de saldo',
                                ),
                              )
                            : const LinearProgressIndicator(),
                      ),
                    ),
                    if (_receipt != null) ...[
                      const ParkBadge('Transferencia realizada', success: true),
                      const SizedBox(height: 24),
                      Text(
                        '${_money.format(_receipt!["amount"])} COP enviados',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      Text('Para: ${_receipt!["recipient_document"]}'),
                      const SizedBox(height: 12),
                      Text(
                        'Referencia: ${_receipt!["transfer_id"]}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Volver a mi saldo'),
                      ),
                    ] else ...[
                      DropdownButtonFormField<String>(
                        initialValue: _documentType,
                        decoration: const InputDecoration(
                          labelText: 'Tipo de documento',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'CC',
                            child: Text('Cédula de ciudadanía'),
                          ),
                          DropdownMenuItem(
                            value: 'TI',
                            child: Text('Tarjeta de identidad'),
                          ),
                        ],
                        onChanged: _busy || _pending
                            ? null
                            : (v) => setState(() => _documentType = v!),
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _document,
                        enabled: !_busy && !_pending,
                        keyboardType: TextInputType.number,
                        textCapitalization: TextCapitalization.none,
                        decoration: const InputDecoration(
                          labelText: 'Documento del destinatario',
                          hintText: 'Número sin puntos ni espacios',
                        ),
                        validator: (value) {
                          final document = value?.trim() ?? '';
                          if (!RegExp(r'^[0-9]{5,15}$').hasMatch(document))
                            return 'Escribe entre 5 y 15 dígitos.';
                          if (document ==
                                  widget
                                      .apiService
                                      .currentUser
                                      ?.documentNumber &&
                              _documentType ==
                                  widget.apiService.currentUser?.documentType)
                            return 'Elige el documento de otro usuario.';
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _amount,
                        enabled: !_busy && !_pending,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Monto (COP)',
                          hintText: 'Ej. 5000',
                        ),
                        validator: (value) {
                          final amount = int.tryParse(value ?? '');
                          return amount == null ||
                                  amount <= 0 ||
                                  amount > 1000000000
                              ? 'Ingresa un monto entre 1 y 1.000.000.000 COP.'
                              : null;
                        },
                      ),
                      const SizedBox(height: 24),
                      if (_error != null) ...[
                        Text(
                          _error!,
                          style: const TextStyle(color: Color(0xFFB3261E)),
                        ),
                        const SizedBox(height: 20),
                      ],
                      FilledButton(
                        onPressed: _busy ? null : _send,
                        child: Text(
                          _busy
                              ? 'Confirmando…'
                              : _pending
                              ? 'Reintentar transferencia'
                              : 'Transferir saldo',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const ParkCard(
              color: ParkColors.yellow,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ParkIcon(Icons.account_balance_wallet_outlined),
                  SizedBox(height: 24),
                  Text(
                    'De tu saldo.\nA su próximo recorrido.',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 28),
                  Text(
                    'El destinatario debe estar registrado en ParkU. Confirma su documento y el importe antes de enviar.',
                  ),
                  SizedBox(height: 20),
                  Text(
                    'La transferencia se registra en el historial de ambas cuentas y no tiene comisión.',
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
