import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:multiple_result/multiple_result.dart';
import 'package:se_controle_ai/core/errors/failure.dart';
import 'package:se_controle_ai/core/shared/view_state.dart';
import 'package:se_controle_ai/data/models/tag_model.dart';
import 'package:se_controle_ai/features/tags/controller/tag_list_controller.dart';

import '../../fixtures/mocks.dart';
import '../../fixtures/tag_fixture.dart';

/// A criação sem refresh, no nível do controller.
///
/// Sem widget: o que está em jogo é a lista que o `POST` deixa em memória, e um
/// teste de tela faria a mesma pergunta passando por diálogo, FAB e navegação.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockTagRepository repository;
  late MockNavigationService nav;
  late TagListController controller;

  /// As tags do estado carregado. Estoura se a tela não estiver em [Loaded] —
  /// que é o que se quer, porque aí a asserção seguinte não teria sentido.
  List<TagModel> carregadas() =>
      (controller.state.value as Loaded<List<TagModel>>).data;

  setUp(() async {
    repository = MockTagRepository();
    nav = navigationServiceMock();
    stubTagList(repository);
    stubTagCreate(repository);
    stubTagDelete(repository);
    stubTagUpdate(repository);

    controller = TagListController(repository: repository, nav: nav);
    // O `onInit` do BaseController dispara o primeiro `GET` no construtor, e
    // ele precisa terminar antes de a criação ter uma lista onde entrar.
    await controller.refresh();
    // O `GET` da abertura já aconteceu; daqui para a frente não deve haver
    // outro.
    clearInteractions(repository);
  });

  tearDown(() => controller.dispose());

  /// Cria como a tela cria. A cor entra sempre: virou obrigatória (TAG-02), e
  /// sem ela o `create` sai antes de chamar o repositório.
  Future<void> criar(String nome, {String cor = '#66BB6A'}) async {
    controller.form.control('title').updateValue(nome);
    controller.setColorSelected = cor;
    await controller.create();
  }

  test('a tag criada entra na lista sem um novo GET', () async {
    await criar('Mercado');

    expect(carregadas().map((tag) => tag.name), contains('Mercado'));
    expect(
      carregadas().firstWhere((tag) => tag.name == 'Mercado').id,
      criadaTagId,
    );
    verifyNever(() => repository.list());
  });

  // A ordem é a do `compareTo`: a tag criada não fica no topo nem no fim.
  test('entra na posição alfabética', () async {
    stubTagCreate(
      repository,
      result: Success(TagModel.fromJson({...tagCriadaJson, 'name': 'Aluguel'})),
    );

    await criar('Aluguel');

    expect(carregadas().map((tag) => tag.name), [
      'Aluguel',
      'Moradia',
      'Outros',
      'Transporte',
    ]);
  });

  // O diálogo se fecha sozinho no sucesso: quem confirmou já viu a tag entrar
  // na lista atrás, e deixar a folha aberta pediria um segundo toque para dizer
  // a mesma coisa. Fecha com a tag como resultado, que é como o formulário de
  // gasto fica sabendo qual selecionar.
  test('fecha o diálogo devolvendo a tag criada', () async {
    await criar('Mercado');

    final devolvida =
        verify(() => nav.pop<TagModel>(captureAny())).captured.single
            as TagModel;
    expect(devolvida.id, criadaTagId);
  });

  test('criação recusada fecha o diálogo sem tag', () async {
    stubTagCreate(
      repository,
      result: const Error(
        ConflictFailure(message: 'Já existe uma tag chamada "Moradia"'),
      ),
    );

    await criar('Moradia');

    verify(() => nav.pop()).called(1);
    verifyNever(() => nav.pop<TagModel>(any()));
  });

  // Quem chama `clearText` é o `initState` do diálogo, não o `create` — o
  // formulário é zerado na abertura, e não no fechamento. Assim o estado está
  // certo qualquer que tenha sido o desfecho anterior: criou, cancelou ou saiu
  // pelo botão de voltar do sistema.
  group('clearText', () {
    test('limpa o campo para a próxima tag', () {
      // Sem isto, reabrir o diálogo traz o nome da tag anterior escrito — e
      // confirmar sem prestar atenção daria 409 (TAG-01).
      controller.form.control('title').updateValue('Mercado');

      controller.clearText();

      expect(controller.form.control('title').value, isNull);
    });

    test('o campo limpo não fica marcado como inválido', () {
      // `reset()` e não `updateValue(null)`: o segundo zera o valor mas mantém
      // o controle *touched*, e aí o `required` dispara na hora — a pessoa
      // reabre o diálogo e vê "campo obrigatório" em vermelho sem ter digitado
      // nada.
      controller.form.control('title').markAsTouched();

      controller.clearText();

      expect(controller.form.control('title').touched, isFalse);
    });

    // Limpar era só do texto: o sinal da cor ficava com o hex da tag anterior,
    // e reabrir o diálogo mostrava um círculo já marcado.
    test('leva a cor embora, não só o nome', () {
      controller.setColorSelected = '#EF5350';

      controller.clearText();

      expect(controller.getColorSelected.value, isNull);
    });
  });

  // TAG-17: criar com o nome de uma arquivada ressuscita aquela tag, então o
  // `POST` pode devolver uma linha que a lista já conhece.
  //
  // A escolha é inserir assim mesmo, sem checar id: a lista local recebe o que
  // o servidor devolveu, e ponto. Uma linha repetida só aparece com a lista
  // desatualizada — a tag foi arquivada em outra sessão e esta tela ainda a
  // mostra — e some no `GET` seguinte, sem sujar nada no servidor.
  test('a ressuscitada entra na lista, como qualquer outra', () async {
    stubTagCreate(
      repository,
      result: Success(
        TagModel.fromJson({
          ...tagCriadaJson,
          'id': moradiaTagId,
          'name': 'moradia',
          'usageCount': 3,
          'restored': true,
        }),
      ),
    );

    await criar('moradia');

    expect(carregadas().map((tag) => tag.name), contains('moradia'));
    expect(
      carregadas().firstWhere((tag) => tag.name == 'moradia').usageCount,
      3,
    );
    verifyNever(() => repository.list());
  });

  // O formulário de gasto cria tag por este controller, e ele nasce na hora do
  // toque — com o `GET` da lista ainda a caminho. A criação vai assim mesmo, e
  // só a lista, que ninguém está vendo, fica para o `GET` trazer.
  test('sem lista carregada, cria e devolve a tag', () async {
    final nuncaVolta = Completer<void>();
    stubTagList(repository, pendenteAte: nuncaVolta.future);
    final emAberto = TagListController(repository: repository, nav: nav);
    addTearDown(emAberto.dispose);
    emAberto.form.control('title').updateValue('Mercado');
    emAberto.setColorSelected = '#66BB6A';

    await emAberto.create();

    expect(emAberto.state.value, isA<Loading<List<TagModel>>>());
    verify(() => repository.create(name: 'Mercado', color: '#66BB6A'))
        .called(1);
    verify(() => nav.pop<TagModel>(any())).called(1);
  });

  // TAG-08: excluir tem dois desfechos — sem uso apaga, em uso arquiva. A tela
  // só lista ativas, então nos dois casos a linha sai daqui.
  group('delete', () {
    final moradia = TagModel.fromJson(tagListJson.first);

    test('tira a linha da lista sem um novo GET', () async {
      await controller.delete(moradia);

      expect(carregadas().map((tag) => tag.name), ['Outros', 'Transporte']);
      verifyNever(() => repository.list());
    });

    // O predicado errado — `(tag) => tag.id == tag.id`, com o parâmetro
    // sombreando o de fora — compara cada item consigo mesmo e é sempre
    // verdadeiro: a lista inteira ia embora junto.
    test('tira só a que foi apontada', () async {
      await controller.delete(moradia);

      expect(carregadas(), hasLength(2));
    });

    // Mutar a lista de dentro do `Loaded` deixaria o sinal com o mesmo objeto,
    // e sem objeto novo o `SignalBuilder` não repinta: a tag sumia da memória e
    // continuava na tela.
    test(
      'publica um estado novo, e não a mesma lista mexida por dentro',
      () async {
        final antes = controller.state.value;

        await controller.delete(moradia);

        expect(controller.state.value, isNot(same(antes)));
        expect((antes as Loaded<List<TagModel>>).data, hasLength(3));
      },
    );

    test('arquivada também sai da lista', () async {
      stubTagDelete(repository, archived: true);

      await controller.delete(moradia);

      expect(carregadas().map((tag) => tag.name), isNot(contains('Moradia')));
    });

    test('falha não mexe na lista', () async {
      stubTagDelete(
        repository,
        result: const Error(NetworkFailure(message: 'Sem conexão.')),
      );

      await controller.delete(moradia);

      expect(carregadas(), hasLength(3));
    });

    test('fecha a confirmação', () async {
      await controller.delete(moradia);

      verify(() => nav.pop()).called(1);
    });
  });

  // A edição devolve a tag pronta, como a criação. Sem isso a tela teria que
  // pedir a lista de novo só para ver um nome trocado.
  group('update', () {
    final moradia = TagModel.fromJson(tagListJson.first);

    /// Edita como a tela edita: `update` lê nome e cor do mesmo formulário que
    /// a criação usa, então o teste preenche o formulário em vez de passar os
    /// campos como argumento. Só o `id` viaja por parâmetro.
    Future<void> editar(
      String id, {
      required String nome,
      String cor = '#4CAF50',
    }) async {
      controller.form.control('title').updateValue(nome);
      controller.setColorSelected = cor;
      await controller.update(id);
    }

    test('troca a linha sem um novo GET', () async {
      await editar(moradia.id, nome: 'Casa', cor: '#4CAF50');

      expect(carregadas().map((tag) => tag.name), isNot(contains('Moradia')));
      expect(carregadas().map((tag) => tag.name), contains('Casa'));
      expect(carregadas(), hasLength(3));
      verifyNever(() => repository.list());
    });

    // Espelha o mesmo teste do `delete`. O `update` publicava `current.data`
    // direto, então o `[]=` e o `sort` reescreviam a lista do estado anterior.
    test(
      'publica um estado novo, e não a mesma lista mexida por dentro',
      () async {
        final antes = controller.state.value as Loaded<List<TagModel>>;
        final listaAntiga = antes.data;

        await editar(moradia.id, nome: 'Zebra');

        expect(controller.state.value, isNot(same(antes)));
        expect(listaAntiga.map((tag) => tag.name), [
          'Moradia',
          'Outros',
          'Transporte',
        ]);
      },
    );

    // Renomear muda o lugar na lista: `update` reordena depois de substituir,
    // como a criação faz. "Moradia" vira "Zebra" e a linha vai para o fim, em
    // vez de ficar onde estava.
    test('reordena depois de renomear', () async {
      await editar(moradia.id, nome: 'Zebra');

      expect(carregadas().map((tag) => tag.name), [
        'Outros',
        'Transporte',
        'Zebra',
      ]);
    });

    // Editar rótulo não mexe em quantos lançamentos usam a tag, e a linha
    // precisa do número para avisar que excluir vai arquivar (TAG-08).
    test('mantém o usageCount que voltou do servidor', () async {
      await editar(moradia.id, nome: 'Casa');

      final casa = carregadas().firstWhere((tag) => tag.name == 'Casa');
      expect(casa.usageCount, 3);
      expect(casa.color, '#4CAF50');
    });

    test('falha não mexe na lista', () async {
      stubTagUpdate(
        repository,
        result: const Error(ConflictFailure(message: 'Já existe.')),
      );

      await editar(moradia.id, nome: 'Outros');

      expect(carregadas().map((tag) => tag.name), contains('Moradia'));
    });
  });
}
