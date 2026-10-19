import 'package:flutter/material.dart';
import 'package:se_controle_ai/core/utils/money_utils.dart';
import 'package:se_controle_ai/core/utils/month_utils.dart';
import 'package:se_controle_ai/data/models/income_model.dart';

class const IncomeDetailCardWidget({
  super.key,
  required final IncomeModel income,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final closed = income.endMonth != null;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(income.description, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              MoneyUtils.format(income.amountCents ?? 0),
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
    );
  }
}
