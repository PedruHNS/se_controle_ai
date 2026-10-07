import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:multiple_result/multiple_result.dart';
import 'package:se_controle_ai/core/errors/app_exception.dart';
import 'package:se_controle_ai/core/errors/failure.dart';
import 'package:se_controle_ai/core/shared/view_state.dart';
import 'package:se_controle_ai/data/models/income_model.dart';
import 'package:se_controle_ai/features/incomes/controller/income_detail_controller.dart';

import '../../fixtures/income_fixture.dart';
import '../../fixtures/mocks.dart';

void main() {
  late MockIncomeRepository repository;
  late IncomeDetailController controller;

  setUp(() async {
    repository = incomeRepositoryMock();
    controller = IncomeDetailController(repository: repository);
    // O id vem da rota, então quem o entrega é a view. No teste, o `start`
    // ocupa esse papel.
    await controller.start('income-1');
  });

  tearDown(() => controller.dispose());

  group('start', () {
    test('busca o ganho com o id que a view passou', () {
      verify(() => repository.getById('income-1', month: null)).called(1);
      expect(controller.state.value, isA<Loaded<IncomeModel>>());
      expect(
        (controller.state.value as Loaded<IncomeModel>).data.description,
        'Salário',
      );
    });

    test('construir não busca nada — sem id não há o que buscar', () {
      final fresh = MockIncomeRepository();
      stubIncomeDetail(fresh);
      addTearDown(IncomeDetailController(repository: fresh).dispose);

      verifyNever(() => fresh.getById(any(), month: any(named: 'month')));
    });

    test(
      'o id do start é o usado por load, refresh e pelas operações',
      () async {
        await controller.refresh();
        await controller.correct(amountCents: 1000);

        expect(controller.id, 'income-1');
        verify(
          () => repository.getById('income-1', month: null),
        ).called(greaterThan(1));
        verify(
          () => repository.correct('income-1', amountCents: 1000),
        ).called(1);
      },
    );
  });

  group('refresh', () {
    test('passa por Loading e volta ao ganho', () async {
      final segura = Completer<void>();
      stubIncomeDetail(repository, pendenteAte: segura.future);

      final pending = controller.refresh();

      expect(controller.state.value, isA<Loading<IncomeModel>>());
      segura.complete();
      await pending;
      expect(controller.state.value, isA<Loaded<IncomeModel>>());
    });

    // É o que o "tentar de novo" do cartão de falha chama.
    test('depois de uma falha volta a mostrar o ganho', () async {
      stubIncomeDetail(
        repository,
        result: Error(
          Failure.fromException(const NetworkException(message: 'sem rede')),
        ),
      );
      await controller.refresh();
      expect(controller.state.value, isA<Failed<IncomeModel>>());

      stubIncomeDetail(repository);
      await controller.refresh();

      expect(controller.state.value, isA<Loaded<IncomeModel>>());
    });

    test(
      'resposta que chega depois do dispose é descartada, sem lançar',
      () async {
        // A página libera o controller ao sair da tela, e a busca pode ainda
        // estar em voo. Escrever no signal liberado lançaria um erro que ninguém
        // captura.
        final segura = Completer<void>();
        final lenta = incomeRepositoryMock();
        stubIncomeDetail(lenta, pendenteAte: segura.future);
        final saiu = IncomeDetailController(repository: lenta);

        final pending = saiu.start('income-1');
        saiu.dispose();
        segura.complete();
        await pending;
      },
    );
  });

  group('reajuste e correção são chamadas diferentes', () {
    // As duas devolvem o mesmo Success — o que as distingue é o que foi
    // enviado. Por isso a asserção é sobre a chamada, não sobre o retorno.
    test('reajuste manda o mês de vigência', () async {
      final failure = await controller.adjust(
        amountCents: 550000,
        effectiveFrom: '2026-11',
      );

      expect(failure, isNull);
      verify(
        () => repository.adjust(
          'income-1',
          amountCents: 550000,
          effectiveFrom: '2026-11',
        ),
      ).called(1);
      verifyNever(
        () => repository.correct(any(), amountCents: any(named: 'amountCents')),
      );
    });

    test('correção manda só o valor — não tem mês', () async {
      final failure = await controller.correct(amountCents: 480000);

      expect(failure, isNull);
      verify(
        () => repository.correct('income-1', amountCents: 480000),
      ).called(1);
      verifyNever(
        () => repository.adjust(
          any(),
          amountCents: any(named: 'amountCents'),
          effectiveFrom: any(named: 'effectiveFrom'),
        ),
      );
    });
  });

  test('encerramento manda o último mês recebido', () async {
    final failure = await controller.close(lastMonth: '2026-12');

    expect(failure, isNull);
    verify(() => repository.close('income-1', lastMonth: '2026-12')).called(1);
  });

  test(
    'operação bem-sucedida recarrega — o 204 não traz o estado novo',
    () async {
      stubIncomeDetail(
        repository,
        result: Success(IncomeModel.fromJson(adjustedSalaryJson)),
      );

      await controller.adjust(amountCents: 550000, effectiveFrom: '2026-11');

      final state = controller.state.value as Loaded<IncomeModel>;
      expect(state.data.amountCents, 550000);
      expect(state.data.history, hasLength(2));
    },
  );

  test('exclusão não recarrega — o ganho deixou de existir', () async {
    clearInteractions(repository);

    final failure = await controller.delete();

    expect(failure, isNull);
    verify(() => repository.delete('income-1')).called(1);
    verifyNever(() => repository.getById(any(), month: any(named: 'month')));
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

    test(
      'devolve a falha para o diálogo, em vez de guardá-la no estado',
      () async {
        final failure = await controller.adjust(
          amountCents: 550000,
          effectiveFrom: '2026-01',
        );

        expect(failure, isA<DomainRuleFailure>());
        expect(failure!.message, 'Reajuste precisa valer de um mês posterior.');
        // A tela continua mostrando o ganho: quem falhou foi a ação, não a busca.
        expect(controller.state.value, isA<Loaded<IncomeModel>>());
      },
    );

    test('falha não recarrega — não há estado novo para buscar', () async {
      clearInteractions(repository);

      await controller.correct(amountCents: 1000);

      verifyNever(() => repository.getById(any(), month: any(named: 'month')));
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
}
