import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:multiple_result/multiple_result.dart';
import 'package:se_controle_ai/core/errors/app_exception.dart';
import 'package:se_controle_ai/core/errors/failure.dart';
import 'package:se_controle_ai/core/utils/month.dart';
import 'package:se_controle_ai/features/incomes/controller/income_form_controller.dart';

import '../../fixtures/mocks.dart';

void main() {
  late MockIncomeRepository repository;
  late IncomeFormController controller;

  /// `create` com os quatro nomeados — a asserção diz exatamente o que devia
  /// ter sido enviado, que é o ponto de usar mock aqui.
  void verifyNoCreate() => verifyNever(
    () => repository.create(
      description: any(named: 'description'),
      amountCents: any(named: 'amountCents'),
      startMonth: any(named: 'startMonth'),
      recurring: any(named: 'recurring'),
    ),
  );

  setUp(() {
    repository = incomeRepositoryMock();
    controller = IncomeFormController(repository);
  });

  tearDown(() => controller.dispose());

  group('estado inicial', () {
    test('começa no mês corrente e recorrente', () {
      expect(controller.startMonth.value, Month.current());
      expect(controller.recurring.value, isTrue);
      expect(controller.saving.value, isFalse);
      expect(controller.failure.value, isNull);
    });
  });

  group('validação local', () {
    test('descrição vazia não chega no repositório', () async {
      final id = await controller.submit(description: '  ', amountCents: 5000);

      expect(id, isNull);
      verifyNoCreate();
      expect(controller.errorFor('description'), 'Informe a descrição.');
    });

    test('valor ausente e valor zero são recusados', () async {
      await controller.submit(description: 'Salário', amountCents: null);
      expect(controller.errorFor('amountCents'), 'Informe o valor.');

      await controller.submit(description: 'Salário', amountCents: 0);
      expect(
        controller.errorFor('amountCents'),
        'O valor precisa ser maior que zero.',
      );

      verifyNoCreate();
    });

    test('erro local não vira erro geral — ele pertence ao campo', () async {
      await controller.submit(description: '', amountCents: null);

      expect(controller.generalFailure, isNull);
      expect(controller.errorFor('description'), isNotNull);
      expect(controller.errorFor('amountCents'), isNotNull);
    });
  });

  group('envio', () {
    test(
      'manda o que foi preenchido, sem espaço sobrando na descrição',
      () async {
        controller.setStartMonth('2026-03');
        controller.setRecurring(false);

        final id = await controller.submit(
          description: '  13º salário  ',
          amountCents: 500000,
        );

        expect(id, 'novo-id');
        verify(
          () => repository.create(
            description: '13º salário',
            amountCents: 500000,
            startMonth: '2026-03',
            recurring: false,
          ),
        ).called(1);
      },
    );

    test('400 do backend cai no campo que o zod apontou', () async {
      stubIncomeOperations(
        repository,
        createResult: Error(
          Failure.fromException(
            const BadRequestException(
              message: 'Dados inválidos',
              issues: [
                FieldIssue(path: 'startMonth', message: 'Mês fora da faixa.'),
              ],
            ),
          ),
        ),
      );

      final id = await controller.submit(
        description: 'Salário',
        amountCents: 500000,
      );

      expect(id, isNull);
      expect(controller.errorFor('startMonth'), 'Mês fora da faixa.');
      // Erro de campo não vira snackbar: ele já está embaixo do campo.
      expect(controller.generalFailure, isNull);
    });

    test('falha sem campo vira erro geral', () async {
      stubIncomeOperations(
        repository,
        createResult: Error(
          Failure.fromException(const NetworkException(message: 'sem rede')),
        ),
      );

      final id = await controller.submit(
        description: 'Salário',
        amountCents: 500000,
      );

      expect(id, isNull);
      expect(controller.generalFailure, isA<NetworkFailure>());
      expect(controller.errorFor('description'), isNull);
    });

    test('saving liga durante o envio e desliga no fim', () async {
      stubIncomeOperations(repository, delay: const Duration(milliseconds: 50));

      final pending = controller.submit(
        description: 'Salário',
        amountCents: 500000,
      );

      expect(controller.saving.value, isTrue);
      await pending;
      expect(controller.saving.value, isFalse);
    });
  });
}
