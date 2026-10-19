import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:multiple_result/multiple_result.dart';
import 'package:se_controle_ai/core/errors/app_exception.dart';
import 'package:se_controle_ai/core/errors/failure.dart';
import 'package:se_controle_ai/core/shared/view_state.dart';
import 'package:se_controle_ai/data/models/income_model.dart';
import 'package:se_controle_ai/data/services/selected_month_service.dart';
import 'package:se_controle_ai/features/incomes/controller/income_controller.dart';
import 'package:se_controle_ai/features/incomes/controller/income_detail_controller.dart';

import '../../fixtures/income_fixture.dart';
import '../../fixtures/mocks.dart';

void main() {
  // A falha avisa por toast, e o toast procura o contexto do `navigatorKey`
  // global — o que só existe com binding inicializado.
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockIncomeRepository repository;
  late MockNavigationService nav;
  late SelectedMonthService month;
  late IncomeController incomes;
  late IncomeDetailController controller;

  /// A lista no estado em que está agora.
  List<IncomeModel> naLista() =>
      (incomes.state.value as Loaded<List<IncomeModel>>).data;

  /// O ganho que a lista entrega ao detalhe pelo `extra` da rota.
  IncomeModel salario() =>
      naLista().firstWhere((i) => i.description == 'Salário');

  setUp(() async {
    repository = incomeRepositoryMock();
    nav = navigationServiceMock();
    month = SelectedMonthService();
    incomes = IncomeController(
      repository: repository,
      selectedMonth: month,
      navigationService: nav,
    );
    await pumpEventQueue();

    controller = IncomeDetailController(
      repository: repository,
      nav: nav,
      selectedMonth: month,
      incomeController: incomes,
    );
    // O ganho vem da rota, então quem o entrega é a view. No teste, o `start`
    // ocupa esse papel.
    controller.start(salario());
    clearInteractions(repository);
  });

  tearDown(() {
    controller.dispose();
    incomes.dispose();
    month.dispose();
  });

  test('o id do start é o que as operações usam', () async {
    await controller.correct(amountCents: 1000);

    expect(controller.id, salario().id);
    verify(
      () => repository.correct(
        salario().id,
        amountCents: 1000,
        month: any(named: 'month'),
      ),
    ).called(1);
  });

  // O valor devolvido vem no mês da lista, para entrar nela sem conta no app.
  test('as operações mandam o mês selecionado na home', () async {
    month.select('2026-12');

    await controller.close(lastMonth: '2026-12');

    verify(
      () => repository.close(any(), lastMonth: '2026-12', month: '2026-12'),
    ).called(1);
  });

  group('reajuste e correção são chamadas diferentes', () {
    // O que as distingue é o que foi enviado. Por isso a asserção é sobre a
    // chamada, não sobre o retorno.
    test('reajuste manda o mês de vigência', () async {
      await controller.adjust(amountCents: 550000, effectiveFrom: '2026-11');

      verify(
        () => repository.adjust(
          any(),
          amountCents: 550000,
          effectiveFrom: '2026-11',
          month: any(named: 'month'),
        ),
      ).called(1);
      verifyNever(
        () => repository.correct(
          any(),
          amountCents: any(named: 'amountCents'),
          month: any(named: 'month'),
        ),
      );
    });

    test('correção manda só o valor — não tem mês de vigência', () async {
      await controller.correct(amountCents: 480000);

      verify(
        () => repository.correct(
          any(),
          amountCents: 480000,
          month: any(named: 'month'),
        ),
      ).called(1);
      verifyNever(
        () => repository.adjust(
          any(),
          amountCents: any(named: 'amountCents'),
          effectiveFrom: any(named: 'effectiveFrom'),
          month: any(named: 'month'),
        ),
      );
    });
  });

  test('encerramento manda o último mês recebido', () async {
    await controller.close(lastMonth: '2026-12');

    verify(
      () => repository.close(
        any(),
        lastMonth: '2026-12',
        month: any(named: 'month'),
      ),
    ).called(1);
  });

  // GAN-12: a operação devolve o ganho como ficou, e ele vai para a lista.
  group('operação que deu certo', () {
    test('o ganho devolvido toma o lugar do antigo na lista', () async {
      final reajustado = IncomeModel.fromJson({
        ...adjustedSalaryJson,
        'id': salario().id,
      });
      stubIncomeOperations(repository, updateResult: Success(reajustado));

      await controller.adjust(amountCents: 550000, effectiveFrom: '2026-11');

      expect(naLista(), hasLength(2));
      expect(salario().amountCents, 550000);
      expect(salario().history, hasLength(2));
    });

    test('nem a lista nem o ganho são buscados de novo', () async {
      await controller.correct(amountCents: 1000);

      verifyNever(() => repository.list(month: any(named: 'month')));
    });

    test('fecha o diálogo e a tela do detalhe', () async {
      await controller.close(lastMonth: '2026-12');

      verify(() => nav.pop()).called(2);
    });
  });

  group('recusa do backend', () {
    setUp(() {
      // 422 é o retorno de reajuste retroativo, valor repetido e ganho já
      // encerrado — a mensagem vem pronta do backend.
      stubIncomeOperations(
        repository,
        result: Error(
          Failure.fromException(
            const UnprocessableEntityException(
              message: 'Reajuste precisa valer de um mês posterior.',
            ),
          ),
        ),
      );
    });

    // O recado sai por toast — quem o vê é o teste da página.
    test('deixa o diálogo aberto e a lista como estava', () async {
      final antes = naLista();

      await controller.adjust(amountCents: 550000, effectiveFrom: '2026-01');

      verifyNever(() => nav.pop());
      expect(naLista(), same(antes));
    });
  });

  test('working liga durante a operação e desliga no fim', () async {
    final segura = Completer<void>();
    stubIncomeOperations(repository, pendenteAte: segura.future);

    final pending = controller.correct(amountCents: 1000);

    expect(controller.working.value, isTrue);
    segura.complete();
    await pending;
    expect(controller.working.value, isFalse);
  });

  test('working desliga também quando a operação falha', () async {
    stubIncomeOperations(
      repository,
      result: Error(
        Failure.fromException(const NetworkException(message: 'sem rede')),
      ),
    );

    await controller.correct(amountCents: 1000);

    expect(controller.working.value, isFalse);
  });
}
