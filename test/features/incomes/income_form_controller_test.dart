import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:multiple_result/multiple_result.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:se_controle_ai/core/errors/app_exception.dart';
import 'package:se_controle_ai/core/month/selected_month_service.dart';
import 'package:se_controle_ai/core/errors/failure.dart';
import 'package:se_controle_ai/features/incomes/controller/income_form_controller.dart';

import '../../fixtures/mocks.dart';

void main() {
  late MockIncomeRepository repository;
  late MockTagRepository tags;
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

  /// Preenche o formulário como a tela faria.
  void fill({
    String? description,
    int? amountCents,
    String? startMonth,
    bool? recurring,
  }) {
    if (description != null) {
      controller.control<String>(IncomeFormController.description).value =
          description;
    }
    if (amountCents != null) {
      controller.control<int>(IncomeFormController.amountCents).value =
          amountCents;
    }
    if (startMonth != null) {
      controller.control<String>(IncomeFormController.startMonth).value =
          startMonth;
    }
    if (recurring != null) {
      controller.control<bool>(IncomeFormController.recurring).value =
          recurring;
    }
  }

  String? errorOf(String field) {
    final errors = controller.form.control(field).errors;
    return errors[IncomeFormController.backendError] as String?;
  }

  late SelectedMonthService month;

  setUp(() {
    month = SelectedMonthService();
    repository = incomeRepositoryMock();
    tags = MockTagRepository();
    stubTagList(tags);
    controller = IncomeFormController(repository, tags, month);
  });

  tearDown(() {
    controller.dispose();
    month.dispose();
  });

  group('estado inicial', () {
    test('competência começa no mês em que o app abre e sem recorrência', () {
      expect(
        controller.control<String>(IncomeFormController.startMonth).value,
        SelectedMonthService.initial(),
      );
      // Desligada por padrão, como no formulário de gasto: recorrência é
      // escolha explícita, não o que acontece quando ninguém toca no switch.
      expect(
        controller.control<bool>(IncomeFormController.recurring).value,
        isFalse,
      );
      expect(controller.saving.value, isFalse);
      expect(controller.generalFailure.value, isNull);
    });

    // O mês vem da AppBar, não do relógio — mesmo motivo do form de gastos.
    test('a competência nasce no mês selecionado', () {
      month.select('2026-12');
      controller = IncomeFormController(repository, tags, month);

      expect(
        controller.control<String>(IncomeFormController.startMonth).value,
        '2026-12',
      );
    });

    test('formulário nasce inválido — descrição e valor são obrigatórios', () {
      expect(controller.form.invalid, isTrue);
      expect(
        controller.form
            .control(IncomeFormController.description)
            .hasError(ValidationMessage.required),
        isTrue,
      );
      expect(
        controller.form
            .control(IncomeFormController.amountCents)
            .hasError(ValidationMessage.required),
        isTrue,
      );
    });
  });

  group('validação declarada no FormGroup', () {
    test('formulário inválido não chega no repositório', () async {
      final id = await controller.submit();

      expect(id, isNull);
      verifyNoCreate();
    });

    test(
      'submit inválido marca tudo como tocado, para o erro aparecer',
      () async {
        // Sem isto, campo nunca tocado fica inválido e silencioso: a pessoa
        // aperta Salvar e nada acontece, sem explicação.
        expect(
          controller.form.control(IncomeFormController.description).touched,
          isFalse,
        );

        await controller.submit();

        expect(
          controller.form.control(IncomeFormController.description).touched,
          isTrue,
        );
        expect(
          controller.form.control(IncomeFormController.amountCents).touched,
          isTrue,
        );
      },
    );

    test('valor zero é recusado pelo min, sem ida ao servidor', () async {
      fill(description: 'Salário', amountCents: 0);

      final id = await controller.submit();

      expect(id, isNull);
      expect(
        controller.form
            .control(IncomeFormController.amountCents)
            .hasError(ValidationMessage.min),
        isTrue,
      );
      verifyNoCreate();
    });

    test('descrição só de espaço não passa do required', () async {
      fill(description: '   ', amountCents: 5000);

      // O required do reactive_forms já recusa string em branco.
      expect(controller.form.invalid, isTrue);
      await controller.submit();
      verifyNoCreate();
    });
  });

  group('envio', () {
    test(
      'manda o que foi preenchido, sem espaço sobrando na descrição',
      () async {
        fill(
          description: '  13º salário  ',
          amountCents: 500000,
          startMonth: '2026-03',
          recurring: false,
        );

        final id = await controller.submit();

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

    test('400 do backend desce para o campo que o zod apontou', () async {
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
      fill(description: 'Salário', amountCents: 500000);

      final id = await controller.submit();

      expect(id, isNull);
      expect(errorOf(IncomeFormController.startMonth), 'Mês fora da faixa.');
      expect(
        controller.form.control(IncomeFormController.startMonth).touched,
        isTrue,
      );
      // Erro de campo não vira snackbar: ele já está embaixo do campo.
      expect(controller.generalFailure.value, isNull);
    });

    test('erro do backend some quando a pessoa corrige o campo', () async {
      stubIncomeOperations(
        repository,
        createResult: Error(
          Failure.fromException(
            const BadRequestException(
              message: 'Dados inválidos',
              issues: [
                FieldIssue(
                  path: 'amountCents',
                  message: 'Acima do teto do backend.',
                ),
              ],
            ),
          ),
        ),
      );
      fill(description: 'Salário', amountCents: 999999999);
      await controller.submit();

      expect(errorOf(IncomeFormController.amountCents), isNotNull);

      // A validação roda de novo na mudança de valor e substitui os erros —
      // é o que evita a mensagem velha grudada num campo já corrigido.
      fill(amountCents: 500000);

      expect(errorOf(IncomeFormController.amountCents), isNull);
      expect(controller.form.valid, isTrue);
    });

    test(
      '400 cujo path não é campo do formulário sobe como falha geral',
      () async {
        stubIncomeOperations(
          repository,
          createResult: Error(
            Failure.fromException(
              const BadRequestException(
                message: 'Corpo inválido',
                issues: [FieldIssue(path: 'body', message: 'JSON malformado.')],
              ),
            ),
          ),
        );
        fill(description: 'Salário', amountCents: 500000);

        await controller.submit();

        // Sem isto a tela recusaria sem dizer nada: nenhum campo mostraria erro.
        expect(controller.generalFailure.value, isA<ValidationFailure>());
      },
    );

    test('falha sem campo vira erro geral', () async {
      stubIncomeOperations(
        repository,
        createResult: Error(
          Failure.fromException(const NetworkException(message: 'sem rede')),
        ),
      );
      fill(description: 'Salário', amountCents: 500000);

      final id = await controller.submit();

      expect(id, isNull);
      expect(controller.generalFailure.value, isA<NetworkFailure>());
      expect(errorOf(IncomeFormController.description), isNull);
    });

    test('saving liga durante o envio e desliga no fim', () async {
      final segura = Completer<void>();
      stubIncomeOperations(repository, pendenteAte: segura.future);
      fill(description: 'Salário', amountCents: 500000);

      final pending = controller.submit();

      expect(controller.saving.value, isTrue);
      segura.complete();
      await pending;
      expect(controller.saving.value, isFalse);
    });
  });
}
