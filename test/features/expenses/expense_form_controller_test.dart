import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:multiple_result/multiple_result.dart';
import 'package:se_controle_ai/core/errors/app_exception.dart';
import 'package:se_controle_ai/core/errors/failure.dart';
import 'package:se_controle_ai/core/month/selected_month_service.dart';
import 'package:se_controle_ai/data/models/expense_model.dart';
import 'package:se_controle_ai/features/expenses/controller/expense_form_controller.dart';

import '../../fixtures/expense_fixture.dart';
import '../../fixtures/mocks.dart';
import '../../fixtures/tag_fixture.dart';

void main() {
  late MockExpenseRepository repository;
  late MockCreditCardRepository cards;
  late MockTagRepository tags;
  late ExpenseFormController controller;
  late SelectedMonthService month;

  ExpenseFormController build() =>
      ExpenseFormController(repository, cards, tags, month);

  setUp(() {
    month = SelectedMonthService();
    repository = expenseRepositoryMock();
    cards = creditCardRepositoryMock();
    tags = MockTagRepository();
    stubTagList(tags);
    stubTagCreate(tags);
    controller = build();
  });

  tearDown(() {
    controller.dispose();
    month.dispose();
  });

  group('cadastro', () {
    test('abre pronto, com débito e sem recorrência', () async {
      await controller.start();

      expect(controller.ready.value, isTrue);
      expect(controller.isEditing, isFalse);
      expect(
        controller
            .control<PaymentMethod>(ExpenseFormController.paymentMethod)
            .value,
        PaymentMethod.debit,
      );
      // Desligada por padrão: o gasto de uma vez só é o caso comum, e o switch
      // ligado fazia um almoço virar cobrança mensal sem ninguém pedir.
      expect(
        controller.control<bool>(ExpenseFormController.recurring).value,
        isFalse,
      );
    });

    // O mês do formulário é o que a pessoa escolheu na AppBar, não o do
    // relógio: quem navegou até outubro para lançar um gasto de outubro não
    // deveria ter que corrigir o campo depois.
    test('a competência nasce no mês selecionado, e não no corrente', () async {
      month.select('2026-12');
      controller = build();

      await controller.start();

      expect(
        controller.control<String>(ExpenseFormController.startMonth).value,
        '2026-12',
      );
      expect(
        controller.control<String>(ExpenseFormController.firstMonth).value,
        '2026-12',
      );
    });

    test('sem ninguém trocar o mês, vale o mês em que o app abriu', () async {
      await controller.start();

      expect(
        controller.control<String>(ExpenseFormController.startMonth).value,
        SelectedMonthService.initial(),
      );
    });

    // A lista de cartões é o que fecha o critério da Fase 3: o cartão
    // cadastrado precisa aparecer como opção no formulário de gasto.
    test('busca os cartões para o seletor', () async {
      await controller.start();

      expect(controller.cards, hasLength(2));
      verify(() => cards.list(month: any(named: 'month'))).called(1);
    });

    test('formulário vazio não manda requisição', () async {
      await controller.start();

      final id = await controller.submit();

      expect(id, isNull);
      verifyNever(
        () => repository.createFixed(
          description: any(named: 'description'),
          paymentMethod: any(named: 'paymentMethod'),
          amountCents: any(named: 'amountCents'),
          startMonth: any(named: 'startMonth'),
          tagId: any(named: 'tagId'),
          notes: any(named: 'notes'),
          creditCardId: any(named: 'creditCardId'),
          recurring: any(named: 'recurring'),
        ),
      );
    });

    test('cadastra no débito', () async {
      await controller.start();

      controller.form.patchValue({
        ExpenseFormController.description: '  Aluguel  ',
        ExpenseFormController.tagId: moradiaTagId,
        ExpenseFormController.amountCents: 120000,
        ExpenseFormController.startMonth: '2026-01',
      });

      final id = await controller.submit();

      expect(id, 'novo-gasto');
      verify(
        () => repository.createFixed(
          // O trim é do controller: espaço sobrando no fim vira descrição
          // diferente no banco.
          description: 'Aluguel',
          paymentMethod: PaymentMethod.debit,
          amountCents: 120000,
          startMonth: '2026-01',
          tagId: moradiaTagId,
          notes: null,
          creditCardId: null,
          recurring: false,
        ),
      ).called(1);
    });

    test('categoria vazia vai como null, não como string vazia', () async {
      await controller.start();

      controller.form.patchValue({
        ExpenseFormController.description: 'Aluguel',
        ExpenseFormController.tagId: moradiaTagId,
        ExpenseFormController.notes: '   ',
        ExpenseFormController.amountCents: 120000,
      });

      await controller.submit();

      verify(
        () => repository.createFixed(
          description: any(named: 'description'),
          paymentMethod: any(named: 'paymentMethod'),
          amountCents: any(named: 'amountCents'),
          startMonth: any(named: 'startMonth'),
          tagId: any(named: 'tagId'),
          notes: null,
          creditCardId: any(named: 'creditCardId'),
          recurring: any(named: 'recurring'),
        ),
      ).called(1);
    });

    // GFX-01 do lado do cliente: o backend recusaria com 422, mas a viagem é
    // evitável e a mensagem fica embaixo do campo.
    test('cartão sem cartão escolhido não sai do lugar', () async {
      await controller.start();

      controller.form.patchValue({
        ExpenseFormController.tagId: moradiaTagId,
        ExpenseFormController.description: 'Youtube',
        ExpenseFormController.amountCents: 2490,
      });
      controller.selectPaymentMethod(PaymentMethod.creditCard);

      final id = await controller.submit();

      expect(id, isNull);
      expect(
        controller.control<String>(ExpenseFormController.creditCardId).invalid,
        isTrue,
      );
    });

    test('cadastra no cartão com o cartão escolhido', () async {
      await controller.start();

      controller.form.patchValue({
        ExpenseFormController.tagId: moradiaTagId,
        ExpenseFormController.description: 'Youtube Music',
        ExpenseFormController.amountCents: 2490,
      });
      controller.selectPaymentMethod(PaymentMethod.creditCard);
      controller
          .control<String>(ExpenseFormController.creditCardId)
          .updateValue('cartao-1');

      final id = await controller.submit();

      expect(id, 'novo-gasto');
      verify(
        () => repository.createFixed(
          description: 'Youtube Music',
          paymentMethod: PaymentMethod.creditCard,
          amountCents: 2490,
          startMonth: any(named: 'startMonth'),
          tagId: any(named: 'tagId'),
          notes: null,
          creditCardId: 'cartao-1',
          recurring: false,
        ),
      ).called(1);
    });

    // GFX-07 do lado do cliente: trocar para débito limpa o cartão. Sem isto o
    // valor ficaria pendurado num campo escondido e sairia junto.
    test('voltar para débito descarta o cartão escolhido', () async {
      await controller.start();

      controller.form.patchValue({
        ExpenseFormController.tagId: moradiaTagId,
        ExpenseFormController.description: 'Aluguel',
        ExpenseFormController.amountCents: 120000,
      });
      controller.selectPaymentMethod(PaymentMethod.creditCard);
      controller
          .control<String>(ExpenseFormController.creditCardId)
          .updateValue('cartao-1');
      controller.selectPaymentMethod(PaymentMethod.debit);

      expect(
        controller.control<String>(ExpenseFormController.creditCardId).value,
        isNull,
      );

      await controller.submit();

      verify(
        () => repository.createFixed(
          description: any(named: 'description'),
          paymentMethod: PaymentMethod.debit,
          amountCents: any(named: 'amountCents'),
          startMonth: any(named: 'startMonth'),
          tagId: any(named: 'tagId'),
          notes: any(named: 'notes'),
          creditCardId: null,
          recurring: any(named: 'recurring'),
        ),
      ).called(1);
    });

    test('avulso manda recurring false', () async {
      await controller.start();

      controller.form.patchValue({
        ExpenseFormController.tagId: moradiaTagId,
        ExpenseFormController.description: 'Presente',
        ExpenseFormController.amountCents: 18000,
        ExpenseFormController.recurring: false,
      });

      await controller.submit();

      verify(
        () => repository.createFixed(
          description: any(named: 'description'),
          paymentMethod: any(named: 'paymentMethod'),
          amountCents: any(named: 'amountCents'),
          startMonth: any(named: 'startMonth'),
          tagId: any(named: 'tagId'),
          notes: any(named: 'notes'),
          creditCardId: any(named: 'creditCardId'),
          recurring: false,
        ),
      ).called(1);
    });
  });

  group('recusas do backend', () {
    test('400 desce para o campo, e não vira falha geral', () async {
      repository = expenseRepositoryMock(
        create: const Error(
          ValidationFailure(
            message: 'Dados inválidos',
            issues: [
              FieldIssue(
                path: 'description',
                message: 'Too small: expected string to have >=1 characters',
              ),
            ],
          ),
        ),
      );
      controller = build();
      await controller.start();

      controller.form.patchValue({
        ExpenseFormController.tagId: moradiaTagId,
        ExpenseFormController.description: 'x',
        ExpenseFormController.amountCents: 100,
      });

      final id = await controller.submit();

      expect(id, isNull);
      expect(controller.generalFailure.value, isNull);
      expect(
        controller.control<String>(ExpenseFormController.description).invalid,
        isTrue,
      );
    });

    // O 422 de regra de negócio não traz `path`, então não pertence a campo
    // nenhum — sobe como falha geral e a view mostra em snackbar.
    test('422 vira falha geral', () async {
      repository = expenseRepositoryMock(
        create: const Error(
          DomainRuleFailure(message: 'Gasto no cartão exige informar o cartão'),
        ),
      );
      controller = build();
      await controller.start();

      controller.form.patchValue({
        ExpenseFormController.tagId: moradiaTagId,
        ExpenseFormController.description: 'x',
        ExpenseFormController.amountCents: 100,
      });

      final id = await controller.submit();

      expect(id, isNull);
      expect(controller.generalFailure.value, isA<DomainRuleFailure>());
    });

    // Sem a lista de cartões não dá para oferecer a escolha, e um formulário
    // que só aceita débito recusaria metade dos gastos sem dizer por quê.
    test('falha ao buscar cartões não abre o formulário', () async {
      cards = creditCardRepositoryMock(
        list: const Error(NetworkFailure(message: 'sem rede')),
      );
      controller = build();

      await controller.start();

      expect(controller.ready.value, isFalse);
      expect(controller.generalFailure.value, isA<NetworkFailure>());
    });
  });

  group('edição', () {
    test('abre preenchido com o gasto', () async {
      await controller.start(id: 'gasto-1');

      expect(controller.ready.value, isTrue);
      expect(controller.isEditing, isTrue);
      expect(
        controller.control<String>(ExpenseFormController.description).value,
        'Aluguel',
      );
      expect(
        controller.control<String>(ExpenseFormController.tagId).value,
        moradiaTagId,
      );
      expect(
        controller.control<String>(ExpenseFormController.notes).value,
        'reajuste anual em julho',
      );
    });

    test('trocar a tag manda só o tagId', () async {
      await controller.start(id: 'gasto-1');

      controller
          .control<String>(ExpenseFormController.tagId)
          .updateValue(outraTagId);

      await controller.submit();

      expect(lastExpenseUpdateBody(repository), {'tagId': outraTagId});
    });

    test('GET que falha mostra erro, e não formulário', () async {
      stubExpenseDetail(
        repository,
        result: const Error(NotFoundFailure(message: 'Gasto não encontrado')),
      );

      await controller.start(id: 'sumiu');

      expect(controller.ready.value, isFalse);
      expect(controller.generalFailure.value, isA<NotFoundFailure>());
    });

    // GFX-06: só o que não é versionado entra no PATCH. Valor e competência
    // nem estão na tela — mudá-los é reajuste, correção ou encerramento.
    test('editar só a descrição manda só a descrição', () async {
      await controller.start(id: 'gasto-1');

      controller.form.patchValue({
        ExpenseFormController.tagId: moradiaTagId,
        ExpenseFormController.description: 'Aluguel novo',
      });

      final id = await controller.submit();

      expect(id, 'gasto-1');
      expect(lastExpenseUpdateBody(repository), {
        'description': 'Aluguel novo',
      });
    });

    // A observação é anulável, então usa Patch: apagar precisa chegar como
    // `null` explícito, e não como "não mexi".
    test('apagar a observação na tela manda null', () async {
      await controller.start(id: 'gasto-1');

      controller.control<String>(ExpenseFormController.notes).updateValue('');

      await controller.submit();

      expect(lastExpenseUpdateBody(repository), {'notes': null});
    });

    test('trocar para cartão manda forma e cartão juntos', () async {
      await controller.start(id: 'gasto-1');

      controller.selectPaymentMethod(PaymentMethod.creditCard);
      controller
          .control<String>(ExpenseFormController.creditCardId)
          .updateValue('cartao-9');

      await controller.submit();

      expect(lastExpenseUpdateBody(repository), {
        'paymentMethod': 'CREDIT_CARD',
        'creditCardId': 'cartao-9',
      });
    });

    test('trocar para débito limpa o cartão no corpo', () async {
      stubExpenseDetail(
        repository,
        result: Success(ExpenseModel.fromJson(youtubeJson)),
      );
      await controller.start(id: 'gasto-2');

      controller.selectPaymentMethod(PaymentMethod.debit);

      await controller.submit();

      expect(lastExpenseUpdateBody(repository), {
        'paymentMethod': 'DEBIT',
        'creditCardId': null,
      });
    });

    // Corpo vazio volta 400 no backend. Prender quem só abriu e fechou seria
    // absurdo, então a tela fecha sem requisição.
    test('abrir e fechar sem mexer não manda requisição', () async {
      await controller.start(id: 'gasto-1');

      final id = await controller.submit();

      expect(id, 'gasto-1');
      expect(expenseUpdateBodies(repository), isEmpty);
    });
  });
}
