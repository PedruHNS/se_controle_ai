import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:se_controle_ai/core/errors/app_exception.dart';
import 'package:se_controle_ai/core/network/api_client.dart';
import 'package:se_controle_ai/core/network/dio_factory.dart';

/// Adapter mockado: a rede nunca é tocada, e o teste manda o que ela responde.
/// Deixa os testes determinísticos e independentes do backend estar de pé.
class MockHttpClientAdapter extends Mock implements HttpClientAdapter {}

ResponseBody _json(Object? body, int status) => ResponseBody.fromString(
  body == null ? '' : jsonEncode(body),
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

/// Monta o client real (mesmo `buildDio` da produção) com a rede substituída.
({ApiClient client, MockHttpClientAdapter adapter}) clientThatReturns(
  Future<ResponseBody> Function(RequestOptions options) responder,
) {
  final adapter = MockHttpClientAdapter();
  when(() => adapter.fetch(any(), any(), any())).thenAnswer(
    (invocation) =>
        responder(invocation.positionalArguments.first as RequestOptions),
  );

  final dio = buildDio();
  dio.httpClientAdapter = adapter;
  return (client: ApiClient(dio), adapter: adapter);
}

/// A requisição que chegou ao adapter. `verify` **consome** o que foi gravado,
/// então use uma vez por teste.
RequestOptions lastRequestOf(MockHttpClientAdapter adapter) =>
    verify(() => adapter.fetch(captureAny(), any(), any())).captured.last
        as RequestOptions;

void main() {
  // `any()` de um tipo não nulo precisa de um valor de reserva registrado —
  // mocktail usa ele só para casar a assinatura, nunca para responder.
  setUpAll(() => registerFallbackValue(RequestOptions()));

  group('devolve o Response do Dio, sem decodificar o corpo', () {
    test('objeto vem como Response<dynamic>', () async {
      final (client: client, adapter: _) = clientThatReturns(
        (_) async => _json({'status': 'ok'}, 200),
      );

      final json = await client.get('/health');

      expect(json, isA<Response<dynamic>>());
      expect(json.data, isA<Map<String, dynamic>>());
      expect(json.data['status'], 'ok');
    });

    test('corpo de lista vem como List no data', () async {
      final (client: client, adapter: _) = clientThatReturns(
        (_) async => _json([
          {'id': 'a'},
          {'id': 'b'},
        ], 200),
      );

      final json = await client.get('/incomes');

      expect(json, isA<Response<dynamic>>());
      expect(json.data, isA<List<dynamic>>());
      expect(json.data, hasLength(2));
      // O cast para model é trabalho do repositório, e Decode ajuda nele — mas
      // recebendo o `data`, não o `Response`.
      expect(Decode.listOf(json.data, (item) => item['id'] as String), [
        'a',
        'b',
      ]);
    });

    test('patch envia o corpo e devolve o Response', () async {
      final (client: client, adapter: adapter) = clientThatReturns(
        (_) async => _json({'id': 'x', 'amountCents': 550000}, 200),
      );

      final response = await client.patch(
        '/incomes/x/amount',
        data: {'amountCents': 550000},
      );

      final request = lastRequestOf(adapter);
      expect(request.method, 'PATCH');
      expect(request.data, {'amountCents': 550000});
      expect(response, isA<Response<dynamic>>());
      expect(response.data['amountCents'], 550000);
    });

    test('204 sem corpo não estoura — devolve vazio', () async {
      final (client: client, adapter: _) = clientThatReturns(
        (_) async => _json(null, 204),
      );

      final json = await client.delete('/incomes/x');

      expect(json, isA<Response<dynamic>>());
      expect(json.data, anyOf(isNull, isEmpty));
    });
  });

  group('query string', () {
    // O dio serializa `{'month': null}` como `?month` — chave pelada, sem `=`.
    // O Express entrega isso ao zod como string vazia, e os schemas do backend
    // são `optional()`: aceitam ausência e recusam vazio. Por isso a asserção
    // é sobre a **URI inteira**: procurar por `month=` deixaria passar `?month`,
    // que foi exatamente o que aconteceu.
    test('parâmetro nulo desaparece da URL, senão o zod recusa', () async {
      final (client: client, adapter: adapter) = clientThatReturns(
        (_) async => _json({'month': '2026-08'}, 200),
      );

      await client.get(
        '/summary',
        queryParameters: {'month': null, 'months': 12},
      );

      final uri = lastRequestOf(adapter).uri;
      expect(uri.queryParameters, {'months': '12'});
      expect(uri.query, 'months=12');
      expect(uri.toString(), isNot(contains('month&')));
    });

    test('query só de nulos não deixa nem a interrogação', () async {
      final (client: client, adapter: adapter) = clientThatReturns(
        (_) async => _json([], 200),
      );

      // É a chamada da tela de ganhos: listar tudo, sem recorte de mês.
      await client.get('/incomes', queryParameters: {'month': null});

      final uri = lastRequestOf(adapter).uri;
      expect(uri.hasQuery, isFalse);
      expect(uri.path, '/incomes');
      expect(uri.toString(), endsWith('/incomes'));
    });

    test('valor válido continua indo, inclusive não-string', () async {
      final (client: client, adapter: adapter) = clientThatReturns(
        (_) async => _json([], 200),
      );

      await client.get(
        '/summary/projection',
        queryParameters: {'from': '2026-08', 'months': 12},
      );

      expect(lastRequestOf(adapter).uri.queryParameters, {
        'from': '2026-08',
        'months': '12',
      });
    });

    test('a limpeza vale para os quatro métodos, não só para o get', () async {
      final (client: client, adapter: adapter) = clientThatReturns(
        (_) async => _json({}, 200),
      );

      await client.post('/incomes', queryParameters: {'month': null});
      await client.patch('/incomes/x/amount', queryParameters: {'month': null});
      await client.delete('/incomes/x', queryParameters: {'month': null});

      final uris = verify(
        () => adapter.fetch(captureAny(), any(), any()),
      ).captured.cast<RequestOptions>().map((request) => request.uri);

      // Um método novo que esqueça o saneamento aparece aqui, e não em runtime
      // no dispositivo.
      for (final uri in uris) {
        expect(uri.hasQuery, isFalse, reason: '$uri levou a chave nula');
      }
    });
  });

  group('lança AppException — DioException nunca escapa', () {
    /// Executa e devolve a exceção lançada, falhando se nada for lançado.
    Future<AppException> captureFrom(ApiClient client, String path) async {
      try {
        await client.get(path);
      } on AppException catch (exception) {
        return exception;
      }
      fail('esperava AppException, nada foi lançado');
    }

    test('400 traz as issues campo a campo', () async {
      final (client: client, adapter: _) = clientThatReturns(
        (_) async => _json({
          'code': 'VALIDATION_ERROR',
          'message': 'Dados inválidos',
          'issues': [
            {'path': 'amountCents', 'message': 'Informe o valor em centavos'},
            {'path': 'startMonth', 'message': 'Use o formato YYYY-MM'},
          ],
        }, 400),
      );

      final exception = await captureFrom(client, '/incomes');

      expect(exception, isA<BadRequestException>());
      final badRequest = exception as BadRequestException;
      expect(badRequest.code, 'VALIDATION_ERROR');
      expect(badRequest.statusCode, 400);
      expect(badRequest.issues, hasLength(2));
      expect(badRequest.issues.first.path, 'amountCents');
    });

    test('404', () async {
      final (client: client, adapter: _) = clientThatReturns(
        (_) async => _json({
          'code': 'NOT_FOUND',
          'message': 'Ganho não encontrado',
        }, 404),
      );

      final exception = await captureFrom(client, '/incomes/x');

      expect(exception, isA<NotFoundException>());
      expect(exception.message, 'Ganho não encontrado');
    });

    test('409 de vigências sobrepostas', () async {
      final (client: client, adapter: _) = clientThatReturns(
        (_) async => _json({
          'code': 'OVERLAPPING_VERSIONS',
          'message': 'A operação criaria vigências sobrepostas',
        }, 409),
      );

      final exception = await captureFrom(client, '/incomes/x/adjustments');

      expect(exception, isA<ConflictException>());
      expect(exception.code, 'OVERLAPPING_VERSIONS');
    });

    test('422 preserva a mensagem específica do backend', () async {
      final (client: client, adapter: _) = clientThatReturns(
        (_) async => _json({
          'code': 'UNPROCESSABLE',
          'message': 'Gasto no cartão exige informar o cartão',
        }, 422),
      );

      final exception = await captureFrom(client, '/expenses');

      expect(exception, isA<UnprocessableEntityException>());
      expect(exception.message, 'Gasto no cartão exige informar o cartão');
    });

    test('500 mantém o detalhe técnico na exceção', () async {
      final (client: client, adapter: _) = clientThatReturns(
        (_) async => _json({
          'code': 'INTERNAL_ERROR',
          'message': 'TypeError: x is not a function',
        }, 500),
      );

      final exception = await captureFrom(client, '/summary');

      expect(exception, isA<ServerException>());
      expect(exception.statusCode, 500);
      expect(exception.message, contains('TypeError'));
    });

    test(
      'corpo que não é o envelope (HTML de proxy) não quebra o mapper',
      () async {
        final (client: client, adapter: _) = clientThatReturns(
          (_) async =>
              ResponseBody.fromString('<html>502 Bad Gateway</html>', 502),
        );

        final exception = await captureFrom(client, '/summary');

        expect(exception, isA<ServerException>());
        expect(exception.message, isNotEmpty);
      },
    );

    test('conexão recusada', () async {
      final (client: client, adapter: _) = clientThatReturns(
        (options) async => throw DioException.connectionError(
          requestOptions: options,
          reason: 'Connection refused',
        ),
      );

      final exception = await captureFrom(client, '/health');

      expect(exception, isA<NetworkException>());
      expect(exception.cause, isA<DioException>());
    });

    test('timeout', () async {
      final (client: client, adapter: _) = clientThatReturns(
        (options) async => throw DioException.receiveTimeout(
          timeout: const Duration(seconds: 1),
          requestOptions: options,
        ),
      );

      final exception = await captureFrom(client, '/summary');

      expect(exception, isA<RequestTimeoutException>());
    });

    test('cancelamento', () async {
      final (client: client, adapter: _) = clientThatReturns(
        (options) async => throw DioException.requestCancelled(
          requestOptions: options,
          reason: null,
        ),
      );

      final exception = await captureFrom(client, '/summary');

      expect(exception, isA<RequestCancelledException>());
    });
  });
}
