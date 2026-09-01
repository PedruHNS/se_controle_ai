import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:signals/signals_flutter.dart';

import '../../../core/di/injector.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/shared/view_state.dart';
import '../../../core/shared/widgets/app_drawer.dart';
import '../../../core/shared/widgets/failure_card_widget.dart';
import '../../../core/shared/widgets/summary_section_placeholder.dart';
import '../../../data/models/credit_card_invoice_model.dart';
import '../../../data/models/monthly_balance_model.dart';
import '../../../data/models/summary_section_model.dart';
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
              builder: (context) {
                final falhaGeral = _controller.wholeScreenFailure.value;

                // Nem toda falha é de seção: quando as quatro caem junto, o
                // que houve foi rede ou sessão, e a tela diz isso uma vez.
                if (falhaGeral == null) {
                  return _SummaryContent(controller: _controller);
                }

                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: FailureCardWidget(
                        failure: falhaGeral,
                        onRetry: _controller.load,
                      ),
                    ),
                  ),
                );
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
/// O corpo da home: quatro seções, cada uma no seu próprio estado.
///
/// Não há um `switch` só envolvendo tudo porque não há mais uma busca só. Uma
/// seção que ainda está vindo mostra o seu lugar reservado, e uma que falhou
/// mostra o próprio erro sem apagar as vizinhas que já chegaram.
class _SummaryContent extends StatelessWidget {
  const _SummaryContent({required this.controller});

  final HomeController controller;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: SliverList.list(
        children: [
          SignalBuilder(
            builder: (context) => _Section<MonthlyBalanceModel>(
              state: controller.balance.value,
              onRetry: controller.load,
              placeholderHeight: 148,
              builder: (balance) => BalanceCard(balance: balance),
            ),
          ),
          const SizedBox(height: 16),
          SignalBuilder(
            builder: (context) => _Section<SummarySectionModel>(
              state: controller.incomes.value,
              onRetry: controller.load,
              builder: (section) => SummarySection(
                title: 'Ganhos',
                icon: Icons.trending_up,
                items: section.items,
                totalCents: section.totalCents,
                emptyMessage:
                    'Nenhum ganho cadastrado. Toque para adicionar um.',
                onTap: () => context.pushNamed(AppRoutes.incomes),
              ),
            ),
          ),
          // Sempre visível, mesmo sem item: desde a Fase 4 esta seção é a porta
          // da lista de gastos, e uma porta que só aparece depois do primeiro
          // gasto não serve para cadastrar o primeiro gasto. É a mesma escolha
          // já feita em Ganhos.
          const SizedBox(height: 16),
          SignalBuilder(
            builder: (context) => _Section<SummarySectionModel>(
              state: controller.debit.value,
              onRetry: controller.load,
              builder: (section) => SummarySection(
                title: 'Dinheiro e crédito',
                icon: Icons.payments_outlined,
                items: section.items,
                totalCents: section.totalCents,
                emptyMessage:
                    'Nenhum gasto no débito. Toque para adicionar um.',
                onTap: () => context.pushNamed(AppRoutes.expenses),
                // O resumo é panorama, não lista: quatro linhas cabem na tela
                // sem empurrar as faturas dos cartões para fora. Quem quer
                // todas toca no cabeçalho. A ordem vem do backend, do
                // lançamento mais recente para o mais antigo, então o que
                // acabou de ser cadastrado aparece.
                maxItems: 4,
              ),
            ),
          ),
          SignalBuilder(
            builder: (context) => _Section<List<CreditCardInvoiceModel>>(
              state: controller.creditCards.value,
              onRetry: controller.load,
              // As faturas são uma seção só, e não uma por cartão: elas vêm da
              // mesma resposta, então falham e chegam juntas de qualquer jeito.
              builder: (invoices) => Column(
                children: [
                  for (final invoice in invoices) ...[
                    const SizedBox(height: 16),
                    // A fatura do resumo é a segunda porta do cartão: quem está
                    // olhando o mês e quer saber o que compõe aquele total já
                    // está com o dedo em cima do card certo.
                    CreditCardInvoiceCard(
                      invoice: invoice,
                      onTap: () => context.pushNamed(
                        AppRoutes.creditCardExpenses,
                        pathParameters: {RouteParams.id: invoice.cardId},
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// Uma seção da home nos seus três estados.
///
/// O erro fica dentro do lugar da seção, e não ocupando a tela: com quatro
/// buscas independentes, uma falha é notícia sobre um pedaço, não sobre o mês.
/// O "tentar de novo" refaz as quatro — são baratas, e uma falha de rede
/// raramente atinge só uma.
class _Section<T> extends StatelessWidget {
  const _Section({
    required this.state,
    required this.onRetry,
    required this.builder,
    this.placeholderHeight = 96,
  });

  final ViewState<T> state;
  final Future<void> Function() onRetry;
  final Widget Function(T data) builder;

  /// Altura do lugar reservado enquanto a seção não chega. Fixa e por seção
  /// para o conteúdo abaixo não pular quando cada resposta entra.
  final double placeholderHeight;

  @override
  Widget build(BuildContext context) => switch (state) {
    Loading() => SummarySectionPlaceholder(height: placeholderHeight),
    Failed(failure: final failure) => FailureCardWidget(
      failure: failure,
      onRetry: onRetry,
    ),
    Loaded(data: final data) => builder(data),
  };
}
