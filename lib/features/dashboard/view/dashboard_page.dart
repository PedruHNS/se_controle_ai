import 'package:flutter/material.dart';
import 'package:signals/signals_flutter.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../core/di/injector.dart';
import '../../../core/shared/view_state.dart';
import '../../../core/shared/widgets/failure_card_widget.dart';
import '../../../core/shared/widgets/month_selector_widget.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../../../data/models/dashboard_model.dart';
import '../controller/dashboard_controller.dart';

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

  @override
  void dispose() {
    getIt.resetLazySingleton<DashboardController>();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard'), centerTitle: true),

      // O seletor fica **fora** do `switch`, e não dentro do ramo carregado:
      // trocar o mês põe a tela em `Loading`, e um seletor que some no toque
      // que a pessoa acabou de dar parece tela travada.
      body: Column(
        children: [
          const MonthSelectorWidget(),
          Expanded(
            child: SignalBuilder(
              builder: (context) {
                final state = _controller.state.value;
                return switch (state) {
                  Loading() => const _DashboardEsqueleto(),
                  Failed(failure: final failure) => Center(
                    child: Padding(
                      padding: const .all(16),
                      child: FailureCardWidget(
                        failure: failure,
                        onRetry: _controller.refresh,
                      ),
                    ),
                  ),
                  Loaded(data: final dashboard) => _DashboardContent(
                    dashboard: dashboard,
                    onRefresh: _controller.refresh,
                  ),
                };
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({required this.dashboard, required this.onRefresh});

  final DashboardModel dashboard;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: .fromLTRB(24, 8, 24, bottomPadding + 24),
        children: [
          _TotaisCard(dashboard: dashboard),
          // Os sete cards entram aqui, um por tarefa (A6 a A12).
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
    return Skeletonizer(
      child: ListView(
        padding: .fromLTRB(24, 8, 24, 24),
        children: [
          _TotaisCard(dashboard: _dashboardDeEsqueleto),
          const SizedBox(height: 12),
          ...List.generate(
            3,
            (_) => const Padding(
              padding: .only(bottom: 12),
              child: Card(child: SizedBox(height: 120, width: double.infinity)),
            ),
          ),
        ],
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
  'byNature': {
    'recurringCents': 0,
    'installmentCents': 0,
    'oneOffCents': 0,
  },
  'history': <Map<String, dynamic>>[],
  'topExpenses': <Map<String, dynamic>>[],
});
