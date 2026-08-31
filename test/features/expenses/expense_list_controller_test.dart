import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:multiple_result/multiple_result.dart';
import 'package:se_controle_ai/core/errors/failure.dart';
import 'package:se_controle_ai/core/shared/view_state.dart';
import 'package:se_controle_ai/data/models/expense_model.dart';
import 'package:se_controle_ai/features/expenses/controller/expense_list_controller.dart';

import '../../fixtures/mocks.dart';

void main() {
  late MockExpenseRepository repository;
  late ExpenseListController controller;

  setUp(() {
    repository = MockExpenseRepository();
    stubExpenseList(repository);
    controller = ExpenseListController(repository);
  });

  tearDown(() => controller.dispose());

  test('busca os gastos e fica em Loaded', () async {
    await controller.load();

    final state = controller.state.value;
    expect(state, isA<Loaded<List<ExpenseModel>>>());
    expect((state as Loaded<List<ExpenseModel>>).data, hasLength(3));
  });

  // Esta é a tela de cadastro: com `?month` o backend esconderia o que não é
  // cobrado neste mês (GFX-10), e um gasto encerrado ficaria inalcançável para
  // consultar ou apagar.
  test('a busca vai sem competência, para não esconder o encerrado', () async {
    await controller.load();

    final captured = verify(
      () => repository.list(
        month: captureAny(named: 'month'),
        type: any(named: 'type'),
        paymentMethod: any(named: 'paymentMethod'),
        creditCardId: any(named: 'creditCardId'),
      ),
    ).captured;

    expect(captured, isNotEmpty);
    expect(captured, everyElement(isNull));
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
