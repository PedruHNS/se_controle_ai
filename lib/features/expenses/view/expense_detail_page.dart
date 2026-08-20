import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:signals/signals_flutter.dart';

import '../../../core/di/injector.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/shared/view_state.dart';
import '../../../core/shared/widgets/amount_history_card.dart';
import '../../../core/shared/widgets/failure_card_widget.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/month.dart';
import '../../../data/models/expense_model.dart';
import '../controller/expense_detail_controller.dart';
import '../widgets/expense_amount_dialog.dart';
import '../widgets/expense_closure_dialog.dart';

/// Um gasto: valor vigente, histórico e as operações.
class ExpenseDetailPage extends StatefulWidget {
  const ExpenseDetailPage({required this.id, super.key});

  final String id;

  @override
  State<ExpenseDetailPage> createState() => _ExpenseDetailPageState();
}

class _ExpenseDetailPageState extends State<ExpenseDetailPage> {
  final _controller = getIt<ExpenseDetailController>();

  @override
  void initState() {
    super.initState();
    // O id é dado da rota, então é a view que o entrega ao controller. Aqui e
    // não no `build`: `initState` roda uma vez, `build` roda a cada frame.
    _controller.start(widget.id);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _edit() async {
    await context.pushNamed(
      AppRoutes.expenseEdit,
      pathParameters: {RouteParams.id: _controller.id},
    );
    if (!mounted) return;
    await _controller.refresh();
  }

  Future<void> _confirmDelete(ExpenseModel expense) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir gasto'),
        content: Text(
          'Apaga "${expense.description}" e todo o histórico, como se nunca '
          'tivesse existido. Para registrar que você parou de pagar, use '
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
      appBar: AppBar(title: const Text('Gasto'), centerTitle: true),
      body: SignalBuilder(
        builder: (context) => switch (_controller.state.value) {
          Loading() => const Center(child: CircularProgressIndicator()),
          Failed(failure: final failure) => Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: FailureCardWidget(
                failure: failure,
                onRetry: _controller.load,
              ),
            ),
          ),
          Loaded(data: final expense) => _ExpenseDetail(
            expense: expense,
            cardLabel: _controller.cardLabel.value,
            working: _controller.working.value,
            onRefresh: _controller.refresh,
            onEdit: _edit,
            onAdjust: () => showExpenseAmountDialog(
              context,
              controller: _controller,
              expense: expense,
              mode: ExpenseAmountMode.adjust,
            ),
            onCorrect: () => showExpenseAmountDialog(
              context,
              controller: _controller,
              expense: expense,
              mode: ExpenseAmountMode.correct,
            ),
            onClose: () => showExpenseClosureDialog(
              context,
              controller: _controller,
              expense: expense,
            ),
            onDelete: () => _confirmDelete(expense),
          ),
        },
      ),
    );
  }
}

class _ExpenseDetail extends StatelessWidget {
  const _ExpenseDetail({
    required this.expense,
    required this.cardLabel,
    required this.working,
    required this.onRefresh,
    required this.onEdit,
    required this.onAdjust,
    required this.onCorrect,
    required this.onClose,
    required this.onDelete,
  });

  final ExpenseModel expense;
  final String? cardLabel;
  final bool working;
  final Future<void> Function() onRefresh;
  final VoidCallback onEdit;
  final VoidCallback onAdjust;
  final VoidCallback onCorrect;
  final VoidCallback onClose;
  final VoidCallback onDelete;

  /// O valor que a tela mostra em destaque: o vigente hoje, ou o da última
  /// vigência quando o gasto já acabou ou ainda não começou.
  int? get _amountCents =>
      expense.amountCentsIn(Month.current()) ?? expense.latestAmountCents;

  String get _paymentLine {
    if (!expense.onCreditCard) return 'No débito';
    return cardLabel == null ? 'No cartão' : 'No cartão · $cardLabel';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final amount = _amountCents;

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
                  Text(expense.description, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    amount == null ? '—' : Money.format(amount),
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    expense.isClosed
                        ? 'Encerrado em ${Month.label(expense.endMonth!)}'
                        : expense.recurring
                        ? 'Recorrente desde ${Month.label(expense.startMonth)}'
                        : 'Mês único — ${Month.label(expense.startMonth)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      _paymentLine,
                      if (expense.category != null) expense.category!,
                    ].join(' · '),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          _ActionCard(
            icon: Icons.tune,
            title: 'Editar dados',
            subtitle:
                'Descrição, categoria e forma de pagamento. Vale para todos '
                'os meses.',
            onTap: working ? null : onEdit,
          ),
          const SizedBox(height: 8),

          // Gasto encerrado não aceita reajuste, correção nem encerramento.
          // Some com os botões em vez de deixar o usuário levar 422.
          if (!expense.isClosed) ...[
            _ActionCard(
              icon: Icons.trending_up,
              title: 'Reajustar',
              subtitle:
                  'O valor subiu a partir de um mês. O passado fica como '
                  'está.',
              onTap: working ? null : onAdjust,
            ),
            const SizedBox(height: 8),
            _ActionCard(
              icon: Icons.edit_outlined,
              title: 'Corrigir valor',
              subtitle:
                  'O valor estava errado. Vale também para os meses que já '
                  'passaram.',
              onTap: working ? null : onCorrect,
            ),
            const SizedBox(height: 8),
            _ActionCard(
              icon: Icons.event_busy_outlined,
              title: 'Encerrar',
              subtitle: 'Parei de pagar. O histórico continua.',
              onTap: working ? null : onClose,
            ),
            const SizedBox(height: 8),
          ],

          _ActionCard(
            icon: Icons.delete_outline,
            title: 'Excluir',
            subtitle: 'Cadastrei errado. Apaga o gasto e todo o histórico.',
            destructive: true,
            onTap: working ? null : onDelete,
          ),

          if (expense.hasAdjustments) ...[
            const SizedBox(height: 16),
            AmountHistoryCard(history: expense.history),
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
