import 'package:flutter/material.dart';
import 'package:se_controle_ai/core/shared/widgets/custom_box_shadow_widget.dart';

import '../../../core/utils/iso_date.dart';
import '../../../core/utils/money.dart';
import '../../../data/models/credit_card_model.dart';

/// Uma linha da lista de cartões: o rótulo, os dois dias e o limite.
class CreditCardWidget extends StatelessWidget {
  final CreditCardModel card;
  final void Function()? onTap;
  final void Function()? onDelete;

  const CreditCardWidget({
    required this.card,
    this.onTap,
    this.onDelete,
    super.key,
  });

  CreditCardWidget.esqueleton({super.key})
    : card = CreditCardModel(
        id: '',
        name: '',
        label: '',
        lastDigits: null,
        closingDay: 0,
        dueDay: 0,
        limitCents: null,
        dueDate: null,
        totalCents: null,
      ),
      onDelete = null,
      onTap = null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final limit = card.limitCents ?? 0;
    final totalCents = card.totalCents ?? 0;
    final remainingLimit = limit - totalCents;

    return CustomBoxShadowWidget(
      child: Material(
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Ink(
            padding: .all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),

            child: Column(
              crossAxisAlignment: .start,

              children: [
                Row(
                  mainAxisAlignment: .spaceBetween,
                  children: [
                    Text(card.name, style: theme.textTheme.titleSmall),
                    InkWell(
                      onTap: onDelete,
                      child: Icon(Icons.delete, size: 20, color: Colors.red),
                    ),
                  ],
                ),

                Padding(
                  padding: .fromLTRB(8, 12, 0, 12),
                  child: Column(
                    crossAxisAlignment: .start,
                    children: [
                      Text(
                        'Limite',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        Money.formatCompact(remainingLimit),
                        style: theme.textTheme.titleLarge,
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                  child: Column(
                    spacing: 8,
                    children: [
                      Row(
                        mainAxisAlignment: .spaceBetween,
                        children: [
                          Text(
                            Money.formatCompact(totalCents),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            Money.formatCompact(limit),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      LinearProgressIndicator(
                        value: (totalCents / limit).clamp(0, 1).toDouble(),
                        backgroundColor:
                            theme.colorScheme.surfaceContainerHighest,
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Divider(),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    mainAxisAlignment: .spaceBetween,
                    children: [
                      Text(
                        'Fecha dia ${card.closingDay}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        'Vence dia ${IsoDate.label(card.dueDay.toString())}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // leading: Icon(Icons.credit_card, color: theme.colorScheme.primary),
            // // O label vem derivado do backend (CAR-06) e é usado como vem: os dígitos
            // // já estão nele quando existem.
            // title: Text(card.label),
            // subtitle: Text(_subtitle),
            // trailing: Row(
            //   mainAxisSize: MainAxisSize.min,
            //   children: [
            //
            //     if (onDelete != null)
            //       IconButton(
            //         tooltip: 'Excluir cartão',
            //         icon: const Icon(Icons.delete_outline),
            //         onPressed: onDelete,
            //       ),
            //   ],
            // ),
          ),
        ),
      ),
    );
  }
}
