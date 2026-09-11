import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:multiple_result/multiple_result.dart';
import 'package:se_controle_ai/core/errors/failure.dart';
import 'package:se_controle_ai/data/models/auth_user_model.dart';
import 'package:se_controle_ai/features/auth/view/login_page.dart';

import '../../fixtures/mocks.dart';
import '../../fixtures/test_injector.dart';

void main() {
  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginPage()));
    await tester.pumpAndSettle();
  }

  testWidgets('deslogado, oferece o Google e nada mais', (tester) async {
    // Sem campo de e-mail, sem senha, sem "criar conta": a identidade é
    // externa (AUT-01), e a tela não pode sugerir que guarda alguma coisa.
    setupAuthTestInjector();
    await pump(tester);

    expect(find.byKey(const Key('login-google')), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.byKey(const Key('login-sair')), findsNothing);
  });

  testWidgets('tocar entra pelo Google', (tester) async {
    final repository = setupAuthTestInjector();
    await pump(tester);

    await tester.tap(find.byKey(const Key('login-google')));
    await tester.pumpAndSettle();

    verify(() => repository.signInWithGoogle()).called(1);
  });

  testWidgets('durante o login o botão não aceita segundo toque', (
    tester,
  ) async {
    // Dois toques abririam duas folhas de escolha de conta, e a segunda
    // cancela a primeira — o sintoma é "cliquei e não aconteceu nada".
    final mock = authRepositoryMock();
    when(() => mock.signInWithGoogle()).thenAnswer((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      return const Success(pedroLogado);
    });
    setupAuthTestInjector(mock: mock);

    await pump(tester);
    await tester.tap(find.byKey(const Key('login-google')));
    await tester.pump();

    expect(find.text('Entrando…'), findsOneWidget);
    await tester.tap(
      find.byKey(const Key('login-google')),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();

    verify(() => mock.signInWithGoogle()).called(1);
  });

  testWidgets('logado, diz quem entrou e oferece sair', (tester) async {
    setupAuthTestInjector(mock: authRepositoryMock(current: pedroLogado));
    await pump(tester);

    expect(find.byKey(const Key('login-quem-entrou')), findsOneWidget);
    expect(find.text('Pedro'), findsOneWidget);
    expect(find.byKey(const Key('login-google')), findsNothing);
    expect(find.byKey(const Key('login-sair')), findsOneWidget);
  });

  testWidgets('o logout vindo de fora devolve a tela ao botão de entrar', (
    tester,
  ) async {
    final eventos = StreamController<AuthUserModel?>();
    setupAuthTestInjector(
      mock: authRepositoryMock(current: pedroLogado, changes: eventos.stream),
    );
    await pump(tester);

    expect(find.byKey(const Key('login-quem-entrou')), findsOneWidget);

    eventos.add(null);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('login-google')), findsOneWidget);
    await eventos.close();
  });

  testWidgets('a falha fica na tela, junto do botão', (tester) async {
    // Aqui não vale toast: quem não conseguiu entrar continua nesta página, e
    // o aviso precisa estar visível ao lado do botão que se vai tocar de novo.
    setupAuthTestInjector(
      mock: authRepositoryMock(
        login: const Error(
          AuthFailure(message: 'Esta conta já entra por outro provedor.'),
        ),
      ),
    );
    await pump(tester);

    await tester.tap(find.byKey(const Key('login-google')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('login-erro')), findsOneWidget);
    expect(
      find.text('Esta conta já entra por outro provedor.'),
      findsOneWidget,
    );
  });

  testWidgets('desistir não deixa nada vermelho na tela', (tester) async {
    setupAuthTestInjector(
      mock: authRepositoryMock(
        login: const Error(CancelledFailure(message: 'Login cancelado.')),
      ),
    );
    await pump(tester);

    await tester.tap(find.byKey(const Key('login-google')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('login-erro')), findsNothing);
    expect(find.byKey(const Key('login-google')), findsOneWidget);
  });
}
