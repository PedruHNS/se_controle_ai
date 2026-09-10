import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/credit_card_model.dart';
import '../../data/models/expense_model.dart';
import '../../data/repositories/auth_repository.dart';
import '../config/globals.dart';

import '../../features/auth/view/login_page.dart';
import '../../features/auth/view/splash_page.dart';
import '../../features/credit_cards/view/credit_card_expenses_page.dart';
import '../../features/credit_cards/view/credit_card_form_page.dart';
import '../../features/credit_cards/view/credit_card_list_page.dart';
import '../../features/home/view/home_page.dart';
import '../../features/incomes/view/income_detail_page.dart';
import '../../features/incomes/view/income_form_page.dart';
import '../../features/expenses/view/expense_detail_page.dart';
import '../../features/expenses/view/expense_form_page.dart';
import '../../features/expenses/view/expense_list_page.dart';
import '../../features/incomes/view/income_list_page.dart';
import '../../features/notifications/view/notification_list_page.dart';
import '../../features/projection/view/projection_page.dart';
import '../../features/tags/view/tag_list_page.dart';
import 'app_routes.dart';
import 'auth_gate.dart';
import 'auth_refresh.dart';

/// Configuração de navegação do app.
///
/// Instância única e `final` de propósito: recriar o GoRouter a cada build do
/// widget raiz descarta a pilha de navegação e o app "volta" para a home sozinho
/// a cada rebuild.
/// Fora do [appRouter] porque o `redirect` precisa **ler** o estado dele, e não
/// só ser notificado: é ele que sabe se o primeiro evento do Firebase já chegou.
final AuthRefresh _authRefresh = AuthRefresh(GetIt.I<AuthRepository>().changes);

/// Quem avisa uma tela de que a de cima saiu e ela voltou a aparecer.
///
/// Existe porque `push` não destrói a tela de baixo: ela fica montada, com o
/// `State` vivo e o controller intacto, então nada nela roda quando o topo é
/// removido. Sem este observador, cadastrar um gasto pela tela de gastos
/// deixava a home mostrando o resumo de antes — e a única saída era o
/// pull-to-refresh.
///
/// `PageRoute` e não `ModalRoute`: diálogo aberto e fechado em cima da home
/// não é "voltar para a home", e assinar `ModalRoute` faria cada confirmação
/// de exclusão disparar uma recarga.
final routeObserver = RouteObserver<PageRoute<dynamic>>();

final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.homePath,
  navigatorKey: Globals.navigatorKey,

  /// O observador que avisa a home quando uma tela empilhada sobre ela sai.
  observers: [routeObserver],

  /// Loga cada navegação no console em debug. Vale muito quando um redirect
  /// leva para lugar inesperado.
  debugLogDiagnostics: kDebugMode,

  /// Sem isto o `redirect` só rodaria na próxima navegação: sair da conta
  /// deixaria a pessoa parada na tela em que estava, olhando dados de uma
  /// sessão que já não existe.
  refreshListenable: _authRefresh.mudancas,

  /// A tranca da navegação (AUT-05, do lado do app).
  ///
  /// Lê o repositório na hora, em vez de guardar uma cópia do usuário: duas
  /// verdades sobre quem está logado divergiriam, e a que decide navegação é a
  /// pior das duas para estar errada.
  ///
  /// **Estar logado é o critério, quando já se sabe quem está logado.** Houve
  /// um segundo critério, de 26 a 27/08: quem estava logado podia ainda não ter
  /// acesso (AUT-11), e o app descobria isso por um 403 dentro das telas. A
  /// regra saiu — quem entra pelo provedor entra no app.
  ///
  /// O que sobrou de sutil é o **começo**: nos primeiros quadros o SDK do
  /// Firebase ainda está lendo a sessão do disco, e `currentUser` é nulo em
  /// quem está logado. Decidir ali manda ao login quem acabou de abrir o app, e
  /// o `AuthRefresh` corrige um quadro depois — o que se vê é um piscar da tela
  /// de login. Por isso existe a espera: enquanto `resolvido` é falso, ninguém
  /// decide nada.
  ///
  /// A decisão em si mora no [rotaParaEstado], que não conhece `context` nem
  /// router e por isso pode ser testada combinação por combinação.
  redirect: (context, state) => rotaParaEstado(
    sessaoResolvida: _authRefresh.resolvido,
    logado: GetIt.I<AuthRepository>().current != null,
    indoPara: state.matchedLocation,
    guardado: state.uri.queryParameters[AppRoutes.deParam],
  ),

  routes: [
    GoRoute(
      path: AppRoutes.splashPath,
      name: AppRoutes.splash,
      builder: (context, state) => const SplashPage(),
    ),

    GoRoute(
      path: AppRoutes.loginPath,
      name: AppRoutes.login,
      builder: (context, state) => const LoginPage(),
    ),

    GoRoute(
      path: AppRoutes.homePath,
      name: AppRoutes.home,
      builder: (context, state) => const HomePage(),

      // Telas filhas entram como `routes:` daqui quando cada fase chegar. Rota
      // aninhada mantém o "voltar" coerente: de /expenses/:id o pop volta para
      // /expenses, não para a home.
    ),

    GoRoute(
      path: AppRoutes.incomesPath,
      name: AppRoutes.incomes,
      builder: (context, state) => const IncomeListPage(),
      routes: [
        // `form` **antes** de `:id`: o go_router casa na ordem, e invertido a
        // rota de formulário viraria um detalhe com id "form".
        GoRoute(
          path: AppRoutes.incomeFormPath,
          name: AppRoutes.incomeForm,
          builder: (context, state) => const IncomeFormPage(),
        ),
        GoRoute(
          path: AppRoutes.incomeDetailPath, // ':id', relativo — sem '/'
          name: AppRoutes.incomeDetail,
          builder: (context, state) =>
              IncomeDetailPage(id: state.pathParameters[RouteParams.id]!),
        ),
      ],
    ),

    GoRoute(
      path: AppRoutes.creditCardsPath,
      name: AppRoutes.creditCards,
      builder: (context, state) => const CreditCardListPage(),
      routes: [
        // `form` antes de `:id`, pela mesma razão de ganhos: o go_router casa na
        // ordem, e invertido a rota de cadastro viraria uma edição de id "form".
        GoRoute(
          path: AppRoutes.creditCardFormPath,
          name: AppRoutes.creditCardForm,
          builder: (context, state) => const CreditCardFormPage(),
        ),
        // `edit` também antes de `:id`, e pela mesma razão que `form`.
        GoRoute(
          path: AppRoutes.creditCardEditPath,
          name: AppRoutes.creditCardEdit,
          // O cartão vai inteiro por `extra`, e não por um id na rota: quem
          // empilha já tem o cartão na mão — é o mesmo que a lista desenhou —,
          // então buscá-lo de novo seria pedir o que já se tem.
          //
          // Sem `extra` — link colado, app reaberto na rota — o `card` vem
          // null e a tela abre em cadastro.
          builder: (context, state) =>
              CreditCardFormPage(card: state.extra as CreditCardModel?),
        ),
        GoRoute(
          path: AppRoutes.creditCardExpensesPath,
          name: AppRoutes.creditCardExpenses,
          builder: (context, state) =>
              CreditCardExpensesPage(id: state.pathParameters[RouteParams.id]!),
        ),
      ],
    ),

    GoRoute(
      path: AppRoutes.expensesPath,
      name: AppRoutes.expenses,
      // O filtro vem da query e é **lido aqui**, não dentro do controller: o
      // construtor do controller só recebe dependência, e dado de rota chega
      // pela view. Valor desconhecido cai em nulo — a lista completa —, que é o
      // que uma URL digitada errado deve dar, não uma tela de erro.
      builder: (context, state) => ExpenseListPage(
        paymentMethod: PaymentMethod.tryFromWire(
          state.uri.queryParameters[AppRoutes.paymentMethodParam],
        ),
      ),
      routes: [
        // `form` antes de `:id`, pela mesma razão de ganhos e cartões: o
        // go_router casa na ordem, e invertido a rota de cadastro viraria um
        // detalhe de id "form".
        GoRoute(
          path: AppRoutes.expenseFormPath,
          name: AppRoutes.expenseForm,
          builder: (context, state) => const ExpenseFormPage(),
        ),
        GoRoute(
          path: AppRoutes.expenseDetailPath,
          name: AppRoutes.expenseDetail,
          builder: (context, state) =>
              ExpenseDetailPage(id: state.pathParameters[RouteParams.id]!),
          routes: [
            // Filha do detalhe: fechar a edição volta para o gasto, que é de
            // onde se entrou nela.
            GoRoute(
              path: AppRoutes.expenseEditPath,
              name: AppRoutes.expenseEdit,
              builder: (context, state) =>
                  ExpenseFormPage(id: state.pathParameters[RouteParams.id]!),
            ),
          ],
        ),
      ],
    ),

    // Sem filhas e sem backend: a tela é só o aviso de "em desenvolvimento". A
    // rota entra agora para o menu ter um destino de verdade, em vez de um item
    // que não faz nada ao ser tocado.
    GoRoute(
      path: AppRoutes.tagsPath,
      name: AppRoutes.tags,
      builder: (context, state) => const TagListPage(),
    ),

    GoRoute(
      path: AppRoutes.notificationsPath,
      name: AppRoutes.notifications,
      builder: (context, state) => const NotificationListPage(),
    ),

    GoRoute(
      path: AppRoutes.projectionPath,
      name: AppRoutes.projection,
      builder: (context, state) => const ProjectionPage(),
    ),
  ],

  /// Cai aqui em URL que não existe — digitada, deep link antigo, typo em
  /// `goNamed`. Sem isto o go_router mostra uma tela de erro crua.
  errorBuilder: (context, state) =>
      _RouteErrorPage(location: state.uri.toString(), error: state.error),
);

class _RouteErrorPage extends StatelessWidget {
  const _RouteErrorPage({required this.location, this.error});

  final String location;
  final Exception? error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Tela não encontrada')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.wrong_location_outlined,
                size: 56,
                color: theme.colorScheme.outline,
              ),
              const SizedBox(height: 16),
              Text(
                'Nenhuma tela responde por este endereço.',
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                location,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
                textAlign: TextAlign.center,
              ),
              // O detalhe técnico só em debug: em release não diz nada ao usuário.
              if (kDebugMode && error != null) ...[
                const SizedBox(height: 8),
                Text(
                  '$error',
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => context.goNamed(AppRoutes.home),
                icon: const Icon(Icons.home_outlined),
                label: const Text('Ir para o início'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
