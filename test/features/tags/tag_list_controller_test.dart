import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:multiple_result/multiple_result.dart';
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
  late MockTagRepository repository;
  late TagListController controller;

  /// As tags do estado carregado. Estoura se a tela não estiver em [Loaded] —
  /// que é o que se quer, porque aí a asserção seguinte não teria sentido.
  List<TagModel> carregadas() =>
      (controller.state.value as Loaded<List<TagModel>>).data;

  setUp(() async {
    repository = MockTagRepository();
    stubTagList(repository);
    stubTagCreate(repository);

    controller = TagListController(repository);
    // O `onInit` do BaseController dispara o primeiro `GET` no construtor, e
    // ele precisa terminar antes de a criação ter uma lista onde entrar.
    await controller.refresh();
    // O `GET` da abertura já aconteceu; daqui para a frente não deve haver
    // outro.
    clearInteractions(repository);
  });

  tearDown(() => controller.dispose());

  Future<void> criar(String nome) async {
    controller.form.control('title').updateValue(nome);
    await controller.create();
  }

  test('a tag criada entra na lista sem um novo GET', () async {
    await criar('Mercado');

    expect(carregadas().map((tag) => tag.name), contains('Mercado'));
    expect(carregadas().firstWhere((tag) => tag.name == 'Mercado').id, criadaTagId);
    verifyNever(
      () => repository.list(includeArchived: any(named: 'includeArchived')),
    );
  });

  // Ordem alfabética de verdade: `compareTo` cru jogaria "aluguel" para depois
  // de "Transporte", porque minúscula vem depois de maiúscula na tabela.
  test('entra na posição alfabética, sem tropeçar na caixa', () async {
    stubTagCreate(
      repository,
      result: Success(TagModel.fromJson({...tagCriadaJson, 'name': 'aluguel'})),
    );

    await criar('aluguel');

    expect(carregadas().map((tag) => tag.name), [
      'aluguel',
      'Moradia',
      'Outros',
      'Transporte',
    ]);
  });

  // O caso que aparece em português: letra acentuada mora acima do 'z' na
  // tabela, então "Água" iria para o fim da lista em vez do começo.
  test('acento não joga a tag para o fim', () async {
    stubTagCreate(
      repository,
      result: Success(TagModel.fromJson({...tagCriadaJson, 'name': 'Água'})),
    );

    await criar('Água');

    expect(carregadas().map((tag) => tag.name), [
      'Água',
      'Moradia',
      'Outros',
      'Transporte',
    ]);
  });

  // TAG-17: criar com o nome de uma arquivada ressuscita aquela tag, então o
  // que volta pode ser uma linha que a lista já conhece.
  test('a ressuscitada substitui a linha, em vez de duplicá-la', () async {
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

    expect(carregadas().where((tag) => tag.id == moradiaTagId), hasLength(1));
    expect(carregadas().map((tag) => tag.name), ['moradia', 'Outros', 'Transporte']);
  });

  // Sem lista em mãos não há onde inserir: aí o refresh é o caminho, e é ele
  // que traz a nova junto.
  test('sem lista carregada, cai no refresh', () async {
    stubTagList(
      repository,
      // A lista ainda em voo deixa a tela em `Loading` quando a criação volta.
      delay: const Duration(milliseconds: 50),
      result: Success(
        [...tagListJson, tagCriadaJson].map(TagModel.fromJson).toList(),
      ),
    );

    final emAberto = TagListController(repository);
    addTearDown(emAberto.dispose);
    emAberto.form.control('title').updateValue('Mercado');

    await emAberto.create();

    expect(
      (emAberto.state.value as Loaded<List<TagModel>>).data.map((t) => t.name),
      contains('Mercado'),
    );
    // Duas: a da abertura e a do refresh que a criação teve de pedir.
    verify(
      () => repository.list(includeArchived: any(named: 'includeArchived')),
    ).called(2);
  });
}
