import 'package:flutter/material.dart';

import '../../../core/utils/iso_date.dart';
import '../../../core/utils/money.dart';
import '../../../data/models/credit_card_model.dart';

/// Uma linha da lista de cartões: o rótulo, os dois dias e o limite.
class CreditCardTile extends StatelessWidget {
  const CreditCardTile({
    required this.card,
    this.onTap,
    this.onDelete,
    super.key,
  });

  final CreditCardModel card;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  /// "Fecha dia 10 · vence 17/08" — o vencimento como data quando a busca trouxe
  /// competência, e como dia do mês quando não trouxe.
  ///
  /// São informações diferentes de propósito: `dueDate` é o vencimento **daquele
  /// mês**, já com o ajuste de mês seguinte (CAR-03) e de último dia (CAR-04);
  /// `dueDay` é só a regra.
  String get _subtitle {
    final due = card.dueDate;
    final vencimento = due == null
        ? 'vence dia ${card.dueDay}'
        : 'vence ${IsoDate.label(due)}';
    return 'Fecha dia ${card.closingDay} · $vencimento';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final limit = card.limitCents;

    return ListTile(
      onTap: onTap,
      leading: Icon(Icons.credit_card, color: theme.colorScheme.primary),
      // O label vem derivado do backend (CAR-06) e é usado como vem: os dígitos
      // já estão nele quando existem.
      title: Text(card.label),
      subtitle: Text(_subtitle),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (limit != null)
            Text(
              Money.formatCompact(limit),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else
            Text(
              'sem limite',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          if (onDelete != null)
            IconButton(
              tooltip: 'Excluir cartão',
              icon: const Icon(Icons.delete_outline),
              onPressed: onDelete,
            ),
        ],
      ),
    );
  }
}
