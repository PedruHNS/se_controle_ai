import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:se_controle_ai/core/router/app_router.dart';
import 'package:se_controle_ai/core/router/app_routes.dart';
import 'package:se_controle_ai/core/shared/widgets/app_drawer.dart';
import 'package:se_controle_ai/features/credit_cards/view/credit_card_list_page.dart';
import 'package:se_controle_ai/features/incomes/view/income_list_page.dart';
import 'package:se_controle_ai/features/notifications/view/notification_list_page.dart';
import 'package:se_controle_ai/features/tags/view/tag_list_page.dart';

import '../../fixtures/test_injector.dart';

void main() {
  // O drawer navega de verdade, então o teste roda sobre o router do app e não
  // sobre um MaterialApp cru: com `home:` os `pushNamed` não achariam rota.
  setUp(() {
    setupTestInjector();
    setupIncomeTestInjector();
    setupCreditCardTestInjector();
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

  testWidgets('o menu da home abre o drawer com os três destinos', (
    tester,
  ) async {
    await openDrawer(tester);

    expect(item('Ganhos'), findsOneWidget);
    expect(item('Cartões'), findsOneWidget);
    expect(item('Tags'), findsOneWidget);
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

  testWidgets('Tags leva ao aviso de tela em desenvolvimento', (tester) async {
    await openDrawer(tester);

    await tester.tap(item('Tags'));
    await tester.pumpAndSettle();

    expect(find.byType(TagListPage), findsOneWidget);
    expect(find.text('Em desenvolvimento'), findsOneWidget);
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
}
