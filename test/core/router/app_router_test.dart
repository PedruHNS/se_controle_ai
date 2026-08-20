import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:se_controle_ai/core/router/app_router.dart';
import 'package:se_controle_ai/core/router/app_routes.dart';
import 'package:se_controle_ai/features/credit_cards/view/credit_card_expenses_page.dart';
import 'package:se_controle_ai/features/credit_cards/view/credit_card_form_page.dart';
import 'package:se_controle_ai/features/credit_cards/view/credit_card_list_page.dart';
import 'package:se_controle_ai/features/home/view/home_page.dart';
import 'package:se_controle_ai/features/expenses/view/expense_detail_page.dart';
import 'package:se_controle_ai/features/expenses/view/expense_form_page.dart';
import 'package:se_controle_ai/features/expenses/view/expense_list_page.dart';
import 'package:se_controle_ai/features/incomes/view/income_form_page.dart';
import 'package:se_controle_ai/features/incomes/view/income_list_page.dart';

import '../../fixtures/test_injector.dart';

void main() {
  // A HomePage resolve HomeController do get_it, então o router não pode ser
  // testado sem as dependências registradas.
  setUp(() {
    setupTestInjector();
    setupIncomeTestInjector();
    setupCreditCardTestInjector();
    setupExpenseTestInjector();
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

    await tester.tap(find.widgetWithText(FloatingActionButton, 'Novo cartão'));
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

  // A edição de gasto é filha do detalhe (`/expenses/:id/edit`), e não irmã:
  // fechar a edição tem que voltar para o gasto, não para a lista.
  testWidgets('a edição de gasto abre a partir do detalhe', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    appRouter.goNamed(
      AppRoutes.expenseDetail,
      pathParameters: {RouteParams.id: 'gasto-1'},
    );
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

    await tester.tap(find.text('Nubank ••••4321').first);
    await tester.pumpAndSettle();

    expect(find.byType(CreditCardExpensesPage), findsOneWidget);

    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();

    expect(find.byType(CreditCardFormPage), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.byType(CreditCardExpensesPage), findsOneWidget);
  });

  // `form` antes de `:id` no router: invertido, esta rota viraria uma edição de
  // cartão com id "form".
  testWidgets('a rota de edição abre o formulário preenchido', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    appRouter.goNamed(
      AppRoutes.creditCardEdit,
      pathParameters: {RouteParams.id: 'id-nubank'},
    );
    await tester.pumpAndSettle();

    expect(find.byType(CreditCardFormPage), findsOneWidget);
    expect(find.text('Editar cartão'), findsOneWidget);
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
