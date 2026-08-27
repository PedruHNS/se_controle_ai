import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:multiple_result/multiple_result.dart';
import 'package:se_controle_ai/core/errors/failure.dart';
import 'package:se_controle_ai/data/models/tag_model.dart';
import 'package:se_controle_ai/features/expenses/controller/expense_form_controller.dart';

import 'package:se_controle_ai/data/models/expense_model.dart';

import '../../fixtures/expense_fixture.dart';
import '../../fixtures/mocks.dart';
import '../../fixtures/tag_fixture.dart';

void main() {
  group('TagModel', () {
    test('lê o JSON do backend', () {
      final tag = TagModel.fromJson(tagListJson.first);

      expect(tag.id, moradiaTagId);
      expect(tag.name, 'Moradia');
      expect(tag.color, '#4CAF50');
    });

    test('cor nula continua nula', () {
      expect(TagModel.fromJson(tagListJson[1]).color, isNull);
      expect(TagModel.fromJson(tagListJson[1]).parsedColor, isNull);
    });

    test('converte #RRGGBB em Color', () {
      final cor = TagModel.fromJson(tagListJson.first).parsedColor;

      expect(cor, const Color(0xFF4CAF50));
    });

    // O backend garante o formato por CHECK, mas um valor estranho aqui viraria
    // exceção na hora de pintar — pior que não pintar.
    test('cor fora do formato não estoura, vira null', () {
      const tag = TagModel(id: 'x', name: 'X', color: 'vermelho');

      expect(tag.parsedColor, isNull);
    });
  });

  group('tag no formulário de gasto', () {
    late MockExpenseRepository repository;
    late MockCreditCardRepository cards;
    late MockTagRepository tags;
    late ExpenseFormController controller;

    setUp(() {
      repository = expenseRepositoryMock();
      cards = creditCardRepositoryMock();
      tags = MockTagRepository();
      stubTagList(tags);
      stubTagCreate(tags);
      controller = ExpenseFormController(repository, cards, tags);
    });

    tearDown(() => controller.dispose());

    test('carrega as tags ao abrir', () async {
      await controller.start();

      expect(controller.tags.value.map((t) => t.name), [
        'Moradia',
        'Outros',
        'Transporte',
      ]);
    });

    // TAG-06: sem tag o formulário não salva, e o backend nem é chamado.
    test('sem tag escolhida, não chama o backend', () async {
      await controller.start();

      controller.form.patchValue({
        ExpenseFormController.description: 'Aluguel',
        ExpenseFormController.amountCents: 120000,
      });

      expect(await controller.submit(), isNull);
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
      stubExpenseDetail(
        repository,
        result: Success(
          ExpenseModel.fromJson({
            ...aluguelJson,
            'tag': {'id': arquivadaTagId, 'name': 'Assinaturas', 'color': null},
          }),
        ),
      );

      await controller.start(id: 'gasto-1');

      expect(controller.ready.value, isTrue);
      expect(controller.tags.value.map((t) => t.id), contains(arquivadaTagId));
      expect(
        controller.control<String>(ExpenseFormController.tagId).value,
        arquivadaTagId,
      );
    });

    test('tag arquivada não aparece no cadastro novo', () async {
      await controller.start();

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

      await controller.start();

      expect(controller.ready.value, isFalse);
      expect(controller.generalFailure.value, isA<NetworkFailure>());
    });

    // O `POST` devolve a tag inteira, então o seletor se atualiza com ela: sem
    // isso era preciso um segundo `GET /tags` para exibir o que o servidor
    // acabou de responder.
    test('criar tag entra no seletor e já fica selecionada, sem novo GET', () async {
      await controller.start();
      // O `GET` da abertura já aconteceu; daqui para a frente não deve haver
      // outro.
      clearInteractions(tags);

      final erro = await controller.createTag(name: 'Mercado', color: null);

      expect(erro, isNull);
      expect(
        controller.control<String>(ExpenseFormController.tagId).value,
        criadaTagId,
      );
      expect(controller.tags.value.map((t) => t.name), contains('Mercado'));
      verify(() => tags.create(name: 'Mercado', color: null)).called(1);
      verifyNever(() => tags.list());
    });

    // A lista local tem que ficar igual à que o servidor devolveria: ordenada
    // por nome, sem diferenciar caixa, como o `ORDER BY name` do Postgres.
    test('a tag nova entra na posição certa', () async {
      await controller.start();
      stubTagCreate(
        tags,
        result: Success(
          TagModel.fromJson({...tagCriadaJson, 'name': 'Farmácia'}),
        ),
      );

      await controller.createTag(name: 'Farmácia', color: null);

      expect(controller.tags.value.map((t) => t.name), [
        'Farmácia',
        'Moradia',
        'Outros',
        'Transporte',
      ]);
    });

    // Nome repetido é 409 (TAG-01). O erro é do diálogo, não da tela: o
    // formulário continua utilizável.
    test('tag recusada devolve a mensagem e não derruba a tela', () async {
      await controller.start();

      stubTagCreate(
        tags,
        result: const Error(
          ConflictFailure(message: 'Já existe uma tag chamada "Moradia"'),
        ),
      );

      final erro = await controller.createTag(name: 'Moradia', color: null);

      expect(erro, 'Já existe uma tag chamada "Moradia"');
      expect(controller.generalFailure.value, isNull);
      expect(controller.ready.value, isTrue);
    });
  });
}
