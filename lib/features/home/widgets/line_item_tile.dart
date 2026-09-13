import 'package:flutter/material.dart';

import '../../../core/utils/iso_date_utils.dart';
import '../../../core/utils/money_utils.dart';
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

  /// A linha de baixo: o dia da compra e a parcela, o que houver.
  ///
  /// O dia vem primeiro porque é o que responde "quando foi isso?", que é a
  /// pergunta de quem lê o resumo. Com ano, mesmo a seção estando sob um mês:
  /// a parcela 3/10 que aparece em setembro foi comprada em julho, e pode ter
  /// sido no ano passado. Em ganho não há dia, e aí sobra só a parcela — ou
  /// nada, e a linha volta a ter uma linha só.
  String? get _subtitle {
    final spentAt = item.spentAt;
    final label = item.installmentLabel;

    final parts = [
      if (spentAt != null) IsoDateUtils.fullLabel(spentAt),
      if (label != null) 'Parcela $label',
    ];

    return parts.isEmpty ? null : parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle = _subtitle;

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
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
      trailing: Text(
        MoneyUtils.format(item.amountCents),
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
