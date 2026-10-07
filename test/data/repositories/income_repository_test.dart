import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:se_controle_ai/core/errors/failure.dart';
import 'package:se_controle_ai/core/network/api_client.dart';
import 'package:se_controle_ai/core/network/dio_factory.dart';
import 'package:se_controle_ai/data/repositories/income_repository.dart';

import '../../fixtures/income_fixture.dart';

/// Os testes de controller e de tela de ganhos usam o repositório **mockado**,
/// então nenhum deles prova o que sai pela rede. É isto que este arquivo
/// guarda: rota e método de cada operação, a query, o corpo enviado e a
/// tradução de cada erro do contrato (`docs/specs/01-ganhos.md`).
///
/// Mesmo arranjo do `dashboard_repository_test`: `ApiClient` real sobre um Dio
/// cujo adapter é mockado, e a rede nunca é tocada.
class MockHttpClientAdapter extends Mock implements HttpClientAdapter {}

ResponseBody _json(Object? body, int status) => ResponseBody.fromString(
  body == null ? '' : jsonEncode(body),
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

({IncomeRepository repository, MockHttpClientAdapter adapter}) _repoQueResponde(
  Future<ResponseBody> Function(RequestOptions options) responder,
) {
  final adapter = MockHttpClientAdapter();
  when(() => adapter.fetch(any(), any(), any())).thenAnswer(
    (invocation) =>
        responder(invocation.positionalArguments.first as RequestOptions),
  );

  final dio = buildDio();
  dio.httpClientAdapter = adapter;
  return (repository: IncomeRepositoryImpl(ApiClient(dio)), adapter: adapter);
}

RequestOptions _ultimaRequisicao(MockHttpClientAdapter adapter) =>
    verify(() => adapter.fetch(captureAny(), any(), any())).captured.last
        as RequestOptions;

/// O envelope de erro que o backend sempre devolve: `{code, message, issues?}`.
Map<String, dynamic> _erro(
  String code,
  String message, {
  List<Object>? issues,
}) => {'code': code, 'message': message, 'issues': ?issues};

void main() {
  setUpAll(() => registerFallbackValue(RequestOptions()));

  group('list', () {
    // Sem a limpeza do `ApiClient`, o Dio mandaria `?month` pelado, e o backend
    // devolveria 400 em vez de listar tudo — a tela de cadastro depende de a
    // listagem vir sem recorte (GAN-10).
    test('sem mês, a query não leva o `month`', () async {
      final (repository: repository, adapter: adapter) = _repoQueResponde(
        (_) async => _json(incomeListJson, 200),
      );

      final result = await repository.list();

      final request = _ultimaRequisicao(adapter);
      expect(request.method, 'GET');
      expect(request.path, '/incomes');
      expect(request.queryParameters.containsKey('month'), isFalse);

      expect(result.isSuccess(), isTrue);
      expect(result.tryGetSuccess(), hasLength(2));
    });

    test('com mês, leva a competência', () async {
      final (repository: repository, adapter: adapter) = _repoQueResponde(
        (_) async => _json(incomeListJson, 200),
      );

      await repository.list(month: '2026-09');

      expect(_ultimaRequisicao(adapter).queryParameters['month'], '2026-09');
    });
  });

  group('getById', () {
    test('busca /incomes/:id e lê o ganho com o histórico', () async {
      final (repository: repository, adapter: adapter) = _repoQueResponde(
        (_) async => _json(adjustedSalaryJson, 200),
      );

      final result = await repository.getById('abc');

      final request = _ultimaRequisicao(adapter);
      expect(request.method, 'GET');
      expect(request.path, '/incomes/abc');
      expect(request.queryParameters.containsKey('month'), isFalse);

      final income = result.tryGetSuccess()!;
      expect(income.amountCents, 550000);
      expect(income.history, hasLength(2));
    });

    test('com mês, leva a competência', () async {
      final (repository: repository, adapter: adapter) = _repoQueResponde(
        (_) async => _json(salaryJson, 200),
      );

      await repository.getById('abc', month: '2026-05');

      expect(_ultimaRequisicao(adapter).queryParameters['month'], '2026-05');
    });
  });

  group('create', () {
    test('manda o corpo do contrato e devolve o id do 201', () async {
      final (repository: repository, adapter: adapter) = _repoQueResponde(
        (_) async => _json({'id': 'novo-id'}, 201),
      );

      final result = await repository.create(
        description: 'Salário',
        amountCents: 500000,
        startMonth: '2026-01',
      );

      final request = _ultimaRequisicao(adapter);
      expect(request.method, 'POST');
      expect(request.path, '/incomes');
      // Sem `tagId`: a chave nem existe, em vez de ir como nula (TAG-07).
      expect(request.data, {
        'description': 'Salário',
        'amountCents': 500000,
        'startMonth': '2026-01',
        'recurring': true,
      });

      expect(result.tryGetSuccess(), 'novo-id');
    });

    test('a tag entra no corpo só quando existe', () async {
      final (repository: repository, adapter: adapter) = _repoQueResponde(
        (_) async => _json({'id': 'novo-id'}, 201),
      );

      await repository.create(
        description: 'Freela',
        amountCents: 80000,
        startMonth: '2026-08',
        tagId: 'tag-1',
        recurring: false,
      );

      final data = _ultimaRequisicao(adapter).data as Map<String, dynamic>;
      expect(data['tagId'], 'tag-1');
      expect(data['recurring'], isFalse);
    });
  });

  // As quatro respondem 204, sem corpo. O que as distingue é a rota, o método e
  // o que vai no corpo — e é por isso que a asserção é sobre a requisição.
  group('operações que respondem 204', () {
    test(
      'reajuste é POST em /adjustments, com valor e mês de vigência',
      () async {
        final (repository: repository, adapter: adapter) = _repoQueResponde(
          (_) async => _json(null, 204),
        );

        final result = await repository.adjust(
          'abc',
          amountCents: 550000,
          effectiveFrom: '2026-11',
        );

        final request = _ultimaRequisicao(adapter);
        expect(request.method, 'POST');
        expect(request.path, '/incomes/abc/adjustments');
        expect(request.data, {
          'amountCents': 550000,
          'effectiveFrom': '2026-11',
        });
        expect(result.isSuccess(), isTrue);
      },
    );

    // O `PATCH` é o que separa correção de reajuste: um `POST` aqui seria outra
    // rota, com outra semântica.
    test('correção é PATCH em /amount, e manda só o valor', () async {
      final (repository: repository, adapter: adapter) = _repoQueResponde(
        (_) async => _json(null, 204),
      );

      final result = await repository.correct('abc', amountCents: 480000);

      final request = _ultimaRequisicao(adapter);
      expect(request.method, 'PATCH');
      expect(request.path, '/incomes/abc/amount');
      expect(request.data, {'amountCents': 480000});
      expect(result.isSuccess(), isTrue);
    });

    test(
      'encerramento é POST em /closure, com o último mês recebido',
      () async {
        final (repository: repository, adapter: adapter) = _repoQueResponde(
          (_) async => _json(null, 204),
        );

        final result = await repository.close('abc', lastMonth: '2026-12');

        final request = _ultimaRequisicao(adapter);
        expect(request.method, 'POST');
        expect(request.path, '/incomes/abc/closure');
        expect(request.data, {'lastMonth': '2026-12'});
        expect(result.isSuccess(), isTrue);
      },
    );

    test('exclusão é DELETE em /incomes/:id', () async {
      final (repository: repository, adapter: adapter) = _repoQueResponde(
        (_) async => _json(null, 204),
      );

      final result = await repository.delete('abc');

      final request = _ultimaRequisicao(adapter);
      expect(request.method, 'DELETE');
      expect(request.path, '/incomes/abc');
      expect(result.isSuccess(), isTrue);
    });
  });

  group('recusas do backend', () {
    // GAN-04, GAN-05 e GAN-08: reajuste retroativo, mesmo valor ou ganho já
    // encerrado. A mensagem vem pronta e vai direto para o diálogo.
    test('422 vira DomainRuleFailure, com a mensagem do backend', () async {
      final (repository: repository, adapter: _) = _repoQueResponde(
        (_) async => _json(
          _erro('BUSINESS_RULE', 'Reajuste precisa valer de um mês posterior.'),
          422,
        ),
      );

      final result = await repository.adjust(
        'abc',
        amountCents: 550000,
        effectiveFrom: '2026-01',
      );

      final failure = result.tryGetError();
      expect(failure, isA<DomainRuleFailure>());
      expect(failure!.message, 'Reajuste precisa valer de um mês posterior.');
    });

    test('409 de vigências sobrepostas vira ConflictFailure', () async {
      final (repository: repository, adapter: _) = _repoQueResponde(
        (_) async => _json(
          _erro('OVERLAPPING_VERSIONS', 'As vigências se sobrepõem.'),
          409,
        ),
      );

      final result = await repository.adjust(
        'abc',
        amountCents: 550000,
        effectiveFrom: '2026-11',
      );

      expect(result.tryGetError(), isA<ConflictFailure>());
    });

    // É o que o formulário usa para pendurar o erro no campo: `issues[].path` no
    // mesmo nome dos campos.
    test('400 traz os campos recusados em ValidationFailure', () async {
      final (repository: repository, adapter: _) = _repoQueResponde(
        (_) async => _json(
          _erro(
            'VALIDATION_ERROR',
            'Dados inválidos',
            issues: [
              {'path': 'startMonth', 'message': 'startMonth deve ser YYYY-MM'},
            ],
          ),
          400,
        ),
      );

      final result = await repository.create(
        description: 'Salário',
        amountCents: 500000,
        startMonth: '2026-13',
      );

      final failure = result.tryGetError();
      expect(failure, isA<ValidationFailure>());
      expect(
        (failure as ValidationFailure).messageFor('startMonth'),
        'startMonth deve ser YYYY-MM',
      );
    });

    test('404 vira NotFoundFailure', () async {
      final (repository: repository, adapter: _) = _repoQueResponde(
        (_) async => _json(_erro('NOT_FOUND', 'Ganho não encontrado.'), 404),
      );

      final result = await repository.getById('sumiu');

      expect(result.tryGetError(), isA<NotFoundFailure>());
    });

    test('falha de rede vira NetworkFailure, sem lançar', () async {
      final (repository: repository, adapter: _) = _repoQueResponde(
        (options) async => throw DioException.connectionError(
          requestOptions: options,
          reason: 'sem rede',
        ),
      );

      final result = await repository.list();

      expect(result.tryGetError(), isA<NetworkFailure>());
    });

    // O `catch` largo do repositório existe para isto: payload que muda de forma
    // no backend vira erro tratado, e não exceção no meio de um `build`.
    test('corpo fora do contrato vira Failure de serialização', () async {
      final (repository: repository, adapter: _) = _repoQueResponde(
        (_) async => _json({'items': <Object>[]}, 200),
      );

      final result = await repository.list();

      expect(result.tryGetError(), isA<SerializationFailure>());
    });
  });
}
