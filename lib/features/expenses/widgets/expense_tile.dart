import 'package:flutter/material.dart';

import '../../../core/utils/iso_date.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/month.dart';
import '../../../data/models/expense_model.dart';

/// Uma linha da lista de gastos: descrição, período, forma de pagamento e o
/// valor vigente.
class ExpenseTile extends StatelessWidget {
  const ExpenseTile({
    required this.expense,
    required this.month,
    this.onTap,
    super.key,
  });

  final ExpenseModel expense;

  /// A competência que a linha descreve — a selecionada na home, não a de hoje.
  /// É ela que decide o selo e o valor: o mesmo gasto é "3/10" em setembro e
  /// "4/10" em outubro.
  final String month;

  final VoidCallback? onTap;

  /// O selo responde "isto ainda é cobrado?", que é a pergunta de quem olha a
  /// lista. Por isso "Encerrado" só aparece quando o gasto acabou **antes**
  /// deste mês: o presente de agosto tem fim marcado, mas em agosto ele está
  /// sendo cobrado.
  ///
  /// Num parcelado o selo é a parcela do mês — "3/10" diz ao mesmo tempo que
  /// está em curso e quanto falta, que é mais do que "Mês único" diria.
  String? get _badge {
    final label = expense.installmentLabelIn(month);
    if (label != null) return label;
    if (expense.endedBefore(month)) return 'Encerrado';
    if (expense.isSingleMonth) return 'Mês único';
    return null;
  }

  /// O valor no mês exibido. Um gasto encerrado ou que só começa no mês que vem
  /// não tem valor **neste** mês — aí a lista mostra o da vigência mais
  /// recente, que é o último valor que ele teve ou terá.
  int? get _amountCents =>
      expense.amountCentsIn(month) ?? expense.latestAmountCents;

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
      isThreeLine: expense.spentAt != null,
      // O período é o que diferencia um aluguel de um presente na lista; a tag
      // entra junto sempre, porque é ela que agrupa e é obrigatória (TAG-06).
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            [
              Month.periodLabel(expense.startMonth, expense.endMonth),
              expense.tag.name,
            ].join(' · '),
          ),
          // O dia da compra (GFX-12) fica na sua própria linha, e não colado
          // no período: são duas datas diferentes — "comprei no dia 30" e
          // "sai da competência de outubro" — e juntá-las numa linha só faria
          // parecer que uma corrige a outra.
          //
          // O verbo segue a data: gasto planejado tem dia no futuro, e dizer
          // "compra em" sobre o que não aconteceu seria afirmação falsa.
          if (expense.spentAt case final spentAt?)
            Text(
              '${IsoDate.isFuture(spentAt) ? 'Previsto para' : 'Compra em'} '
              '${IsoDate.fullLabel(spentAt)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
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
