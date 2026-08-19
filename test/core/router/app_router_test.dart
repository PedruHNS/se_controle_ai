import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:se_controle_ai/core/router/app_router.dart';
import 'package:se_controle_ai/core/router/app_routes.dart';
import 'package:se_controle_ai/features/credit_cards/view/credit_card_form_page.dart';
import 'package:se_controle_ai/features/credit_cards/view/credit_card_list_page.dart';
import 'package:se_controle_ai/features/home/view/home_page.dart';
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

  testWidgets('da home até o formulário de cartão, pela lista', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    // A linha da home é a única porta para o cadastro: as faturas do resumo só
    // aparecem quando existe gasto no mês. Ela fica no fim do resumo, e a
    // ListView não constrói o que está fora da tela — daí o scroll.
    await tester.scrollUntilVisible(find.text('Cartões'), 200);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cartões'));
    await tester.pumpAndSettle();

    expect(find.byType(CreditCardListPage), findsOneWidget);

    await tester.tap(find.widgetWithText(FloatingActionButton, 'Novo cartão'));
    await tester.pumpAndSettle();

    expect(find.byType(CreditCardFormPage), findsOneWidget);
    expect(find.text('Novo cartão'), findsWidgets);
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
