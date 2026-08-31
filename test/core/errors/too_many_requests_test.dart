import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:se_controle_ai/core/errors/app_exception.dart';
import 'package:se_controle_ai/core/errors/failure.dart';
import 'package:se_controle_ai/core/network/exception_mapper.dart';
import 'package:se_controle_ai/core/shared/widgets/failure_card_widget.dart';

/// Monta o 429 como o backend responde: envelope no corpo e `Retry-After` em
/// segundos no header (AUT-15).
DioException recusa({String? retryAfter}) {
  final options = RequestOptions(path: '/summary');

  return DioException(
    requestOptions: options,
    type: DioExceptionType.badResponse,
    response: Response<dynamic>(
      requestOptions: options,
      statusCode: 429,
      data: const {
        'code': 'TOO_MANY_REQUESTS',
        'message': 'Requisições demais. Aguarde um instante e tente de novo.',
      },
      headers: Headers.fromMap({
        if (retryAfter != null) 'retry-after': [retryAfter],
      }),
    ),
  );
}

void main() {
  group('429 do começo ao fim', () {
    test('o 429 vira TooManyRequestsException, e não erro inesperado', () {
      final exception = mapDioException(recusa(retryAfter: '900'));

      expect(exception, isA<TooManyRequestsException>());
      expect(exception.statusCode, 429);
      expect(exception.code, 'TOO_MANY_REQUESTS');
    });

    test('lê o Retry-After em segundos', () {
      final exception =
          mapDioException(recusa(retryAfter: '900'))
              as TooManyRequestsException;

      expect(exception.retryAfter, const Duration(seconds: 900));
    });

    // Sem número legível a espera fica desconhecida, e a mensagem tem que
    // funcionar assim — inclusive quando o servidor manda data HTTP em vez de
    // segundos, que a RFC admite e este app não interpreta.
    for (final (caso, header) in const [
      ('sem o header', null),
      ('com data HTTP', 'Wed, 21 Oct 2026 07:28:00 GMT'),
      ('com zero', '0'),
    ]) {
      test('espera desconhecida $caso', () {
        final exception =
            mapDioException(recusa(retryAfter: header))
                as TooManyRequestsException;

        expect(exception.retryAfter, isNull);
      });
    }

    test('a mensagem diz em quantos minutos, não em segundos', () {
      final failure = Failure.fromException(
        mapDioException(recusa(retryAfter: '900')),
      );

      expect(failure, isA<TooManyRequestsFailure>());
      expect(failure.message, contains('15 minutos'));
      expect(failure.message, isNot(contains('900')));
    });

    // Arredonda para cima: prometer menos do que falta produz uma segunda
    // recusa, que é pior do que esperar um pouco a mais.
    test('espera quebrada arredonda para o minuto de cima', () {
      final failure = Failure.fromException(
        mapDioException(recusa(retryAfter: '61')),
      );

      expect(failure.message, contains('2 minutos'));
    });

    test('espera curta fica em segundos', () {
      final failure = Failure.fromException(
        mapDioException(recusa(retryAfter: '30')),
      );

      expect(failure.message, contains('30 segundos'));
    });

    test('sem Retry-After, a mensagem fica genérica e ainda serve', () {
      final failure = Failure.fromException(mapDioException(recusa()));

      expect(failure.message, contains('Aguarde um instante'));
    });

    // A janela é de 15 minutos: o botão daria o mesmo erro em toda tentativa
    // até ela virar. É a mesma razão do 401 não ser retentável.
    test('não é retentável', () {
      final failure = Failure.fromException(
        mapDioException(recusa(retryAfter: '900')),
      );

      expect(failure.isRetryable, isFalse);
    });

    testWidgets('o card explica a espera e não oferece "tentar de novo"', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FailureCardWidget(
              failure: const TooManyRequestsFailure(),
              // Passado de propósito: mesmo com callback, o isRetryable manda.
              onRetry: () async {},
            ),
          ),
        ),
      );

      expect(find.text('Muitas tentativas'), findsOneWidget);
      expect(find.text('Tentar de novo'), findsNothing);
    });
  });
}
