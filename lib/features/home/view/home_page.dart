import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:signals/signals_flutter.dart';

import '../../../core/di/injector.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/shared/view_state.dart';
import '../../../core/shared/widgets/app_drawer.dart';
import '../../../core/shared/widgets/failure_card_widget.dart';
import '../../../data/models/monthly_summary_model.dart';
import '../controller/home_controller.dart';
import '../widgets/balance_card.dart';
import '../widgets/credit_card_invoice_card.dart';
import '../widgets/summary_section.dart';

/// Resumo do mês — tela inicial.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // O controller é um lazySingleton do get_it, e é o get_it que o libera pelo
  // `dispose:` do registro — por isso não há `dispose` aqui. Consequência
  // desejada: o mês selecionado continua o mesmo ao sair da home e voltar.
  final _controller = getIt<HomeController>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: SignalBuilder(
          builder: (context) {
            // `scaleDown` em vez de deixar a AppBar cortar: mesmo abreviado, o
            // rótulo não cabe em tela estreita (176px de texto para 128px de
            // espaço num aparelho de 360dp). Encolher a fonte mantém "ago/2026"
            // inteiro e legível; o corte comia o ano.
            return FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(_controller.monthLabel.value),
            );
          },
        ),
        centerTitle: true,
        // O padrão reserva 16px de cada lado do título, e aqui eles são a
        // diferença entre caber e não caber.
        titleSpacing: 0,
        // Sem `leading:` de propósito — o espaço é do botão do menu, que o
        // Scaffold coloca ali sozinho por existir um `drawer:`. Preencher o
        // `leading` aqui tomaria o lugar dele e deixaria o menu só no gesto de
        // arrastar da borda.
        //
        // Por isso as duas setas de mês ficam juntas à direita, na ordem em que
        // apontam, e o sino fecha a fila — o que é do mês perto do rótulo do
        // mês, o que é do app na ponta.
        actions: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _controller.canGoPrevious.value
                ? _controller.goToPreviousMonth
                : null,
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _controller.canGoNext.value
                ? _controller.goToNextMonth
                : null,
          ),
          IconButton(
            icon: const Icon(Icons.notifications_none),
            tooltip: 'Notificações',
            onPressed: () => context.pushNamed(AppRoutes.notifications),
          ),
        ],
      ),
      // O atalho fica **no corpo**, não no `bottom` do AppBar. No AppBar ele
      // disputava altura com o título: o `bottom` reservava zero, o botão ocupava
      // seu espaço mesmo assim e empurrava o rótulo do mês para fora da barra —
      // dava a impressão de que a navegação tinha trocado o mês por um botão.
      //
      // Aqui também fica visível nos três estados: navegar para um mês que falha
      // ao carregar não pode tirar o caminho de volta. Como `PinnedHeaderSliver`,
      // ele gruda no topo do viewport e o conteúdo rola por baixo.
      body: RefreshIndicator(
        onRefresh: _controller.refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SignalBuilder(
              builder: (context) => PinnedHeaderSliver(
                child: _controller.isCurrentMonth.value
                    ? const SizedBox.shrink()
                    : _BackToCurrentMonth(
                        onPressed: _controller.goToCurrentMonth,
                      ),
              ),
            ),
            SignalBuilder(
              builder: (context) => switch (_controller.state.value) {
                Loading() => const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                ),
                Failed(failure: final failure) => SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: FailureCardWidget(
                        failure: failure,
                        onRetry: _controller.load,
                      ),
                    ),
                  ),
                ),
                Loaded(data: final summary) => _SummaryContent(
                  summary: summary,
                ),
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Faixa de volta ao mês corrente, visível só fora dele.
///
/// Cor de destaque em vez de botão solto: a faixa também serve de aviso de que o
/// que está na tela não é o mês de hoje.
class _BackToCurrentMonth extends StatelessWidget {
  const _BackToCurrentMonth({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.secondaryContainer,
      child: SizedBox(
        width: double.infinity,
        child: TextButton.icon(
          onPressed: onPressed,
          icon: const Icon(Icons.today, size: 16),
          label: const Text('Voltar para o mês atual'),
          style: TextButton.styleFrom(
            foregroundColor: theme.colorScheme.onSecondaryContainer,
            shape: const RoundedRectangleBorder(),
          ),
        ),
      ),
    );
  }
}

/// Conteúdo do mês carregado. É um sliver: vive dentro do [CustomScrollView] da
/// [HomePage], que também carrega a faixa fixa e o pull-to-refresh.
class _SummaryContent extends StatelessWidget {
  const _SummaryContent({required this.summary});

  final MonthlySummaryModel summary;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: SliverList.list(
        children: [
          BalanceCard(summary: summary),
          const SizedBox(height: 16),
          SummarySection(
            title: 'Ganhos',
            icon: Icons.trending_up,
            items: summary.incomes,
            totalCents: summary.incomeCents,
            emptyMessage: 'Nenhum ganho cadastrado. Toque para adicionar um.',
            onTap: () => context.pushNamed(AppRoutes.incomes),
          ),
          // Sempre visível, mesmo sem item: desde a Fase 4 esta seção é a porta
          // da lista de gastos, e uma porta que só aparece depois do primeiro
          // gasto não serve para cadastrar o primeiro gasto. É a mesma escolha
          // já feita em Ganhos.
          const SizedBox(height: 16),
          SummarySection(
            title: 'Débito e dinheiro',
            icon: Icons.payments_outlined,
            items: summary.debit.items,
            totalCents: summary.debit.totalCents,
            emptyMessage: 'Nenhum gasto no débito. Toque para adicionar um.',
            onTap: () => context.pushNamed(AppRoutes.expenses),
          ),
          for (final invoice in summary.creditCards) ...[
            const SizedBox(height: 16),
            // A fatura do resumo é a segunda porta do cartão: quem está olhando
            // o mês e quer saber o que compõe aquele total já está com o dedo
            // em cima do card certo.
            CreditCardInvoiceCard(
              invoice: invoice,
              onTap: () => context.pushNamed(
                AppRoutes.creditCardExpenses,
                pathParameters: {RouteParams.id: invoice.cardId},
              ),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
