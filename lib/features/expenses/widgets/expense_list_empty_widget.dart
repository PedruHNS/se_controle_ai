import 'package:flutter/material.dart';

import '../../../core/utils/month_utils.dart';

class const ExpenseListEmptyWidget({super.key, required final String month})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisAlignment: .center,
      children: [
        Icon(
          Icons.payments_outlined,
          size: 48,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(height: 12),
        Text(
          'Nenhum gasto em ${MonthUtils.label(month)}',
          textAlign: .center,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          'Comece pelo que se repete todo mês — aluguel, streaming, escola.',
          textAlign: .center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
