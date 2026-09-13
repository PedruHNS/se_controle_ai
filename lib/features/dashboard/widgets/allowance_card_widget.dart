import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money_utils.dart';
import '../../../data/enums/dashboard_scope.dart';
import '../../../data/models/dashboard_allowance_model.dart';
import '../../../data/models/dashboard_totals_model.dart';
import 'dashboard_card_widget.dart';

/// Card 1 — o que justifica a tela: quanto ainda posso gastar por dia.
///
/// A pergunta muda com a competência (DSH-06), então o título e a frase mudam
/// junto: no mês corrente é "ainda cabe", num que passou é a média realizada, e
/// num futuro é o orçamento diário.
class AllowanceCardWidget extends StatelessWidget {
  const AllowanceCardWidget({
    required this.allowance,
    required this.totals,
    super.key,
  });

  final DashboardAllowanceModel allowance;
  final DashboardTotalsModel totals;

  String get _titulo => switch (allowance.scope) {
    DashboardScope.current => 'Pode gastar por dia',
    DashboardScope.past => 'Gastou por dia',
    DashboardScope.future => 'Vai poder gastar por dia',
  };

  String get _rodape => switch (allowance.scope) {
    DashboardScope.current =>
      'Dividido pelos ${allowance.daysRemaining} dias que faltam, contando hoje',
    DashboardScope.past =>
      'Média dos ${allowance.daysRemaining} dias do mês, do que foi gasto',
    DashboardScope.future =>
      'Dividido pelos ${allowance.daysRemaining} dias do mês',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final perDay = allowance.perDayCents;
    final overspent = allowance.overspentCents;

    return DashboardCardWidget(
      title: _titulo,
      footnote: perDay == null ? null : _rodape,
      child: Column(
        crossAxisAlignment: .start,
        spacing: 12,
        children: [
          // DSH-07: saldo negativo troca a frase, não o sinal. Dividir um
          // negativo pelos dias é aritmética certa e conselho inútil.
          if (perDay == null && overspent != null)
            Text(
              'Você já passou ${MoneyUtils.format(overspent)} do que tinha este mês.',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            )
          else
            Text(
              MoneyUtils.format(perDay ?? 0),
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          _BarraDaRenda(totals: totals),
        ],
      ),
    );
  }
}

/// Quanto da renda do mês já foi comprometido.
///
/// Sem renda no mês o `committedPercent` vem nulo (RES-04) e a barra não
/// aparece: não há de que tirar percentual, e uma barra vazia sugeriria que
/// nada foi gasto.
class _BarraDaRenda extends StatelessWidget {
  const _BarraDaRenda({required this.totals});

  final DashboardTotalsModel totals;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percent = totals.committedPercent;
    if (percent == null) return const SizedBox.shrink();

    final proporcao = (percent / 100).clamp(0.0, 1.0);
    final cor = switch (percent) {
      > 100 => theme.colorScheme.error,
      > 80 => theme.appColors.warning,
      _ => theme.colorScheme.primary,
    };

    return Column(
      crossAxisAlignment: .start,
      spacing: 6,
      children: [
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
          '${percent.toStringAsFixed(1).replaceAll('.', ',')}% da renda já comprometida',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
