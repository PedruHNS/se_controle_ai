import 'package:flutter/material.dart';

import '../../../core/utils/money.dart';
import '../../../data/models/summary_line_item_model.dart';

/// Uma linha do resumo. Serve para ganho, gasto no débito e item de fatura — as
/// três coisas têm a mesma forma no backend (`SummaryLineItem`).
class LineItemTile extends StatelessWidget {
  const LineItemTile({
    required this.item,
    this.onTap,
    this.maxLines,
    super.key,
  });

  final SummaryLineItemModel item;
  final VoidCallback? onTap;

  /// Limita a descrição a este número de linhas, com reticências. Nulo deixa
  /// quebrar à vontade, que é o certo nas seções que crescem para baixo — só a
  /// fatura, de altura fixa, precisa que a linha tenha tamanho previsível.
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = item.installmentLabel;

    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      onTap: onTap,
      title: Text(
        item.description,
        style: theme.textTheme.bodyMedium,
        maxLines: maxLines,
        overflow: maxLines == null ? null : TextOverflow.ellipsis,
      ),
      // `3/10` só existe em parcelado; em gasto fixo vem nulo.
      subtitle: label == null
          ? null
          : Text(
              'Parcela $label',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
      trailing: Text(
        Money.format(item.amountCents),
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
