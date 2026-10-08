import 'package:flutter/material.dart';

import '../../../core/utils/month_utils.dart';

class IncomeEmptyWidget extends StatelessWidget {
  final String month;

  const IncomeEmptyWidget({required this.month, super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisAlignment: .center,
      children: [
        Icon(
          Icons.trending_up,
          size: 48,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(height: 12),
        Text(
          'Nenhum ganho em ${MonthUtils.label(month)}',
          textAlign: .center,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          'Cadastre em "Novo ganho" ou veja outro mês no seletor.',
          textAlign: .center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
