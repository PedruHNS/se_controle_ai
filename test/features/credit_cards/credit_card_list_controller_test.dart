import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:multiple_result/multiple_result.dart';
import 'package:se_controle_ai/core/month/selected_month_controller.dart';
import 'package:se_controle_ai/core/errors/failure.dart';
import 'package:se_controle_ai/core/shared/view_state.dart';
import 'package:se_controle_ai/core/utils/month.dart';
import 'package:se_controle_ai/data/models/credit_card_model.dart';
import 'package:se_controle_ai/features/credit_cards/controller/credit_card_list_controller.dart';

import '../../fixtures/mocks.dart';

void main() {
  // O `delete` que falha avisa por toast, e o toast procura o contexto do
  // `navigatorKey` global — o que só existe com binding inicializado. Sem esta
  // linha o teste morre em "Binding has not yet been initialized", que não tem
  // nada a ver com o que ele está conferindo.
  TestWidgetsFlutterBinding.ensureInitialized();

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

  test('load passa por Loading', () async {
    final segura = Completer<void>();
    stubCreditCardList(repository, pendenteAte: segura.future);

    final pending = controller.load();

    expect(controller.state.value, isA<Loading<List<CreditCardModel>>>());
    segura.complete();
    await pending;
    expect(controller.state.value, isA<Loaded<List<CreditCardModel>>>());
  });

  // `refresh` é `load` — não existe mais a busca silenciosa que segurava a
  // lista na tela enquanto a nova resposta não chegava. Quem puxa para
  // atualizar vê a lista sumir e voltar.
  test('refresh passa por Loading, igual ao load', () async {
    await controller.load();
    final segura = Completer<void>();
    stubCreditCardList(repository, pendenteAte: segura.future);

    final pending = controller.refresh();

    expect(controller.state.value, isA<Loading<List<CreditCardModel>>>());
    segura.complete();
    await pending;
    expect(controller.state.value, isA<Loaded<List<CreditCardModel>>>());
  });

  group('delete', () {
    test('exclui e recarrega a lista', () async {
      await controller.load();

      // Zera o que veio do `onInit` e do `load` acima, para o `verify` abaixo
      // falar só da exclusão.
      clearInteractions(repository);

      await controller.delete('id-do-cartao');

      verify(() => repository.delete('id-do-cartao')).called(1);
      // A recarga silenciosa depois do 204: a lista precisa perder o cartão.
      verify(() => repository.list(month: any(named: 'month'))).called(1);
    });

    // CAR-07: a FK é RESTRICT, e o 409 é explicação, não erro de sistema. Ele
    // não volta mais como retorno — o controller avisa por toast —, então o que
    // dá para conferir aqui é o efeito: a lista não é recarregada.
    test('409 de cartão com gastos vinculados não recarrega a lista', () async {
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

      await controller.delete('id-do-cartao');

      // Nada mudou no backend, e recarregar só piscaria a lista à toa.
      verifyNever(() => repository.list(month: any(named: 'month')));
    });
  });
}
