import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:se_controle_ai/core/di/injector.dart';
import 'package:se_controle_ai/core/router/app_router.dart';
import 'package:se_controle_ai/core/router/app_routes.dart';
import 'package:se_controle_ai/data/models/credit_card_model.dart';
import 'package:se_controle_ai/data/models/expense_model.dart';
import 'package:se_controle_ai/data/services/navigation_service.dart';
import 'package:se_controle_ai/features/credit_cards/view/credit_card_expenses_page.dart';
import 'package:se_controle_ai/features/credit_cards/view/credit_card_form_page.dart';
import 'package:se_controle_ai/features/credit_cards/view/credit_card_list_page.dart';
import 'package:se_controle_ai/features/home/view/home_page.dart';
import 'package:se_controle_ai/features/expenses/view/expense_detail_page.dart';
import 'package:se_controle_ai/features/expenses/view/expense_form_page.dart';
import 'package:se_controle_ai/features/expenses/view/expense_list_page.dart';
import 'package:se_controle_ai/features/incomes/view/income_form_page.dart';
import 'package:se_controle_ai/features/incomes/view/income_list_page.dart';

import '../../fixtures/credit_card_fixture.dart';
import '../../fixtures/expense_fixture.dart';
import '../../fixtures/test_injector.dart';

void main() {
  // A HomePage resolve HomeController do get_it, então o router não pode ser
  // testado sem as dependências registradas.
  setUp(() {
    setupTestInjector();
    setupIncomeTestInjector();
    setupCreditCardTestInjector();
    setupExpenseTestInjector();

    // Aqui a navegação é a de verdade, e é o único lugar onde ela é.
    //
    // Os injectors de teste registram um `NavigationService` dublê, para um
    // diálogo fechado num teste não mexer na pilha do seguinte. Este arquivo
    // testa justamente o router, então precisa do oposto: a lista de cartões
    // empilha por `_nav.pushNamed`, e com o dublê o toque no cartão não sai do
    // lugar.
    //
    // Trocado **depois** dos setups, e não antes: `appRouter` é global e
    // preguiçoso, e o `redirect` dele resolve o `AuthRepository` na primeira
    // vez que alguém o toca. Tocá-lo antes de registrar os mocks estoura com
    // "AuthRepository is not registered".
    if (getIt.isRegistered<NavigationService>()) {
      getIt.unregister<NavigationService>();
    }
    getIt.registerSingleton<NavigationService>(NavigationService(appRouter));
  });

  // O appRouter é global e guarda a pilha de navegação entre testes; sem isto,
  // o teste do 404 deixaria o router fora da home para o teste seguinte.
  tearDown(() async {
    appRouter.go(AppRoutes.homePath);
    // await resetInjector();
  });

  Widget app() => MaterialApp.router(routerConfig: appRouter);

  testWidgets('rota inicial resolve na home', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.byType(HomePage), findsOneWidget);
  });

  testWidgets('goNamed pelo nome da rota chega na home', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    appRouter.goNamed(AppRoutes.home);
    await tester.pumpAndSettle();

    expect(find.byType(HomePage), findsOneWidget);
  });

  // O formulário não é alcançável a partir da home em um toque: o caminho é
  // seção "Ganhos" → lista → FAB. Este teste anda a corrente inteira, porque é
  // ela que o usuário anda — e é onde um `pushNamed` errado apareceria.
  testWidgets('da home até o formulário de ganho, pela lista', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ganhos'));
    await tester.pumpAndSettle();

    expect(find.byType(IncomeListPage), findsOneWidget);

    // Pelo tipo do botão, e não por `find.text`: o rótulo do FAB e o título do
    // formulário são os dois "Novo ganho".
    await tester.tap(find.widgetWithText(FloatingActionButton, 'Novo ganho'));
    await tester.pumpAndSettle();

    expect(find.byType(IncomeFormPage), findsOneWidget);
  });

  testWidgets('da home até o formulário de cartão, pelo menu', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    // O menu lateral é a porta do cadastro de cartão: as faturas do resumo só
    // aparecem quando existe gasto no mês, e nunca houve uma linha "Cartões" na
    // home — este teste procurava por ela e ficou vermelho da Fase 3 até a 4.
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cartões'));
    await tester.pumpAndSettle();

    expect(find.byType(CreditCardListPage), findsOneWidget);

    // Pelo ícone: o FAB da lista deixou de ser `extended` e não tem mais
    // rótulo. O texto "Novo cartão" agora só existe na tela de destino, que é
    // justamente o que a asserção lá embaixo confere.
    await tester.tap(
      find.descendant(
        of: find.byType(FloatingActionButton),
        matching: find.byIcon(Icons.add),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CreditCardFormPage), findsOneWidget);
    expect(find.text('Novo cartão'), findsWidgets);
  });

  // A corrente da Fase 4, ponta a ponta: menu → lista de gastos → formulário.
  testWidgets('da home até o formulário de gasto, pelo menu', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Gastos'));
    await tester.pumpAndSettle();

    expect(find.byType(ExpenseListPage), findsOneWidget);

    await tester.tap(find.widgetWithText(FloatingActionButton, 'Novo gasto'));
    await tester.pumpAndSettle();

    expect(find.byType(ExpenseFormPage), findsOneWidget);
  });

  // A edição de gasto é filha do detalhe (`/expenses/detail/edit`), e não irmã:
  // fechar a edição tem que voltar para o gasto, não para a lista.
  testWidgets('a edição de gasto abre a partir do detalhe', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    final aluguel = ExpenseModel.fromJson(aluguelJson);
    appRouter.goNamed(AppRoutes.expenseDetail, extra: aluguel);
    await tester.pumpAndSettle();

    expect(find.byType(ExpenseDetailPage), findsOneWidget);

    await tester.tap(find.text('Editar dados'));
    await tester.pumpAndSettle();

    expect(find.byType(ExpenseFormPage), findsOneWidget);
    expect(find.text('Editar gasto'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.byType(ExpenseDetailPage), findsOneWidget);
  });

  // O toque num cartão abre o cartão, e a edição é filha dele: fechar a edição
  // volta para o cartão, não para a lista.
  testWidgets('do cartão da lista até a edição, e de volta', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cartões'));
    await tester.pumpAndSettle();

    // O nome puro, e não o `label` do CAR-06: o tile passou a mostrar só o
    // nome do cartão.
    await tester.tap(find.text('Nubank').first);
    await tester.pumpAndSettle();

    expect(find.byType(CreditCardExpensesPage), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    // A edição entra pelo menu do card, e não mais pelo lápis da fatura: a
    // lista é quem conhece o cadastro inteiro. Voltar cai na lista, que é de
    // onde a tela foi empilhada.
    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();

    expect(find.byType(CreditCardFormPage), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.byType(CreditCardListPage), findsOneWidget);
  });

  // O detalhe do gasto não tem id na rota: o gasto vai por `extra`. Daqui ele é
  // aberto de fora de /expenses, e voltar tem que cair no cartão.
  testWidgets('o gasto da fatura abre o detalhe, e volta ao cartão', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    appRouter.goNamed(
      AppRoutes.creditCardExpenses,
      pathParameters: {RouteParams.id: 'cartao-1'},
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Aluguel'));
    await tester.pumpAndSettle();

    expect(find.byType(ExpenseDetailPage), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.byType(CreditCardExpensesPage), findsOneWidget);
  });

  // `form` e `edit` antes de `:id` no router: invertido, estas rotas virariam
  // a tela de um cartão de id "form" ou "edit".
  testWidgets('a rota de edição abre o formulário preenchido', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    // Só o cartão, sem id na rota: quem preenche a tela é o objeto, e não havia
    // ninguém do outro lado para ler o id.
    appRouter.goNamed(
      AppRoutes.creditCardEdit,
      extra: CreditCardModel.fromJson(nubankJson),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CreditCardFormPage), findsOneWidget);
    expect(find.text('Editar cartão'), findsOneWidget);
    // Preenchido, e não só aberto: é o `extra` chegando no `loadCardCredit` —
    // a rota entregando o cartão não vale de nada se o form não o receber.
    expect(find.text('Nubank'), findsOneWidget);
  });

  testWidgets('endereço inexistente cai no errorBuilder, não em tela crua', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    appRouter.go('/rota-que-nao-existe');
    await tester.pumpAndSettle();

    expect(find.text('Tela não encontrada'), findsOneWidget);
    expect(find.text('/rota-que-nao-existe'), findsOneWidget);
    expect(find.byType(HomePage), findsNothing);
  });

  testWidgets('o botão da tela de erro volta para a home', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    appRouter.go('/nao-existe');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ir para o início'));
    await tester.pumpAndSettle();

    expect(find.byType(HomePage), findsOneWidget);
  });
}
