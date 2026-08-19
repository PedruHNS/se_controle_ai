import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:multiple_result/multiple_result.dart';
import 'package:se_controle_ai/core/errors/app_exception.dart';
import 'package:se_controle_ai/core/errors/failure.dart';
import 'package:se_controle_ai/core/shared/view_state.dart';
import 'package:se_controle_ai/data/models/income_model.dart';
import 'package:se_controle_ai/features/incomes/controller/income_list_controller.dart';

import '../../fixtures/income_fixture.dart';
import '../../fixtures/mocks.dart';

void main() {
  late MockIncomeRepository repository;
  late IncomeListController controller;

  setUp(() {
    repository = incomeRepositoryMock();
    controller = IncomeListController(repository);
  });

  tearDown(() => controller.dispose());

  test('busca sozinho ao ser construído', () {
    expect(controller.state.value, isA<Loaded<List<IncomeModel>>>());
    expect(
      (controller.state.value as Loaded<List<IncomeModel>>).data,
      hasLength(2),
    );
  });

  test('lista sem mês — é a tela de cadastro, não o recorte do resumo', () {
    // Com `?month`, um ganho encerrado sumiria da lista e não teria como ser
    // consultado nem apagado.
    verify(() => repository.list(month: null)).called(1);
  });

  test('falha vira Failed, com a falha traduzida', () async {
    stubIncomeList(
      repository,
      result: Error(
        Failure.fromException(const NetworkException(message: 'sem rede')),
      ),
    );

    await controller.load();

    final state = controller.state.value;
    expect(state, isA<Failed<List<IncomeModel>>>());
    expect((state as Failed<List<IncomeModel>>).failure, isA<NetworkFailure>());
  });

  test('refresh mantém o conteúdo na tela durante a busca', () async {
    stubIncomeList(repository, delay: const Duration(milliseconds: 50));

    final pending = controller.refresh();

    expect(controller.state.value, isA<Loaded<List<IncomeModel>>>());
    await pending;
    expect(controller.state.value, isA<Loaded<List<IncomeModel>>>());
  });

  test('load sem silent passa por Loading', () async {
    stubIncomeList(repository, delay: const Duration(milliseconds: 50));

    final pending = controller.load();

    expect(controller.state.value, isA<Loading<List<IncomeModel>>>());
    await pending;
    expect(controller.state.value, isA<Loaded<List<IncomeModel>>>());
  });

  test(
    'resposta atrasada de uma busca anterior não sobrescreve a atual',
    () async {
      // A primeira chamada demora e devolve a lista cheia; a segunda é rápida e
      // devolve vazio. Quem tem de vencer é a última **disparada**.
      var call = 0;
      when(() => repository.list(month: any(named: 'month'))).thenAnswer((
        _,
      ) async {
        call++;
        if (call == 1) {
          await Future<void>.delayed(const Duration(milliseconds: 80));
          return Success(incomeListJson.map(IncomeModel.fromJson).toList());
        }
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return const Success(<IncomeModel>[]);
      });

      final slow = controller.load();
      await controller.load();
      await slow;

      expect(
        (controller.state.value as Loaded<List<IncomeModel>>).data,
        isEmpty,
      );
    },
  );
}
