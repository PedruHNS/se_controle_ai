import 'package:flutter/material.dart';

import '../../../core/utils/money.dart';
import '../../../core/utils/month.dart';
import '../../../data/models/expense_model.dart';

/// Uma linha da lista de gastos: descrição, período, forma de pagamento e o
/// valor vigente.
class ExpenseTile extends StatelessWidget {
  const ExpenseTile({required this.expense, this.onTap, super.key});

  final ExpenseModel expense;
  final VoidCallback? onTap;

  /// O selo responde "isto ainda é cobrado?", que é a pergunta de quem olha a
  /// lista. Por isso "Encerrado" só aparece quando o gasto acabou **antes**
  /// deste mês: o presente de agosto tem fim marcado, mas em agosto ele está
  /// sendo cobrado.
  ///
  /// Num parcelado o selo é a parcela do mês — "3/10" diz ao mesmo tempo que
  /// está em curso e quanto falta, que é mais do que "Mês único" diria.
  String? get _badge {
    final label = expense.installmentLabelIn(Month.current());
    if (label != null) return label;
    if (expense.endedBefore(Month.current())) return 'Encerrado';
    if (expense.isSingleMonth) return 'Mês único';
    return null;
  }

  /// O valor do mês corrente. Um gasto encerrado ou que só começa no mês que
  /// vem não tem valor **neste** mês — aí a lista mostra o da vigência mais
  /// recente, que é o último valor que ele teve ou terá.
  int? get _amountCents =>
      expense.amountCentsIn(Month.current()) ?? expense.latestAmountCents;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final amount = _amountCents;

    return ListTile(
      onTap: onTap,
      leading: Icon(
        expense.isInstallment
            ? Icons.view_week_outlined
            : expense.onCreditCard
            ? Icons.credit_card
            : Icons.payments_outlined,
        color: theme.colorScheme.onSurfaceVariant,
      ),
      title: Text(expense.description),
      // O período é o que diferencia um aluguel de um presente na lista; a tag
      // entra junto sempre, porque é ela que agrupa e é obrigatória (TAG-06).
      subtitle: Text(
        [
          Month.periodLabel(expense.startMonth, expense.endMonth),
          expense.tag.name,
        ].join(' · '),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            amount == null ? '—' : Money.format(amount),
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
          if (_badge != null)
            Text(
              _badge!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}
