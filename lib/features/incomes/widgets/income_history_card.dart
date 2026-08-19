import 'package:flutter/material.dart';

import '../../../core/utils/money.dart';
import '../../../core/utils/month.dart';
import '../../../data/models/income_model.dart';

/// A linha do tempo de vigências — é a prova visual de que um reajuste em
/// novembro não mexeu no que foi recebido em setembro.
class IncomeHistoryCard extends StatelessWidget {
  const IncomeHistoryCard({required this.income, super.key});

  final IncomeModel income;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Icon(
                  Icons.history,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text('Histórico de valores', style: theme.textTheme.titleSmall),
              ],
            ),
          ),
          // Mais recente primeiro: é o que se consulta com mais frequência.
          for (final version in income.history.reversed)
            ListTile(
              dense: true,
              leading: Icon(
                version.isOpen ? Icons.play_arrow : Icons.check,
                size: 16,
                color: version.isOpen
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              title: Text(
                Month.periodLabel(version.validFrom, version.validTo),
              ),
              trailing: Text(
                Money.format(version.amountCents),
                style: theme.textTheme.bodyLarge,
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
