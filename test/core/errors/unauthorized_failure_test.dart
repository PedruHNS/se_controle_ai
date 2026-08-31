import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:se_controle_ai/core/errors/app_exception.dart';
import 'package:se_controle_ai/core/errors/failure.dart';
import 'package:se_controle_ai/core/shared/widgets/failure_card_widget.dart';

void main() {
  // A frase é a que o backend devolve hoje, para os dois casos que ele não
  // distingue de propósito: token ausente e token que não serve mais (AUT-06).
  const exception = UnauthorizedException(
    message: 'Token ausente, inválido ou expirado',
    code: 'UNAUTHORIZED',
  );

  group('401 do começo ao fim', () {
    test('a exceção vira UnauthorizedFailure', () {
      final failure = Failure.fromException(exception);

      expect(failure, isA<UnauthorizedFailure>());
      expect(failure.code, 'UNAUTHORIZED');
    });

    // A mensagem do backend descreve o problema para quem opera o servidor.
    // Quem está olhando a tela não sabe o que é um token — sabe que entrou e
    // que agora não está mais entrando.
    test('a mensagem é a do app, não a do backend', () {
      final failure = Failure.fromException(exception);

      expect(failure.message, isNot(contains('Token')));
      expect(failure.message, contains('sessão expirou'));
    });

    // O AuthInterceptor já renovou o token e repetiu uma vez antes de a falha
    // chegar aqui. Se chegou, repetir de novo dá o mesmo 401 — o botão seria
    // uma promessa falsa.
    test('não é retentável', () {
      expect(Failure.fromException(exception).isRetryable, isFalse);
    });

    testWidgets('o card não oferece "tentar de novo"', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FailureCardWidget(
              failure: const UnauthorizedFailure(),
              // Passado de propósito: mesmo com callback, o isRetryable manda.
              onRetry: () async {},
            ),
          ),
        ),
      );

      expect(find.text('Sessão expirada'), findsOneWidget);
      expect(find.text('Tentar de novo'), findsNothing);
    });
  });
}
