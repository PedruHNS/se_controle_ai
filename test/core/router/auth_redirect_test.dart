import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:se_controle_ai/core/router/app_router.dart';
import 'package:se_controle_ai/core/router/app_routes.dart';
import 'package:se_controle_ai/data/models/auth_user_model.dart';
import 'package:se_controle_ai/features/auth/view/login_page.dart';
import 'package:se_controle_ai/features/home/view/home_page.dart';

import '../../fixtures/mocks.dart';
import '../../fixtures/test_injector.dart';

void main() {
  setUp(setupTestInjector);

  // O appRouter é global e guarda a pilha entre testes, como o app_router_test
  // já registra. Sem devolver à home, o teste seguinte começa onde este parou.
  tearDown(() {
    setupAuthTestInjector(mock: authRepositoryMock(current: pedroLogado));
    appRouter.go(AppRoutes.homePath);
  });

  Widget app() => MaterialApp.router(routerConfig: appRouter);

  Future<void> irPara(WidgetTester tester, String rota) async {
    await tester.pumpWidget(app());
    appRouter.go(rota);
    await tester.pumpAndSettle();
  }

  testWidgets('deslogado, a home vira login', (tester) async {
    setupAuthTestInjector();

    await irPara(tester, AppRoutes.homePath);

    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.byType(HomePage), findsNothing);
  });

  testWidgets('deslogado, nenhuma tela interna abre', (tester) async {
    // A tranca não é só da home: entrar direto em /expenses por link também
    // precisa parar no login, senão a tela carregaria e levaria 401.
    setupAuthTestInjector();

    await irPara(tester, AppRoutes.expensesPath);

    expect(find.byType(LoginPage), findsOneWidget);
  });

  testWidgets('logado, a home abre normalmente', (tester) async {
    await irPara(tester, AppRoutes.homePath);

    expect(find.byType(HomePage), findsOneWidget);
    expect(find.byType(LoginPage), findsNothing);
  });

  testWidgets('logado, o login não tem o que mostrar', (tester) async {
    // Vale inclusive para quem chega por link ou por `--route=/login`, que era
    // como esta tela era alcançada antes de o redirect existir.
    await irPara(tester, AppRoutes.loginPath);

    expect(find.byType(HomePage), findsOneWidget);
  });

  testWidgets('sair leva de volta ao login, sem ninguém navegar', (
    tester,
  ) async {
    // Quem tira a pessoa da tela é o redirect, avisado pelo AuthRefresh — não
    // um `go` escrito no botão. Dois caminhos para a mesma decisão teriam que
    // concordar para sempre.
    final eventos = StreamController<AuthUserModel?>.broadcast();
    setupAuthTestInjector(
      mock: authRepositoryMock(current: pedroLogado, changes: eventos.stream),
    );

    await irPara(tester, AppRoutes.homePath);
    expect(find.byType(HomePage), findsOneWidget);

    // O logout de verdade: o repositório passa a não ter mais ninguém, e o
    // stream avisa.
    setupAuthTestInjector(mock: authRepositoryMock(changes: eventos.stream));
    appRouter.go(AppRoutes.homePath);
    await tester.pumpAndSettle();

    expect(find.byType(LoginPage), findsOneWidget);

    await eventos.close();
  });
}
