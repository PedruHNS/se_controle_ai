import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money_utils.dart';
import '../../../data/models/dashboard_card_model.dart';
import 'dashboard_card_widget.dart';

/// Card 4 — as faturas do mês, cada uma dentro do trilho do seu limite.
///
/// Comparar os cartões de relance é a leitura que o carrossel da home não dá.
/// **Todo cartão cadastrado aparece**, inclusive o sem gasto no mês (DSH-16).
class CardsLimitCardWidget extends StatelessWidget {
  const CardsLimitCardWidget({required this.cards, super.key});

  final List<DashboardCardModel> cards;

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) return const SizedBox.shrink();

    return DashboardCardWidget(
      title: 'Faturas e limite',
      child: Column(
        spacing: 14,
        children: [for (final card in cards) _Fatura(card: card)],
      ),
    );
  }
}

class _Fatura extends StatelessWidget {
  const _Fatura({required this.card});

  final DashboardCardModel card;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final limite = card.limitCents;
    final proporcao = limite == null || limite <= 0
        ? null
        : (card.totalCents / limite).clamp(0.0, 1.0);

    final cor = switch (proporcao) {
      null => theme.colorScheme.primary,
      >= 1 => theme.colorScheme.error,
      > 0.8 => theme.appColors.warning,
      _ => theme.colorScheme.primary,
    };

    return Column(
      crossAxisAlignment: .start,
      spacing: 4,
      children: [
        Row(
          children: [
            Expanded(child: Text(card.label, overflow: .ellipsis)),
            Text(
              MoneyUtils.format(card.totalCents),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        // DSH-17: sem limite cadastrado não há trilho. O card mostra o valor da
        // fatura e pronto — não inventa um limite, nem esconde o cartão.
        if (proporcao != null) ...[
          ClipRRect(
            borderRadius: .circular(4),
            child: LinearProgressIndicator(
              value: proporcao,
              minHeight: 8,
              color: cor,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          ),
          Text(
            'de ${MoneyUtils.format(limite!)} de limite',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ] else
          Text(
            'Sem limite cadastrado',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}
