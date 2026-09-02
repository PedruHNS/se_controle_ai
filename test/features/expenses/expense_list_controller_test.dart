import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:multiple_result/multiple_result.dart';
import 'package:se_controle_ai/core/errors/failure.dart';
import 'package:se_controle_ai/core/month/selected_month_controller.dart';
import 'package:se_controle_ai/core/shared/view_state.dart';
import 'package:se_controle_ai/core/utils/month.dart';
import 'package:se_controle_ai/data/models/expense_model.dart';
import 'package:se_controle_ai/features/expenses/controller/expense_list_controller.dart';

import '../../fixtures/mocks.dart';

void main() {
  late MockExpenseRepository repository;
  late SelectedMonthController selectedMonth;
  late ExpenseListController controller;

  setUp(() {
    repository = MockExpenseRepository();
    stubExpenseList(repository);
    selectedMonth = SelectedMonthController();
    controller = ExpenseListController(repository, selectedMonth);
  });

  tearDown(() {
    controller.dispose();
    selectedMonth.dispose();
  });

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

  // O filtro nasceu com a segunda seção de gasto da home: a de cima leva à
  // lista inteira, a de baixo ao recorte de dinheiro. É a mesma tela, e é o
  // filtro que muda.
  group('filtro por forma de pagamento', () {
    test('sem filtro, a busca vai sem paymentMethod', () async {
      await controller.load();

      expect(capturedPaymentMethods(), everyElement(isNull));
    });

    test('applyFilter troca o filtro e rebusca', () async {
      clearInteractions(repository);

      await controller.applyFilter(PaymentMethod.debit);

      expect(controller.paymentMethod, PaymentMethod.debit);
      expect(capturedPaymentMethods(), [PaymentMethod.debit]);
    });

    // A guarda existe porque a view reafirma o filtro a cada montagem: sem
    // ela, toda entrada na tela custaria uma requisição a mais.
    test('applyFilter com o mesmo filtro não rebusca', () async {
      await controller.applyFilter(PaymentMethod.debit);
      clearInteractions(repository);

      await controller.applyFilter(PaymentMethod.debit);

      verifyNever(
        () => repository.list(
          month: any(named: 'month'),
          activeFrom: any(named: 'activeFrom'),
          type: any(named: 'type'),
          paymentMethod: any(named: 'paymentMethod'),
          creditCardId: any(named: 'creditCardId'),
        ),
      );
    });

    // O controller é singleton e sobrevive à saída da tela. Voltar à lista
    // inteira depois do recorte tem de limpar o filtro, senão a tela "Gastos"
    // mostraria só o dinheiro.
    test('applyFilter com nulo volta à lista inteira', () async {
      await controller.applyFilter(PaymentMethod.debit);
      clearInteractions(repository);

      await controller.applyFilter(null);

      expect(controller.paymentMethod, isNull);
      expect(capturedPaymentMethods(), [null]);
    });

    test('a troca de mês mantém o filtro', () async {
      await controller.applyFilter(PaymentMethod.debit);
      clearInteractions(repository);

      selectedMonth.goToNext();
      await pumpEventQueue();

      expect(capturedPaymentMethods(), everyElement(PaymentMethod.debit));
    });
  });

  test('busca os gastos e fica em Loaded', () async {
    await controller.load();

    final state = controller.state.value;
    expect(state, isA<Loaded<List<ExpenseModel>>>());
    expect((state as Loaded<List<ExpenseModel>>).data, hasLength(3));
  });

  // Sem `?month` porque com ele o backend esconderia também o que ainda não
  // começou (GFX-10), e um gasto lançado para dezembro sumiria da tela de
  // cadastro. O recorte daqui é o outro, o `activeFrom` (GFX-11).
  test('a busca vai sem competência, para não esconder o que vem', () async {
    await controller.load();

    final captured = verify(
      () => repository.list(
        month: captureAny(named: 'month'),
        activeFrom: any(named: 'activeFrom'),
        type: any(named: 'type'),
        paymentMethod: any(named: 'paymentMethod'),
        creditCardId: any(named: 'creditCardId'),
      ),
    ).captured;

    expect(captured, isNotEmpty);
    expect(captured, everyElement(isNull));
  });

  // GFX-11: o avulso de setembro já foi cobrado e não sai de novo — em outubro
  // ele só encheria a lista com o selo "Encerrado".
  test('a busca leva o mês selecionado em activeFrom', () async {
    await controller.load();

    final captured = capturedActiveFrom();

    // `everyElement` e não uma lista exata: o `onInit` já dispara uma busca na
    // construção, então o número de chamadas depende de quem chamou `load`
    // depois. O que importa é que nenhuma delas vá sem o recorte.
    expect(captured, isNotEmpty);
    expect(captured, everyElement(Month.current()));
  });

  test('trocar o mês na home refaz a busca com o novo activeFrom', () async {
    final outro = Month.previous(Month.current());

    selectedMonth.select(outro);
    // O `effect` chama `load` de forma síncrona, mas a busca é assíncrona.
    await Future<void>.delayed(Duration.zero);

    expect(capturedActiveFrom().last, outro);
  });

  test('falha vira Failed', () async {
    stubExpenseList(
      repository,
      result: const Error(NetworkFailure(message: 'sem rede')),
    );

    await controller.load();

    expect(controller.state.value, isA<Failed<List<ExpenseModel>>>());
  });

  test('refresh mantém o conteúdo na tela durante a busca', () async {
    await controller.load();
    final segura = Completer<void>();
    stubExpenseList(repository, pendenteAte: segura.future);

    final pending = controller.refresh();

    expect(controller.state.value, isA<Loaded<List<ExpenseModel>>>());

    segura.complete();
    await pending;
  });

  // A guarda de corrida que toda tela do app tem: uma resposta atrasada não
  // pode sobrescrever a que veio depois dela.
  test('resposta atrasada não sobrescreve a mais nova', () async {
    final presa = Completer<void>();
    stubExpenseList(repository, pendenteAte: presa.future);
    final slow = controller.load();

    stubExpenseList(
      repository,
      result: const Error(NetworkFailure(message: 'a mais nova')),
    );
    await controller.load();

    expect(controller.state.value, isA<Failed<List<ExpenseModel>>>());

    presa.complete();
    await slow;

    expect(
      controller.state.value,
      isA<Failed<List<ExpenseModel>>>(),
      reason: 'a busca antiga voltou depois e reescreveu o estado',
    );
  });
}
