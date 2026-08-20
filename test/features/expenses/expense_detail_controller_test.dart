import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:multiple_result/multiple_result.dart';
import 'package:se_controle_ai/core/errors/failure.dart';
import 'package:se_controle_ai/core/shared/view_state.dart';
import 'package:se_controle_ai/data/models/expense_model.dart';
import 'package:se_controle_ai/features/expenses/controller/expense_detail_controller.dart';

import '../../fixtures/expense_fixture.dart';
import '../../fixtures/mocks.dart';

void main() {
  late MockExpenseRepository repository;
  late MockCreditCardRepository cards;
  late ExpenseDetailController controller;

  setUp(() {
    repository = expenseRepositoryMock();
    cards = creditCardRepositoryMock();
    controller = ExpenseDetailController(repository, cards);
  });

  tearDown(() => controller.dispose());

  test('start guarda o id e busca o gasto', () async {
    await controller.start('gasto-1');

    expect(controller.id, 'gasto-1');
    expect(controller.state.value, isA<Loaded<ExpenseModel>>());
    verify(() => repository.getById('gasto-1', month: null)).called(1);
  });

  test('falha na busca vira Failed', () async {
    stubExpenseDetail(
      repository,
      result: const Error(NotFoundFailure(message: 'Gasto não encontrado')),
    );

    await controller.start('sumiu');

    expect(controller.state.value, isA<Failed<ExpenseModel>>());
  });

  group('operações de dinheiro', () {
    test('reajuste manda valor e mês, e recarrega', () async {
      await controller.start('gasto-1');

      final failure = await controller.adjust(
        amountCents: 150000,
        effectiveFrom: '2026-09',
      );

      expect(failure, isNull);
      verify(
        () => repository.adjust(
          'gasto-1',
          amountCents: 150000,
          effectiveFrom: '2026-09',
        ),
      ).called(1);
      // A recarga silenciosa é o que faz o histórico aparecer atualizado sem a
      // tela piscar: duas buscas no total, a de abertura e a de depois da ação.
      verify(() => repository.getById('gasto-1', month: null)).called(2);
    });

    test('correção manda só o valor', () async {
      await controller.start('gasto-1');

      final failure = await controller.correct(amountCents: 130000);

      expect(failure, isNull);
      verify(
        () => repository.correct('gasto-1', amountCents: 130000),
      ).called(1);
    });

    test('encerramento manda o último mês', () async {
      await controller.start('gasto-1');

      final failure = await controller.close(lastMonth: '2026-10');

      expect(failure, isNull);
      verify(() => repository.close('gasto-1', lastMonth: '2026-10')).called(1);
    });

    // O 422 do backend ("Reajuste precisa valer de 2026-08 em diante") é
    // devolvido a quem chamou, e não guardado num signal: quem precisa mostrá-lo
    // é o diálogo, que é onde a pergunta foi feita.
    test('recusa do backend volta como Failure, sem recarregar', () async {
      repository = expenseRepositoryMock(
        operations: const Error(
          DomainRuleFailure(message: 'Reajuste precisa valer de 2026-08'),
        ),
      );
      controller = ExpenseDetailController(repository, cards);
      await controller.start('gasto-1');

      final failure = await controller.adjust(
        amountCents: 1,
        effectiveFrom: '2026-01',
      );

      expect(failure, isA<DomainRuleFailure>());
      expect(failure?.message, contains('2026-08'));
      verify(() => repository.getById('gasto-1', month: null)).called(1);
    });

    test('exclusão não recarrega: o gasto deixou de existir', () async {
      await controller.start('gasto-1');

      final failure = await controller.delete();

      expect(failure, isNull);
      verify(() => repository.delete('gasto-1')).called(1);
      verify(() => repository.getById('gasto-1', month: null)).called(1);
    });
  });

  group('nome do cartão', () {
    test('gasto no cartão busca o cartão e mostra o label', () async {
      stubExpenseDetail(
        repository,
        result: Success(ExpenseModel.fromJson(youtubeJson)),
      );

      await controller.start('gasto-1');

      expect(controller.cardLabel.value, 'Nubank ••••4321');
    });

    test('gasto no débito não busca cartão nenhum', () async {
      await controller.start('gasto-1');

      expect(controller.cardLabel.value, isNull);
      verifyNever(() => cards.getById(any(), month: any(named: 'month')));
    });

    // O nome do cartão é decoração: o gasto já está na tela sem ele, e uma
    // falha aqui não pode virar tela de erro.
    test('falha ao buscar o cartão não derruba a tela', () async {
      stubExpenseDetail(
        repository,
        result: Success(ExpenseModel.fromJson(youtubeJson)),
      );
      stubCreditCardDetail(
        cards,
        result: const Error(NetworkFailure(message: 'sem rede')),
      );

      await controller.start('gasto-1');

      expect(controller.state.value, isA<Loaded<ExpenseModel>>());
      expect(controller.cardLabel.value, isNull);
    });
  });
}
