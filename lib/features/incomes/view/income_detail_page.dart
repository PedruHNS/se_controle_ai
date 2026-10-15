import 'package:flutter/material.dart';
import 'package:signals/signals_flutter.dart';

import '../../../core/di/injector.dart';
import '../../../core/shared/view_state.dart';
import '../../../core/shared/widgets/amount_history_card.dart';
import '../../../core/shared/widgets/failure_card_widget.dart';
import '../../../core/shared/widgets/state_transition.dart';
import '../../../core/utils/money_utils.dart';
import '../../../core/utils/month_utils.dart';
import '../../../data/models/income_model.dart';
import '../controller/income_detail_controller.dart';
import '../widgets/income_amount_dialog.dart';
import '../widgets/income_closure_dialog.dart';

/// Um ganho: valor vigente, histórico e as quatro operações.
class IncomeDetailPage extends StatefulWidget {
  final IncomeModel income;
  const IncomeDetailPage({required this.income, super.key});

  @override
  State<IncomeDetailPage> createState() => _IncomeDetailPageState();
}

class _IncomeDetailPageState extends State<IncomeDetailPage> {
  final _controller = getIt<IncomeDetailController>();

  @override
  void initState() {
    super.initState();
    _controller.start(widget.income);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _confirmDelete(IncomeModel income) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir ganho'),
        content: Text(
          'Apaga "${income.description}" e todo o histórico, como se nunca '
          'tivesse existido. Para registrar que você parou de receber, use '
          'Encerrar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final failure = await _controller.delete();

    if (!mounted) return;

    if (failure != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure.message)));
      return;
    }

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ganho'), centerTitle: true),
      body: SignalBuilder(
        builder: (context) {
          final state = _controller.state.value;

          return StateTransition(
            stateKey: state.runtimeType,
            child: switch (state) {
              Loading() => const Center(child: CircularProgressIndicator()),
              Failed(failure: final failure) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: FailureCardWidget(
                    failure: failure,
                    onRetry: _controller.refresh,
                  ),
                ),
              ),
              Loaded(data: final income) => _IncomeDetail(
                income: income,
                working: _controller.working.value,
                onRefresh: _controller.refresh,
                onAdjust: () => showIncomeAmountDialog(
                  context,
                  controller: _controller,
                  income: income,
                  mode: IncomeAmountMode.adjust,
                ),
                onCorrect: () => showIncomeAmountDialog(
                  context,
                  controller: _controller,
                  income: income,
                  mode: IncomeAmountMode.correct,
                ),
                onClose: () => showIncomeClosureDialog(
                  context,
                  controller: _controller,
                  income: income,
                ),
                onDelete: () => _confirmDelete(income),
              ),
            },
          );
        },
      ),
    );
  }
}

class _IncomeDetail extends StatelessWidget {
  const _IncomeDetail({
    required this.income,
    required this.working,
    required this.onRefresh,
    required this.onAdjust,
    required this.onCorrect,
    required this.onClose,
    required this.onDelete,
  });

  final IncomeModel income;
  final bool working;
  final Future<void> Function() onRefresh;
  final VoidCallback onAdjust;
  final VoidCallback onCorrect;
  final VoidCallback onClose;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Ter data de fim é o que decide se as operações de dinheiro ainda existem
    // (GAN-08). Não é o mesmo que "não entra mais": o ganho de mês único nasce
    // com `endMonth` e ainda entra no mês dele.
    final closed = income.endMonth != null;

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(income.description, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    MoneyUtils.format(income.amountCents),
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    closed
                        ? 'Encerrado em ${MonthUtils.label(income.endMonth!)}'
                        : income.recurring
                        ? 'Recorrente desde ${MonthUtils.label(income.startMonth)}'
                        : 'Mês único — ${MonthUtils.label(income.startMonth)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Ganho encerrado não aceita reajuste, correção nem encerramento
          // (GAN-08). Some com os botões em vez de deixar o usuário levar 422.
          if (!closed) ...[
            _ActionCard(
              icon: Icons.trending_up,
              title: 'Reajustar',
              subtitle:
                  'Recebi um aumento a partir de um mês. O passado fica '
                  'como está.',
              onTap: working ? null : onAdjust,
            ),
            const SizedBox(height: 8),
            _ActionCard(
              icon: Icons.edit_outlined,
              title: 'Corrigir valor',
              subtitle:
                  'O valor estava errado. Vale também para os meses que '
                  'já passaram.',
              onTap: working ? null : onCorrect,
            ),
            const SizedBox(height: 8),
            _ActionCard(
              icon: Icons.event_busy_outlined,
              title: 'Encerrar',
              subtitle: 'Parei de receber. O histórico continua.',
              onTap: working ? null : onClose,
            ),
            const SizedBox(height: 8),
          ],

          _ActionCard(
            icon: Icons.delete_outline,
            title: 'Excluir',
            subtitle: 'Cadastrei errado. Apaga o ganho e todo o histórico.',
            destructive: true,
            onTap: working ? null : onDelete,
          ),

          // A linha do tempo só aparece quando há mais de uma vigência para
          // comparar.
          if (income.history.length > 1) ...[
            const SizedBox(height: 16),
            AmountHistoryCard(history: income.history),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = destructive ? theme.colorScheme.error : null;

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: color),
        title: Text(title, style: TextStyle(color: color)),
        subtitle: Text(subtitle, style: theme.textTheme.bodySmall),
      ),
    );
  }
}
