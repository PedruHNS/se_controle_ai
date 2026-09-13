import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:signals/signals_flutter.dart';

import '../../../core/di/injector.dart';
import '../../../data/services/selected_month_service.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/shared/view_state.dart';
import '../../../core/shared/widgets/amount_history_card.dart';
import '../../../core/shared/widgets/failure_card_widget.dart';
import '../../../core/shared/widgets/state_transition.dart';
import '../../../core/utils/iso_date.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/month.dart';
import '../../../data/models/expense_model.dart';
import '../controller/expense_detail_controller.dart';
import '../widgets/expense_amount_dialog.dart';
import '../widgets/expense_closure_dialog.dart';
import '../widgets/expense_reschedule_dialog.dart';
import '../widgets/expense_settlement_dialog.dart';
import '../widgets/installments_card.dart';

/// Um gasto: o valor deste mês, o plano e as operações.
///
/// **As operações de dinheiro dependem do tipo** (GPR-17): fixo reajusta,
/// corrige e encerra; parcelado reparcela e quita. A tela mostra só as que
/// cabem — o backend recusaria as outras com 422, e oferecer um botão para
/// levar erro é pior que não oferecer.
class ExpenseDetailPage extends StatefulWidget {
  const ExpenseDetailPage({required this.id, super.key});

  final String id;

  @override
  State<ExpenseDetailPage> createState() => _ExpenseDetailPageState();
}

class _ExpenseDetailPageState extends State<ExpenseDetailPage> {
  final _controller = getIt<ExpenseDetailController>();

  /// A competência que a home selecionou: é ela que decide qual valor aparece
  /// em destaque e qual parcela está em curso. As **operações** continuam
  /// ancoradas em hoje — reajustar ou encerrar fala de tempo real, não do mês
  /// que se está olhando.
  final _selectedMonth = getIt<SelectedMonthService>();

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
        builder: (context) {
          final state = _controller.state.value;
          final month = _selectedMonth.month.value;

          return StateTransition(
            stateKey: state.runtimeType,
            child: switch (state) {
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
                month: month,
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
                onReschedule: () => showExpenseRescheduleDialog(
                  context,
                  controller: _controller,
                  expense: expense,
                ),
                onSettle: () => showExpenseSettlementDialog(
                  context,
                  controller: _controller,
                  expense: expense,
                ),
                onDelete: () => _confirmDelete(expense),
              ),
            },
          );
        },
      ),
    );
  }
}

class _ExpenseDetail extends StatelessWidget {
  const _ExpenseDetail({
    required this.expense,
    required this.month,
    required this.cardLabel,
    required this.working,
    required this.onRefresh,
    required this.onEdit,
    required this.onAdjust,
    required this.onCorrect,
    required this.onClose,
    required this.onReschedule,
    required this.onSettle,
    required this.onDelete,
  });

  final ExpenseModel expense;

  /// A competência exibida — a selecionada na home.
  final String month;

  final String? cardLabel;
  final bool working;
  final Future<void> Function() onRefresh;
  final VoidCallback onEdit;
  final VoidCallback onAdjust;
  final VoidCallback onCorrect;
  final VoidCallback onClose;
  final VoidCallback onReschedule;
  final VoidCallback onSettle;
  final VoidCallback onDelete;

  /// O valor que a tela mostra em destaque: o cobrado no mês exibido, ou o
  /// último quando o gasto já acabou ou ainda não começou.
  int? get _amountCents =>
      expense.amountCentsIn(month) ?? expense.latestAmountCents;

  /// A linha de baixo do cabeçalho, que muda com o tipo: um parcelado se
  /// descreve pelo plano ("3/10 · total de R$ 3.000,00"), um fixo pelo período.
  String get _periodLine {
    if (expense.isInstallment) {
      final label = expense.installmentLabelIn(month);
      final total = expense.totalCents;
      return [
        if (label != null) 'Parcela $label',
        if (total != null) 'total de ${Money.format(total)}',
        if (label == null)
          Month.periodLabel(expense.startMonth, expense.endMonth),
      ].join(' · ');
    }

    if (expense.isClosed) {
      return 'Encerrado em ${Month.label(expense.endMonth!)}';
    }
    return expense.recurring
        ? 'Recorrente desde ${Month.label(expense.startMonth)}'
        : 'Mês único — ${Month.label(expense.startMonth)}';
  }

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
                    _periodLine,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [_paymentLine, expense.tag.name].join(' · '),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  // O dia da compra (GFX-12), abaixo do período e não junto:
                  // no parcelado ele fica meses atrás da competência exibida,
                  // e é essa distância que explica por que a parcela 3/10 cai
                  // aqui.
                  if (expense.spentAt case final spentAt?) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${IsoDate.isFuture(spentAt) ? 'Previsto para' : 'Compra em'} '
                      '${IsoDate.fullLabel(spentAt)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  // Único lugar onde a observação aparece: ela é texto livre e
                  // nada a consulta — não filtra, não agrupa, não entra no
                  // resumo. Mostrá-la na lista roubaria espaço do que agrupa.
                  if (expense.notes case final notes?) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(notes, style: theme.textTheme.bodySmall),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          _ActionCard(
            icon: Icons.tune,
            title: 'Editar dados',
            subtitle:
                'Descrição, categoria, observação e forma de pagamento. Vale '
                'para todos os meses.',
            onTap: working ? null : onEdit,
          ),
          const SizedBox(height: 8),

          // Parcelado tem as suas duas, e não aceita as de fixo (GPR-17).
          if (expense.isInstallment) ...[
            _ActionCard(
              icon: Icons.call_split,
              title: 'Reparcelar',
              subtitle:
                  'Mudou o total ou o número de vezes. As parcelas já '
                  'cobradas ficam como estão.',
              onTap: working ? null : onReschedule,
            ),
            const SizedBox(height: 8),
            _ActionCard(
              icon: Icons.done_all,
              title: 'Quitar',
              subtitle:
                  'Paguei o resto adiantado. As parcelas de um mês em diante '
                  'somem.',
              onTap: working ? null : onSettle,
            ),
            const SizedBox(height: 8),
          ],

          // Gasto fixo encerrado não aceita reajuste, correção nem
          // encerramento. Some com os botões em vez de deixar levar 422.
          if (expense.isFixed && !expense.isClosed) ...[
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

          // Cada tipo mostra o seu plano: a linha do tempo de vigências no
          // fixo, a de parcelas no parcelado.
          if (expense.hasAdjustments) ...[
            const SizedBox(height: 16),
            AmountHistoryCard(history: expense.history),
          ],
          if (expense.installments.isNotEmpty) ...[
            const SizedBox(height: 16),
            InstallmentsCard(
              installments: expense.installments,
              currentMonth: month,
            ),
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
