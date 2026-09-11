import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/di/injector.dart';
import '../../../core/month/selected_month_service.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/month.dart';
import '../../../data/models/dashboard_history_entry_model.dart';
import 'dashboard_card_widget.dart';

/// Card 6 — os últimos seis meses, com o mês da tela destacado.
///
/// "R$ 4.200" não significa nada sozinho; significa se for o maior dos últimos
/// seis. É o que sobrou da tela de projeção, agora olhando para trás.
///
/// **E é também um seletor.** Tocar numa barra — ou no rótulo dela — troca a
/// competência da tela, e arrastar para os lados anda um mês. A janela é
/// móvel: ela termina sempre no mês selecionado (DSH-20), então escolher JUN
/// faz o card passar a mostrar JAN a JUN. O mês seguinte não está desenhado em
/// lugar nenhum, e é por isso que o arrasto existe — sem ele, daqui só se anda
/// para trás.
class HistoryCardWidget extends StatelessWidget {
  const HistoryCardWidget({
    required this.history,
    required this.month,
    super.key,
  });

  final List<DashboardHistoryEntryModel> history;

  /// A competência da tela — a barra dela é a destacada (DSH-22).
  final String month;

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final maior = history
        .map((e) => e.expenseCents)
        .fold(0, (maior, valor) => valor > maior ? valor : maior);

    // **Do mês selecionado para trás**, e não em ordem de calendário: a janela
    // termina sempre na competência pedida (DSH-20), então em ordem crescente
    // a barra que interessa ficava encostada na borda direita, longe de onde o
    // olho começa. Invertida, ela abre o card, e os meses anteriores se afastam
    // para a direita — o eixo lê "agora, e antes disso".
    final janela = history.reversed.toList(growable: false);

    return DashboardCardWidget(
      title: 'Gasto dos últimos seis meses',
      footnote: 'Maior mês da janela: ${Money.format(maior)}',
      child: GestureDetector(
        // Arrastar anda um mês, e é o único caminho para o mês seguinte: a
        // janela termina no mês selecionado, então ele nunca está desenhado.
        // Para a esquerda avança, como virar a página de um calendário.
        onHorizontalDragEnd: (detalhes) {
          final velocidade = detalhes.primaryVelocity ?? 0;
          if (velocidade == 0) return;
          final servico = getIt<SelectedMonthService>();
          velocidade < 0 ? servico.goToNext() : servico.goToPrevious();
        },
        child: SizedBox(
          height: 160,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maior == 0 ? 1 : maior * 1.2,
              barTouchData: BarTouchData(
                // Sem balão: o toque aqui não é para inspecionar valor, é para
                // escolher o mês.
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (_, _, _, _) => null,
                ),
                touchCallback: (evento, resposta) {
                  if (evento is! FlTapUpEvent) return;
                  final indice = resposta?.spot?.touchedBarGroupIndex;
                  if (indice == null || indice < 0) return;
                  _selecionar(janela[indice].month);
                },
              ),
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(),
                topTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    getTitlesWidget: (valor, meta) {
                      final entrada = janela[valor.toInt()];
                      final selecionado = entrada.month == month;

                      // O rótulo é um widget de verdade na árvore, diferente da
                      // barra, que é pintura — então ele também recebe o toque, e
                      // é o alvo mais fácil de acertar com o dedo.
                      return GestureDetector(
                        onTap: () => _selecionar(entrada.month),
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const .only(top: 6),
                          child: Text(
                            // `set/2026` não cabe em seis rótulos lado a lado.
                            Month.shortLabel(entrada.month).split('/').first,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: selecionado
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                              color: selecionado
                                  ? theme.colorScheme.primary
                                  : null,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              barGroups: [
                for (final (indice, entrada) in janela.indexed)
                  BarChartGroupData(
                    x: indice,
                    barRods: [
                      BarChartRodData(
                        toY: entrada.expenseCents.toDouble(),
                        width: 18,
                        borderRadius: .circular(4),
                        color: entrada.month == month
                            ? theme.colorScheme.primary
                            : theme.colorScheme.surfaceContainerHighest,
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Trocar a competência basta: quem rebusca é o `effect` do controller.
  void _selecionar(String month) => getIt<SelectedMonthService>().select(month);
}
