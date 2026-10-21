import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:multiple_result/multiple_result.dart';
import 'package:se_controle_ai/core/errors/failure.dart';
import 'package:se_controle_ai/core/shared/view_state.dart';
import 'package:se_controle_ai/data/services/selected_month_service.dart';
import 'package:se_controle_ai/data/models/tag_model.dart';
import 'package:se_controle_ai/features/expenses/controller/expense_controller.dart';

import 'package:se_controle_ai/data/models/expense_model.dart';

import '../../fixtures/expense_fixture.dart';
import '../../fixtures/mocks.dart';
import '../../fixtures/tag_fixture.dart';

import 'package:se_controle_ai/core/utils/tag_color_utils.dart';

void main() {
  // A recusa avisa por toast, e o toast procura o contexto pelo `navigatorKey`
  // — o que exige o binding.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TagModel', () {
    test('lê o JSON do backend', () {
      final tag = TagModel.fromJson(tagListJson.first);

      expect(tag.id, moradiaTagId);
      expect(tag.name, 'Moradia');
      expect(tag.color, '#4CAF50');
    });

    // TAG-02: não há mais tag sem cor. O que era "Outros sem cor" na fixture
    // virou o cinza neutro que a migration 010 deu a quem não tinha escolhido.
    test('toda tag vem com cor', () {
      final outros = TagModel.fromJson(tagListJson[1]);

      expect(outros.color, '#78909C');
      expect(TagColorUtils.parse(outros.color), const Color(0xFF78909C));
    });

    test('converte #RRGGBB em Color', () {
      final cor = TagColorUtils.parse(
        TagModel.fromJson(tagListJson.first).color,
      );

      expect(cor, const Color(0xFF4CAF50));
    });

    // O backend garante o formato por CHECK, mas um valor estranho aqui viraria
    // exceção na hora de pintar — pior que pintar de cinza.
    test('cor fora do formato não estoura, cai no cinza de reserva', () {
      const tag = TagModel(id: 'x', name: 'X', color: 'vermelho');

      expect(TagColorUtils.parse(tag.color), const Color(0xFF78909C));
    });
  });

  group('tag no formulário de gasto', () {
    late MockExpenseRepository repository;
    late MockCreditCardRepository cards;
    late MockTagRepository tags;
    late ExpenseController controller;
    late SelectedMonthService month;

    setUp(() {
      month = SelectedMonthService();
      repository = expenseRepositoryMock();
      cards = creditCardRepositoryMock();
      tags = MockTagRepository();
      stubTagList(tags);
      stubTagCreate(tags);
      controller = ExpenseController(
        repository: repository,
        cardRepository: cards,
        tagRepository: tags,
        selectedMonth: month,
        nav: navigationServiceMock(),
      );
    });

    tearDown(() {
      controller.dispose();
      month.dispose();
    });

    final comTagArquivada = ExpenseModel.fromJson({
      ...aluguelJson,
      'tag': {'id': arquivadaTagId, 'name': 'Assinaturas', 'color': '#8D6E63'},
    });

    test('carrega as tags ao abrir', () async {
      await controller.startForm();

      expect(controller.tags.value.map((t) => t.name), [
        'Moradia',
        'Outros',
        'Transporte',
      ]);
    });

    // TAG-06: sem tag o formulário não salva, e o backend nem é chamado.
    test('sem tag escolhida, não chama o backend', () async {
      await controller.startForm();

      controller.form.patchValue({
        ExpenseController.description: 'Aluguel',
        ExpenseController.amountCents: 120000,
      });

      await controller.submit();

      verifyNever(
        () => repository.createFixed(
          description: any(named: 'description'),
          paymentMethod: any(named: 'paymentMethod'),
          amountCents: any(named: 'amountCents'),
          startMonth: any(named: 'startMonth'),
          tagId: any(named: 'tagId'),
          notes: any(named: 'notes'),
          creditCardId: any(named: 'creditCardId'),
          recurring: any(named: 'recurring'),
        ),
      );
    });

    // O seletor traz só as ativas, mas um gasto antigo pode apontar para uma
    // arquivada. Sem ela na lista, o dropdown teria valor sem item
    // correspondente — que no Flutter é assertion, não campo vazio.
    test('editando gasto com tag arquivada, ela entra na lista', () async {
      await controller.startForm(expense: comTagArquivada);

      expect(controller.formState.value, isA<Loaded<void>>());
      expect(controller.tags.value.map((t) => t.id), contains(arquivadaTagId));
      expect(
        controller.control<String>(ExpenseController.tagId).value,
        arquivadaTagId,
      );
    });

    test('tag arquivada não aparece no cadastro novo', () async {
      await controller.startForm();

      expect(
        controller.tags.value.map((t) => t.id),
        isNot(contains(arquivadaTagId)),
      );
    });

    test('a falha ao buscar as tags impede o formulário de abrir', () async {
      stubTagList(
        tags,
        result: const Error(NetworkFailure(message: 'Sem conexão.')),
      );

      await controller.startForm();

      final state = controller.formState.value;
      expect(state, isA<Failed<void>>());
      expect((state as Failed<void>).failure, isA<NetworkFailure>());
    });

    // Quem cria é o `TagListController`, pelo diálogo de tags; o formulário só
    // recebe a tag pronta. Sem um segundo `GET /tags` para exibir o que o
    // servidor acabou de responder.
    test('a tag criada entra no seletor e já fica selecionada', () async {
      await controller.startForm();
      clearInteractions(tags);

      controller.selectCreatedTag(TagModel.fromJson(tagCriadaJson));

      expect(
        controller.control<String>(ExpenseController.tagId).value,
        criadaTagId,
      );
      expect(controller.tags.value.map((t) => t.id), contains(criadaTagId));
      verifyNever(() => tags.list());
      verifyNever(
        () => tags.create(
          name: any(named: 'name'),
          color: any(named: 'color'),
        ),
      );
    });

    // A lista local tem que ficar ordenada por nome, como a que o servidor
    // devolve.
    test('a tag nova entra na posição certa', () async {
      await controller.startForm();

      controller.selectCreatedTag(
        TagModel.fromJson({...tagCriadaJson, 'name': 'Farmácia'}),
      );

      expect(controller.tags.value.map((t) => t.name), [
        'Farmácia',
        'Moradia',
        'Outros',
        'Transporte',
      ]);
    });

    // TAG-17: criar com o nome de uma arquivada ressuscita aquela tag. Se ela
    // já estava no seletor — a do gasto em edição —, troca a linha em vez de
    // repetir.
    test('a ressuscitada não aparece duas vezes', () async {
      await controller.startForm(expense: comTagArquivada);

      controller.selectCreatedTag(
        const TagModel(
          id: arquivadaTagId,
          name: 'Assinaturas',
          color: '#8D6E63',
        ),
      );

      expect(
        controller.tags.value.where((t) => t.id == arquivadaTagId),
        hasLength(1),
      );
    });
  });
}
