import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:se_controle_ai/data/services/navigation_service.dart';
import 'package:signals/signals_flutter.dart';

import '../../../core/di/injector.dart';
import '../../../core/router/app_router.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/shared/view_state.dart';
import '../../../core/shared/widgets/month_selector_widget.dart';
import '../../../core/shared/widgets/app_drawer.dart';
import '../../../core/shared/widgets/failure_card_widget.dart';
import '../../../core/shared/widgets/summary_section_placeholder.dart';
import '../../../data/models/credit_card_invoice_model.dart';
import '../../../data/models/expense_model.dart';
import '../../../data/models/monthly_balance_model.dart';
import '../../../data/models/summary_section_model.dart';
import '../controller/home_controller.dart';
import '../widgets/balance_card.dart';
import '../widgets/home_fab.dart';
import '../widgets/invoice_carousel.dart';
import '../widgets/summary_section.dart';

/// Resumo do mês — tela inicial.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with RouteAware {
  // O controller é um lazySingleton do get_it, e quem o libera é o `dispose:`
  // do registro, disparado pelo `resetLazySingleton` lá embaixo. Na prática
  // isso quase nunca roda: a home é a base da pilha, e `push` não destrói o
  // que fica embaixo — só sair da conta a remove. É também por isso que o
  // refresh ao voltar precisa do [routeObserver].
  final _controller = getIt<HomeController>();

  /// O menu do botão de criar está aberto? Mora aqui, e não no [HomeFab],
  /// porque abrir também escurece o corpo da tela — e a cortina é do corpo.
  bool _fabExpanded = false;

  void _setFab(bool expanded) => setState(() => _fabExpanded = expanded);

  /// Abre um formulário de cadastro e recarrega o mês se algo foi criado.
  ///
  /// O formulário devolve o id do que nasceu, ou nulo se a pessoa desistiu —
  /// no segundo caso não há o que recarregar, e recarregar mesmo assim faria a
  /// tela piscar à toa.
  Future<void> _openForm(String route) async {
    _setFab(false);

    // Sem `refresh` no retorno: quem recarrega agora é o [didPopNext], que
    // vale para toda tela empilhada — inclusive as do menu, que não passam
    // por aqui. Chamar nos dois lugares buscaria o resumo duas vezes.
    await context.pushNamed(route);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final route = ModalRoute.of(context);
    if (route is PageRoute) routeObserver.subscribe(this, route);
  }

  /// A tela de cima saiu e a home reapareceu.
  ///
  /// Recarrega sempre, sem perguntar se algo mudou: um gasto cadastrado na
  /// tela de gastos, um cartão editado no menu ou uma tag renomeada mexem no
  /// resumo, e a home não tem como saber disso sozinha. O preço é uma busca a
  /// cada volta, mesmo quando nada mudou — decidido em 10/09/2026, com a
  /// alternativa (um contador de escritas) anotada para quando o custo
  /// incomodar.
  ///
  /// `silent`, via [HomeController.refresh]: o conteúdo antigo fica na tela
  /// enquanto o novo vem, senão voltar do menu piscaria a home inteira.
  @override
  void didPopNext() => _controller.refresh();

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    getIt.resetLazySingleton<HomeController>();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        // O mesmo seletor da lista de cartões, que fala direto com o
        // `SelectedMonthService`. Quem recarrega a home é o `effect` do
        // controller, e não mais o toque na seta.
        title: const MonthSelectorWidget(short: false),
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

                // Nem toda falha é de seção: quando todas caem junto, o que
                // houve foi rede ou sessão, e a tela diz isso uma vez.
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

            SliverPadding(padding: .only(bottom: bottomPadding + 40)),
          ],
        ),
      ),
      floatingActionButton: HomeFab(
        expanded: _fabExpanded,
        onToggle: () => _setFab(!_fabExpanded),
        onNewIncome: () => _openForm(AppRoutes.incomeForm),
        onNewExpense: () => _openForm(AppRoutes.expenseForm),
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
/// O corpo da home: cada seção no seu próprio estado.
///
/// Não há um `switch` só envolvendo tudo porque não há mais uma busca só. Uma
/// seção que ainda está vindo mostra o seu lugar reservado, e uma que falhou
/// mostra o próprio erro sem apagar as vizinhas que já chegaram.
class _SummaryContent extends StatelessWidget {
  _SummaryContent({required this.controller});

  final HomeController controller;
  final _nav = getIt<NavigationService>();

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
                onTap: () => _nav.pushNamed(AppRoutes.incomes),
              ),
            ),
          ),
          // Sempre visível, mesmo sem item: desde a Fase 4 esta seção é a porta
          // da lista de gastos, e uma porta que só aparece depois do primeiro
          // gasto não serve para cadastrar o primeiro gasto. É a mesma escolha
          // já feita em Ganhos.
          //
          // As duas seções abaixo leem a mesma coisa com filtros diferentes, e
          // é de propósito. A de cima é o que sai do mês inteiro — o único
          // lugar do corpo do resumo onde um gasto no cartão aparece sem abrir
          // a fatura. A de baixo separa o dinheiro do que vai na fatura, que é
          // a pergunta de quem quer saber quanto ainda sai da conta este mês.
          const SizedBox(height: 16),
          SignalBuilder(
            builder: (context) => _Section<SummarySectionModel>(
              state: controller.expenses.value,
              onRetry: controller.load,
              builder: (section) => SummarySection(
                title: 'Dinheiro e crédito',
                // Espelha o `trending_up` de Ganhos: as duas seções são os dois
                // lados do mês, e o par de setas diz isso antes de ler o rótulo.
                icon: Icons.trending_down,
                items: section.items,
                totalCents: section.totalCents,
                emptyMessage:
                    'Nenhum gasto neste mês. Toque para adicionar um.',
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
          const SizedBox(height: 16),
          SignalBuilder(
            builder: (context) => _Section<SummarySectionModel>(
              state: controller.debit.value,
              onRetry: controller.load,
              builder: (section) => SummarySection(
                title: 'Dinheiro',
                icon: Icons.payments_outlined,
                items: section.items,
                totalCents: section.totalCents,
                emptyMessage:
                    'Nenhum gasto no dinheiro. Toque para adicionar um.',
                // A mesma lista da seção de cima, filtrada — e não uma tela
                // nova: o filtro viaja na URL, então a lista continua sendo uma
                // só e o destino é compartilhável.
                onTap: () => context.pushNamed(
                  AppRoutes.expenses,
                  queryParameters: {
                    AppRoutes.paymentMethodParam: PaymentMethod.debit.wire,
                  },
                ),
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
              //
              // Lado a lado, e não empilhadas: o mês tem um fim, e cada cartão
              // empurrando o resto para baixo fazia a home crescer com o número
              // de cartões. O espaço vazio quando não há fatura nenhuma
              // continua sendo espaço nenhum.
              builder: (invoices) => invoices.isEmpty
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.only(top: 16),
                      // A fatura do resumo é a segunda porta do cartão: quem
                      // está olhando o mês e quer saber o que compõe aquele
                      // total já está com o dedo em cima do card certo.
                      child: InvoiceCarousel(
                        invoices: invoices,
                        onOpen: (invoice) => context.pushNamed(
                          AppRoutes.creditCardExpenses,
                          pathParameters: {RouteParams.id: invoice.cardId},
                        ),
                      ),
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
/// O erro fica dentro do lugar da seção, e não ocupando a tela: com uma busca
/// por seção, uma falha é notícia sobre um pedaço, não sobre o mês.
/// O "tentar de novo" refaz todas — são baratas, e uma falha de rede
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
