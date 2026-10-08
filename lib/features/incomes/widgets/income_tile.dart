import 'package:flutter/material.dart';

import '../../../core/utils/money_utils.dart';
import '../../../core/utils/month_utils.dart';
import '../../../data/models/income_model.dart';

class IncomeTile extends StatelessWidget {
  final IncomeModel income;
  final String month;
  final VoidCallback? onTap;

  const IncomeTile({
    required this.income,
    required this.month,
    this.onTap,
    super.key,
  });

  const IncomeTile.skeleton({super.key})
    : income = const IncomeModel(
        id: '',
        description: 'Salário da empresa',
        recurring: true,
        startMonth: '2026-01',
        endMonth: null,
        amountCents: 450000,
        history: [],
      ),
      month = '2026-01',
      onTap = null;

  String? get _badge {
    final end = income.endMonth;
    if (end == null) return null;
    if (MonthUtils.isBefore(end, month)) return 'Encerrado';
    if (end == income.startMonth) return 'Mês único';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final badge = _badge;

    return ListTile(
      onTap: onTap,
      title: Text(income.description),
      subtitle: Text(
        MonthUtils.periodLabel(income.startMonth, income.endMonth),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            MoneyUtils.format(income.amountCents),
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
          Visibility(
            visible: badge != null,
            child: Text(
              badge ?? '',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
