import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:multiple_result/multiple_result.dart';
import 'package:se_controle_ai/data/services/selected_month_service.dart';
import 'package:se_controle_ai/core/errors/failure.dart';
import 'package:se_controle_ai/core/shared/view_state.dart';
import 'package:se_controle_ai/data/models/credit_card_model.dart';
import 'package:se_controle_ai/features/credit_cards/controller/credit_card_controller.dart';

import '../../fixtures/mocks.dart';

void main() {
  // O `delete` que falha avisa por toast, e o toast procura o contexto do
  // `navigatorKey` global — o que só existe com binding inicializado. Sem esta
  // linha o teste morre em "Binding has not yet been initialized", que não tem
  // nada a ver com o que ele está conferindo.
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockCreditCardRepository repository;
  late CreditCardController controller;

  setUp(() {
    repository = MockCreditCardRepository();
    stubCreditCardList(repository);
    stubCreditCardOperations(repository);
    controller = CreditCardController(repository, SelectedMonthService());
  });

  tearDown(() => controller.dispose());

  test('busca os cartões e fica em Loaded', () async {
    await controller.refresh();

    final state = controller.state.value;
    expect(state, isA<Loaded<List<CreditCardModel>>>());
    expect((state as Loaded<List<CreditCardModel>>).data, hasLength(2));
  });

  // Sem `?month` o backend devolve `dueDate` null em todo cartão, e a lista
  // ficaria sem vencimento para mostrar.
  test(
    'a busca leva a competência selecionada, para o dueDate vir resolvido',
    () async {
      await controller.refresh();

      final captured = verify(
        () => repository.list(month: captureAny(named: 'month')),
      ).captured;

      // `everyElement` e não uma lista exata: o `onInit` já dispara uma busca
      // na construção, então o número de chamadas depende de quem chamou `load`
      // depois. O que importa é que nenhuma delas vá sem competência.
      expect(captured, isNotEmpty);
      expect(captured, everyElement(SelectedMonthService.initial()));
    },
  );

  test('falha vira Failed', () async {
    stubCreditCardList(
      repository,
      result: const Error(NetworkFailure(message: 'sem rede')),
    );

    await controller.refresh();

    expect(controller.state.value, isA<Failed<List<CreditCardModel>>>());
  });

  // A busca não é mais pública: quem chama de fora é o `refresh`, e a carga
  // inicial vem do `effect` do mês. Não existe busca silenciosa — quem puxa
  // para atualizar vê a lista sumir e voltar, porque o estado passa por
  // `Loading` antes da resposta.
  test('refresh passa por Loading antes de voltar a Loaded', () async {
    await controller.refresh();
    final segura = Completer<void>();
    stubCreditCardList(repository, pendenteAte: segura.future);

    final pending = controller.refresh();

    expect(controller.state.value, isA<Loading<List<CreditCardModel>>>());
    segura.complete();
    await pending;
    expect(controller.state.value, isA<Loaded<List<CreditCardModel>>>());
  });

  group('delete', () {
    test('exclui e tira o cartão da lista sem rebuscar', () async {
      await controller.refresh();
      final antes =
          (controller.state.value as Loaded<List<CreditCardModel>>).data;
      final excluido = antes.first.id;

      // Zera o que veio do `onInit` e do `load` acima, para o `verify` abaixo
      // falar só da exclusão.
      clearInteractions(repository);

      await controller.delete(excluido);

      verify(() => repository.delete(excluido)).called(1);

      // O cartão sai da lista que já está na tela, em vez de a lista ser
      // buscada de novo: o backend já confirmou o 204, e rebuscar só custaria
      // uma volta de rede para chegar ao mesmo resultado — piscando a lista no
      // caminho.
      verifyNever(() => repository.list(month: any(named: 'month')));

      final depois =
          (controller.state.value as Loaded<List<CreditCardModel>>).data;
      expect(depois, hasLength(antes.length - 1));
      expect(depois.map((card) => card.id), isNot(contains(excluido)));
    });

    // A exclusão escreve sobre a lista que está na tela, então sem lista na
    // tela não há o que escrever — e `Loaded` é a única forma de estado que
    // carrega os cartões.
    test('delete antes de a lista chegar não faz nada', () async {
      final segura = Completer<void>();
      stubCreditCardList(repository, pendenteAte: segura.future);
      final pending = controller.refresh();

      await controller.delete('id-do-cartao');

      verifyNever(() => repository.delete(any()));
      expect(controller.state.value, isA<Loading<List<CreditCardModel>>>());

      segura.complete();
      await pending;
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
      await controller.refresh();
      clearInteractions(repository);

      await controller.delete('id-do-cartao');

      // Nada mudou no backend, e recarregar só piscaria a lista à toa.
      verifyNever(() => repository.list(month: any(named: 'month')));
    });
  });
}
