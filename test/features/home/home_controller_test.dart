import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:multiple_result/multiple_result.dart';
import 'package:se_controle_ai/core/month/selected_month_service.dart';
import 'package:se_controle_ai/core/errors/failure.dart';
import 'package:se_controle_ai/core/shared/view_state.dart';
import 'package:se_controle_ai/core/utils/month.dart';
import 'package:se_controle_ai/data/models/credit_card_invoice_model.dart';
import 'package:se_controle_ai/data/models/monthly_balance_model.dart';
import 'package:se_controle_ai/data/models/summary_section_model.dart';
import 'package:se_controle_ai/features/home/controller/home_controller.dart';

import '../../fixtures/mocks.dart';
import '../../fixtures/summary_fixture.dart';

void main() {
  // O serviço do mês avisa pelo toast quando esbarra no limite da faixa, e o
  // `MessageMixin` lê o `navigatorKey` — sem binding, `currentContext` lança
  // antes de chegar à guarda de contexto nulo. Mesmo motivo dos testes de
  // controller de tag e de cartão.
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockSummaryRepository repository;
  late HomeController controller;

  setUp(() {
    repository = summaryRepositoryMock();
    controller = HomeController(repository, SelectedMonthService());
  });

  tearDown(() => controller.dispose());

  /// As buscas saem todas do mesmo `load`, então uma delas basta para
  /// descrever "buscou" ou "não buscou". O saldo é a escolhida em todo o
  /// arquivo, por ser a que a tela mostra primeiro.
  void verificaBuscou({required String month, int vezes = 1}) =>
      verify(() => repository.getBalance(month: month)).called(vezes);

  group('estado inicial', () {
    // O BaseController chama onInit() no construtor, e o onInit do HomeController
    // dispara load(). Ou seja: construir já busca — quando o corpo do teste roda,
    // a busca do setUp terminou.
    test('busca as cinco seções sozinho ao ser construído', () {
      final inicial = SelectedMonthService.initial();
      verificaBuscou(month: inicial);
      verify(() => repository.getIncomes(month: inicial)).called(1);
      verify(() => repository.getExpenses(month: inicial)).called(1);
      verify(() => repository.getDebit(month: inicial)).called(1);
      verify(() => repository.getCreditCards(month: inicial)).called(1);

      expect(controller.balance.value, isA<Loaded<MonthlyBalanceModel>>());
      expect(controller.incomes.value, isA<Loaded<SummarySectionModel>>());
      expect(controller.expenses.value, isA<Loaded<SummarySectionModel>>());
      expect(controller.debit.value, isA<Loaded<SummarySectionModel>>());
      expect(
        controller.creditCards.value,
        isA<Loaded<List<CreditCardInvoiceModel>>>(),
      );
      expect(controller.month.value, inicial);
      // Falso de propósito: o app abre no mês seguinte, então o mês da tela
      // não é o do relógio. É justamente isso que acende o atalho de "voltar
      // para o mês atual" já na abertura.
      expect(controller.isCurrentMonth.value, isFalse);
    });

    test('fica em Loading enquanto a resposta não volta', () async {
      final segura = Completer<void>();
      final slowRepository = summaryRepositoryMock(pendenteAte: segura.future);
      final slowController = HomeController(
        slowRepository,
        SelectedMonthService(),
      );
      addTearDown(slowController.dispose);

      expect(slowController.balance.value, isA<Loading<MonthlyBalanceModel>>());

      // Solta a resposta e deixa a fila de eventos girar: sem esperar tempo
      // nenhum, o estado final já está lá.
      segura.complete();
      await pumpEventQueue();

      expect(slowController.balance.value, isA<Loaded<MonthlyBalanceModel>>());
    });
  });

  // As duas seções de gasto leem a mesma competência com filtros diferentes, e
  // é a diferença entre elas que justifica as duas existirem: a de cima traz o
  // que foi no cartão, a de baixo não.
  group('gastos e débito', () {
    test('a seção de gastos traz tudo que sai; a de débito, só o dinheiro', () {
      final gastos = controller.expenses.value as Loaded<SummarySectionModel>;
      final debito = controller.debit.value as Loaded<SummarySectionModel>;

      expect(
        gastos.data.items.map((item) => item.description),
        containsAll(['Aluguel', 'Netflix', 'Notebook']),
      );
      expect(debito.data.items.map((item) => item.description), ['Aluguel']);
    });

    test('o total da seção de gastos é o do saldo', () {
      final saldo = controller.balance.value as Loaded<MonthlyBalanceModel>;
      final gastos = controller.expenses.value as Loaded<SummarySectionModel>;

      expect(gastos.data.totalCents, saldo.data.expenseCents);
    });
  });

  // O motivo de existirem rotas separadas em vez de uma. Se estes três caírem,
  // a separação virou custo sem benefício: seria uma busca só, com mais passos.
  group('seções independentes', () {
    test('uma seção que falha não apaga as que chegaram', () async {
      stubHome(repository);
      stubCreditCardSections(repository, result: const Error(NetworkFailure()));

      await controller.load();

      expect(
        controller.creditCards.value,
        isA<Failed<List<CreditCardInvoiceModel>>>(),
      );
      expect(controller.balance.value, isA<Loaded<MonthlyBalanceModel>>());
      expect(controller.incomes.value, isA<Loaded<SummarySectionModel>>());
      expect(controller.expenses.value, isA<Loaded<SummarySectionModel>>());
      expect(controller.debit.value, isA<Loaded<SummarySectionModel>>());
    });

    test('uma seção lenta não segura as outras', () async {
      final presa = Completer<void>();
      stubHome(repository);
      stubCreditCardSections(repository, pendenteAte: presa.future);

      final pending = controller.load();
      await pumpEventQueue();

      // As rápidas já estão na tela com a de faturas ainda em voo.
      expect(controller.balance.value, isA<Loaded<MonthlyBalanceModel>>());
      expect(controller.incomes.value, isA<Loaded<SummarySectionModel>>());
      expect(controller.expenses.value, isA<Loaded<SummarySectionModel>>());
      expect(controller.debit.value, isA<Loaded<SummarySectionModel>>());
      expect(
        controller.creditCards.value,
        isA<Loading<List<CreditCardInvoiceModel>>>(),
      );

      presa.complete();
      await pending;
      expect(
        controller.creditCards.value,
        isA<Loaded<List<CreditCardInvoiceModel>>>(),
      );
    });

    test('load só termina quando todas terminam', () async {
      final presa = Completer<void>();
      stubHome(repository);
      stubDebitSection(repository, pendenteAte: presa.future);

      var terminou = false;
      final pending = controller.load().then((_) => terminou = true);
      await pumpEventQueue();

      // O RefreshIndicator depende disto: recolher a rosquinha antes da última
      // seção chegar mostraria "pronto" com um pedaço ainda carregando.
      expect(terminou, isFalse);

      presa.complete();
      await pending;
      expect(terminou, isTrue);
    });
  });

  group('load', () {
    test('sucesso vira Loaded com os dados', () async {
      clearInteractions(repository);

      await controller.load();

      final state = controller.balance.value;
      expect(state, isA<Loaded<MonthlyBalanceModel>>());
      expect((state as Loaded<MonthlyBalanceModel>).data.month, '2026-08');
      verificaBuscou(month: SelectedMonthService.initial());
    });

    test('falha vira Failed com a falha traduzida', () async {
      stubHome(repository, failure: const NetworkFailure());

      await controller.load();

      final state = controller.balance.value;
      expect(state, isA<Failed<MonthlyBalanceModel>>());
      expect(
        (state as Failed<MonthlyBalanceModel>).failure,
        isA<NetworkFailure>(),
      );
    });

    test('silent mantém o conteúdo na tela durante a busca', () async {
      final segura = Completer<void>();
      stubHome(repository, pendenteAte: segura.future);

      final pending = controller.load(silent: true);

      expect(controller.balance.value, isA<Loaded<MonthlyBalanceModel>>());
      segura.complete();
      await pending;
      expect(controller.balance.value, isA<Loaded<MonthlyBalanceModel>>());
    });
  });

  group('navegação entre meses', () {
    test('avança e volta pedindo o mês novo', () async {
      final start = controller.month.value;
      clearInteractions(repository);

      await controller.goToNextMonth();
      expect(controller.month.value, Month.next(start));

      await controller.goToPreviousMonth();
      expect(controller.month.value, start);

      expect(capturedMonths(repository), [Month.next(start), start]);
    });

    test('goToCurrentMonth volta de qualquer lugar', () async {
      await controller.goToMonth('2026-01');
      expect(controller.isCurrentMonth.value, isFalse);

      await controller.goToCurrentMonth();
      expect(controller.month.value, Month.current());
    });

    test('já no mês da tela e com dado carregado, não refaz a busca', () async {
      clearInteractions(repository);

      // Pede o mês que já está na tela, e não `goToCurrentMonth`: desde que o
      // app abre no mês seguinte, "voltar para o atual" é uma troca de
      // verdade, e aí buscar de novo é o comportamento certo.
      await controller.goToMonth(controller.month.value);

      verifyNever(() => repository.getBalance(month: any(named: 'month')));
    });

    test('mesmo mês SEM dado na tela busca — não deixa preso no erro', () async {
      // A busca inicial falhou: o estado é Failed, não Loaded. Pedir o mesmo mês
      // tem de disparar a busca de novo, senão "voltar para o mês atual" estando
      // no mês atual não faria nada e a tela ficaria presa no erro.
      final failing = summaryRepositoryMock(failure: const NetworkFailure());
      final controllerInError = HomeController(failing, SelectedMonthService());
      addTearDown(controllerInError.dispose);
      await Future<void>.delayed(Duration.zero);

      expect(
        controllerInError.balance.value,
        isA<Failed<MonthlyBalanceModel>>(),
      );
      clearInteractions(failing);
      stubHome(failing);

      await controllerInError.goToCurrentMonth();

      verify(() => failing.getBalance(month: Month.current())).called(1);
      expect(
        controllerInError.balance.value,
        isA<Loaded<MonthlyBalanceModel>>(),
      );
    });

    // Uma seção em erro basta: `alreadyLoaded` exige todas carregadas, que é
    // o que faz o "tentar de novo" da seção quebrada funcionar.
    test('mesmo mês com UMA seção em erro rebusca', () async {
      stubCreditCardSections(repository, result: const Error(NetworkFailure()));
      await controller.load();
      clearInteractions(repository);

      stubHome(repository);
      await controller.goToMonth(controller.month.value);

      verificaBuscou(month: SelectedMonthService.initial());
      expect(
        controller.creditCards.value,
        isA<Loaded<List<CreditCardInvoiceModel>>>(),
      );
    });

    test('mesmo mês a partir de erro tenta de novo', () async {
      stubHome(repository, failure: const NetworkFailure());
      await controller.load();
      clearInteractions(repository);

      stubHome(repository);
      await controller.goToMonth(controller.month.value);

      verify(() => repository.getBalance(month: any(named: 'month'))).called(1);
      expect(controller.balance.value, isA<Loaded<MonthlyBalanceModel>>());
    });

    test('goToMonth recusa competência inválida', () async {
      final start = controller.month.value;
      clearInteractions(repository);

      await controller.goToMonth('2026-13');
      await controller.goToMonth('lixo');
      await controller.goToMonth('9999-12');

      expect(controller.month.value, start);
      verifyNever(() => repository.getBalance(month: any(named: 'month')));
    });

    test('goToMonth para o mesmo mês já carregado não refaz a busca', () async {
      await controller.load();
      clearInteractions(repository);

      await controller.goToMonth(controller.month.value);

      verifyNever(() => repository.getBalance(month: any(named: 'month')));
    });

    test('não passa dos limites que o backend aceita', () async {
      await controller.goToMonth('2100-12');
      clearInteractions(repository);

      await controller.goToNextMonth();

      expect(controller.month.value, '2100-12');
      verifyNever(() => repository.getBalance(month: any(named: 'month')));

      await controller.goToMonth('2000-01');
      clearInteractions(repository);

      await controller.goToPreviousMonth();

      expect(controller.month.value, '2000-01');
      verifyNever(() => repository.getBalance(month: any(named: 'month')));
    });
  });

  group('corrida', () {
    test('resposta atrasada de mês antigo não sobrescreve a atual', () async {
      // Duas buscas em voo; a primeira volta depois da segunda.
      // A lenta fica presa até o fim do teste: assim a ordem de chegada é
      // decidida aqui, e não por quanto tempo a máquina levou.
      final presa = Completer<void>();
      stubHome(repository, pendenteAte: presa.future);
      final slow = controller.load();

      stubHome(repository, json: emptySummaryJson);
      await controller.load();

      expect(
        (controller.balance.value as Loaded<MonthlyBalanceModel>).data.month,
        '2026-09',
      );

      // A lenta chega agora e precisa ser descartada.
      presa.complete();
      await slow;
      expect(
        (controller.balance.value as Loaded<MonthlyBalanceModel>).data.month,
        '2026-09',
        reason: 'a resposta atrasada sobrescreveu a mais nova',
      );
    });
  });
}
