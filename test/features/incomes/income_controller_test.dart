import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:multiple_result/multiple_result.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:se_controle_ai/core/errors/app_exception.dart';
import 'package:se_controle_ai/core/errors/failure.dart';
import 'package:se_controle_ai/core/shared/view_state.dart';
import 'package:se_controle_ai/core/utils/month_utils.dart';
import 'package:se_controle_ai/data/models/income_model.dart';
import 'package:se_controle_ai/data/services/selected_month_service.dart';
import 'package:se_controle_ai/features/incomes/controller/income_controller.dart';

import '../../fixtures/income_fixture.dart';
import '../../fixtures/mocks.dart';

void main() {
  late MockIncomeRepository repository;
  late MockTagRepository tags;
  late SelectedMonthService month;
  late IncomeController controller;

  IncomeController build({
    MockIncomeRepository? incomes,
    MockTagRepository? tagList,
  }) => IncomeController(
    repository: incomes ?? repository,
    tagRepository: tagList ?? tags,
    selectedMonth: month,
  );

  setUp(() {
    month = SelectedMonthService();
    repository = incomeRepositoryMock();
    tags = MockTagRepository();
    stubTagList(tags);
    controller = build();
  });

  tearDown(() {
    controller.dispose();
    month.dispose();
  });

  /// A lista no estado em que o backend a devolve: por descrição.
  List<IncomeModel> loadedIncomes() =>
      (controller.state.value as Loaded<List<IncomeModel>>).data;

  /// `create` com os quatro nomeados — a asserção diz exatamente o que devia
  /// ter sido enviado, que é o ponto de usar mock aqui.
  void verifyNoCreate() => verifyNever(
    () => repository.create(
      description: any(named: 'description'),
      amountCents: any(named: 'amountCents'),
      startMonth: any(named: 'startMonth'),
      recurring: any(named: 'recurring'),
    ),
  );

  /// Preenche o formulário como a tela faria.
  void fill({
    String? description,
    int? amountCents,
    String? startMonth,
    bool? recurring,
  }) {
    if (description != null) {
      controller.control<String>('description').value = description;
    }
    if (amountCents != null) {
      controller.control<int>('amountCents').value = amountCents;
    }
    if (startMonth != null) {
      controller.control<String>('startMonth').value = startMonth;
    }
    if (recurring != null) {
      controller.control<bool>('recurring').value = recurring;
    }
  }

  /// A mensagem do backend que caiu no campo, seja qual for a chave. O nome da
  /// chave é contrato com os widgets de campo, e quem o prova é o teste de
  /// página — o `required` e o `min` também são erros do campo, mas não são
  /// texto.
  String? errorOf(String field) => controller.form
      .control(field)
      .errors
      .values
      .whereType<String>()
      .firstOrNull;

  Result<List<IncomeModel>, Failure> semRede() =>
      Error(Failure.fromException(const NetworkException(message: 'sem rede')));

  group('lista', () {
    test('busca sozinho ao ser construído', () {
      expect(controller.state.value, isA<Loaded<List<IncomeModel>>>());
      expect(loadedIncomes(), hasLength(2));
    });

    test('lista o mês selecionado na home', () {
      verify(() => repository.list(month: month.month.value)).called(1);
    });

    test('trocar o mês busca a lista do novo mês', () async {
      final proximo = MonthUtils.next(month.month.value);

      month.select(proximo);
      await pumpEventQueue();

      verify(() => repository.list(month: proximo)).called(1);
      expect(controller.state.value, isA<Loaded<List<IncomeModel>>>());
    });

    test('construir não busca as tags — quem as quer é o formulário', () {
      verifyNever(() => tags.list());
    });

    test('falha vira Failed, com a falha traduzida', () async {
      stubIncomeList(repository, result: semRede());

      await controller.refresh();

      final state = controller.state.value;
      expect(state, isA<Failed<List<IncomeModel>>>());
      expect(
        (state as Failed<List<IncomeModel>>).failure,
        isA<NetworkFailure>(),
      );
    });

    test('refresh passa por Loading e volta ao conteúdo', () async {
      final segura = Completer<void>();
      stubIncomeList(repository, pendenteAte: segura.future);

      final pending = controller.refresh();

      expect(controller.state.value, isA<Loading<List<IncomeModel>>>());
      segura.complete();
      await pending;
      expect(controller.state.value, isA<Loaded<List<IncomeModel>>>());
    });

    // É o que o "tentar de novo" do cartão de falha chama.
    test('refresh depois de uma falha volta a mostrar a lista', () async {
      stubIncomeList(repository, result: semRede());
      await controller.refresh();
      expect(controller.state.value, isA<Failed<List<IncomeModel>>>());

      stubIncomeList(repository);
      await controller.refresh();

      expect(controller.state.value, isA<Loaded<List<IncomeModel>>>());
    });
  });

  group('estado inicial do formulário', () {
    test('competência começa no mês em que o app abre e sem recorrência', () {
      expect(
        controller.control<String>('startMonth').value,
        SelectedMonthService.initial(),
      );
      // Desligada por padrão, como no formulário de gasto: recorrência é
      // escolha explícita, não o que acontece quando ninguém toca no switch.
      expect(controller.control<bool>('recurring').value, isFalse);
      expect(controller.saving.value, isFalse);
      expect(controller.generalFailure.value, isNull);
    });

    // O mês vem da AppBar, não do relógio — mesmo motivo do form de gastos.
    test('a competência nasce no mês selecionado', () {
      month.select('2026-12');
      controller = build();

      expect(controller.control<String>('startMonth').value, '2026-12');
    });

    test('formulário nasce inválido — descrição e valor são obrigatórios', () {
      expect(controller.form.invalid, isTrue);
      expect(
        controller.form
            .control('description')
            .hasError(ValidationMessage.required),
        isTrue,
      );
      expect(
        controller.form
            .control('amountCents')
            .hasError(ValidationMessage.required),
        isTrue,
      );
    });
  });

  // O controller é um por app, então o formulário não nasce limpo a cada
  // abertura: quem o limpa é o `startForm`.
  group('startForm', () {
    test('limpa o que a abertura anterior deixou', () async {
      fill(
        description: 'Salário',
        amountCents: 500000,
        startMonth: '2026-03',
        recurring: true,
      );
      controller.control<String>('tagId').value = 'tag-1';
      controller.form.markAllAsTouched();
      expect(controller.form.touched, isTrue);

      await controller.startForm();

      expect(controller.control<String>('description').value, isNull);
      expect(controller.control<int>('amountCents').value, isNull);
      expect(controller.control<String>('tagId').value, isNull);
      expect(controller.control<bool>('recurring').value, isFalse);
      expect(controller.form.touched, isFalse);
      expect(controller.saving.value, isFalse);
    });

    test('leva a competência para o mês selecionado agora', () async {
      // O formulário é criado uma vez. Sem o reset, ele ficaria com o mês da
      // primeira abertura, mesmo que a pessoa tenha trocado de mês depois.
      controller.control<String>('startMonth');
      month.select('2026-12');

      await controller.startForm();

      expect(controller.control<String>('startMonth').value, '2026-12');
    });

    test('some com o erro que a abertura anterior deixou', () async {
      stubIncomeOperations(
        repository,
        createResult: Error(
          Failure.fromException(
            const BadRequestException(
              message: 'Dados inválidos',
              issues: [
                FieldIssue(path: 'amountCents', message: 'Alto demais.'),
              ],
            ),
          ),
        ),
      );
      fill(description: 'Salário', amountCents: 999999999);
      await controller.submit();
      expect(errorOf('amountCents'), isNotNull);

      await controller.startForm();

      expect(errorOf('amountCents'), isNull);
      expect(controller.generalFailure.value, isNull);
    });

    test('busca as tags do seletor', () async {
      await controller.startForm();

      verify(() => tags.list()).called(1);
      expect(controller.tags.value, isNotEmpty);
    });

    test(
      'falha na busca deixa o seletor vazio e não trava o formulário',
      () async {
        // A tag é opcional (TAG-07): não poder escolher rótulo não impede o
        // cadastro, e a falha não vira recado nenhum.
        final semTags = MockTagRepository();
        stubTagList(
          semTags,
          result: Error(
            Failure.fromException(const NetworkException(message: 'sem rede')),
          ),
        );
        final other = build(tagList: semTags);
        addTearDown(other.dispose);

        await other.startForm();

        expect(other.tags.value, isEmpty);
        expect(other.generalFailure.value, isNull);
      },
    );

    test('lista que chega depois do dispose é descartada, sem lançar', () async {
      // A página libera o controller ao sair da tela, e a busca pode ainda
      // estar em voo. Escrever no signal liberado lançaria um erro que ninguém
      // captura.
      final segura = Completer<void>();
      final lentas = MockTagRepository();
      stubTagList(lentas, pendenteAte: segura.future);
      final saiu = build(tagList: lentas);
      // A busca da lista, do `onInit`, termina antes: é só a das tags que está
      // sob teste.
      await pumpEventQueue();

      final pending = saiu.startForm();
      saiu.dispose();
      segura.complete();
      await pending;
    });
  });

  group('validação declarada no FormGroup', () {
    test('formulário inválido não chega no repositório', () async {
      final id = await controller.submit();

      expect(id, isNull);
      verifyNoCreate();
    });

    test(
      'submit inválido marca tudo como tocado, para o erro aparecer',
      () async {
        // Sem isto, campo nunca tocado fica inválido e silencioso: a pessoa
        // aperta Salvar e nada acontece, sem explicação.
        expect(controller.form.control('description').touched, isFalse);

        await controller.submit();

        expect(controller.form.control('description').touched, isTrue);
        expect(controller.form.control('amountCents').touched, isTrue);
      },
    );

    test('valor zero é recusado pelo min, sem ida ao servidor', () async {
      fill(description: 'Salário', amountCents: 0);

      final id = await controller.submit();

      expect(id, isNull);
      expect(
        controller.form.control('amountCents').hasError(ValidationMessage.min),
        isTrue,
      );
      verifyNoCreate();
    });

    test('descrição só de espaço não passa do required', () async {
      fill(description: '   ', amountCents: 5000);

      // O required do reactive_forms já recusa string em branco.
      expect(controller.form.invalid, isTrue);
      await controller.submit();
      verifyNoCreate();
    });
  });

  group('envio', () {
    test(
      'manda o que foi preenchido, sem espaço sobrando na descrição',
      () async {
        fill(
          description: '  13º salário  ',
          amountCents: 500000,
          startMonth: '2026-03',
          recurring: false,
        );

        final id = await controller.submit();

        expect(id, 'novo-id');
        verify(
          () => repository.create(
            description: '13º salário',
            amountCents: 500000,
            startMonth: '2026-03',
            recurring: false,
          ),
        ).called(1);
      },
    );

    test('400 do backend desce para o campo que o zod apontou', () async {
      stubIncomeOperations(
        repository,
        createResult: Error(
          Failure.fromException(
            const BadRequestException(
              message: 'Dados inválidos',
              issues: [
                FieldIssue(path: 'startMonth', message: 'Mês fora da faixa.'),
              ],
            ),
          ),
        ),
      );
      fill(description: 'Salário', amountCents: 500000);

      final id = await controller.submit();

      expect(id, isNull);
      expect(errorOf('startMonth'), 'Mês fora da faixa.');
      expect(controller.form.control('startMonth').touched, isTrue);
      // Erro de campo não vira snackbar: ele já está embaixo do campo.
      expect(controller.generalFailure.value, isNull);
    });

    test('erro do backend some quando a pessoa corrige o campo', () async {
      stubIncomeOperations(
        repository,
        createResult: Error(
          Failure.fromException(
            const BadRequestException(
              message: 'Dados inválidos',
              issues: [
                FieldIssue(
                  path: 'amountCents',
                  message: 'Acima do teto do backend.',
                ),
              ],
            ),
          ),
        ),
      );
      fill(description: 'Salário', amountCents: 999999999);
      await controller.submit();

      expect(errorOf('amountCents'), isNotNull);

      // A validação roda de novo na mudança de valor e substitui os erros —
      // é o que evita a mensagem velha grudada num campo já corrigido.
      fill(amountCents: 500000);

      expect(errorOf('amountCents'), isNull);
      expect(controller.form.valid, isTrue);
    });

    test(
      '400 cujo path não é campo do formulário sobe como falha geral',
      () async {
        stubIncomeOperations(
          repository,
          createResult: Error(
            Failure.fromException(
              const BadRequestException(
                message: 'Corpo inválido',
                issues: [FieldIssue(path: 'body', message: 'JSON malformado.')],
              ),
            ),
          ),
        );
        fill(description: 'Salário', amountCents: 500000);

        await controller.submit();

        // Sem isto a tela recusaria sem dizer nada: nenhum campo mostraria erro.
        expect(controller.generalFailure.value, isA<ValidationFailure>());
      },
    );

    test('falha sem campo vira erro geral', () async {
      stubIncomeOperations(
        repository,
        createResult: Error(
          Failure.fromException(const NetworkException(message: 'sem rede')),
        ),
      );
      fill(description: 'Salário', amountCents: 500000);

      final id = await controller.submit();

      expect(id, isNull);
      expect(controller.generalFailure.value, isA<NetworkFailure>());
      expect(errorOf('description'), isNull);
    });

    test('saving liga durante o envio e desliga no fim', () async {
      final segura = Completer<void>();
      stubIncomeOperations(repository, pendenteAte: segura.future);
      fill(description: 'Salário', amountCents: 500000);

      final pending = controller.submit();

      expect(controller.saving.value, isTrue);
      segura.complete();
      await pending;
      expect(controller.saving.value, isFalse);
    });
  });

  // O ganho cadastrado entra na lista pelo próprio controller, e é por isso que
  // a tela da lista não recarrega ao voltar do formulário.
  group('ganho cadastrado entra na lista', () {
    // O backend lista por descrição (`ORDER BY description, valid_from`).
    List<IncomeModel> listaOrdenada() => [
      IncomeModel.fromJson(
        singleMonthIncomeJson(
          month: '2026-03',
          id: 'aluguel',
          description: 'Aluguel recebido',
        ),
      ),
      IncomeModel.fromJson(salaryJson),
    ];

    IncomeModel criado({
      String description = 'Freela',
      String month = '2026-08',
    }) => IncomeModel.fromJson(
      singleMonthIncomeJson(
        month: month,
        id: 'novo-id',
        description: description,
      ),
    );

    setUp(() async {
      stubIncomeList(repository, result: Success(listaOrdenada()));
      // O mês dos ganhos criados abaixo: a lista só aceita o que vige nele.
      month.select('2026-08');
      await controller.refresh();
      clearInteractions(repository);
    });

    test('busca só o ganho criado, e não a lista inteira', () async {
      stubIncomeDetail(repository, result: Success(criado()));
      fill(description: 'Freela', amountCents: 80000);

      await controller.submit();

      verify(() => repository.getById('novo-id', month: '2026-08')).called(1);
      verifyNever(() => repository.list(month: any(named: 'month')));
    });

    test('cai onde a próxima busca o poria: por descrição', () async {
      stubIncomeDetail(repository, result: Success(criado()));
      fill(description: 'Freela', amountCents: 80000);

      await controller.submit();

      expect(loadedIncomes().map((i) => i.description), [
        'Aluguel recebido',
        'Freela',
        'Salário',
      ]);
    });

    test('mesma descrição: o que começou antes vem primeiro', () async {
      stubIncomeDetail(
        repository,
        result: Success(criado(description: 'Salário', month: '2026-08')),
      );
      fill(description: 'Salário', amountCents: 80000);

      await controller.submit();

      expect(loadedIncomes().map((i) => i.startMonth), [
        '2026-03',
        '2026-01',
        '2026-08',
      ]);
    });

    test('ganho que não vige no mês exibido não entra na lista', () async {
      stubIncomeDetail(repository, result: Success(criado(month: '2026-09')));
      fill(description: 'Freela', amountCents: 80000);

      final id = await controller.submit();

      expect(id, 'novo-id');
      expect(loadedIncomes().map((i) => i.description), [
        'Aluguel recebido',
        'Salário',
      ]);
    });

    test('falha no cadastro não mexe na lista', () async {
      stubIncomeOperations(repository, createResult: semRedeCriacao());
      fill(description: 'Freela', amountCents: 80000);

      await controller.submit();

      expect(loadedIncomes(), hasLength(2));
      verifyNever(() => repository.getById(any(), month: any(named: 'month')));
    });

    // O ganho já existe no backend. Não poder buscá-lo não faz o cadastro
    // falhar — senão a pessoa tentaria de novo e cadastraria duas vezes.
    test(
      'falha ao buscar o ganho criado busca a lista, e o cadastro vale',
      () async {
        stubIncomeDetail(
          repository,
          result: Error(
            Failure.fromException(const NetworkException(message: 'sem rede')),
          ),
        );
        stubIncomeList(repository, result: Success(listaOrdenada()));
        fill(description: 'Freela', amountCents: 80000);

        final id = await controller.submit();

        expect(id, 'novo-id');
        expect(controller.generalFailure.value, isNull);
        verify(() => repository.list(month: '2026-08')).called(1);
      },
    );

    test('lista que não está na tela é buscada de novo', () async {
      stubIncomeList(repository, result: semRede());
      await controller.refresh();
      expect(controller.state.value, isA<Failed<List<IncomeModel>>>());
      clearInteractions(repository);

      stubIncomeList(repository);
      fill(description: 'Freela', amountCents: 80000);
      await controller.submit();

      expect(controller.state.value, isA<Loaded<List<IncomeModel>>>());
      verify(() => repository.list(month: '2026-08')).called(1);
    });

    // A busca do ganho criado leva um instante, e o botão liberado nesse
    // intervalo deixaria cadastrar duas vezes.
    test('saving só desliga depois de o ganho entrar na lista', () async {
      final segura = Completer<void>();
      stubIncomeDetail(
        repository,
        result: Success(criado()),
        pendenteAte: segura.future,
      );
      fill(description: 'Freela', amountCents: 80000);

      final pending = controller.submit();
      await pumpEventQueue();

      expect(controller.saving.value, isTrue);
      expect(loadedIncomes(), hasLength(2));

      segura.complete();
      await pending;

      expect(controller.saving.value, isFalse);
      expect(loadedIncomes(), hasLength(3));
    });
  });
}

/// O cadastro que o backend recusa por rede — para os testes que querem a lista
/// intacta depois de um `create` que falhou.
Result<String, Failure> semRedeCriacao() =>
    Error(Failure.fromException(const NetworkException(message: 'sem rede')));
