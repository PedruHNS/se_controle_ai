import 'package:se_controle_ai/core/di/injector.dart';
import 'package:se_controle_ai/core/month/selected_month_controller.dart';
import 'package:se_controle_ai/data/repositories/credit_card_repository.dart';
import 'package:se_controle_ai/data/repositories/expense_repository.dart';
import 'package:se_controle_ai/data/repositories/income_repository.dart';
import 'package:se_controle_ai/data/repositories/summary_repository.dart';
import 'package:se_controle_ai/data/repositories/tag_repository.dart';
import 'package:se_controle_ai/features/credit_cards/controller/credit_card_expenses_controller.dart';
import 'package:se_controle_ai/features/credit_cards/controller/credit_card_form_controller.dart';
import 'package:se_controle_ai/features/credit_cards/controller/credit_card_list_controller.dart';
import 'package:se_controle_ai/features/expenses/controller/expense_detail_controller.dart';
import 'package:se_controle_ai/features/expenses/controller/expense_form_controller.dart';
import 'package:se_controle_ai/features/expenses/controller/expense_list_controller.dart';
import 'package:se_controle_ai/features/home/controller/home_controller.dart';
import 'package:se_controle_ai/features/incomes/controller/income_detail_controller.dart';
import 'package:se_controle_ai/features/incomes/controller/income_form_controller.dart';
import 'package:se_controle_ai/features/incomes/controller/income_list_controller.dart';
import 'package:se_controle_ai/core/theme/theme_controller.dart';
import 'package:se_controle_ai/features/projection/controller/projection_controller.dart';
import 'package:se_controle_ai/features/tags/controller/tag_list_controller.dart';

import 'mocks.dart';

/// Registra as dependências que as telas resolvem, com os repositórios mockados.
///
/// Sem isto, qualquer teste que monte a `HomePage` estoura com "HomeController is
/// not registered" — e usando o `setupInjector` de produção a tela tentaria falar
/// com o backend, deixando o teste dependente do Docker estar de pé.
///
/// **Idempotente de propósito.** O get_it é global e sobrevive entre testes, então
/// chamar isto no `setUp` sem um `reset` no `tearDown` daria "already registered"
/// a partir do segundo teste.
///
/// Os controllers são `registerFactory` aqui, e não o `lazySingleton` da
/// produção: cada teste precisa de um controller novo, senão o estado de um vaza
/// para o próximo. Devolve o mock para o teste ajustar o `when`.
/// O mês selecionado, compartilhado por todas as telas do teste.
///
/// **Singleton, e não `registerFactory` como os controllers de tela.** Aqui a
/// regra se inverte: se cada tela recebesse a sua instância, o teste passaria a
/// exercitar exatamente o bug que este controller fecha — home num mês, gastos
/// em outro. É registrado de novo a cada `setUp`, então o mês de um teste não
/// vaza para o seguinte.
///
/// Sem `dispose:` de propósito: o get_it liberaria os signals na hora do
/// unregister, e um controller do teste anterior que ainda tivesse referência
/// estouraria ao ler um signal morto.
void setupSelectedMonth() {
  if (getIt.isRegistered<SelectedMonthController>()) {
    getIt.unregister<SelectedMonthController>();
  }

  getIt.registerSingleton<SelectedMonthController>(SelectedMonthController());
}

MockSummaryRepository setupTestInjector() {
  final repository = summaryRepositoryMock();

  setupSelectedMonth();

  if (getIt.isRegistered<SummaryRepository>()) {
    getIt.unregister<SummaryRepository>();
  }
  if (getIt.isRegistered<HomeController>()) {
    getIt.unregister<HomeController>();
  }
  if (getIt.isRegistered<ProjectionController>()) {
    getIt.unregister<ProjectionController>();
  }
  if (getIt.isRegistered<ThemeController>()) {
    getIt.unregister<ThemeController>();
  }

  getIt
    ..registerSingleton<SummaryRepository>(repository)
    ..registerFactory<HomeController>(
      () => HomeController(
        getIt<SummaryRepository>(),
        getIt<SelectedMonthController>(),
      ),
    )
    // A projeção lê o mesmo repositório do resumo, então vem no mesmo pacote.
    ..registerFactory<ProjectionController>(
      () => ProjectionController(
        getIt<SummaryRepository>(),
        getIt<SelectedMonthController>(),
      ),
    )
    // O tema não é de feature nenhuma, mas o menu lateral o resolve — e o menu
    // aparece em todo teste que monta a home. Sem isto, qualquer tela com
    // drawer estoura com "ThemeController is not registered".
    ..registerFactory<ThemeController>(ThemeController.new);

  return repository;
}

/// Registra o repositório de tags, com a lista já stubada.
///
/// Vale para gastos e para ganhos: o formulário de gasto não abre sem tags
/// (TAG-06 as torna obrigatórias) e o de ganho as busca para o seletor
/// opcional. Separado dos outros para poder ser chamado pelos dois.
MockTagRepository setupTagTestInjector({MockTagRepository? mock}) {
  final repository = mock ?? MockTagRepository();
  stubTagList(repository);
  stubTagCreate(repository);
  stubTagUpdate(repository);
  stubTagDelete(repository);

  if (getIt.isRegistered<TagRepository>()) {
    getIt.unregister<TagRepository>();
  }
  if (getIt.isRegistered<TagListController>()) {
    getIt.unregister<TagListController>();
  }

  getIt
    ..registerSingleton<TagRepository>(repository)
    ..registerFactory<TagListController>(
      () => TagListController(getIt<TagRepository>()),
    );

  return repository;
}

/// O mesmo para as telas de ganhos.
MockIncomeRepository setupIncomeTestInjector({MockIncomeRepository? mock}) {
  final repository = mock ?? incomeRepositoryMock();
  setupTagTestInjector();

  if (!getIt.isRegistered<SelectedMonthController>()) setupSelectedMonth();

  if (getIt.isRegistered<IncomeRepository>()) {
    getIt.unregister<IncomeRepository>();
  }
  if (getIt.isRegistered<IncomeListController>()) {
    getIt.unregister<IncomeListController>();
  }
  if (getIt.isRegistered<IncomeFormController>()) {
    getIt.unregister<IncomeFormController>();
  }
  if (getIt.isRegistered<IncomeDetailController>()) {
    getIt.unregister<IncomeDetailController>();
  }

  getIt
    ..registerSingleton<IncomeRepository>(repository)
    ..registerFactory<IncomeListController>(
      () => IncomeListController(getIt<IncomeRepository>()),
    )
    ..registerFactory<IncomeFormController>(
      () => IncomeFormController(
        getIt<IncomeRepository>(),
        getIt<TagRepository>(),
      ),
    )
    ..registerFactory<IncomeDetailController>(
      () => IncomeDetailController(getIt<IncomeRepository>()),
    );

  return repository;
}

/// O mesmo para as telas de cartões.
MockCreditCardRepository setupCreditCardTestInjector({
  MockCreditCardRepository? mock,
}) {
  final repository = mock ?? creditCardRepositoryMock();

  if (!getIt.isRegistered<SelectedMonthController>()) setupSelectedMonth();

  if (getIt.isRegistered<CreditCardRepository>()) {
    getIt.unregister<CreditCardRepository>();
  }
  if (getIt.isRegistered<CreditCardListController>()) {
    getIt.unregister<CreditCardListController>();
  }
  if (getIt.isRegistered<CreditCardFormController>()) {
    getIt.unregister<CreditCardFormController>();
  }
  if (getIt.isRegistered<CreditCardExpensesController>()) {
    getIt.unregister<CreditCardExpensesController>();
  }

  getIt
    ..registerSingleton<CreditCardRepository>(repository)
    ..registerFactory<CreditCardListController>(
      () => CreditCardListController(
        getIt<CreditCardRepository>(),
        getIt<SelectedMonthController>(),
      ),
    )
    ..registerFactory<CreditCardFormController>(
      () => CreditCardFormController(getIt<CreditCardRepository>()),
    )
    // A tela do cartão mostra os gastos dele, então precisa do repositório de
    // gastos registrado também — na prática, [setupExpenseTestInjector]. Como é
    // factory, a ordem entre os dois não importa: quem resolve é o `getIt` na
    // hora de construir.
    ..registerFactory<CreditCardExpensesController>(
      () => CreditCardExpensesController(
        getIt<ExpenseRepository>(),
        getIt<CreditCardRepository>(),
        getIt<SelectedMonthController>(),
      ),
    );

  return repository;
}

/// O mesmo para as telas de gastos.
///
/// O formulário e o detalhe dependem **também** do repositório de cartões, então
/// quem chama isto precisa ter registrado os cartões antes — na prática,
/// [setupCreditCardTestInjector] logo acima. Registrar um mock de cartão aqui
/// dentro esconderia essa dependência, que é justamente o que a Fase 4 tem de
/// novo em relação a ganhos.
MockExpenseRepository setupExpenseTestInjector({MockExpenseRepository? mock}) {
  final repository = mock ?? expenseRepositoryMock();
  setupTagTestInjector();

  // A lista e o detalhe de gasto leem o mês para saber qual valor mostrar, e
  // este setup é chamado por testes que não passam pela home.
  if (!getIt.isRegistered<SelectedMonthController>()) setupSelectedMonth();

  if (getIt.isRegistered<ExpenseRepository>()) {
    getIt.unregister<ExpenseRepository>();
  }
  if (getIt.isRegistered<ExpenseListController>()) {
    getIt.unregister<ExpenseListController>();
  }
  if (getIt.isRegistered<ExpenseFormController>()) {
    getIt.unregister<ExpenseFormController>();
  }
  if (getIt.isRegistered<ExpenseDetailController>()) {
    getIt.unregister<ExpenseDetailController>();
  }

  getIt
    ..registerSingleton<ExpenseRepository>(repository)
    ..registerFactory<ExpenseListController>(
      () => ExpenseListController(getIt<ExpenseRepository>()),
    )
    ..registerFactory<ExpenseFormController>(
      () => ExpenseFormController(
        getIt<ExpenseRepository>(),
        getIt<CreditCardRepository>(),
        getIt<TagRepository>(),
      ),
    )
    ..registerFactory<ExpenseDetailController>(
      () => ExpenseDetailController(
        getIt<ExpenseRepository>(),
        getIt<CreditCardRepository>(),
      ),
    );

  return repository;
}
