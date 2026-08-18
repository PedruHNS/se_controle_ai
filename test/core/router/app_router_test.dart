import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:se_controle_ai/core/router/app_router.dart';
import 'package:se_controle_ai/core/router/app_routes.dart';
import 'package:se_controle_ai/features/home/view/home_page.dart';

import '../../fixtures/test_injector.dart';

void main() {
  // A HomePage resolve HomeController do get_it, então o router não pode ser
  // testado sem as dependências registradas.
  setUp(setupTestInjector);

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
