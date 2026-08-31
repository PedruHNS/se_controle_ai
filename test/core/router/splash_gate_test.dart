import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:se_controle_ai/core/router/app_router.dart';
import 'package:se_controle_ai/data/models/auth_user_model.dart';
import 'package:se_controle_ai/features/auth/view/login_page.dart';
import 'package:se_controle_ai/features/home/view/home_page.dart';

import '../../fixtures/mocks.dart';
import '../../fixtures/test_injector.dart';

/// A abertura do app, no intervalo em que ainda não se sabe quem está logado.
///
/// **Arquivo separado, e não mais um caso no `auth_redirect_test`.** O
/// `AuthRefresh` do router é global e assina o stream do primeiro repositório
/// que encontrar; assim que um evento chega, ele fica resolvido para o resto do
/// isolate. Testar a espera exige o primeiro contato com o `appRouter`
/// acontecendo aqui, com um stream que ainda não emitiu — o que só um arquivo
/// próprio garante, porque cada arquivo de teste roda no seu isolate.
void main() {
  testWidgets('a abertura espera o Firebase em vez de piscar o login', (
    tester,
  ) async {
    // O stream que não emitiu ainda: é o Firebase lendo a sessão do disco.
    final eventos = StreamController<AuthUserModel?>.broadcast();
    addTearDown(eventos.close);

    setupTestInjector();
    // `current: null` reproduz o instante real: o SDK ainda não restaurou a
    // sessão, então `currentUser` é nulo **mesmo em quem está logado**. É
    // exatamente aqui que o app decidia errado.
    setupAuthTestInjector(mock: authRepositoryMock(changes: eventos.stream));

    await tester.pumpWidget(MaterialApp.router(routerConfig: appRouter));
    await tester.pump();

    expect(find.byKey(const Key('splash-espera')), findsOneWidget);
    expect(
      find.byType(LoginPage),
      findsNothing,
      reason: 'o piscar do login é o bug que a espera existe para tirar',
    );

    // O SDK responde: havia sessão.
    setupAuthTestInjector(
      mock: authRepositoryMock(current: pedroLogado, changes: eventos.stream),
    );
    eventos.add(pedroLogado);
    await tester.pumpAndSettle();

    expect(find.byType(HomePage), findsOneWidget);
    expect(find.byKey(const Key('splash-espera')), findsNothing);
  });
}
