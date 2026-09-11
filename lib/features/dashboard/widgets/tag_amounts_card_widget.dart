import 'package:flutter/material.dart';

import '../../../core/utils/money.dart';
import '../../../core/utils/tag_color.dart';
import '../../../data/models/dashboard_tag_amount_model.dart';
import 'dashboard_card_widget.dart';

/// Card 2 — para onde o dinheiro foi.
///
/// Barras horizontais na cor da própria tag, com o rótulo ao lado e **sem
/// legenda**: comparar comprimentos é mais fácil que comparar ângulos, e com
/// oito categorias uma pizza vira disco ilegível.
///
/// A ordem vem pronta do backend, da maior para a menor (DSH-09) — reordenar
/// aqui seria a mesma regra escrita em dois lugares.
class TagAmountsCardWidget extends StatelessWidget {
  const TagAmountsCardWidget({required this.byTag, super.key});

  final List<DashboardTagAmountModel> byTag;

  /// Cores para tag anterior à migration `010`, que não tem cor escolhida
  /// (DSH-10). O índice da barra escolhe uma — o importante é as barras não se
  /// confundirem entre si.
  static const _semCor = [
    Color(0xFF5C6BC0),
    Color(0xFF26A69A),
    Color(0xFFAB47BC),
    Color(0xFFFF7043),
    Color(0xFF789262),
  ];

  @override
  Widget build(BuildContext context) {
    if (byTag.isEmpty) return const SizedBox.shrink();

    final maior = byTag.first.amountCents;

    return DashboardCardWidget(
      title: 'Gasto por categoria',
      child: Column(
        spacing: 12,
        children: [
          for (final (indice, tag) in byTag.indexed)
            _Barra(
              tag: tag,
              proporcao: maior == 0 ? 0 : tag.amountCents / maior,
              cor:
                  TagColor.tryParse(tag.color) ??
                  _semCor[indice % _semCor.length],
            ),
        ],
      ),
    );
  }
}

class _Barra extends StatelessWidget {
  const _Barra({required this.tag, required this.proporcao, required this.cor});

  final DashboardTagAmountModel tag;
  final double proporcao;
  final Color cor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: .start,
      spacing: 4,
      children: [
        Row(
          children: [
            Expanded(child: Text(tag.name, overflow: .ellipsis)),
            Text(
              Money.format(tag.amountCents),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        ClipRRect(
          borderRadius: .circular(4),
          child: LinearProgressIndicator(
            value: proporcao,
            minHeight: 8,
            color: cor,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
          ),
        ),
      ],
    );
  }
}
