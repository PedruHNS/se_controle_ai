import 'package:mocktail/mocktail.dart';
import 'package:multiple_result/multiple_result.dart';
import 'package:se_controle_ai/core/errors/failure.dart';
import 'package:se_controle_ai/core/shared/patch.dart';
import 'package:se_controle_ai/data/models/credit_card_model.dart';
import 'package:se_controle_ai/data/models/income_model.dart';
import 'package:se_controle_ai/data/models/month_projection_model.dart';
import 'package:se_controle_ai/data/models/monthly_summary_model.dart';
import 'package:se_controle_ai/data/repositories/credit_card_repository.dart';
import 'package:se_controle_ai/data/repositories/income_repository.dart';
import 'package:se_controle_ai/data/repositories/summary_repository.dart';

import 'credit_card_fixture.dart';
import 'income_fixture.dart';
import 'summary_fixture.dart';

/// Os mocks de repositório do app.
///
/// Mock e não implementação falsa escrita à mão: com `verify` a asserção diz
/// **qual chamada** era esperada, com os argumentos no lugar. Em ganhos isso é
/// a diferença entre um teste que vale e um que não vale — reajuste e correção
/// devolvem o mesmo `Success`, e só o argumento os distingue.
class MockSummaryRepository extends Mock implements SummaryRepository {}

class MockIncomeRepository extends Mock implements IncomeRepository {}

class MockCreditCardRepository extends Mock implements CreditCardRepository {}

/// Stub de `getMonthly` para qualquer mês.
///
/// [delay] simula latência: é o que permite observar `Loading` e testar duas
/// buscas em voo ao mesmo tempo.
void stubMonthly(
  MockSummaryRepository mock, {
  Result<MonthlySummaryModel, Failure>? result,
  Duration? delay,
}) {
  final answer = result ?? Success(MonthlySummaryModel.fromJson(summaryJson));
  when(() => mock.getMonthly(month: any(named: 'month'))).thenAnswer((_) async {
    if (delay != null) await Future<void>.delayed(delay);
    return answer;
  });
}

void stubProjection(
  MockSummaryRepository mock, {
  Result<List<MonthProjectionModel>, Failure> result = const Success([]),
}) {
  when(
    () => mock.getProjection(
      from: any(named: 'from'),
      months: any(named: 'months'),
    ),
  ).thenAnswer((_) async => result);
}

/// Mock de resumo pronto para uso: responde o mês de exemplo em qualquer mês
/// pedido, e devolve projeção vazia.
MockSummaryRepository summaryRepositoryMock({
  Result<MonthlySummaryModel, Failure>? result,
  Duration? delay,
}) {
  final mock = MockSummaryRepository();
  stubMonthly(mock, result: result, delay: delay);
  stubProjection(mock);
  return mock;
}

/// Os meses pedidos ao mock, na ordem.
///
/// `verify` **consome** o que foi gravado, então chamar duas vezes no mesmo
/// teste devolve lista vazia na segunda. Use uma vez, no fim.
List<String?> capturedMonths(MockSummaryRepository mock) => verify(
  () => mock.getMonthly(month: captureAny(named: 'month')),
).captured.cast<String?>();

/// Stub de `list` de ganhos.
void stubIncomeList(
  MockIncomeRepository mock, {
  Result<List<IncomeModel>, Failure>? result,
  Duration? delay,
}) {
  final answer =
      result ?? Success(incomeListJson.map(IncomeModel.fromJson).toList());
  when(() => mock.list(month: any(named: 'month'))).thenAnswer((_) async {
    if (delay != null) await Future<void>.delayed(delay);
    return answer;
  });
}

void stubIncomeDetail(
  MockIncomeRepository mock, {
  Result<IncomeModel, Failure>? result,
}) {
  when(() => mock.getById(any(), month: any(named: 'month'))).thenAnswer(
    (_) async => result ?? Success(IncomeModel.fromJson(salaryJson)),
  );
}

/// Stub das quatro operações que devolvem 204. Um valor só para todas porque o
/// que se verifica delas é a chamada, não a resposta — e quando importa falhar,
/// falham todas juntas (o teste de 422).
void stubIncomeOperations(
  MockIncomeRepository mock, {
  Result<bool, Failure> result = const Success(true),
  Result<String, Failure> createResult = const Success('novo-id'),
  Duration? delay,
}) {
  Future<T> answer<T>(T value) async {
    if (delay != null) await Future<void>.delayed(delay);
    return value;
  }

  when(
    () => mock.create(
      description: any(named: 'description'),
      amountCents: any(named: 'amountCents'),
      startMonth: any(named: 'startMonth'),
      recurring: any(named: 'recurring'),
    ),
  ).thenAnswer((_) => answer(createResult));

  when(
    () => mock.adjust(
      any(),
      amountCents: any(named: 'amountCents'),
      effectiveFrom: any(named: 'effectiveFrom'),
    ),
  ).thenAnswer((_) => answer(result));

  when(
    () => mock.correct(any(), amountCents: any(named: 'amountCents')),
  ).thenAnswer((_) => answer(result));

  when(
    () => mock.close(any(), lastMonth: any(named: 'lastMonth')),
  ).thenAnswer((_) => answer(result));

  when(() => mock.delete(any())).thenAnswer((_) => answer(result));
}

/// Mock de ganhos pronto: lista de exemplo, detalhe do salário e as operações
/// respondendo sucesso.
MockIncomeRepository incomeRepositoryMock({
  Result<List<IncomeModel>, Failure>? list,
  Result<IncomeModel, Failure>? detail,
  Result<bool, Failure> operations = const Success(true),
  Result<String, Failure> create = const Success('novo-id'),
  Duration? delay,
}) {
  final mock = MockIncomeRepository();
  stubIncomeList(mock, result: list, delay: delay);
  stubIncomeDetail(mock, result: detail);
  stubIncomeOperations(
    mock,
    result: operations,
    createResult: create,
    delay: delay,
  );
  return mock;
}

/// Stub de `list` de cartões.
void stubCreditCardList(
  MockCreditCardRepository mock, {
  Result<List<CreditCardModel>, Failure>? result,
  Duration? delay,
}) {
  final answer =
      result ??
      Success(creditCardListJson.map(CreditCardModel.fromJson).toList());
  when(() => mock.list(month: any(named: 'month'))).thenAnswer((_) async {
    if (delay != null) await Future<void>.delayed(delay);
    return answer;
  });
}

void stubCreditCardDetail(
  MockCreditCardRepository mock, {
  Result<CreditCardModel, Failure>? result,
}) {
  when(() => mock.getById(any(), month: any(named: 'month'))).thenAnswer(
    (_) async => result ?? Success(CreditCardModel.fromJson(nubankJson)),
  );
}

/// Stub de criação, edição e exclusão.
///
/// O `update` casa com qualquer `Patch`, para o teste que **verifica** o patch
/// poder olhar o argumento capturado em vez de precisar de um stub por
/// combinação — são três estados em dois campos.
void stubCreditCardOperations(
  MockCreditCardRepository mock, {
  Result<bool, Failure> result = const Success(true),
  Result<String, Failure> createResult = const Success('novo-cartao'),
  Duration? delay,
}) {
  // `Patch` não é anulável no `update`, e para esses o mocktail precisa de um
  // valor de reserva antes de aceitar `any()`. Registrar aqui, e não em um
  // `setUpAll` de cada teste, mantém o custo do detalhe dentro do stub.
  registerFallbackValue(const Patch<String>.keep());
  registerFallbackValue(const Patch<int>.keep());

  Future<T> answer<T>(T value) async {
    if (delay != null) await Future<void>.delayed(delay);
    return value;
  }

  when(
    () => mock.create(
      name: any(named: 'name'),
      closingDay: any(named: 'closingDay'),
      dueDay: any(named: 'dueDay'),
      lastDigits: any(named: 'lastDigits'),
      limitCents: any(named: 'limitCents'),
    ),
  ).thenAnswer((_) => answer(createResult));

  when(
    () => mock.update(
      any(),
      name: any(named: 'name'),
      closingDay: any(named: 'closingDay'),
      dueDay: any(named: 'dueDay'),
      lastDigits: any(named: 'lastDigits'),
      limitCents: any(named: 'limitCents'),
    ),
  ).thenAnswer((invocation) {
    _recordUpdateBody(mock, invocation);
    return answer(result);
  });

  when(() => mock.delete(any())).thenAnswer((_) => answer(result));
}

/// Mock de cartões pronto: a lista de exemplo, o detalhe do Nubank e as
/// operações respondendo sucesso.
MockCreditCardRepository creditCardRepositoryMock({
  Result<List<CreditCardModel>, Failure>? list,
  Result<CreditCardModel, Failure>? detail,
  Result<bool, Failure> operations = const Success(true),
  Result<String, Failure> create = const Success('novo-cartao'),
  Duration? delay,
}) {
  final mock = MockCreditCardRepository();
  stubCreditCardList(mock, result: list, delay: delay);
  stubCreditCardDetail(mock, result: detail);
  stubCreditCardOperations(
    mock,
    result: operations,
    createResult: create,
    delay: delay,
  );
  return mock;
}

/// Os corpos de `PATCH` que o mock recebeu, na ordem, montados como o
/// repositório montaria.
///
/// Escrito pelo próprio stub, e não lido do `captured` do mocktail: lá os
/// argumentos nomeados voltam numa ordem que não é a da declaração, e reconstruir
/// o corpo por posição dava `_Keep<String>` no lugar do nome.
final _updateBodies = <MockCreditCardRepository, List<Map<String, dynamic>>>{};

void _recordUpdateBody(MockCreditCardRepository mock, Invocation invocation) {
  final named = invocation.namedArguments;

  final body = <String, dynamic>{
    'name': ?named[const Symbol('name')] as String?,
    'closingDay': ?named[const Symbol('closingDay')] as int?,
    'dueDay': ?named[const Symbol('dueDay')] as int?,
  };

  // O mesmo `writeTo` da produção decide o que entra: é o mapeamento do CAR-08,
  // e ele próprio está coberto em `patch_test.dart`.
  (named[const Symbol('lastDigits')] as Patch<String>? ??
          const Patch<String>.keep())
      .writeTo(body, 'lastDigits');
  (named[const Symbol('limitCents')] as Patch<int>? ?? const Patch<int>.keep())
      .writeTo(body, 'limitCents');

  (_updateBodies[mock] ??= []).add(body);
}

/// Todos os corpos de `update` recebidos por este mock.
List<Map<String, dynamic>> updateBodies(MockCreditCardRepository mock) =>
    _updateBodies[mock] ?? const [];

/// O corpo do último `update`. É o que os testes do CAR-08 afirmam: quais chaves
/// foram enviadas, e com quê.
Map<String, dynamic> capturedUpdateBody(MockCreditCardRepository mock) =>
    updateBodies(mock).last;
