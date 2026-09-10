import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:multiple_result/multiple_result.dart';
import 'package:se_controle_ai/core/errors/app_exception.dart';
import 'package:se_controle_ai/core/errors/failure.dart';
import 'package:se_controle_ai/core/month/selected_month_service.dart';
import 'package:se_controle_ai/core/utils/month.dart';
import 'package:se_controle_ai/data/models/credit_card_model.dart';
import 'package:se_controle_ai/data/models/expense_model.dart';
import 'package:se_controle_ai/features/expenses/controller/expense_form_controller.dart';

import '../../fixtures/credit_card_fixture.dart';
import '../../fixtures/expense_fixture.dart';
import '../../fixtures/mocks.dart';
import '../../fixtures/tag_fixture.dart';

// Os dois cartões da fixture fecham em dias diferentes — 10 e 27 —, e é essa
// diferença que prova que a fatura sai do cartão, e não de uma regra fixa.
const nubankId = '39e95359-97f2-441c-bc26-f68a8821ae5a';
const cartaoSimplesId = 'e0a0cdba-9f48-45d5-9843-90ddc4ef1cbf';

/// Hoje em `YYYY-MM-DD`. A regra da fatura compara a compra com o relógio —
/// desde que fatura fechada não recebe lançamento novo, uma data fixa no teste
/// envelheceria e passaria a cair sempre na fatura aberta.
String isoDeHoje() {
  final hoje = DateTime.now();
  return '${hoje.year.toString().padLeft(4, '0')}-'
      '${hoje.month.toString().padLeft(2, '0')}-'
      '${hoje.day.toString().padLeft(2, '0')}';
}

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

    // O campo de dia nasce em hoje, e é dele que a competência sai. Antes da
    // GFX-12 ela vinha do mês da AppBar; hoje o mês da AppBar não manda mais
    // em nada — quem está vendo dezembro e lança um almoço de hoje lança em
    // setembro, que é quando o almoço aconteceu.
    test('o dia nasce em hoje', () async {
      await controller.start();

      expect(
        controller.control<String>(ExpenseFormController.spentAt).value,
        isoDeHoje(),
      );
    });

    test('a competência nasce do dia, e não do mês que está na tela', () async {
      month.select('2026-12');
      controller = build();

      await controller.start();

      expect(
        controller.control<String>(ExpenseFormController.startMonth).value,
        isoDeHoje().substring(0, 7),
      );
    });

    test('sem dia não há o que salvar', () async {
      await controller.start();

      controller.control<String>(ExpenseFormController.spentAt).value = null;

      expect(
        controller.control<String>(ExpenseFormController.spentAt).valid,
        isFalse,
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
          spentAt: any(named: 'spentAt'),
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
          spentAt: any(named: 'spentAt'),
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
          spentAt: any(named: 'spentAt'),
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
          spentAt: any(named: 'spentAt'),
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
          spentAt: any(named: 'spentAt'),
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
          spentAt: any(named: 'spentAt'),
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

  group('dia da compra (GFX-12)', () {
    test('quem não mexe no campo cadastra com o dia de hoje', () async {
      await controller.start();

      controller.form.patchValue({
        ExpenseFormController.description: 'Aluguel',
        ExpenseFormController.tagId: moradiaTagId,
        ExpenseFormController.amountCents: 120000,
        ExpenseFormController.startMonth: '2026-01',
      });

      await controller.submit();

      // O app sempre manda o dia. O backend ainda aceita ausente — quem não
      // manda recebe o instante do cadastro —, mas esse caminho deixou de ser
      // alcançável pela tela quando o campo virou obrigatório.
      verify(
        () => repository.createFixed(
          description: any(named: 'description'),
          paymentMethod: any(named: 'paymentMethod'),
          amountCents: any(named: 'amountCents'),
          startMonth: any(named: 'startMonth'),
          tagId: any(named: 'tagId'),
          notes: any(named: 'notes'),
          creditCardId: any(named: 'creditCardId'),
          recurring: any(named: 'recurring'),
          spentAt: isoDeHoje(),
        ),
      ).called(1);
    });

    test('a data escolhida vai junto no cadastro', () async {
      await controller.start();

      controller.form.patchValue({
        ExpenseFormController.description: 'Mercado',
        ExpenseFormController.tagId: moradiaTagId,
        ExpenseFormController.amountCents: 25000,
        ExpenseFormController.startMonth: '2026-01',
        ExpenseFormController.spentAt: '2026-01-08',
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
          recurring: any(named: 'recurring'),
          spentAt: '2026-01-08',
        ),
      ).called(1);
    });

    test('vale igual no parcelado', () async {
      await controller.start();

      controller.selectType(ExpenseType.installment);
      controller.form.patchValue({
        ExpenseFormController.description: 'Geladeira',
        ExpenseFormController.tagId: moradiaTagId,
        ExpenseFormController.totalCents: 300000,
        ExpenseFormController.installmentsCount: 10,
        ExpenseFormController.firstMonth: '2026-01',
        ExpenseFormController.spentAt: '2026-01-08',
      });

      await controller.submit();

      verify(
        () => repository.createInstallment(
          description: any(named: 'description'),
          paymentMethod: any(named: 'paymentMethod'),
          totalCents: any(named: 'totalCents'),
          installmentsCount: any(named: 'installmentsCount'),
          firstMonth: any(named: 'firstMonth'),
          tagId: any(named: 'tagId'),
          notes: any(named: 'notes'),
          creditCardId: any(named: 'creditCardId'),
          spentAt: '2026-01-08',
        ),
      ).called(1);
    });

    // A fatura em que uma compra de **hoje** cai, calculada à parte do código
    // que está sob teste: até o fechamento é a deste mês, depois é a próxima.
    String faturaDeHoje(int fechamento) {
      final hoje = DateTime.now();
      final mes = Month.of(hoje.year, hoje.month);

      return hoje.day <= fechamento ? mes : Month.next(mes);
    }

    /// Um cartão só, com o fechamento que o teste precisa.
    void comCartaoQueFecha(int dia) {
      cards = creditCardRepositoryMock(
        list: Success([
          CreditCardModel.fromJson({
            ...nubankJson,
            'id': nubankId,
            'closingDay': dia,
          }),
        ]),
      );
      controller.dispose();
      controller = build();
    }

    Future<void> comprarHoje() async {
      controller.selectPaymentMethod(PaymentMethod.creditCard);
      controller.form.patchValue({
        ExpenseFormController.creditCardId: nubankId,
        ExpenseFormController.spentAt: isoDeHoje(),
      });
      await Future<void>.delayed(Duration.zero);
    }

    // O bug de 10/09/2026: cartão que fecha dia 1, compra lançada no dia 10, e
    // a primeira parcela caiu na fatura de setembro — que fechou no dia 1.
    test('a compra vai para a fatura que ainda está aberta', () async {
      comCartaoQueFecha(1);
      await controller.start();

      await comprarHoje();

      expect(
        controller.control<String>(ExpenseFormController.startMonth).value,
        faturaDeHoje(1),
      );
    });

    test('cartão que fecha no fim do mês mantém a compra neste mês', () async {
      comCartaoQueFecha(28);
      await controller.start();

      await comprarHoje();

      expect(
        controller.control<String>(ExpenseFormController.startMonth).value,
        faturaDeHoje(28),
      );
    });

    test('no parcelado quem se move é a primeira parcela', () async {
      comCartaoQueFecha(1);
      await controller.start();

      controller.selectType(ExpenseType.installment);
      await comprarHoje();

      expect(
        controller.control<String>(ExpenseFormController.firstMonth).value,
        faturaDeHoje(1),
      );
    });

    // Lançar hoje uma compra de meses atrás não pode mexer numa fatura que já
    // foi paga: o mínimo é a que ainda está aberta.
    test('compra antiga não cai em fatura fechada', () async {
      comCartaoQueFecha(10);
      await controller.start();

      controller.selectPaymentMethod(PaymentMethod.creditCard);
      controller.form.patchValue({
        ExpenseFormController.creditCardId: nubankId,
        ExpenseFormController.spentAt: '2026-01-12',
      });
      await Future<void>.delayed(Duration.zero);

      final competencia = controller
          .control<String>(ExpenseFormController.startMonth)
          .value!;

      expect(competencia, isNot('2026-02'));
      expect(
        Month.isBefore(competencia, Month.current()),
        isFalse,
        reason: 'nenhuma competência anterior ao mês corrente é lançável',
      );
    });

    // No débito não há fechamento, então não há o que calcular — a competência
    // continua sendo escolha de quem preenche.
    test('no débito o dia não mexe na competência', () async {
      await controller.start();

      controller.form.patchValue({
        ExpenseFormController.startMonth: '2026-01',
        ExpenseFormController.spentAt: '2026-01-28',
      });
      await Future<void>.delayed(Duration.zero);

      expect(
        controller.control<String>(ExpenseFormController.startMonth).value,
        '2026-01',
      );
    });

    // Assinatura não se compra num dia; ela começa num.
    test('recorrente troca o rótulo do campo', () async {
      await controller.start();

      expect(controller.spentAtLabel, 'Dia da compra');

      controller.form.patchValue({ExpenseFormController.recurring: true});
      await Future<void>.delayed(Duration.zero);

      expect(controller.spentAtLabel, 'Começou em');
    });

    // Cadastrar hoje o aluguel que começou em janeiro é registro retroativo de
    // cobrança que aconteceu — empurrar para a fatura aberta apagaria
    // justamente o histórico que a pessoa está tentando registrar.
    test('recorrente não é empurrado para a fatura aberta', () async {
      comCartaoQueFecha(28);
      await controller.start();

      controller.selectPaymentMethod(PaymentMethod.creditCard);
      controller.form.patchValue({
        ExpenseFormController.creditCardId: nubankId,
        ExpenseFormController.recurring: true,
        ExpenseFormController.spentAt: '2026-01-05',
      });
      await Future<void>.delayed(Duration.zero);

      expect(
        controller.control<String>(ExpenseFormController.startMonth).value,
        '2026-01',
      );

      // A mesma data numa compra pontual cai na fatura aberta, que é o
      // contraste: a trava existe, só não vale para recorrente.
      controller.form.patchValue({ExpenseFormController.recurring: false});
      await Future<void>.delayed(Duration.zero);

      expect(
        controller.control<String>(ExpenseFormController.startMonth).value,
        isNot('2026-01'),
      );
    });

    test('o texto de apoio diz em qual fatura a compra caiu', () async {
      comCartaoQueFecha(1);
      await controller.start();

      // No débito não há fatura, e o texto fala de competência.
      expect(controller.spentAtHelper, contains('competência'));

      controller.selectPaymentMethod(PaymentMethod.creditCard);
      controller.form.patchValue({
        ExpenseFormController.creditCardId: nubankId,
      });
      await Future<void>.delayed(Duration.zero);

      expect(controller.spentAtHelper, contains('Fecha dia 1'));

      await comprarHoje();

      expect(
        controller.spentAtHelper,
        contains(Month.label(faturaDeHoje(1)).toLowerCase()),
      );
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
