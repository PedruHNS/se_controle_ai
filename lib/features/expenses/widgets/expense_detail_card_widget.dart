import 'package:flutter/material.dart';

import '../../../core/shared/widgets/amount_history_card.dart';
import '../../../core/utils/expense_utils.dart';
import '../../../core/utils/iso_date_utils.dart';
import '../../../core/utils/money_utils.dart';
import '../../../core/utils/month_utils.dart';
import '../../../data/enums/expense_type.dart';
import '../../../data/enums/payment_method.dart';
import '../../../data/models/expense_model.dart';

class const ExpenseDetailCardWidget({
  super.key,
  required final ExpenseModel expense,
  required final String month,
  required final String? cardLabel,
}) extends StatelessWidget {
  String get _periodLine {
    if (expense.type == ExpenseType.installment) {
      final label = ExpenseUtils.installmentLabelIn(expense, month);
      final total = expense.totalCents;
      return [
        if (label != null) 'Parcela $label',
        if (total != null) 'total de ${MoneyUtils.format(total)}',
        if (label == null)
          MonthUtils.periodLabel(expense.startMonth, expense.endMonth),
      ].join(' · ');
    }

    final end = expense.endMonth;
    if (end != null) return 'Encerrado em ${MonthUtils.label(end)}';

    return expense.recurring
        ? 'Recorrente desde ${MonthUtils.label(expense.startMonth)}'
        : 'Mês único — ${MonthUtils.label(expense.startMonth)}';
  }

  String get _paymentLine {
    if (expense.paymentMethod != PaymentMethod.creditCard) return 'No débito';
    return cardLabel == null ? 'No cartão' : 'No cartão · $cardLabel';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final amount =
        ExpenseUtils.amountCentsIn(expense, month) ??
        ExpenseUtils.latestAmountCents(expense);
    final spentAt = expense.spentAt;
    final notes = expense.notes;
    final secondary = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Card(
      margin: .zero,
      child: Padding(
        padding: const .all(20),
        child: Column(
          crossAxisAlignment: .start,
          children: [
            Text(expense.description, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              amount == null ? '—' : MoneyUtils.format(amount),
              style: theme.textTheme.headlineMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: 8),
            Text(_periodLine, style: secondary),
            const SizedBox(height: 4),
            Text(
              [_paymentLine, expense.tag.name].join(' · '),
              style: secondary,
            ),
            Visibility(
              visible: spentAt != null,
              child: Padding(
                padding: const .only(top: 4),
                child: Text(
                  '${IsoDateUtils.isFuture(spentAt ?? '') ? 'Previsto para' : 'Compra em'} '
                  '${IsoDateUtils.fullLabel(spentAt ?? '')}',
                  style: secondary,
                ),
              ),
            ),
            Visibility(
              visible: notes != null,
              child: Container(
                width: double.infinity,
                margin: const .only(top: 12),
                padding: const .all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: .circular(8),
                ),
                child: Text(notes ?? '', style: theme.textTheme.bodySmall),
              ),
            ),
            Visibility(
              visible: expense.history.length > 1,
              child: Padding(
                padding: const .only(top: 12),
                child: AmountHistoryCard(history: expense.history),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
