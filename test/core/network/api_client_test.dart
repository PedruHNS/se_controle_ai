import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:se_controle_ai/core/errors/app_exception.dart';
import 'package:se_controle_ai/core/network/api_client.dart';
import 'package:se_controle_ai/core/network/dio_factory.dart';

/// Adapter que responde o que o teste mandar, sem tocar a rede. Deixa os testes
/// determinísticos e independentes do backend estar de pé.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.responder);

  final Future<ResponseBody> Function(RequestOptions options) responder;

  /// Última requisição que passou por aqui — para conferir URL e corpo.
  RequestOptions? lastRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    lastRequest = options;
    return responder(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Object? body, int status) => ResponseBody.fromString(
  body == null ? '' : jsonEncode(body),
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

/// Monta o client real (mesmo `buildDio` da produção) com a rede substituída.
({ApiClient client, _FakeAdapter adapter}) clientThatReturns(
  Future<ResponseBody> Function(RequestOptions options) responder,
) {
  final dio = buildDio();
  final adapter = _FakeAdapter(responder);
  dio.httpClientAdapter = adapter;
  return (client: ApiClient(dio), adapter: adapter);
}

void main() {
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
    test(
      'parâmetro nulo é removido, senão o zod recusa string vazia',
      () async {
        final (client: client, adapter: adapter) = clientThatReturns(
          (_) async => _json({'month': '2026-08'}, 200),
        );

        await client.get(
          '/summary',
          queryParameters: {'month': null, 'months': 12},
        );

        final uri = adapter.lastRequest!.uri.toString();
        expect(uri, contains('months=12'));
        expect(uri, isNot(contains('month=&')));
        expect(uri, isNot(contains('month=1')));
      },
    );
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
