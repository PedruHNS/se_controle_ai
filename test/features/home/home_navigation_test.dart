import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:se_controle_ai/core/router/app_router.dart';
import 'package:se_controle_ai/core/router/app_routes.dart';
import 'package:se_controle_ai/core/shared/widgets/app_drawer.dart';
import 'package:se_controle_ai/features/credit_cards/view/credit_card_list_page.dart';
import 'package:se_controle_ai/features/expenses/view/expense_form_page.dart';
import 'package:se_controle_ai/features/expenses/view/expense_list_page.dart';
import 'package:se_controle_ai/features/home/widgets/home_fab.dart';
import 'package:se_controle_ai/features/incomes/view/income_form_page.dart';
import 'package:se_controle_ai/features/incomes/view/income_list_page.dart';
import 'package:se_controle_ai/features/notifications/view/notification_list_page.dart';
import 'package:se_controle_ai/features/projection/view/projection_page.dart';
import 'package:se_controle_ai/features/tags/view/tag_list_page.dart';

import '../../fixtures/test_injector.dart';
import 'package:se_controle_ai/data/enums/payment_method.dart';

void main() {
  // O drawer navega de verdade, então o teste roda sobre o router do app e não
  // sobre um MaterialApp cru: com `home:` os `pushNamed` não achariam rota.
  setUp(() {
    setupTestInjector();
    setupIncomeTestInjector();
    setupCreditCardTestInjector();
    setupExpenseTestInjector();
    setupTagTestInjector();
  });

  // O appRouter é global e guarda a pilha entre testes.
  tearDown(() => appRouter.go(AppRoutes.homePath));

  Widget app() => MaterialApp.router(routerConfig: appRouter);

  Future<void> openDrawer(WidgetTester tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
  }

  /// Escopo no Drawer: "Ganhos" também é o título de uma seção da home, e sem
  /// isto o `find.text` acharia os dois.
  Finder item(String label) =>
      find.descendant(of: find.byType(AppDrawer), matching: find.text(label));

  testWidgets('o menu da home abre o drawer com os cinco destinos', (
    tester,
  ) async {
    await openDrawer(tester);

    expect(item('Ganhos'), findsOneWidget);
    expect(item('Gastos'), findsOneWidget);
    expect(item('Cartões'), findsOneWidget);
    expect(item('Projeção'), findsOneWidget);
    expect(item('Tags'), findsOneWidget);
  });

  testWidgets('Projeção leva à tela de projeção', (tester) async {
    await openDrawer(tester);

    await tester.tap(item('Projeção'));
    await tester.pumpAndSettle();

    expect(find.byType(ProjectionPage), findsOneWidget);
  });

  testWidgets('Gastos leva à lista de gastos', (tester) async {
    await openDrawer(tester);

    await tester.tap(item('Gastos'));
    await tester.pumpAndSettle();

    expect(find.byType(ExpenseListPage), findsOneWidget);
  });

  testWidgets('Cartões leva à lista de cartões', (tester) async {
    await openDrawer(tester);

    await tester.tap(item('Cartões'));
    await tester.pumpAndSettle();

    expect(find.byType(CreditCardListPage), findsOneWidget);
  });

  testWidgets('Ganhos leva à lista de ganhos', (tester) async {
    await openDrawer(tester);

    await tester.tap(item('Ganhos'));
    await tester.pumpAndSettle();

    expect(find.byType(IncomeListPage), findsOneWidget);
  });

  testWidgets('Tags leva à tela de tags', (tester) async {
    await openDrawer(tester);

    await tester.tap(item('Tags'));
    await tester.pumpAndSettle();

    expect(find.byType(TagListPage), findsOneWidget);
    // Deixou de ser placeholder na Etapa 6: a lista vem do backend.
    expect(find.text('Moradia'), findsOneWidget);
  });

  testWidgets('o sino da AppBar leva às notificações, ainda vazias', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.notifications_none));
    await tester.pumpAndSettle();

    expect(find.byType(NotificationListPage), findsOneWidget);
    expect(find.text('Nada por aqui ainda'), findsOneWidget);
    expect(find.byType(ListTile), findsNothing);
  });

  // O drawer fecha antes de navegar: aberto, ele é uma entrada no histórico
  // local, e o primeiro "voltar" da tela nova só o fecharia.
  testWidgets('voltar da tela aberta pelo menu devolve para a home', (
    tester,
  ) async {
    await openDrawer(tester);

    await tester.tap(item('Tags'));
    await tester.pumpAndSettle();

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.byType(TagListPage), findsNothing);
    expect(find.byType(AppDrawer), findsNothing);
    expect(find.byIcon(Icons.menu), findsOneWidget);
  });

  // As duas seções de gasto da home levam à mesma tela, com filtros
  // diferentes. É o que permite a lista continuar sendo uma só.
  group('seções de gasto', () {
    /// A home é mais alta que o surface padrão do teste, e o que está fora do
    /// viewport de um sliver não está na árvore para ser tocado.
    Future<void> abrirHome(WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
    }

    testWidgets('"Dinheiro e crédito" leva à lista inteira', (tester) async {
      await abrirHome(tester);

      await tester.tap(find.text('Dinheiro e crédito'));
      await tester.pumpAndSettle();

      final page = tester.widget<ExpenseListPage>(
        find.byType(ExpenseListPage),
      );
      expect(page.paymentMethod, isNull);
      expect(find.text('Gastos'), findsWidgets);
    });

    testWidgets('"Dinheiro" leva à mesma lista, filtrada no débito', (
      tester,
    ) async {
      await abrirHome(tester);

      await tester.tap(find.text('Dinheiro'));
      await tester.pumpAndSettle();

      final page = tester.widget<ExpenseListPage>(
        find.byType(ExpenseListPage),
      );
      expect(page.paymentMethod, PaymentMethod.debit);
      // O título separa os dois destinos: sem ele, o recorte é
      // indistinguível da lista completa que veio faltando.
      expect(find.text('Gastos no dinheiro'), findsOneWidget);
    });
  });

  // O botão de criar da home é o atalho para o cadastro: sem ele, lançar um
  // gasto custa abrir o menu, entrar na lista e só ali achar o `+`.
  group('botão de criar', () {
    /// As opções do menu são só ícone, e os mesmos dois ícones abrem as seções
    /// no corpo da home — daí o escopo no [HomeFab].
    Finder opcao(IconData icone) =>
        find.descendant(of: find.byType(HomeFab), matching: find.byIcon(icone));

    Future<void> abrirMenu(WidgetTester tester) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
    }

    testWidgets('Novo gasto leva ao formulário de gasto', (tester) async {
      await abrirMenu(tester);

      await tester.tap(opcao(Icons.payments_outlined));
      await tester.pumpAndSettle();

      expect(find.byType(ExpenseFormPage), findsOneWidget);
    });

    testWidgets('Novo ganho leva ao formulário de ganho', (tester) async {
      await abrirMenu(tester);

      await tester.tap(opcao(Icons.trending_up));
      await tester.pumpAndSettle();

      expect(find.byType(IncomeFormPage), findsOneWidget);
    });

    // Voltar do formulário cai na home, e não na lista do assunto: o caminho
    // foi o atalho, não o menu.
    testWidgets('voltar do formulário devolve para a home, com o menu fechado', (
      tester,
    ) async {
      await abrirMenu(tester);

      await tester.tap(opcao(Icons.payments_outlined));
      await tester.pumpAndSettle();

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.byType(ExpenseFormPage), findsNothing);
      expect(find.byType(ExpenseListPage), findsNothing);
      expect(find.byIcon(Icons.menu), findsOneWidget);
      expect(opcao(Icons.payments_outlined).hitTestable(), findsNothing);
    });
  });
}
