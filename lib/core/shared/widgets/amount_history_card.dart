import 'package:flutter/material.dart';

import '../../../data/models/amount_version_model.dart';
import '../../utils/money_utils.dart';
import '../../utils/month_utils.dart';

class const AmountHistoryCard({
  super.key,
  required final List<AmountVersionModel> history,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: .stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 8, 12, 4),
          child: Row(
            spacing: 8,
            children: [
              Icon(
                Icons.history,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),

              Text('Histórico de valores', style: theme.textTheme.titleSmall),
            ],
          ),
        ),
        SizedBox(
          height: 140,
          child: ListView.builder(
            physics: AlwaysScrollableScrollPhysics(),
            reverse: true,
            padding: .only(top: 8),
            itemCount: history.length,
            itemBuilder: (context, index) {
              return ListTile(
                dense: true,
                leading: Icon(
                  history[index].validTo == null
                      ? Icons.play_arrow
                      : Icons.check,
                  size: 16,
                  color: history[index].validTo == null
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
                title: Text(
                  MonthUtils.periodLabel(
                    history[index].validFrom,
                    history[index].validTo,
                  ),
                ),
                trailing: Text(
                  MoneyUtils.format(history[index].amountCents),
                  style: theme.textTheme.bodyLarge,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
