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
