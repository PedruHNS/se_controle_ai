import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:multiple_result/multiple_result.dart';
import 'package:se_controle_ai/core/month/selected_month_controller.dart';
import 'package:se_controle_ai/core/errors/failure.dart';
import 'package:se_controle_ai/core/shared/view_state.dart';
import 'package:se_controle_ai/core/utils/month.dart';
import 'package:se_controle_ai/data/models/credit_card_model.dart';
import 'package:se_controle_ai/features/credit_cards/controller/credit_card_list_controller.dart';

import '../../fixtures/credit_card_fixture.dart';
import '../../fixtures/mocks.dart';

void main() {
  late MockCreditCardRepository repository;
  late CreditCardListController controller;

  setUp(() {
    repository = MockCreditCardRepository();
    stubCreditCardList(repository);
    stubCreditCardOperations(repository);
    controller = CreditCardListController(
      repository,
      SelectedMonthController(),
    );
  });

  tearDown(() => controller.dispose());

  test('busca os cartões e fica em Loaded', () async {
    await controller.load();

    final state = controller.state.value;
    expect(state, isA<Loaded<List<CreditCardModel>>>());
    expect((state as Loaded<List<CreditCardModel>>).data, hasLength(2));
  });

  // Sem `?month` o backend devolve `dueDate` null em todo cartão, e a lista
  // ficaria sem vencimento para mostrar.
  test(
    'a busca leva a competência corrente, para o dueDate vir resolvido',
    () async {
      await controller.load();

      final captured = verify(
        () => repository.list(month: captureAny(named: 'month')),
      ).captured;

      // `everyElement` e não uma lista exata: o `onInit` já dispara uma busca
      // na construção, então o número de chamadas depende de quem chamou `load`
      // depois. O que importa é que nenhuma delas vá sem competência.
      expect(captured, isNotEmpty);
      expect(captured, everyElement(Month.current()));
    },
  );

  test('falha vira Failed', () async {
    stubCreditCardList(
      repository,
      result: const Error(NetworkFailure(message: 'sem rede')),
    );

    await controller.load();

    expect(controller.state.value, isA<Failed<List<CreditCardModel>>>());
  });

  test('load sem silent passa por Loading', () async {
    stubCreditCardList(repository, delay: const Duration(milliseconds: 50));

    final pending = controller.load();

    expect(controller.state.value, isA<Loading<List<CreditCardModel>>>());
    await pending;
    expect(controller.state.value, isA<Loaded<List<CreditCardModel>>>());
  });

  test('refresh mantém o conteúdo na tela durante a busca', () async {
    await controller.load();
    stubCreditCardList(repository, delay: const Duration(milliseconds: 50));

    final pending = controller.refresh();

    expect(controller.state.value, isA<Loaded<List<CreditCardModel>>>());
    await pending;
  });

  test(
    'resposta atrasada de uma busca anterior não sobrescreve a atual',
    () async {
      var call = 0;
      when(() => repository.list(month: any(named: 'month'))).thenAnswer((
        _,
      ) async {
        call++;
        if (call == 1) {
          await Future<void>.delayed(const Duration(milliseconds: 80));
          return Success(
            creditCardListJson.map(CreditCardModel.fromJson).toList(),
          );
        }
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return const Success(<CreditCardModel>[]);
      });

      final slow = controller.load();
      await controller.load();
      await slow;

      expect(
        (controller.state.value as Loaded<List<CreditCardModel>>).data,
        isEmpty,
      );
    },
  );

  group('delete', () {
    test('exclui, recarrega e não devolve falha', () async {
      await controller.load();

      // Zera o que veio do `onInit` e do `load` acima, para o `verify` abaixo
      // falar só da exclusão.
      clearInteractions(repository);

      final failure = await controller.delete('id-do-cartao');

      expect(failure, isNull);
      verify(() => repository.delete('id-do-cartao')).called(1);
      // A recarga silenciosa depois do 204: a lista precisa perder o cartão.
      verify(() => repository.list(month: any(named: 'month'))).called(1);
    });

    // CAR-07: a FK é RESTRICT, e o 409 é a explicação que precisa chegar ao
    // diálogo — não um erro de sistema.
    test('devolve o 409 de cartão com gastos vinculados', () async {
      stubCreditCardOperations(
        repository,
        result: const Error(
          ConflictFailure(
            message: 'Cartão possui gastos vinculados e não pode ser excluído',
          ),
        ),
      );
      await controller.load();
      clearInteractions(repository);

      final failure = await controller.delete('id-do-cartao');

      expect(failure, isA<ConflictFailure>());
      expect(failure!.message, contains('gastos vinculados'));
      // Sem recarga: nada mudou no backend, e recarregar só piscaria a lista.
      verifyNever(() => repository.list(month: any(named: 'month')));
    });

    test('working sobe durante a exclusão e desce depois', () async {
      stubCreditCardOperations(
        repository,
        delay: const Duration(milliseconds: 50),
      );
      await controller.load();

      final pending = controller.delete('id-do-cartao');

      expect(controller.working.value, isTrue);
      await pending;
      expect(controller.working.value, isFalse);
    });
  });
}
