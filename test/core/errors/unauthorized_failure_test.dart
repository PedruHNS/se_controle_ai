import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:se_controle_ai/core/errors/app_exception.dart';
import 'package:se_controle_ai/core/errors/failure.dart';
import 'package:se_controle_ai/core/shared/widgets/failure_card_widget.dart';

void main() {
  const exception = UnauthorizedException(
    message: 'Chave de API ausente ou inválida',
    code: 'UNAUTHORIZED',
  );

  group('401 do começo ao fim', () {
    test('a exceção vira UnauthorizedFailure', () {
      final failure = Failure.fromException(exception);

      expect(failure, isA<UnauthorizedFailure>());
      expect(failure.code, 'UNAUTHORIZED');
    });

    // A mensagem do backend descreve o problema para quem opera o servidor.
    // Quem está olhando a tela não sabe o que é uma chave de API.
    test('a mensagem é a do app, não a do backend', () {
      final failure = Failure.fromException(exception);

      expect(failure.message, isNot(contains('Chave de API')));
      expect(failure.message, contains('não conseguiu se identificar'));
    });

    // É a diferença que importa: repetir com a mesma chave dá o mesmo 401 para
    // sempre, então o botão seria uma promessa falsa.
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

      expect(find.text('Acesso negado'), findsOneWidget);
      expect(find.text('Tentar de novo'), findsNothing);
    });
  });
}
