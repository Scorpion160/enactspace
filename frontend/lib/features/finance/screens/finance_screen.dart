import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../members/models/member_model.dart';
import '../../members/services/members_service.dart';
import '../models/fee_model.dart';
import '../models/financial_account_model.dart';
import '../models/payment_model.dart';
import '../services/finance_service.dart';

class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key});

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> {
  final FinanceService _financeService = FinanceService();
  final MembersService _membersService = MembersService();

  bool _loading = true;
  String? _error;

  List<MemberModel> _members = [];
  List<FinancialAccountModel> _accounts = [];
  List<FeeModel> _fees = [];
  List<PaymentModel> _payments = [];

  @override
  void initState() {
    super.initState();
    _loadFinance();
  }

  Future<void> _loadFinance() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _membersService.getMembers(),
        _financeService.getAccounts(),
        _financeService.getFees(),
        _financeService.getPayments(),
      ]);

      if (!mounted) return;

      setState(() {
        _members = results[0] as List<MemberModel>;
        _accounts = results[1] as List<FinancialAccountModel>;
        _fees = results[2] as List<FeeModel>;
        _payments = results[3] as List<PaymentModel>;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  MemberModel? _memberById(String userId) {
    try {
      return _members.firstWhere((member) => member.id == userId);
    } catch (_) {
      return null;
    }
  }

  String _memberName(String userId) {
    return _memberById(userId)?.displayName ?? 'Membre inconnu';
  }

  double get _totalDue {
    return _accounts.fold(0, (sum, account) => sum + account.balanceDue);
  }

  double get _totalPaid {
    return _accounts.fold(0, (sum, account) => sum + account.totalPaid);
  }

  double get _pendingPayments {
    return _payments
        .where((payment) => payment.status == 'pending')
        .fold(0, (sum, payment) => sum + payment.amount);
  }

  double get _validatedPayments {
    return _payments
        .where((payment) => payment.status == 'validated')
        .fold(0, (sum, payment) => sum + payment.amount);
  }

  Future<void> _openCreatePaymentDialog() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (context) {
        return CreatePaymentDialog(
          financeService: _financeService,
          members: _members,
        );
      },
    );

    if (created == true) {
      await _loadFinance();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Paiement enregistré avec succès.')),
      );
    }
  }

  Future<void> _openCreateFeeDialog() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (context) {
        return CreateFeeDialog(
          financeService: _financeService,
          members: _members,
        );
      },
    );

    if (created == true) {
      await _loadFinance();

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Frais créé avec succès.')));
    }
  }

  Future<void> _validatePayment(PaymentModel payment) async {
    try {
      await _financeService.validatePayment(payment.id);
      await _loadFinance();

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Paiement validé.')));
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text(e.toString().replaceAll('Exception: ', '')),
        ),
      );
    }
  }

  Future<void> _cancelPayment(PaymentModel payment) async {
    try {
      await _financeService.cancelPayment(payment.id);
      await _loadFinance();

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Paiement annulé.')));
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text(e.toString().replaceAll('Exception: ', '')),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadFinance,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _FinanceHeader(
            totalDue: _totalDue,
            totalPaid: _totalPaid,
            pendingPayments: _pendingPayments,
            validatedPayments: _validatedPayments,
            onRefresh: _loadFinance,
            onCreatePayment: _openCreatePaymentDialog,
            onCreateFee: _openCreateFeeDialog,
          ),
          const SizedBox(height: 22),
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_error != null)
            _ErrorCard(message: _error!, onRetry: _loadFinance)
          else ...[
            _AccountsCard(accounts: _accounts, memberName: _memberName),
            const SizedBox(height: 18),
            _FeesCard(fees: _fees, memberName: _memberName),
            const SizedBox(height: 18),
            _PaymentsCard(
              payments: _payments,
              memberName: _memberName,
              onValidate: _validatePayment,
              onCancel: _cancelPayment,
            ),
          ],
        ],
      ),
    );
  }
}

class _FinanceHeader extends StatelessWidget {
  final double totalDue;
  final double totalPaid;
  final double pendingPayments;
  final double validatedPayments;
  final VoidCallback onRefresh;
  final VoidCallback onCreatePayment;
  final VoidCallback onCreateFee;
  const _FinanceHeader({
    required this.totalDue,
    required this.totalPaid,
    required this.pendingPayments,
    required this.validatedPayments,
    required this.onRefresh,
    required this.onCreatePayment,
    required this.onCreateFee,
  });

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 760;

    final actions = Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        OutlinedButton.icon(
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Actualiser'),
        ),
        ElevatedButton.icon(
          onPressed: onCreateFee,
          icon: const Icon(Icons.receipt_long_rounded),
          label: const Text('Nouveau frais'),
        ),
        ElevatedButton.icon(
          onPressed: onCreatePayment,
          icon: const Icon(Icons.add_card_rounded),
          label: const Text('Nouveau paiement'),
        ),
      ],
    );

    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: AppTheme.softBlack,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          isWide
              ? Row(
                  children: [
                    _HeaderIcon(),
                    const SizedBox(width: 18),
                    const Expanded(child: _HeaderText()),
                    actions,
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _HeaderIcon(),
                        const SizedBox(width: 18),
                        const Expanded(child: _HeaderText()),
                      ],
                    ),
                    const SizedBox(height: 18),
                    actions,
                  ],
                ),
          const SizedBox(height: 22),
          _FinanceStatsGrid(
            totalDue: totalDue,
            totalPaid: totalPaid,
            pendingPayments: pendingPayments,
            validatedPayments: validatedPayments,
          ),
        ],
      ),
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        color: AppTheme.enactusYellow,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Icon(
        Icons.account_balance_wallet_rounded,
        color: AppTheme.softBlack,
        size: 34,
      ),
    );
  }
}

class _HeaderText extends StatelessWidget {
  const _HeaderText();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Finance',
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w900,
          ),
        ),
        SizedBox(height: 6),
        Text(
          'Cotisations, pénalités, paiements et suivi des soldes.',
          style: TextStyle(color: Colors.white70, height: 1.4),
        ),
      ],
    );
  }
}

class _FinanceStatsGrid extends StatelessWidget {
  final double totalDue;
  final double totalPaid;
  final double pendingPayments;
  final double validatedPayments;

  const _FinanceStatsGrid({
    required this.totalDue,
    required this.totalPaid,
    required this.pendingPayments,
    required this.validatedPayments,
  });

  @override
  Widget build(BuildContext context) {
    final stats = [
      _FinanceStatItem('Dette totale', totalDue, Icons.warning_rounded),
      _FinanceStatItem('Total payé', totalPaid, Icons.check_circle_rounded),
      _FinanceStatItem(
        'Paiements attente',
        pendingPayments,
        Icons.pending_rounded,
      ),
      _FinanceStatItem(
        'Paiements validés',
        validatedPayments,
        Icons.verified_rounded,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final count = constraints.maxWidth >= 1000
            ? 4
            : constraints.maxWidth >= 650
            ? 2
            : 1;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: stats.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: count,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 2.6,
          ),
          itemBuilder: (context, index) {
            final stat = stats[index];

            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppTheme.enactusYellow,
                    foregroundColor: AppTheme.softBlack,
                    child: Icon(stat.icon),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _money(stat.amount),
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          stat.label,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _FinanceStatItem {
  final String label;
  final double amount;
  final IconData icon;

  const _FinanceStatItem(this.label, this.amount, this.icon);
}

class _AccountsCard extends StatelessWidget {
  final List<FinancialAccountModel> accounts;
  final String Function(String userId) memberName;

  const _AccountsCard({required this.accounts, required this.memberName});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Comptes membres',
      icon: Icons.people_alt_rounded,
      child: accounts.isEmpty
          ? const _EmptyText('Aucun compte financier.')
          : Column(
              children: accounts.map((account) {
                return ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.person_rounded),
                  ),
                  title: Text(memberName(account.userId)),
                  subtitle: Text('Payé : ${_money(account.totalPaid)}'),
                  trailing: Text(
                    _money(account.balanceDue),
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: account.balanceDue > 0
                          ? Colors.red.shade700
                          : Colors.green.shade700,
                    ),
                  ),
                );
              }).toList(),
            ),
    );
  }
}

class _FeesCard extends StatelessWidget {
  final List<FeeModel> fees;
  final String Function(String userId) memberName;

  const _FeesCard({required this.fees, required this.memberName});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Frais et pénalités',
      icon: Icons.receipt_long_rounded,
      child: fees.isEmpty
          ? const _EmptyText('Aucun frais ou pénalité.')
          : Column(
              children: fees.take(20).map((fee) {
                return ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.receipt_rounded),
                  ),
                  title: Text('${fee.typeLabel} — ${memberName(fee.userId)}'),
                  subtitle: Text('${fee.label} • ${fee.statusLabel}'),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _money(fee.amount),
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      Text(
                        'reste ${_money(fee.remainingAmount)}',
                        style: const TextStyle(color: Colors.black54),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }
}

class _PaymentsCard extends StatelessWidget {
  final List<PaymentModel> payments;
  final String Function(String userId) memberName;
  final ValueChanged<PaymentModel> onValidate;
  final ValueChanged<PaymentModel> onCancel;

  const _PaymentsCard({
    required this.payments,
    required this.memberName,
    required this.onValidate,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Paiements',
      icon: Icons.payments_rounded,
      child: payments.isEmpty
          ? const _EmptyText('Aucun paiement enregistré.')
          : Column(
              children: payments.take(20).map((payment) {
                final isPending = payment.status == 'pending';

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isPending
                        ? Colors.orange.shade100
                        : Colors.green.shade100,
                    child: Icon(
                      isPending
                          ? Icons.pending_rounded
                          : Icons.verified_rounded,
                    ),
                  ),
                  title: Text(memberName(payment.userId)),
                  subtitle: Text(
                    '${payment.methodLabel} • ${payment.statusLabel}'
                    '${payment.reference == null ? '' : ' • ${payment.reference}'}',
                  ),
                  trailing: Wrap(
                    spacing: 6,
                    children: [
                      Text(
                        _money(payment.amount),
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      if (isPending)
                        IconButton(
                          onPressed: () => onValidate(payment),
                          icon: const Icon(Icons.verified_rounded),
                          tooltip: 'Valider',
                        ),
                      if (isPending)
                        IconButton(
                          onPressed: () => onCancel(payment),
                          icon: const Icon(Icons.cancel_rounded),
                          tooltip: 'Annuler',
                          color: Colors.red,
                        ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }
}

class CreateFeeDialog extends StatefulWidget {
  final FinanceService financeService;
  final List<MemberModel> members;

  const CreateFeeDialog({
    super.key,
    required this.financeService,
    required this.members,
  });

  @override
  State<CreateFeeDialog> createState() => _CreateFeeDialogState();
}

class _CreateFeeDialogState extends State<CreateFeeDialog> {
  final _formKey = GlobalKey<FormState>();

  final _labelController = TextEditingController(text: 'Cotisation mensuelle');
  final _amountController = TextEditingController(text: '1000');

  String? _selectedUserId;
  String _type = 'cotisation';
  DateTime? _dueDate = DateTime.now().add(const Duration(days: 7));

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _labelController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
    );

    if (selected == null) return;

    setState(() {
      _dueDate = selected;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedUserId == null) {
      setState(() {
        _error = 'Sélectionnez un membre.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await widget.financeService.createFee(
        userId: _selectedUserId!,
        type: _type,
        label: _labelController.text,
        amount: double.parse(_amountController.text.trim()),
        dueDate: _dueDate,
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  String get _dueDateLabel {
    if (_dueDate == null) return 'Aucune date limite';

    final d = _dueDate!;
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: const Text('Nouveau frais'),
      content: SizedBox(
        width: _dialogWidth(context, 520),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                if (_error != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Text(
                      _error!,
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                  ),
                DropdownButtonFormField<String>(
                  initialValue: _selectedUserId,
                  decoration: const InputDecoration(
                    labelText: 'Membre',
                    prefixIcon: Icon(Icons.person_rounded),
                  ),
                  items: widget.members.map((member) {
                    return DropdownMenuItem(
                      value: member.id,
                      child: Text(member.displayName),
                    );
                  }).toList(),
                  onChanged: _loading
                      ? null
                      : (value) {
                          setState(() {
                            _selectedUserId = value;
                          });
                        },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Sélectionnez un membre.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _type,
                  decoration: const InputDecoration(
                    labelText: 'Type',
                    prefixIcon: Icon(Icons.category_rounded),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'cotisation',
                      child: Text('Cotisation'),
                    ),
                    DropdownMenuItem(
                      value: 'penalite',
                      child: Text('Pénalité'),
                    ),
                    DropdownMenuItem(value: 'event', child: Text('Événement')),
                    DropdownMenuItem(value: 'autre', child: Text('Autre')),
                  ],
                  onChanged: _loading
                      ? null
                      : (value) {
                          if (value == null) return;
                          setState(() {
                            _type = value;
                          });
                        },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _labelController,
                  decoration: const InputDecoration(
                    labelText: 'Libellé',
                    prefixIcon: Icon(Icons.label_rounded),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Le libellé est obligatoire.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Montant',
                    suffixText: 'FCFA',
                    prefixIcon: Icon(Icons.payments_rounded),
                  ),
                  validator: (value) {
                    final amount = double.tryParse(value ?? '');
                    if (amount == null || amount <= 0) {
                      return 'Montant invalide.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.event_rounded),
                    title: const Text('Date limite'),
                    subtitle: Text(_dueDateLabel),
                    trailing: Wrap(
                      spacing: 8,
                      children: [
                        TextButton(
                          onPressed: _loading ? null : _pickDueDate,
                          child: const Text('Choisir'),
                        ),
                        TextButton(
                          onPressed: _loading
                              ? null
                              : () {
                                  setState(() {
                                    _dueDate = null;
                                  });
                                },
                          child: const Text('Aucune'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(false),
          child: const Text('Annuler'),
        ),
        ElevatedButton.icon(
          onPressed: _loading ? null : _submit,
          icon: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.save_rounded),
          label: Text(_loading ? 'Création...' : 'Créer'),
        ),
      ],
    );
  }
}

class CreatePaymentDialog extends StatefulWidget {
  final FinanceService financeService;
  final List<MemberModel> members;

  const CreatePaymentDialog({
    super.key,
    required this.financeService,
    required this.members,
  });

  @override
  State<CreatePaymentDialog> createState() => _CreatePaymentDialogState();
}

class _CreatePaymentDialogState extends State<CreatePaymentDialog> {
  final _formKey = GlobalKey<FormState>();

  final _amountController = TextEditingController();
  final _referenceController = TextEditingController();
  final _proofUrlController = TextEditingController();

  String? _selectedUserId;
  String _method = 'cash';

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _amountController.dispose();
    _referenceController.dispose();
    _proofUrlController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedUserId == null) {
      setState(() {
        _error = 'Sélectionnez un membre.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await widget.financeService.createPayment(
        userId: _selectedUserId!,
        amount: double.parse(_amountController.text.trim()),
        method: _method,
        reference: _referenceController.text.trim().isEmpty
            ? null
            : _referenceController.text.trim(),
        proofUrl: _proofUrlController.text.trim().isEmpty
            ? null
            : _proofUrlController.text.trim(),
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: const Text('Nouveau paiement'),
      content: SizedBox(
        width: _dialogWidth(context, 520),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                if (_error != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Text(
                      _error!,
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                  ),
                DropdownButtonFormField<String>(
                  initialValue: _selectedUserId,
                  decoration: const InputDecoration(
                    labelText: 'Membre',
                    prefixIcon: Icon(Icons.person_rounded),
                  ),
                  items: widget.members.map((member) {
                    return DropdownMenuItem(
                      value: member.id,
                      child: Text(member.displayName),
                    );
                  }).toList(),
                  onChanged: _loading
                      ? null
                      : (value) {
                          setState(() {
                            _selectedUserId = value;
                          });
                        },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Sélectionnez un membre.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Montant',
                    suffixText: 'FCFA',
                    prefixIcon: Icon(Icons.payments_rounded),
                  ),
                  validator: (value) {
                    final amount = double.tryParse(value ?? '');
                    if (amount == null || amount <= 0) {
                      return 'Montant invalide.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _method,
                  decoration: const InputDecoration(
                    labelText: 'Méthode',
                    prefixIcon: Icon(Icons.account_balance_wallet_rounded),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'cash', child: Text('Espèces')),
                    DropdownMenuItem(value: 'wave', child: Text('Wave')),
                    DropdownMenuItem(
                      value: 'orange_money',
                      child: Text('Orange Money'),
                    ),
                    DropdownMenuItem(value: 'bank', child: Text('Banque')),
                  ],
                  onChanged: _loading
                      ? null
                      : (value) {
                          if (value == null) return;
                          setState(() {
                            _method = value;
                          });
                        },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _referenceController,
                  decoration: const InputDecoration(
                    labelText: 'Référence',
                    prefixIcon: Icon(Icons.tag_rounded),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _proofUrlController,
                  decoration: const InputDecoration(
                    labelText: 'Lien de preuve',
                    prefixIcon: Icon(Icons.link_rounded),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(false),
          child: const Text('Annuler'),
        ),
        ElevatedButton.icon(
          onPressed: _loading ? null : _submit,
          icon: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.save_rounded),
          label: Text(_loading ? 'Enregistrement...' : 'Enregistrer'),
        ),
      ],
    );
  }
}

double _dialogWidth(BuildContext context, double maxWidth) {
  return (MediaQuery.sizeOf(context).width - 32).clamp(280.0, maxWidth);
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Row(
              children: [
                Icon(icon),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 26),
            child,
          ],
        ),
      ),
    );
  }
}

class _EmptyText extends StatelessWidget {
  final String text;

  const _EmptyText(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Text(text, style: const TextStyle(color: Colors.black54)),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: Colors.red.shade600,
              size: 44,
            ),
            const SizedBox(height: 12),
            const Text(
              'Erreur de chargement',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}

String _money(double value) {
  final rounded = value.round().toString();
  final buffer = StringBuffer();

  for (int i = 0; i < rounded.length; i++) {
    final reverseIndex = rounded.length - i;
    buffer.write(rounded[i]);

    if (reverseIndex > 1 && reverseIndex % 3 == 1) {
      buffer.write(' ');
    }
  }

  return '${buffer.toString()} FCFA';
}
