import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:multiple_result/multiple_result.dart';
import 'package:se_controle_ai/core/errors/app_exception.dart';
import 'package:se_controle_ai/core/errors/failure.dart';
import 'package:se_controle_ai/core/shared/view_state.dart';
import 'package:se_controle_ai/data/services/selected_month_service.dart';
import 'package:se_controle_ai/core/utils/month_utils.dart';
import 'package:se_controle_ai/data/models/credit_card_model.dart';
import 'package:se_controle_ai/data/models/expense_model.dart';
import 'package:se_controle_ai/features/expenses/controller/expense_controller.dart';

import '../../fixtures/credit_card_fixture.dart';
import '../../fixtures/expense_fixture.dart';
import '../../fixtures/mocks.dart';
import '../../fixtures/tag_fixture.dart';

import 'package:se_controle_ai/data/enums/payment_method.dart';
import 'package:se_controle_ai/data/enums/expense_type.dart';

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
  // A recusa avisa por toast, e o toast procura o contexto pelo `navigatorKey`
  // — o que exige o binding.
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockExpenseRepository repository;
  late MockCreditCardRepository cards;
  late MockTagRepository tags;
  late MockNavigationService nav;
  late ExpenseController controller;
  late SelectedMonthService month;

  ExpenseController build() => ExpenseController(
    repository: repository,
    cardRepository: cards,
    tagRepository: tags,
    selectedMonth: month,
    nav: nav,
  );

  setUp(() {
    month = SelectedMonthService();
    repository = expenseRepositoryMock();
    cards = creditCardRepositoryMock();
    tags = MockTagRepository();
    stubTagList(tags);
    stubTagCreate(tags);
    nav = navigationServiceMock();
    controller = build();
  });

  tearDown(() {
    controller.dispose();
    month.dispose();
  });

  final aluguel = ExpenseModel.fromJson(aluguelJson);

  /// Os nomes do estado carregado da lista.
  List<String> naLista() =>
      (controller.state.value as Loaded<List<ExpenseModel>>).data
          .map((expense) => expense.description)
          .toList();

  /// A lista na tela, com o `GET` da abertura já esquecido pelo mock.
  ///
  /// [noMesAtual] porque o app abre no mês seguinte: um gasto lançado hoje
  /// cairia fora da tela, e a controller levaria a home até ele em vez de
  /// inserir a linha.
  Future<void> comListaCarregada({
    PaymentMethod? paymentMethod,
    bool noMesAtual = false,
  }) async {
    if (noMesAtual) month.select(MonthUtils.current());
    controller.start(paymentMethod);
    await pumpEventQueue();
    clearInteractions(repository);
  }

  void nenhumaBuscaDaLista() => verifyNever(
    () => repository.list(
      month: any(named: 'month'),
      activeFrom: any(named: 'activeFrom'),
      type: any(named: 'type'),
      paymentMethod: any(named: 'paymentMethod'),
      creditCardId: any(named: 'creditCardId'),
    ),
  );

  /// Um repositório cujas operações devolvem o aluguel com [descricao].
  void operacoesDevolvem(String descricao) => stubExpenseOperations(
    repository,
    result: Success(
      ExpenseModel.fromJson({...aluguelJson, 'description': descricao}),
    ),
  );

  group('lista', () {
    /// Os `paymentMethod` que o mock recebeu, em ordem de chamada.
    List<Object?> capturedPaymentMethods() => verify(
      () => repository.list(
        month: any(named: 'month'),
        activeFrom: any(named: 'activeFrom'),
        type: any(named: 'type'),
        paymentMethod: captureAny(named: 'paymentMethod'),
        creditCardId: any(named: 'creditCardId'),
      ),
    ).captured;

    /// Os `activeFrom` que o mock recebeu, em ordem de chamada.
    List<Object?> capturedActiveFrom() => verify(
      () => repository.list(
        month: any(named: 'month'),
        activeFrom: captureAny(named: 'activeFrom'),
        type: any(named: 'type'),
        paymentMethod: any(named: 'paymentMethod'),
        creditCardId: any(named: 'creditCardId'),
      ),
    ).captured;

    // A mesma controller serve o formulário aberto da home, então nascer não
    // pode buscar a lista: quem busca é o `start`, que só a tela da lista chama.
    test('nada é buscado antes do start', () {
      verifyNever(
        () => repository.list(
          month: any(named: 'month'),
          activeFrom: any(named: 'activeFrom'),
          type: any(named: 'type'),
          paymentMethod: any(named: 'paymentMethod'),
          creditCardId: any(named: 'creditCardId'),
        ),
      );
      expect(controller.state.value, isA<Loading<List<ExpenseModel>>>());
    });

    test('busca os gastos e fica em Loaded', () async {
      controller.start(null);
      await pumpEventQueue();

      expect(naLista(), hasLength(3));
    });

    test('com filtro, a primeira e única busca já vai com ele', () async {
      controller.start(PaymentMethod.debit);
      await pumpEventQueue();

      expect(capturedPaymentMethods(), [PaymentMethod.debit]);
    });

    // Sem `?month`, que esconderia o que ainda não começou (GFX-10); o recorte
    // é o `activeFrom` (GFX-11).
    test('a busca vai sem competência, com o mês em activeFrom', () async {
      controller.start(null);
      await pumpEventQueue();

      final captured = verify(
        () => repository.list(
          month: captureAny(named: 'month'),
          activeFrom: captureAny(named: 'activeFrom'),
          type: any(named: 'type'),
          paymentMethod: any(named: 'paymentMethod'),
          creditCardId: any(named: 'creditCardId'),
        ),
      ).captured;
      expect(captured, [null, SelectedMonthService.initial()]);
    });

    test('trocar o mês refaz a busca, mantendo o filtro', () async {
      await comListaCarregada(paymentMethod: PaymentMethod.debit);

      final outro = MonthUtils.previous(MonthUtils.current());
      month.select(outro);
      await pumpEventQueue();

      expect(capturedActiveFrom(), [outro]);
      clearInteractions(repository);
      await controller.refresh();
      expect(capturedPaymentMethods(), [PaymentMethod.debit]);
    });

    test('falha vira Failed', () async {
      stubExpenseList(
        repository,
        result: const Error(NetworkFailure(message: 'sem rede')),
      );

      controller.start(null);
      await pumpEventQueue();

      expect(controller.state.value, isA<Failed<List<ExpenseModel>>>());
    });

    test('refresh volta para Loading enquanto busca', () async {
      await comListaCarregada();
      final segura = Completer<void>();
      stubExpenseList(repository, pendenteAte: segura.future);

      final pending = controller.refresh();
      expect(controller.state.value, isA<Loading<List<ExpenseModel>>>());

      segura.complete();
      await pending;
      expect(controller.state.value, isA<Loaded<List<ExpenseModel>>>());
    });
  });

  group('operações de dinheiro', () {
    test('reajuste manda valor e mês, e fecha o diálogo e o detalhe', () async {
      await controller.adjust(
        aluguel.id,
        amountCents: 150000,
        effectiveFrom: '2026-09',
      );

      verify(
        () => repository.adjust(
          aluguel.id,
          amountCents: 150000,
          effectiveFrom: '2026-09',
        ),
      ).called(1);
      verify(() => nav.pop()).called(2);
    });

    // A operação devolve o gasto como ficou (GFX-13), e é ele que troca a
    // linha — sem buscar a lista de novo.
    test('com a lista na tela, troca a linha pelo gasto devolvido', () async {
      await comListaCarregada();
      operacoesDevolvem('Aluguel novo');

      await controller.correct(aluguel.id, amountCents: 130000);

      nenhumaBuscaDaLista();
      expect(naLista(), contains('Aluguel novo'));
      expect(naLista(), isNot(contains('Aluguel')));
      expect(naLista(), hasLength(3));
      verify(() => nav.pop()).called(2);
    });

    // Detalhe aberto pela fatura do cartão: não há lista para atualizar.
    test('sem a lista carregada, só fecha', () async {
      await controller.close(aluguel.id, lastMonth: '2026-10');

      verify(() => repository.close(aluguel.id, lastMonth: '2026-10'))
          .called(1);
      nenhumaBuscaDaLista();
      verify(() => nav.pop()).called(2);
    });

    test('reparcelamento manda os dois totais e o mês', () async {
      await controller.reschedule(
        aluguel.id,
        newTotalCents: 300000,
        newInstallmentsCount: 12,
        fromMonth: '2026-11',
      );

      verify(
        () => repository.reschedule(
          aluguel.id,
          newTotalCents: 300000,
          newInstallmentsCount: 12,
          fromMonth: '2026-11',
        ),
      ).called(1);
      verify(() => nav.pop()).called(2);
    });

    test('quitação manda o mês', () async {
      await controller.settle(aluguel.id, fromMonth: '2026-11');

      verify(() => repository.settle(aluguel.id, fromMonth: '2026-11'))
          .called(1);
      verify(() => nav.pop()).called(2);
    });

    // O 422 sai por toast, e o diálogo continua aberto para a correção.
    test('recusa do backend não fecha nada nem mexe na lista', () async {
      repository = expenseRepositoryMock(
        operations: const Error(
          DomainRuleFailure(message: 'Reajuste precisa valer de 2026-08'),
        ),
      );
      controller.dispose();
      controller = build();
      await comListaCarregada();

      await controller.adjust(
        aluguel.id,
        amountCents: 1,
        effectiveFrom: '2026-01',
      );

      verifyNever(() => nav.pop());
      nenhumaBuscaDaLista();
      expect(controller.saving.value, isFalse);
    });

    test('saving fica ligado enquanto a operação não volta', () async {
      final segura = Completer<void>();
      repository = expenseRepositoryMock(pendenteAte: segura.future);
      controller.dispose();
      controller = build();

      final pending = controller.correct(aluguel.id, amountCents: 130000);
      expect(controller.saving.value, isTrue);

      segura.complete();
      await pending;
      expect(controller.saving.value, isFalse);
    });

    test('exclusão tira da lista e fecha a confirmação e o detalhe', () async {
      await comListaCarregada();

      await controller.delete(aluguel.id);

      verify(() => repository.delete(aluguel.id)).called(1);
      expect(naLista(), isNot(contains('Aluguel')));
      nenhumaBuscaDaLista();
      verify(() => nav.pop()).called(2);
    });

    test('exclusão recusada deixa tudo como estava', () async {
      repository = expenseRepositoryMock(
        operations: const Error(NetworkFailure(message: 'sem rede')),
      );
      controller.dispose();
      controller = build();
      await comListaCarregada();

      await controller.delete(aluguel.id);

      verifyNever(() => nav.pop());
      expect(naLista(), contains('Aluguel'));
    });
  });

  group('nome do cartão', () {
    test('gasto no cartão busca o cartão e mostra o label', () async {
      final youtube = ExpenseModel.fromJson(youtubeJson);

      await controller.loadCardLabel(youtube.creditCardId);

      expect(controller.cardLabel.value, 'Nubank ••••4321');
    });

    test('gasto no débito não busca cartão nenhum', () async {
      await controller.loadCardLabel(aluguel.creditCardId);

      expect(controller.cardLabel.value, isNull);
      verifyNever(() => cards.getById(any(), month: any(named: 'month')));
    });

    // O nome do cartão é decoração: sem ele a tela diz só "No cartão".
    test('falha ao buscar o cartão deixa o nome vazio', () async {
      stubCreditCardDetail(
        cards,
        result: const Error(NetworkFailure(message: 'sem rede')),
      );

      await controller.loadCardLabel('cartao-1');

      expect(controller.cardLabel.value, isNull);
    });
  });

  group('formulário', () {
    // A controller é uma só e vive enquanto a lista vive, então cada abertura
    // do formulário tem de começar limpa — nada da edição anterior vaza.
    test('abrir o cadastro depois de uma edição começa limpo', () async {
      await controller.loadExpense(aluguel);
      await controller.resetForm();

      expect(controller.form.control('description').value, isNull);
      expect(controller.form.control('tagId').value, isNull);
      expect(controller.form.touched, isFalse);
    });

    test('cadastrar com a lista na tela insere o gasto devolvido', () async {
      await comListaCarregada(noMesAtual: true);
      stubExpenseOperations(
        repository,
        createResult: Success(
          ExpenseModel.fromJson({
            ...aluguelJson,
            'id': 'novo-gasto',
            'description': 'Mercado',
          }),
        ),
      );
      await controller.resetForm();

      controller.form.patchValue({
        'description': 'Mercado',
        'tagId': moradiaTagId,
        'amountCents': 2500,
      });
      await controller.onSubmit(expense: null);

      nenhumaBuscaDaLista();
      expect(naLista(), contains('Mercado'));
      expect(naLista(), hasLength(4));
      verify(() => nav.pop()).called(1);
    });

    // A lista é a do recorte de dinheiro: um gasto no cartão cadastrado dali
    // não pertence a ela.
    test(
      'no recorte de dinheiro, gasto no cartão não entra na lista',
      () async {
        await comListaCarregada(
          paymentMethod: PaymentMethod.debit,
          noMesAtual: true,
        );
        stubExpenseOperations(
          repository,
          createResult: Success(
            ExpenseModel.fromJson({
              ...youtubeJson,
              'id': 'novo-gasto',
              'description': 'Spotify',
            }),
          ),
        );
        await controller.resetForm();

        controller.form.patchValue({
          'description': 'Spotify',
          'tagId': moradiaTagId,
          'amountCents': 2190,
        });
        await controller.onSubmit(expense: null);

        expect(naLista(), isNot(contains('Spotify')));
        verify(() => nav.pop()).called(1);
      },
    );

    test('editar troca a linha pelo gasto devolvido', () async {
      await comListaCarregada();
      operacoesDevolvem('Aluguel novo');
      await controller.loadExpense(aluguel);

      controller.form.patchValue({'description': 'Aluguel novo'});
      await controller.onSubmit(expense: aluguel);

      nenhumaBuscaDaLista();
      expect(naLista(), contains('Aluguel novo'));
      expect(naLista(), hasLength(3));
      verify(() => nav.pop()).called(2);
    });

    // Trocar para cartão um gasto da lista de dinheiro tira ele dela.
    test('no recorte de dinheiro, editar para cartão tira da lista', () async {
      await comListaCarregada(paymentMethod: PaymentMethod.debit);
      stubExpenseOperations(
        repository,
        result: Success(
          ExpenseModel.fromJson({
            ...aluguelJson,
            'paymentMethod': 'CREDIT_CARD',
            'creditCardId': 'cartao-1',
          }),
        ),
      );
      await controller.loadExpense(aluguel);

      await controller.onSubmit(expense: aluguel);

      expect(naLista(), isNot(contains('Aluguel')));
    });

    group('cadastro', () {
      test('abre pronto, com débito e sem recorrência', () async {
        await controller.resetForm();

        expect(controller.formState.value, isA<Loaded<void>>());
        expect(controller.getPaymentMethod.value, PaymentMethod.debit);
        // Desligada por padrão: o gasto de uma vez só é o caso comum, e o switch
        // ligado fazia um almoço virar cobrança mensal sem ninguém pedir.
        expect(controller.isRecurring.value, isFalse);
      });

      // O campo de dia nasce em hoje, e é dele que a competência sai. Antes da
      // GFX-12 ela vinha do mês da AppBar; hoje o mês da AppBar não manda mais
      // em nada — quem está vendo dezembro e lança um almoço de hoje lança em
      // setembro, que é quando o almoço aconteceu.
      test('o dia nasce em hoje', () async {
        await controller.resetForm();

        expect(controller.form.control('spentAt').value, isoDeHoje());
      });

      test(
        'a competência nasce do dia, e não do mês que está na tela',
        () async {
          month.select('2026-12');
          controller = build();

          await controller.resetForm();

          expect(
            controller.form.control('startMonth').value,
            isoDeHoje().substring(0, 7),
          );
        },
      );

      test('sem dia não há o que salvar', () async {
        await controller.resetForm();

        controller.form.control('spentAt').value = null;

        expect(controller.form.control('spentAt').valid, isFalse);
      });

      // A lista de cartões é o que fecha o critério da Fase 3: o cartão
      // cadastrado precisa aparecer como opção no formulário de gasto.
      test('busca os cartões para o seletor', () async {
        await controller.resetForm();

        expect(controller.cards, hasLength(2));
        verify(() => cards.list(month: any(named: 'month'))).called(1);
      });

      // O Salvar só habilita com o formulário válido, como no de cartão.
      test('formulário vazio não é válido', () async {
        await controller.resetForm();

        expect(controller.form.valid, isFalse);
      });

      test('cadastra no débito e fecha a tela', () async {
        await controller.resetForm();

        controller.form.patchValue({
          'description': '  Aluguel  ',
          'tagId': moradiaTagId,
          'amountCents': 120000,
          'startMonth': '2026-01',
        });

        await controller.onSubmit(expense: null);

        verify(() => nav.pop()).called(1);
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
        await controller.resetForm();

        controller.form.patchValue({
          'description': 'Aluguel',
          'tagId': moradiaTagId,
          'notes': '   ',
          'amountCents': 120000,
        });

        await controller.onSubmit(expense: null);

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
        await controller.resetForm();

        controller.form.patchValue({
          'tagId': moradiaTagId,
          'description': 'Youtube',
          'amountCents': 2490,
        });
        controller.setPaymentMethod = PaymentMethod.creditCard;

        expect(controller.form.valid, isFalse);
        expect(controller.form.control('creditCardId').invalid, isTrue);
      });

      test('cadastra no cartão com o cartão escolhido', () async {
        await controller.resetForm();

        controller.form.patchValue({
          'tagId': moradiaTagId,
          'description': 'Youtube Music',
          'amountCents': 2490,
        });
        controller.setPaymentMethod = PaymentMethod.creditCard;
        controller.form.control('creditCardId').updateValue('cartao-1');

        await controller.onSubmit(expense: null);

        verify(() => nav.pop()).called(1);
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
        await controller.resetForm();

        controller.form.patchValue({
          'tagId': moradiaTagId,
          'description': 'Aluguel',
          'amountCents': 120000,
        });
        controller.setPaymentMethod = PaymentMethod.creditCard;
        controller.form.control('creditCardId').updateValue('cartao-1');
        controller.setPaymentMethod = PaymentMethod.debit;

        expect(controller.form.control('creditCardId').value, isNull);

        await controller.onSubmit(expense: null);

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
        await controller.resetForm();

        controller.form.patchValue({
          'tagId': moradiaTagId,
          'description': 'Presente',
          'amountCents': 18000,
        });
        controller.setIsRecurring = false;

        await controller.onSubmit(expense: null);

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
      // A recusa sai por toast, e a tela continua aberta para a correção — o 422
      // de regra de negócio e o 400 de validação do mesmo jeito.
      for (final failure in const <Failure>[
        DomainRuleFailure(message: 'Gasto no cartão exige informar o cartão'),
        ValidationFailure(
          message: 'Dados inválidos',
          issues: [FieldIssue(path: 'description', message: 'Too small')],
        ),
      ]) {
        test('${failure.runtimeType} não fecha a tela', () async {
          repository = expenseRepositoryMock(create: Error(failure));
          controller = build();
          await controller.resetForm();

          controller.form.patchValue({
            'tagId': moradiaTagId,
            'description': 'x',
            'amountCents': 100,
          });

          await controller.onSubmit(expense: null);

          verifyNever(() => nav.pop());
          expect(controller.saving.value, isFalse);
        });
      }

      // Sem a lista de cartões não dá para oferecer a escolha, e um formulário
      // que só aceita débito recusaria metade dos gastos sem dizer por quê.
      test('falha ao buscar cartões não abre o formulário', () async {
        cards = creditCardRepositoryMock(
          list: const Error(NetworkFailure(message: 'sem rede')),
        );
        controller = build();

        await controller.resetForm();

        final state = controller.formState.value;
        expect(state, isA<Failed<void>>());
        expect((state as Failed<void>).failure, isA<NetworkFailure>());
      });

      test('abrir de novo tenta os GET que falharam', () async {
        cards = creditCardRepositoryMock(
          list: const Error(NetworkFailure(message: 'sem rede')),
        );
        controller = build();
        await controller.resetForm();

        stubCreditCardList(cards);
        await controller.resetForm();

        expect(controller.formState.value, isA<Loaded<void>>());
      });
    });

    group('competência fora do mês da home', () {
      // A competência sai do dia, então o gasto pode cair fora do mês que a
      // pessoa está olhando. Sem levar a home junto, ele sumiria da tela e a
      // leitura seria "não salvou".
      test('cadastrar leva a home para o mês onde o gasto caiu', () async {
        month.select(MonthUtils.next(MonthUtils.next(MonthUtils.current())));
        controller = build();
        await controller.resetForm();

        controller.form.patchValue({
          'description': 'Mercado',
          'tagId': moradiaTagId,
          'amountCents': 2500,
        });

        await controller.onSubmit(expense: null);

        expect(month.month.value, MonthUtils.current());
      });

      test('a edição não mexe no mês da home', () async {
        month.select(MonthUtils.next(MonthUtils.next(MonthUtils.current())));
        final antes = month.month.value;
        controller = build();
        await controller.loadExpense(aluguel);

        await controller.onSubmit(expense: aluguel);

        expect(month.month.value, antes);
      });
    });

    group('dia da compra (GFX-12)', () {
      test('quem não mexe no campo cadastra com o dia de hoje', () async {
        await controller.resetForm();

        controller.form.patchValue({
          'description': 'Aluguel',
          'tagId': moradiaTagId,
          'amountCents': 120000,
          'startMonth': '2026-01',
        });

        await controller.onSubmit(expense: null);

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
        await controller.resetForm();

        controller.form.patchValue({
          'description': 'Mercado',
          'tagId': moradiaTagId,
          'amountCents': 25000,
          'startMonth': '2026-01',
          'spentAt': '2026-01-08',
        });

        await controller.onSubmit(expense: null);

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
        await controller.resetForm();

        controller.setType = ExpenseType.installment;
        controller.form.patchValue({
          'description': 'Geladeira',
          'tagId': moradiaTagId,
          'totalCents': 300000,
          'installmentsCount': 10,
          'firstMonth': '2026-01',
          'spentAt': '2026-01-08',
        });

        await controller.onSubmit(expense: null);

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
      /// A competência de uma compra feita **hoje**, pelas duas contas da CAR-03:
      /// a fatura pelo fechamento e, quando ela vence depois de fechar, o mês
      /// seguinte — que é quando a fatura é paga.
      String faturaDeHoje(int fechamento, {int vencimento = 17}) {
        final hoje = DateTime.now();
        final mes = MonthUtils.of(hoje.year, hoje.month);
        final fecha = hoje.day <= fechamento ? mes : MonthUtils.next(mes);

        return vencimento > fechamento ? fecha : MonthUtils.next(fecha);
      }

      /// Um cartão só, com os dias que o teste precisa. O vencimento importa
      /// tanto quanto o fechamento desde a CAR-03: é ele que diz em que mês a
      /// fatura é paga, e é esse mês que vira competência.
      void comCartaoQueFecha(int dia, {int vence = 17}) {
        cards = creditCardRepositoryMock(
          list: Success([
            CreditCardModel.fromJson({
              ...nubankJson,
              'id': nubankId,
              'closingDay': dia,
              'dueDay': vence,
            }),
          ]),
        );
        controller.dispose();
        controller = build();
      }

      Future<void> comprarHoje() async {
        controller.setPaymentMethod = PaymentMethod.creditCard;
        controller.form.patchValue({
          'creditCardId': nubankId,
          'spentAt': isoDeHoje(),
        });
        await Future<void>.delayed(Duration.zero);
      }

      // O bug de 10/09/2026: cartão que fecha dia 1, compra lançada no dia 10, e
      // a primeira parcela caiu na fatura de setembro — que fechou no dia 1.
      test('a compra vai para a fatura que ainda está aberta', () async {
        comCartaoQueFecha(1);
        await controller.resetForm();

        await comprarHoje();

        expect(controller.form.control('startMonth').value, faturaDeHoje(1));
      });

      // O bug de 12/09/2026, como aconteceu: Inter fecha 31 e vence 5. A compra
      // do dia 12 cabe na fatura que fecha em 30/09 — e essa fatura só é paga em
      // 05/10. Antes ela virava competência de setembro, o mês da fatura que já
      // tinha sido paga no dia 5.
      test(
        'cartão que vence antes de fechar joga a compra no mês do pagamento',
        () async {
          comCartaoQueFecha(31, vence: 5);
          await controller.resetForm();

          await comprarHoje();

          final hoje = DateTime.now();
          expect(
            controller.form.control('startMonth').value,
            MonthUtils.next(MonthUtils.of(hoje.year, hoje.month)),
          );
        },
      );

      test(
        'fechamento no fim do mês não empurra pela data da compra',
        () async {
          comCartaoQueFecha(28);
          await controller.resetForm();

          await comprarHoje();

          expect(controller.form.control('startMonth').value, faturaDeHoje(28));
        },
      );

      test('no parcelado quem se move é a primeira parcela', () async {
        comCartaoQueFecha(1);
        await controller.resetForm();

        controller.setType = ExpenseType.installment;
        await comprarHoje();

        expect(controller.form.control('firstMonth').value, faturaDeHoje(1));
      });

      // Lançar hoje uma compra de meses atrás não pode mexer numa fatura que já
      // foi paga: o mínimo é a que ainda está aberta.
      test('compra antiga não cai em fatura fechada', () async {
        comCartaoQueFecha(10);
        await controller.resetForm();

        controller.setPaymentMethod = PaymentMethod.creditCard;
        controller.form.patchValue({
          'creditCardId': nubankId,
          'spentAt': '2026-01-12',
        });
        await Future<void>.delayed(Duration.zero);

        final competencia = controller.form.control('startMonth').value!;

        expect(competencia, isNot('2026-02'));
        expect(
          MonthUtils.isBefore(competencia, MonthUtils.current()),
          isFalse,
          reason: 'nenhuma competência anterior ao mês corrente é lançável',
        );
      });

      // No débito não há fechamento, então não há o que calcular — a competência
      // continua sendo escolha de quem preenche.
      test('no débito o dia não mexe na competência', () async {
        await controller.resetForm();

        controller.form.patchValue({
          'startMonth': '2026-01',
          'spentAt': '2026-01-28',
        });
        await Future<void>.delayed(Duration.zero);

        expect(controller.form.control('startMonth').value, '2026-01');
      });

      // Só o fixo é recorrente: o switch fica escondido no parcelado, e o valor
      // que sobrou nele não pode decidir a regra da fatura.
      test('o recorrente que sobrou no switch não vale no parcelado', () async {
        comCartaoQueFecha(28);
        await controller.resetForm();

        controller.setIsRecurring = true;
        controller.setType = ExpenseType.installment;
        controller.setPaymentMethod = PaymentMethod.creditCard;
        controller.form.patchValue({
          'creditCardId': nubankId,
          'spentAt': '2026-01-05',
        });
        await Future<void>.delayed(Duration.zero);

        // Fevereiro seria a conta do recorrente; o parcelado cai na fatura
        // aberta, como qualquer compra pontual.
        expect(controller.form.control('firstMonth').value, isNot('2026-02'));
      });

      // Cadastrar hoje o aluguel que começou em janeiro é registro retroativo de
      // cobrança que aconteceu — empurrar para a fatura aberta apagaria
      // justamente o histórico que a pessoa está tentando registrar.
      test('recorrente não é empurrado para a fatura aberta', () async {
        comCartaoQueFecha(28);
        await controller.resetForm();

        controller.setPaymentMethod = PaymentMethod.creditCard;
        controller.setIsRecurring = true;
        controller.form.patchValue({
          'creditCardId': nubankId,
          'spentAt': '2026-01-05',
        });
        await Future<void>.delayed(Duration.zero);

        // Fevereiro, e não janeiro: a compra de 05/01 entra na fatura que fecha
        // em 28/01, e essa fatura vence no dia 17 de **fevereiro**. Não é o
        // empurrão da fatura aberta — é a segunda conta da CAR-03, que vale
        // igual no recorrente.
        expect(controller.form.control('startMonth').value, '2026-02');

        // A mesma data numa compra pontual cai na fatura aberta, que é o
        // contraste: a trava existe, só não vale para recorrente.
        controller.setIsRecurring = false;
        await Future<void>.delayed(Duration.zero);

        expect(controller.form.control('startMonth').value, isNot('2026-02'));
      });
    });

    group('edição', () {
      // A edição se abre do detalhe, e salvar fecha o formulário e o detalhe:
      // quem mostra o resultado é a lista, como nas operações de dinheiro.
      test('abre preenchido com o gasto', () async {
        await controller.loadExpense(aluguel);

        expect(controller.formState.value, isA<Loaded<void>>());
        expect(controller.form.control('description').value, 'Aluguel');
        expect(controller.form.control('tagId').value, moradiaTagId);
        expect(
          controller.form.control('notes').value,
          'reajuste anual em julho',
        );
      });

      // GFX-06: vão os dados cadastrais inteiros, e não só o que mudou — o
      // `PATCH` de descrição, forma, observação e cartão é substituição. Valor e
      // competência nem estão na tela.
      test('editar a descrição manda os dados cadastrais inteiros', () async {
        await controller.loadExpense(aluguel);

        controller.form.patchValue({'description': 'Aluguel novo'});

        await controller.onSubmit(expense: aluguel);

        verify(() => nav.pop()).called(2);
        expect(lastExpenseUpdateBody(repository), {
          'description': 'Aluguel novo',
          'paymentMethod': 'DEBIT',
          'notes': 'reajuste anual em julho',
          'creditCardId': null,
        });
      });

      // A tag é a exceção: reenviar uma arquivada é recusado com 422, então ela
      // só entra no corpo quando trocou.
      test('trocar a tag manda o tagId junto', () async {
        await controller.loadExpense(aluguel);

        controller.form.control('tagId').updateValue(outraTagId);

        await controller.onSubmit(expense: aluguel);

        expect(
          lastExpenseUpdateBody(repository),
          containsPair('tagId', outraTagId),
        );
      });

      test('salvar sem mexer não manda a tag', () async {
        await controller.loadExpense(aluguel);

        await controller.onSubmit(expense: aluguel);

        expect(lastExpenseUpdateBody(repository), isNot(contains('tagId')));
        verify(() => nav.pop()).called(2);
      });

      test('apagar a observação na tela manda null', () async {
        await controller.loadExpense(aluguel);

        controller.form.control('notes').updateValue('');

        await controller.onSubmit(expense: aluguel);

        expect(lastExpenseUpdateBody(repository), containsPair('notes', null));
      });

      test('trocar para cartão manda forma e cartão juntos', () async {
        await controller.loadExpense(aluguel);

        controller.setPaymentMethod = PaymentMethod.creditCard;
        controller.form.control('creditCardId').updateValue('cartao-9');

        await controller.onSubmit(expense: aluguel);

        expect(
          lastExpenseUpdateBody(repository),
          allOf(
            containsPair('paymentMethod', 'CREDIT_CARD'),
            containsPair('creditCardId', 'cartao-9'),
          ),
        );
      });

      test('trocar para débito limpa o cartão no corpo', () async {
        final youtube = ExpenseModel.fromJson(youtubeJson);
        await controller.loadExpense(youtube);

        controller.setPaymentMethod = PaymentMethod.debit;

        await controller.onSubmit(expense: youtube);

        expect(
          lastExpenseUpdateBody(repository),
          allOf(
            containsPair('paymentMethod', 'DEBIT'),
            containsPair('creditCardId', null),
          ),
        );
      });
    });
  });
}
