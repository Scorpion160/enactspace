import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../models/fee_model.dart';
import '../models/mobile_money_transaction_model.dart';
import '../services/finance_service.dart';

class MobileMoneyPaymentSheet extends StatefulWidget {
  final FinanceService financeService;
  final List<FeeModel> fees;
  final FeeModel initialFee;
  final String Function(String userId) memberName;
  final VoidCallback onChanged;
  final Future<void> Function(String method, List<String> feeIds, int amount)
  onDeclareManually;

  const MobileMoneyPaymentSheet({
    super.key,
    required this.financeService,
    required this.fees,
    required this.initialFee,
    required this.memberName,
    required this.onChanged,
    required this.onDeclareManually,
  });

  @override
  State<MobileMoneyPaymentSheet> createState() =>
      _MobileMoneyPaymentSheetState();
}

class _MobileMoneyPaymentSheetState extends State<MobileMoneyPaymentSheet> {
  final Set<String> _selectedFeeIds = {};
  final TextEditingController _amountController = TextEditingController();
  String _channel = 'wave-senegal';
  bool _busy = false;
  String? _error;
  MobileMoneyTransactionModel? _transaction;

  @override
  void initState() {
    super.initState();
    _selectedFeeIds.add(widget.initialFee.id);
    _amountController.text = _selectedBalance.toString();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  int get _selectedBalance {
    return widget.fees
        .where((fee) => _selectedFeeIds.contains(fee.id))
        .fold<int>(0, (sum, fee) => sum + fee.remainingAmount.round());
  }

  int? get _enteredAmount => int.tryParse(_amountController.text.trim());

  bool get _amountIsValid {
    final amount = _enteredAmount;
    return amount != null && amount > 0 && amount <= _selectedBalance;
  }

  void _setFeeSelected(String feeId, bool selected) {
    final previousBalance = _selectedBalance;
    final previousAmount = _enteredAmount;
    setState(() {
      if (selected) {
        _selectedFeeIds.add(feeId);
      } else {
        _selectedFeeIds.remove(feeId);
      }
      final balance = _selectedBalance;
      if (balance <= 0) {
        _amountController.clear();
      } else if (previousAmount == null ||
          previousAmount <= 0 ||
          previousAmount == previousBalance ||
          previousAmount > balance) {
        _amountController.text = balance.toString();
      }
      _error = null;
    });
  }

  Future<void> _initiatePayment() async {
    if (_selectedFeeIds.isEmpty || !_amountIsValid) {
      setState(() {
        _error =
            'Saisissez un montant compris entre 1 et '
            '${_money(_selectedBalance.toDouble())}.';
      });
      return;
    }
    final amount = _enteredAmount!;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final transaction = await widget.financeService
          .initiateMobileMoneyPayment(
            feeIds: _selectedFeeIds.toList(),
            channel: _channel,
            amount: amount,
            memberId: widget.initialFee.userId,
          );
      if (!mounted) return;
      setState(() => _transaction = transaction);
      final checkoutUrl = transaction.checkoutUrl;
      if (checkoutUrl != null && checkoutUrl.isNotEmpty) {
        final uri = Uri.tryParse(checkoutUrl);
        if (uri == null || uri.scheme != 'https') {
          throw Exception('Lien de paiement invalide.');
        }
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _declareManually() async {
    if (_busy) return;
    if (_selectedFeeIds.isEmpty || !_amountIsValid) {
      setState(() {
        _error =
            'Saisissez un montant compris entre 1 et '
            '${_money(_selectedBalance.toDouble())}.';
      });
      return;
    }
    final method = _channel == 'orange-money-senegal' ? 'orange_money' : 'wave';
    await widget.onDeclareManually(
      method,
      _selectedFeeIds.toList(),
      _enteredAmount!,
    );
  }

  Future<void> _refreshStatus() async {
    final transaction = _transaction;
    if (transaction == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final refreshed = await widget.financeService
          .refreshMobileMoneyTransaction(transaction.transactionId);
      if (!mounted) return;
      setState(() => _transaction = refreshed);
      if (refreshed.isFinal) {
        widget.onChanged();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final transaction = _transaction;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppTheme.enactusYellow,
                    child: Icon(
                      Icons.phone_android_rounded,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Payer par Mobile Money',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        Text(
                          widget.memberName(widget.initialFee.userId),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: Text('Wave'),
                    selected: _channel == 'wave-senegal',
                    onSelected: _busy
                        ? null
                        : (_) => setState(() => _channel = 'wave-senegal'),
                  ),
                  ChoiceChip(
                    label: Text('Orange Money'),
                    selected: _channel == 'orange-money-senegal',
                    onSelected: _busy
                        ? null
                        : (_) =>
                              setState(() => _channel = 'orange-money-senegal'),
                  ),
                ],
              ),
              SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Le bouton « Payer en ligne » ouvre uniquement le checkout sécurisé '
                  'fourni par le prestataire configuré. EnactSpace ne suppose pas qu’un '
                  'lien non documenté peut ouvrir ou préremplir Wave ou Orange Money.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              SizedBox(height: 14),
              ...widget.fees.map((fee) {
                final selected = _selectedFeeIds.contains(fee.id);
                return CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: selected,
                  enabled: !_busy && transaction == null,
                  onChanged: (value) {
                    _setFeeSelected(fee.id, value == true);
                  },
                  title: Text(
                    fee.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text('Reste ${_money(fee.remainingAmount)}'),
                );
              }),
              const Divider(height: 24),
              TextField(
                controller: _amountController,
                enabled: !_busy && transaction == null,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() => _error = null),
                decoration: InputDecoration(
                  labelText: 'Montant à payer',
                  suffixText: 'FCFA',
                  prefixIcon: Icon(Icons.payments_rounded),
                  helperText:
                      'Solde sélectionné : ${_money(_selectedBalance.toDouble())}',
                  errorText:
                      _amountController.text.isNotEmpty && !_amountIsValid
                      ? 'Montant compris entre 1 et $_selectedBalance FCFA.'
                      : null,
                ),
              ),
              if (transaction != null) ...[
                SizedBox(height: 12),
                _TransactionStatusCard(transaction: transaction),
              ],
              if (_error != null) ...[
                SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: Colors.red.shade700)),
              ],
              SizedBox(height: 16),
              if (transaction == null) ...[
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _declareManually,
                    icon: Icon(Icons.receipt_long_rounded),
                    label: Text(
                      _channel == 'orange-money-senegal'
                          ? 'J’ai payé par Orange Money — joindre le reçu'
                          : 'J’ai payé par Wave — joindre le reçu',
                    ),
                  ),
                ),
                SizedBox(height: 10),
              ],
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _busy
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: Text('Fermer'),
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _busy
                          ? null
                          : transaction == null
                          ? _initiatePayment
                          : _refreshStatus,
                      icon: _busy
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              transaction == null
                                  ? Icons.open_in_new_rounded
                                  : Icons.sync_rounded,
                            ),
                      label: Text(
                        transaction == null
                            ? 'Payer en ligne'
                            : 'Vérifier le statut',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TransactionStatusCard extends StatelessWidget {
  final MobileMoneyTransactionModel transaction;

  const _TransactionStatusCard({required this.transaction});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.enactusYellow.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppTheme.enactusYellow.withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        children: [
          Icon(_icon, color: _color),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.statusLabel,
                  style: TextStyle(fontWeight: FontWeight.w900, color: _color),
                ),
                Text(
                  transaction.message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color get _color {
    switch (transaction.status) {
      case 'successful':
        return Colors.green.shade700;
      case 'failed':
      case 'cancelled':
      case 'expired':
        return Colors.red.shade700;
      default:
        return AppTheme.softBlack;
    }
  }

  IconData get _icon {
    switch (transaction.status) {
      case 'successful':
        return Icons.verified_rounded;
      case 'failed':
      case 'cancelled':
      case 'expired':
        return Icons.error_rounded;
      default:
        return Icons.hourglass_top_rounded;
    }
  }
}

String _money(double amount) => '${amount.toStringAsFixed(0)} FCFA';
