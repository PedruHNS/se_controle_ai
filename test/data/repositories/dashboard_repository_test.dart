import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:se_controle_ai/core/errors/failure.dart';
import 'package:se_controle_ai/core/network/api_client.dart';
import 'package:se_controle_ai/core/network/dio_factory.dart';
import 'package:se_controle_ai/data/repositories/dashboard_repository.dart';

import '../../fixtures/dashboard_fixture.dart';

/// Adapter mockado: a rede nunca é tocada, e o teste manda o que ela responde.
/// Mesmo arranjo do `api_client_test`, repetido aqui porque o helper de lá é
/// privado do arquivo.
class MockHttpClientAdapter extends Mock implements HttpClientAdapter {}

ResponseBody _json(Object? body, int status) => ResponseBody.fromString(
  body == null ? '' : jsonEncode(body),
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

({DashboardRepository repository, MockHttpClientAdapter adapter}) _repoQueResponde(
  Future<ResponseBody> Function(RequestOptions options) responder,
) {
  final adapter = MockHttpClientAdapter();
  when(() => adapter.fetch(any(), any(), any())).thenAnswer(
    (invocation) =>
        responder(invocation.positionalArguments.first as RequestOptions),
  );

  final dio = buildDio();
  dio.httpClientAdapter = adapter;
  return (
    repository: DashboardRepositoryImpl(ApiClient(dio)),
    adapter: adapter,
  );
}

RequestOptions _ultimaRequisicao(MockHttpClientAdapter adapter) =>
    verify(() => adapter.fetch(captureAny(), any(), any())).captured.last
        as RequestOptions;

void main() {
  setUpAll(() => registerFallbackValue(RequestOptions()));

  test('busca /dashboard levando a competência', () async {
    final (repository: repository, adapter: adapter) = _repoQueResponde(
      (_) async => _json(dashboardJson, 200),
    );

    final result = await repository.getDashboard(month: '2026-09');

    final request = _ultimaRequisicao(adapter);
    expect(request.path, '/dashboard');
    expect(request.queryParameters['month'], '2026-09');

    expect(result.isSuccess(), isTrue);
    final dashboard = result.tryGetSuccess()!;
    expect(dashboard.month, '2026-09');
    expect(dashboard.byTag, hasLength(4));
    expect(dashboard.daily.days, hasLength(30));
  });

  test('mês sem lançamento é sucesso, e não erro', () async {
    final (repository: repository, adapter: _) = _repoQueResponde(
      (_) async => _json(dashboardVazioJson, 200),
    );

    final result = await repository.getDashboard(month: '2026-11');

    expect(result.isSuccess(), isTrue);
    expect(result.tryGetSuccess()!.topExpenses, isEmpty);
  });

  test('400 de mês fora do formato vira Failure', () async {
    final (repository: repository, adapter: _) = _repoQueResponde(
      (_) async => _json({
        'code': 'VALIDATION_ERROR',
        'message': 'month deve ser YYYY-MM',
      }, 400),
    );

    final result = await repository.getDashboard(month: '2026-13');

    expect(result.isError(), isTrue);
    expect(result.tryGetError(), isA<Failure>());
  });

  test('falha de rede vira Failure, sem lançar', () async {
    final (repository: repository, adapter: _) = _repoQueResponde(
      (options) async => throw DioException.connectionError(
        requestOptions: options,
        reason: 'sem rede',
      ),
    );

    final result = await repository.getDashboard(month: '2026-09');

    expect(result.isError(), isTrue);
  });

  // O `catch` largo do repositório existe para isto: payload que muda de forma
  // no backend vira erro tratado, e não exceção no meio de um `build`.
  test('corpo fora do contrato vira Failure de serialização', () async {
    final (repository: repository, adapter: _) = _repoQueResponde(
      (_) async => _json({'month': '2026-09'}, 200),
    );

    final result = await repository.getDashboard(month: '2026-09');

    expect(result.isError(), isTrue);
    expect(result.tryGetError(), isA<Failure>());
  });
}
