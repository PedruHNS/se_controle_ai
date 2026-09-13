import 'package:flutter/material.dart';

import '../../../core/utils/iso_date_utils.dart';
import '../../../core/utils/money_utils.dart';
import '../../../data/models/dashboard_top_expense_model.dart';
import 'dashboard_card_widget.dart';

/// Card 7 — os cinco maiores gastos cobrados na competência.
///
/// É o detalhe do card 2: lá a pergunta é para onde o dinheiro foi, aqui é
/// quais foram os maiores. O dia é o **da compra** (GFX-12), não o da cobrança
/// — a geladeira parcelada aparece com a data em que foi comprada, e o rótulo
/// `3/10` explica por que o valor é o da parcela.
class TopExpensesCardWidget extends StatelessWidget {
  const TopExpensesCardWidget({required this.topExpenses, super.key});

  final List<DashboardTopExpenseModel> topExpenses;

  @override
  Widget build(BuildContext context) {
    if (topExpenses.isEmpty) return const SizedBox.shrink();

    return DashboardCardWidget(
      title: 'Maiores gastos do mês',
      child: Column(
        spacing: 12,
        children: [for (final gasto in topExpenses) _Linha(gasto: gasto)],
      ),
    );
  }
}

class _Linha extends StatelessWidget {
  const _Linha({required this.gasto});

  final DashboardTopExpenseModel gasto;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // O backend manda ISO 8601 com hora; a tela mostra só o dia.
    final iso = IsoDateUtils.fromInstant(gasto.spentAt);
    final dia = iso == null ? null : IsoDateUtils.label(iso);
    final parcela = gasto.installmentLabel;

    return Row(
      spacing: 12,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: .start,
            children: [
              Text(gasto.description, overflow: .ellipsis),
              Text(
                [?dia, ?parcela].join(' · '),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Text(
          MoneyUtils.format(gasto.amountCents),
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
