import 'package:flutter/material.dart';

import '../../../core/utils/money.dart';
import '../../../data/models/dashboard_nature_model.dart';
import 'dashboard_card_widget.dart';

/// Card 5 — quanto do mês já estava vendido antes de ele começar.
///
/// Uma barra só, dividida em três: dois meses de total idêntico podem ser vidas
/// diferentes, e é essa diferença que o card mostra.
class NatureCardWidget extends StatelessWidget {
  const NatureCardWidget({required this.byNature, super.key});

  final DashboardNatureModel byNature;

  /// Três pastéis de **matizes diferentes**, e não três tons do esquema do
  /// tema: o `secondary` e o `tertiary` do Material caem quase na mesma cor
  /// aqui, e na barra o parcelado e o avulso viravam a mesma faixa.
  ///
  /// Fixos, e não vindos do tema, porque são cores de série de dado e não de
  /// superfície: precisam se distinguir entre si, não acompanhar o fundo. A
  /// luminosidade é média de propósito — pastel claro demais some no card
  /// branco, e escuro demais some no tema escuro.
  static const _azul = Color(0xFF7BA7E8);
  static const _laranja = Color(0xFFF0A868);
  static const _verde = Color(0xFF7FC8A9);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total =
        byNature.recurringCents +
        byNature.installmentCents +
        byNature.oneOffCents;

    if (total == 0) return const SizedBox.shrink();

    final fatias = [
      (rotulo: 'Fixo recorrente', cents: byNature.recurringCents, cor: _azul),
      (rotulo: 'Parcelado', cents: byNature.installmentCents, cor: _laranja),
      (rotulo: 'Avulso', cents: byNature.oneOffCents, cor: _verde),
    ];

    return DashboardCardWidget(
      title: 'Composição do gasto',
      child: Column(
        crossAxisAlignment: .start,
        spacing: 12,
        children: [
          ClipRRect(
            borderRadius: .circular(4),
            child: Row(
              children: [
                for (final fatia in fatias)
                  if (fatia.cents > 0)
                    Expanded(
                      flex: fatia.cents,
                      child: Container(height: 10, color: fatia.cor),
                    ),
              ],
            ),
          ),
          for (final fatia in fatias)
            Row(
              spacing: 8,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: fatia.cor,
                    borderRadius: .circular(2),
                  ),
                ),
                Expanded(child: Text(fatia.rotulo)),
                Text(
                  Money.format(fatia.cents),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
