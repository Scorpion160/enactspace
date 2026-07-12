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

  const MobileMoneyPaymentSheet({
    super.key,
    required this.financeService,
    required this.fees,
    required this.initialFee,
    required this.memberName,
    required this.onChanged,
  });

  @override
  State<MobileMoneyPaymentSheet> createState() =>
      _MobileMoneyPaymentSheetState();
}

class _MobileMoneyPaymentSheetState extends State<MobileMoneyPaymentSheet> {
  final Set<String> _selectedFeeIds = {};
  String _channel = 'wave-senegal';
  bool _busy = false;
  String? _error;
  MobileMoneyTransactionModel? _transaction;

  @override
  void initState() {
    super.initState();
    _selectedFeeIds.add(widget.initialFee.id);
  }

  int get _amount {
    return widget.fees
        .where((fee) => _selectedFeeIds.contains(fee.id))
        .fold<int>(0, (sum, fee) => sum + fee.remainingAmount.round());
  }

  Future<void> _initiatePayment() async {
    if (_selectedFeeIds.isEmpty || _amount <= 0) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final transaction = await widget.financeService
          .initiateMobileMoneyPayment(
            feeIds: _selectedFeeIds.toList(),
            channel: _channel,
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
                  const CircleAvatar(
                    backgroundColor: AppTheme.enactusYellow,
                    child: Icon(
                      Icons.phone_android_rounded,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(width: 12),
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
                          style: const TextStyle(color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Wave'),
                    selected: _channel == 'wave-senegal',
                    onSelected: _busy
                        ? null
                        : (_) => setState(() => _channel = 'wave-senegal'),
                  ),
                  ChoiceChip(
                    label: const Text('Orange Money'),
                    selected: _channel == 'orange-money-senegal',
                    onSelected: _busy
                        ? null
                        : (_) =>
                              setState(() => _channel = 'orange-money-senegal'),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ...widget.fees.map((fee) {
                final selected = _selectedFeeIds.contains(fee.id);
                return CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: selected,
                  enabled: !_busy && transaction == null,
                  onChanged: (value) {
                    setState(() {
                      if (value == true) {
                        _selectedFeeIds.add(fee.id);
                      } else {
                        _selectedFeeIds.remove(fee.id);
                      }
                    });
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
              Row(
                children: [
                  const Text('Total'),
                  const Spacer(),
                  Text(
                    _money(_amount.toDouble()),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              if (transaction != null) ...[
                const SizedBox(height: 12),
                _TransactionStatusCard(transaction: transaction),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: Colors.red.shade700)),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _busy
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text('Fermer'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _busy
                          ? null
                          : transaction == null
                          ? _initiatePayment
                          : _refreshStatus,
                      icon: _busy
                          ? const SizedBox(
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
                        transaction == null ? 'Payer' : 'Verifier',
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
          const SizedBox(width: 10),
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
