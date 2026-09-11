import 'package:flutter/material.dart';

import '../../../core/di/injector.dart';
import '../../../core/month/selected_month_service.dart';
import '../../../core/shared/widgets/month_selector_widget.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/month.dart';
import '../../../data/models/dashboard_history_entry_model.dart';

/// A régua de meses: uma barra de gasto por competência, rolável na horizontal.
///
/// **É o seletor da tela.** Tocar numa barra troca a competência; rolar não
/// troca nada, só revela o que está fora do enquadramento. É a diferença que
/// separa uma régua de um carrossel — quem arrasta está procurando, não
/// escolhendo.
///
/// A régua vem ancorada em **hoje** (DSH-20), e não na competência selecionada:
/// se ela terminasse no mês escolhido, cada toque devolveria outra faixa e as
/// barras se reorganizariam debaixo do dedo. Ancorada, o toque muda o destaque
/// e mais nada.
///
/// Desenhada à mão, sem `fl_chart`: são retângulos com rótulo, e o que este
/// card precisa — rolagem, alvo de toque e posição inicial — é encanamento de
/// lista, não de gráfico.
class MonthStripCardWidget extends StatefulWidget {
  const MonthStripCardWidget({
    required this.history,
    required this.month,
    super.key,
  });

  final List<DashboardHistoryEntryModel> history;

  /// A competência selecionada — a barra destacada. Nula enquanto a primeira
  /// busca não voltou: aí o card mostra só as setas, e não uma régua vazia.
  final String? month;

  @override
  State<MonthStripCardWidget> createState() => _MonthStripCardWidgetState();
}

class _MonthStripCardWidgetState extends State<MonthStripCardWidget> {
  /// Largura de cada mês. Fixa porque é ela que permite calcular a posição
  /// inicial sem esperar o primeiro quadro — e folgada, para as barras
  /// respirarem em vez de virarem uma cerca.
  static const _largura = 64.0;

  /// Em que posição o mês selecionado aparece ao abrir. Terceira, e não
  /// primeira: assim os meses anteriores ficam à vista, que é o que dá a
  /// referência de "este mês é caro?".
  static const _posicaoInicial = 2;

  late final ScrollController _scroll = ScrollController(
    initialScrollOffset: _offsetInicial(),
  );

  double _offsetInicial() {
    final indice = widget.history.indexWhere((e) => e.month == widget.month);
    if (indice < 0) return 0;
    return ((indice - _posicaoInicial) * _largura).clamp(0, double.infinity);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final maior = widget.history
        .map((e) => e.expenseCents)
        .fold(0, (maior, valor) => valor > maior ? valor : maior);

    return Container(
      padding: const .only(top: 12),
      decoration: BoxDecoration(
        // A cor do fundo da tela, e não a de card: a régua gruda no topo
        // (`PinnedHeaderSliver`) e precisa ser opaca para o conteúdo não
        // aparecer através dela ao rolar. Com esta cor ela some no fundo, e
        // quem ganha contorno são as barras, que usam a cor de card.
        color: theme.scaffoldBackgroundColor,
        borderRadius: .circular(10),
        boxShadow: [
          BoxShadow(
            color: theme.scaffoldBackgroundColor,
            blurRadius: 40,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: .min,
        children: [
          if (widget.history.isNotEmpty)
            SizedBox(
              height: 150,
              child: ListView.builder(
                controller: _scroll,
                scrollDirection: Axis.horizontal,
                padding: const .symmetric(horizontal: 8),
                itemExtent: _largura,
                itemCount: widget.history.length,
                itemBuilder: (context, indice) {
                  final entrada = widget.history[indice];
                  return _Mes(
                    entrada: entrada,
                    selecionado: entrada.month == widget.month,
                    proporcao: maior == 0 ? 0 : entrada.expenseCents / maior,
                    onTap: () =>
                        getIt<SelectedMonthService>().select(entrada.month),
                  );
                },
              ),
            ),
          const MonthSelectorWidget(),
        ],
      ),
    );
  }
}

class _Mes extends StatelessWidget {
  const _Mes({
    required this.entrada,
    required this.selecionado,
    required this.proporcao,
    required this.onTap,
  });

  final DashboardHistoryEntryModel entrada;
  final bool selecionado;
  final double proporcao;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final janeiro = entrada.month.endsWith('-01');

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: .end,
        children: [
          // O valor só do mês escolhido: com 37 barras, um número em cada uma
          // vira ruído, e o que interessa ler é o da barra destacada.
          SizedBox(
            height: 18,
            child: selecionado
                ? FittedBox(
                    child: Text(
                      Money.formatCompact(entrada.expenseCents),
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Align(
              alignment: .bottomCenter,
              child: FractionallySizedBox(
                heightFactor: proporcao == 0 ? 0.02 : proporcao,
                widthFactor: 0.36,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    // A barra apagada usa a cor de **card**, e não o
                    // `surfaceContainerHighest`: sem o fundo branco atrás, ela
                    // encostava no lilás do tema e sumia. É branco no claro e o
                    // degrau acima do fundo no escuro, então continua visível
                    // nos dois.
                    color: selecionado
                        ? theme.colorScheme.primary
                        : theme.appColors.card,
                    borderRadius: .vertical(top: .circular(4)),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            Month.shortLabel(entrada.month).split('/').first,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: selecionado ? FontWeight.w700 : FontWeight.w400,
              color: selecionado ? theme.colorScheme.primary : null,
            ),
          ),
          // O ano só em janeiro: repetido em toda barra viraria ruído, e sem
          // ele uma régua de três anos não diz de que "SET" se trata.
          SizedBox(
            height: 14,
            child: janeiro
                ? Text(
                    entrada.month.substring(0, 4),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  )
                : null,
          ),
        ],
      ),
    );
  }
}
