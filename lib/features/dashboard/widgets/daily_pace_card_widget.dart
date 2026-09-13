import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/utils/money_utils.dart';
import '../../../data/models/dashboard_allowance_model.dart';
import '../../../data/models/dashboard_daily_model.dart';
import 'dashboard_card_widget.dart';

/// Card 3 — o ritmo do mês.
///
/// Três desenhos no mesmo par de eixos: o gasto **acumulado** dia a dia, a reta
/// do ritmo que cabe, e a curva apagada do mês anterior. Juntos respondem
/// "quanto cabe hoje" e "estou acima da linha desde quando" — e a curva de trás
/// responde "isso é normal para mim?".
///
/// A série é só das **compras feitas nesta competência** (DSH-11). O que ficou
/// de fora — fixos e parcelas de compras antigas — é a linha de base, dita no
/// rodapé: sem ela, metade do mês sumiria do desenho sem ninguém perceber.
class DailyPaceCardWidget extends StatelessWidget {
  const DailyPaceCardWidget({
    required this.daily,
    required this.allowance,
    super.key,
  });

  final DashboardDailyModel daily;
  final DashboardAllowanceModel allowance;

  /// O acumulado dia a dia. O gráfico é de acumulado e não de barra por dia
  /// porque a pergunta é sobre ritmo, não sobre um dia específico.
  List<FlSpot> _acumulado(List<DashboardDayModel> dias) {
    var total = 0;
    return [
      for (final dia in dias)
        FlSpot(dia.day.toDouble(), (total += dia.amountCents) / 100),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (daily.days.isEmpty) return const SizedBox.shrink();

    final curva = _acumulado(daily.days);
    final anterior = _acumulado(daily.previousDays);
    final ultimoDia = daily.days.last.day.toDouble();

    // A reta do "ritmo que cabe" **não vem do backend**: é o `allowance`
    // distribuído pelos dias, e quem desenha é a tela.
    final perDay = allowance.perDayCents;
    final reta = perDay == null
        ? null
        : [const FlSpot(1, 0), FlSpot(ultimoDia, (perDay * ultimoDia) / 100)];

    final maiorY = [
      ...curva.map((p) => p.y),
      ...anterior.map((p) => p.y),
      ...?reta?.map((p) => p.y),
    ].fold<double>(0, (maior, y) => y > maior ? y : maior);

    return DashboardCardWidget(
      title: 'Ritmo do mês',
      footnote:
          'Fixos e parcelas de compras antigas: ${MoneyUtils.format(daily.baselineCents)} '
          'já estavam lançados antes do mês começar.',
      child: SizedBox(
        height: 180,
        child: LineChart(
          LineChartData(
            minX: 1,
            maxX: ultimoDia,
            minY: 0,
            maxY: maiorY == 0 ? 1 : maiorY * 1.1,
            lineTouchData: const LineTouchData(enabled: false),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) => FlLine(
                color: theme.colorScheme.surfaceContainerHighest,
                strokeWidth: 1,
              ),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              leftTitles: const AxisTitles(),
              topTitles: const AxisTitles(),
              rightTitles: const AxisTitles(),
              // Três marcas, e não uma a cada sete dias: com intervalo fixo o
              // último rótulo caía em cima do penúltimo ("dia 28dia 31") em
              // mês de 31 dias. Começo, meio e fim bastam para situar a curva.
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  interval: 1,
                  getTitlesWidget: (valor, meta) {
                    final dia = valor.toInt();
                    if (dia != 1 && dia != 15 && dia != ultimoDia.toInt()) {
                      return const SizedBox.shrink();
                    }

                    return SideTitleWidget(
                      meta: meta,
                      // Encosta na borda em vez de transbordar: os rótulos do
                      // primeiro e do último dia ficam nos cantos do gráfico.
                      fitInside: SideTitleFitInsideData.fromTitleMeta(meta),
                      child: Text('dia $dia', style: theme.textTheme.bodySmall),
                    );
                  },
                ),
              ),
            ),
            lineBarsData: [
              // A do mês anterior primeiro, para ficar por baixo.
              if (anterior.isNotEmpty)
                LineChartBarData(
                  spots: anterior,
                  isCurved: false,
                  dotData: const FlDotData(show: false),
                  barWidth: 2,
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.25,
                  ),
                ),
              if (reta != null)
                LineChartBarData(
                  spots: reta,
                  isCurved: false,
                  dotData: const FlDotData(show: false),
                  barWidth: 1,
                  dashArray: const [4, 4],
                  color: theme.colorScheme.outline,
                ),
              LineChartBarData(
                spots: curva,
                isCurved: false,
                dotData: const FlDotData(show: false),
                barWidth: 3,
                color: theme.colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
