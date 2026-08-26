import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:multiple_result/multiple_result.dart';
import 'package:se_controle_ai/core/errors/failure.dart';
import 'package:se_controle_ai/data/models/auth_user_model.dart';
import 'package:se_controle_ai/features/auth/controller/login_controller.dart';

import '../../fixtures/mocks.dart';

void main() {
  late MockAuthRepository repository;

  LoginController comRepositorio(MockAuthRepository mock) {
    repository = mock;
    return LoginController(mock);
  }

  test('nasce sabendo quem já estava logado', () {
    // Reabrir o app com sessão viva não pode mostrar a tela de "entre com o
    // Google" por um instante antes de perceber que já há alguém.
    final controller = comRepositorio(authRepositoryMock(current: pedroLogado));

    expect(controller.user.value?.uid, 'uid-do-pedro');
    controller.dispose();
  });

  test('acompanha o logout vindo de fora', () async {
    // O token pode ser revogado do lado do Firebase, e aí a sessão cai sem
    // ninguém ter tocado em nada. Sem escutar o stream, a tela continuaria
    // dizendo que há alguém logado.
    final eventos = StreamController<AuthUserModel?>();
    final controller = comRepositorio(
      authRepositoryMock(current: pedroLogado, changes: eventos.stream),
    );

    eventos.add(null);
    await Future<void>.delayed(Duration.zero);

    expect(controller.user.value, isNull);

    await eventos.close();
    controller.dispose();
  });

  group('entrar', () {
    test('marca trabalhando enquanto a folha está aberta', () async {
      final mock = authRepositoryMock();
      when(() => mock.signInWithGoogle()).thenAnswer((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 30));
        return const Success(pedroLogado);
      });
      final controller = comRepositorio(mock);

      final futuro = controller.signInWithGoogle();
      expect(controller.working.value, isTrue);

      await futuro;
      expect(controller.working.value, isFalse);

      controller.dispose();
    });

    test('desistir não deixa aviso na tela', () async {
      // Fechar a folha de escolha de conta é mudança de ideia, não erro. Um
      // aviso vermelho aqui seria algo para a pessoa dispensar sem motivo.
      final controller = comRepositorio(
        authRepositoryMock(
          login: const Error(CancelledFailure(message: 'Login cancelado.')),
        ),
      );

      await controller.signInWithGoogle();

      expect(controller.failure.value, isNull);
      controller.dispose();
    });

    test('falha de verdade fica visível junto do botão', () async {
      final controller = comRepositorio(
        authRepositoryMock(
          login: const Error(AuthFailure(message: 'Não foi possível entrar.')),
        ),
      );

      await controller.signInWithGoogle();

      expect(controller.failure.value?.message, 'Não foi possível entrar.');
      controller.dispose();
    });

    test('nova tentativa limpa o aviso anterior', () async {
      // Sem isto, o erro da tentativa passada fica embaixo do botão enquanto a
      // nova roda — e some só no fim, o que se lê como "falhou de novo".
      final mock = authRepositoryMock(
        login: const Error(AuthFailure(message: 'Não foi possível entrar.')),
      );
      final controller = comRepositorio(mock);

      await controller.signInWithGoogle();
      expect(controller.failure.value, isNotNull);

      when(
        () => mock.signInWithGoogle(),
      ).thenAnswer((_) async => const Success(pedroLogado));
      await controller.signInWithGoogle();

      expect(controller.failure.value, isNull);
      controller.dispose();
    });
  });

  group('sair', () {
    test('chama o repositório', () async {
      final controller = comRepositorio(
        authRepositoryMock(current: pedroLogado),
      );

      await controller.signOut();

      verify(() => repository.signOut()).called(1);
      controller.dispose();
    });

    test('falha ao sair aparece na tela', () async {
      final mock = authRepositoryMock(current: pedroLogado);
      when(() => mock.signOut()).thenAnswer(
        (_) async => const Error(NetworkFailure()),
      );
      final controller = comRepositorio(mock);

      await controller.signOut();

      expect(controller.failure.value, isA<NetworkFailure>());
      controller.dispose();
    });
  });
}
