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
  // A falha geral avisa por toast, e o toast procura o contexto do
  // `navigatorKey` global — o que só existe com binding inicializado.
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockIncomeRepository repository;
  late SelectedMonthService month;
  late IncomeController controller;

  IncomeController build({MockIncomeRepository? incomes}) =>
      IncomeController(repository: incomes ?? repository, selectedMonth: month);

  setUp(() {
    month = SelectedMonthService();
    repository = incomeRepositoryMock();
    controller = build();
  });

  tearDown(() {
    controller.dispose();
    month.dispose();
  });

  /// A lista no estado em que o backend a devolve: por descrição.
  List<IncomeModel> loadedIncomes() =>
      (controller.state.value as Loaded<List<IncomeModel>>).data;

  /// Preenche o formulário como a tela faria.
  void fill({
    String? description,
    int? amountCents,
    String? startMonth,
    bool? recurring,
  }) {
    if (description != null) {
      controller.form.control('description').value = description;
    }
    if (amountCents != null) {
      controller.form.control('amountCents').value = amountCents;
    }
    if (startMonth != null) {
      controller.form.control('startMonth').value = startMonth;
    }
    if (recurring != null) controller.setIsRecurring = recurring;
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
        controller.form.control('startMonth').value,
        SelectedMonthService.initial(),
      );
      // Desligada por padrão, como no formulário de gasto: recorrência é
      // escolha explícita, não o que acontece quando ninguém toca no switch.
      expect(controller.isRecurring.value, isFalse);
      expect(controller.saving.value, isFalse);
    });

    // O mês vem da AppBar, não do relógio — mesmo motivo do form de gastos.
    test('a competência nasce no mês selecionado', () {
      month.select('2026-12');
      controller = build();

      expect(controller.form.control('startMonth').value, '2026-12');
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
    test('limpa o que a abertura anterior deixou', () {
      fill(
        description: 'Salário',
        amountCents: 500000,
        startMonth: '2026-03',
        recurring: true,
      );
      controller.form.markAllAsTouched();
      expect(controller.form.touched, isTrue);

      controller.startForm();

      expect(controller.form.control('description').value, isNull);
      expect(controller.form.control('amountCents').value, isNull);
      expect(controller.isRecurring.value, isFalse);
      expect(controller.form.touched, isFalse);
    });

    test('leva a competência para o mês selecionado agora', () {
      // O formulário é criado uma vez. Sem o reset, ele ficaria com o mês da
      // primeira abertura, mesmo que a pessoa tenha trocado de mês depois.
      controller.form.control('startMonth');
      month.select('2026-12');

      controller.startForm();

      expect(controller.form.control('startMonth').value, '2026-12');
    });
  });

  // O `submit` não confere o formulário: quem barra o inválido é o Salvar,
  // desabilitado enquanto o form não fecha — e isso o teste da página prova.
  // Aqui fica o que o FormGroup declara.
  group('validação declarada no FormGroup', () {
    test('valor zero é recusado pelo min', () {
      fill(description: 'Salário', amountCents: 0);

      expect(controller.form.invalid, isTrue);
      expect(
        controller.form.control('amountCents').hasError(ValidationMessage.min),
        isTrue,
      );
    });

    test('descrição só de espaço não passa do required', () {
      fill(description: '   ', amountCents: 5000);

      // O required do reactive_forms já recusa string em branco.
      expect(controller.form.invalid, isTrue);
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

        await controller.submit();

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

    // É o `saving` que gira o botão do formulário — a lista fica no ar.
    test('saving liga durante o envio e desliga no fim', () async {
      final segura = Completer<void>();
      stubIncomeOperations(repository, pendenteAte: segura.future);
      fill(description: 'Salário', amountCents: 500000);

      final pending = controller.submit();

      expect(controller.saving.value, isTrue);
      expect(controller.state.value, isA<Loaded<List<IncomeModel>>>());
      segura.complete();
      await pending;
      expect(controller.saving.value, isFalse);
    });

    test('saving desliga também quando o cadastro falha', () async {
      stubIncomeOperations(repository, createResult: semRedeCriacao());
      fill(description: 'Salário', amountCents: 500000);

      await controller.submit();

      expect(controller.saving.value, isFalse);
    });

    // Toda falha sai por toast — quem o vê é o teste da página. O 400 não
    // pendura mais a mensagem no campo que o zod apontou.
    test('400 do backend não desce para o campo', () async {
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

      await controller.submit();

      expect(errorOf('startMonth'), isNull);
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

    // O `201` já traz o ganho inteiro (GAN-11): nem a lista nem o ganho são
    // buscados de volta.
    test(
      'entra com o que o cadastro devolveu, sem voltar ao servidor',
      () async {
        stubIncomeOperations(repository, createResult: Success(criado()));
        fill(description: 'Freela', amountCents: 80000);

        await controller.submit();

        expect(loadedIncomes().map((i) => i.id), contains('novo-id'));
        verifyNever(
          () => repository.getById(any(), month: any(named: 'month')),
        );
        verifyNever(() => repository.list(month: any(named: 'month')));
      },
    );

    // Na mesma ordem do backend: o ganho criado não fica no topo nem no fim.
    test('o ganho criado entra na ordem alfabética', () async {
      stubIncomeOperations(repository, createResult: Success(criado()));
      fill(description: 'Freela', amountCents: 80000);

      await controller.submit();

      expect(loadedIncomes().map((i) => i.description), [
        'Aluguel recebido',
        'Freela',
        'Salário',
      ]);
    });

    test('falha no cadastro não mexe na lista', () async {
      stubIncomeOperations(repository, createResult: semRedeCriacao());
      fill(description: 'Freela', amountCents: 80000);

      await controller.submit();

      expect(loadedIncomes(), hasLength(2));
    });

    // Sem lista na tela não há onde encaixar o ganho, e só o `refresh` busca
    // de novo.
    test('lista que não está na tela fica como estava', () async {
      stubIncomeList(repository, result: semRede());
      await controller.refresh();
      clearInteractions(repository);

      stubIncomeOperations(repository, createResult: Success(criado()));
      fill(description: 'Freela', amountCents: 80000);
      await controller.submit();

      expect(controller.state.value, isA<Failed<List<IncomeModel>>>());
      verifyNever(() => repository.list(month: any(named: 'month')));
    });
  });
}

/// O cadastro que o backend recusa por rede — para os testes que querem a lista
/// intacta depois de um `create` que falhou.
Result<IncomeModel, Failure> semRedeCriacao() =>
    Error(Failure.fromException(const NetworkException(message: 'sem rede')));
