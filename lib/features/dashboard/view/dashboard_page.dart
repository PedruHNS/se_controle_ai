import 'package:flutter/material.dart';
import 'package:signals/signals_flutter.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../core/di/injector.dart';
import '../../../core/shared/view_state.dart';
import '../../../core/shared/widgets/failure_card_widget.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../../../data/models/dashboard_model.dart';
import '../controller/dashboard_controller.dart';
import '../widgets/allowance_card_widget.dart';
import '../widgets/cards_limit_card_widget.dart';
import '../widgets/daily_pace_card_widget.dart';
import '../widgets/month_strip_card_widget.dart';
import '../widgets/nature_card_widget.dart';
import '../widgets/tag_amounts_card_widget.dart';
import '../widgets/top_expenses_card_widget.dart';

/// Como está este mês, e quanto ainda posso gastar.
///
/// Substitui a tela de projeção, que respondia "quanto vou ter juntado" — o
/// assunto inteiro dela virou, no máximo, o card de contexto dos últimos seis
/// meses.
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final _controller = getIt<DashboardController>();

  /// O último dashboard que chegou, guardado só para a régua de meses.
  ///
  /// Ela vive **fora** do `switch`: trocar a competência põe a tela em
  /// `Loading`, e uma régua que some no toque que a pessoa acabou de dar levaria
  /// embora o próprio seletor. Guardando o anterior, ela fica parada enquanto o
  /// resto recarrega — que é exatamente o que se espera de uma régua.
  final _ultimo = signal<DashboardModel?>(null);
  EffectCleanup? _observando;

  @override
  void initState() {
    super.initState();
    _observando = effect(() {
      final state = _controller.state.value;
      if (state is Loaded<DashboardModel>) _ultimo.value = state.data;
    });
  }

  @override
  void dispose() {
    _observando?.call();
    _ultimo.dispose();
    getIt.resetLazySingleton<DashboardController>();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard'), centerTitle: true),

      body: RefreshIndicator.adaptive(
        onRefresh: () async => _controller.refresh(),
        child: CustomScrollView(
          slivers: [
            PinnedHeaderSliver(
              child: SignalBuilder(
                builder: (context) {
                  final dashboard = _ultimo.value;

                  return Padding(
                    padding: const .only(bottom: 8),
                    child: MonthStripCardWidget(
                      history: dashboard?.history ?? const [],
                      month: dashboard?.month,
                    ),
                  );
                },
              ),
            ),
            SignalBuilder(
              builder: (context) {
                final state = _controller.state.value;
                // Os três ramos devolvem **sliver**, não widget de caixa: o
                // `CustomScrollView` só aceita sliver, e um `ListView` dentro
                // de um `SliverToBoxAdapter` não tem altura para se medir.
                return switch (state) {
                  Loading<DashboardModel>() => const _DashboardEsqueleto(),
                  Failed(failure: final failure) => SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: const .all(16),
                        child: FailureCardWidget(
                          failure: failure,
                          onRetry: _controller.refresh,
                        ),
                      ),
                    ),
                  ),
                  Loaded(data: final dashboard) => _DashboardContent(
                    dashboard: dashboard,
                  ),
                };
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({required this.dashboard});

  final DashboardModel dashboard;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return SliverPadding(
      
      padding: .fromLTRB(24, 8, 24, bottomPadding + 24),
      sliver: SliverList.list(
        children: [
          _TotaisCard(dashboard: dashboard),
          const SizedBox(height: 12),
          AllowanceCardWidget(
            allowance: dashboard.allowance,
            totals: dashboard.totals,
          ),
          const SizedBox(height: 12),
          TagAmountsCardWidget(byTag: dashboard.byTag),
          const SizedBox(height: 12),
          DailyPaceCardWidget(
            daily: dashboard.daily,
            allowance: dashboard.allowance,
          ),
          const SizedBox(height: 12),
          CardsLimitCardWidget(cards: dashboard.cards),
          const SizedBox(height: 12),
          NatureCardWidget(byNature: dashboard.byNature),
          const SizedBox(height: 12),
          TopExpensesCardWidget(topExpenses: dashboard.topExpenses),
        ],
      ),
    );
  }
}

/// Os números do topo: o que entrou, o que saiu e o que sobra.
///
/// Não é um dos sete cards — é o `totals`, que a spec fixa como igual ao que
/// `GET /summary/balance` devolve para a mesma competência (DSH-03).
class _TotaisCard extends StatelessWidget {
  const _TotaisCard({required this.dashboard});

  final DashboardModel dashboard;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totals = dashboard.totals;
    final sobra = totals.balanceCents;

    return Container(
      padding: .all(16),
      decoration: BoxDecoration(
        color: theme.appColors.card,
        borderRadius: .circular(10),
        boxShadow: [
          BoxShadow(
            color: theme.appColors.cardShadow,
            blurRadius: 40,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: .start,
        spacing: 12,
        children: [
          Text(
            sobra < 0 ? 'Faltou este mês' : 'Sobra deste mês',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            Money.format(sobra),
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: sobra < 0 ? theme.colorScheme.error : null,
            ),
          ),
          Row(
            children: [
              _Numero(rotulo: 'Entrou', cents: totals.incomeCents),
              _Numero(rotulo: 'Saiu', cents: totals.expenseCents),
            ],
          ),
        ],
      ),
    );
  }
}

class _Numero extends StatelessWidget {
  const _Numero({required this.rotulo, required this.cents});

  final String rotulo;
  final int cents;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Expanded(
      child: Column(
        crossAxisAlignment: .start,
        children: [
          Text(
            rotulo,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(Money.format(cents)),
        ],
      ),
    );
  }
}

/// O lugar reservado enquanto a busca não volta.
///
/// Mesmo desenho do conteúdo, com o `Skeletonizer` por cima — é o que faz a
/// tela não pular quando os números chegam.
class _DashboardEsqueleto extends StatelessWidget {
  const _DashboardEsqueleto();

  @override
  Widget build(BuildContext context) {
    // `Skeletonizer.sliver`, e não o construtor normal: aqui dentro do
    // `CustomScrollView` o que se entrega é sliver.
    return Skeletonizer.sliver(
      child: SliverPadding(
        padding: const .fromLTRB(24, 8, 24, 24),
        sliver: SliverList.list(
          children: [
            _TotaisCard(dashboard: _dashboardDeEsqueleto),
            const SizedBox(height: 12),
            ...List.generate(
              3,
              (_) => const Padding(
                padding: .only(bottom: 12),
                child: Card(
                  child: SizedBox(height: 120, width: double.infinity),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Números de mentira, só para o esqueleto ter o tamanho certo das linhas.
final _dashboardDeEsqueleto = DashboardModel.fromJson({
  'month': '2026-09',
  'totals': {
    'incomeCents': 500000,
    'expenseCents': 312400,
    'balanceCents': 187600,
    'committedPercent': 62.5,
  },
  'allowance': {
    'scope': 'current',
    'daysRemaining': 21,
    'perDayCents': 8933,
    'overspentCents': null,
  },
  'byTag': <Map<String, dynamic>>[],
  'daily': {
    'baselineCents': 0,
    'days': <Map<String, dynamic>>[],
    'previousDays': <Map<String, dynamic>>[],
  },
  'cards': <Map<String, dynamic>>[],
  'byNature': {'recurringCents': 0, 'installmentCents': 0, 'oneOffCents': 0},
  'history': <Map<String, dynamic>>[],
  'topExpenses': <Map<String, dynamic>>[],
});
