import 'package:flutter/material.dart';

import '../../../core/utils/money.dart';
import '../../../core/utils/month.dart';
import '../../../data/models/income_model.dart';

/// Uma linha da lista de ganhos: descrição, valor vigente e o período.
class IncomeTile extends StatelessWidget {
  const IncomeTile({
    required this.income,
    required this.month,
    this.onTap,
    super.key,
  });

  final IncomeModel income;

  /// A competência que a linha descreve — a selecionada na home, não a de hoje.
  /// É ela que decide o selo: um ganho encerrado em julho é "Encerrado" em
  /// agosto e ainda não é em julho.
  final String month;

  final VoidCallback? onTap;

  String? get _badge {
    if (income.endedBefore(month)) return 'Encerrado';
    if (income.isSingleMonth) return 'Mês único';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      onTap: onTap,
      title: Text(income.description),
      // O período é o que diferencia um salário de um 13º na lista.
      subtitle: Text(Month.periodLabel(income.startMonth, income.endMonth)),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            Money.format(income.amountCents),
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
          // O selo responde "isto ainda entra?", que é a pergunta de quem olha
          // a lista. Por isso "Encerrado" só aparece quando o ganho acabou
          // **antes** deste mês: a venda de agosto tem fim marcado, mas em
          // agosto ela está entrando.
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
