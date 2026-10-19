import 'package:se_controle_ai/core/di/injector.dart';
import 'package:se_controle_ai/data/services/selected_month_service.dart';
import 'package:se_controle_ai/data/repositories/auth_repository.dart';
import 'package:se_controle_ai/data/repositories/credit_card_repository.dart';
import 'package:se_controle_ai/data/repositories/expense_repository.dart';
import 'package:se_controle_ai/data/repositories/income_repository.dart';
import 'package:se_controle_ai/data/repositories/summary_repository.dart';
import 'package:se_controle_ai/data/repositories/tag_repository.dart';
import 'package:se_controle_ai/data/services/navigation_service.dart';
import 'package:se_controle_ai/features/auth/controller/login_controller.dart';
import 'package:se_controle_ai/features/credit_cards/controller/credit_card_expenses_controller.dart';
import 'package:se_controle_ai/features/credit_cards/controller/credit_card_controller.dart';
import 'package:se_controle_ai/features/expenses/controller/expense_detail_controller.dart';
import 'package:se_controle_ai/features/expenses/controller/expense_form_controller.dart';
import 'package:se_controle_ai/features/expenses/controller/expense_list_controller.dart';
import 'package:se_controle_ai/features/home/controller/home_controller.dart';
import 'package:se_controle_ai/features/incomes/controller/income_controller.dart';
import 'package:se_controle_ai/features/incomes/controller/income_detail_controller.dart';
import 'package:se_controle_ai/core/theme/theme_controller.dart';
import 'package:se_controle_ai/features/tags/controller/tag_list_controller.dart';

import 'mocks.dart';
import 'package:se_controle_ai/features/dashboard/controller/dashboard_controller.dart';
import 'package:se_controle_ai/data/repositories/dashboard_repository.dart';

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
///
/// A exceção é o [HomeController] — ver o comentário no registro dele.
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
  if (getIt.isRegistered<SelectedMonthService>()) {
    getIt.unregister<SelectedMonthService>();
  }

  getIt.registerSingleton<SelectedMonthService>(SelectedMonthService());
}

MockSummaryRepository setupTestInjector() {
  final repository = summaryRepositoryMock();

  setupSelectedMonth();

  // Sessão viva por padrão. Desde que o router ganhou `redirect`, um injector
  // sem autenticação mandaria **toda** tela de teste para o login — o que
  // faria dezenas de testes falharem por um motivo que não é o deles. Quem
  // quer testar o caminho deslogado chama `setupAuthTestInjector()` depois,
  // sem usuário.
  setupAuthTestInjector(mock: authRepositoryMock(current: pedroLogado));

  if (getIt.isRegistered<SummaryRepository>()) {
    getIt.unregister<SummaryRepository>();
  }
  if (getIt.isRegistered<HomeController>()) {
    getIt.unregister<HomeController>();
  }
  if (getIt.isRegistered<ThemeController>()) {
    getIt.unregister<ThemeController>();
  }

  // A home passou a navegar pelo `NavigationService` — mesmo duplo que tags e
  // cartões usam, e pelo mesmo motivo: o service de verdade embrulha o
  // `appRouter`, que é único por processo.
  if (!getIt.isRegistered<NavigationService>()) {
    getIt.registerSingleton<NavigationService>(navigationServiceMock());
  }

  getIt
    ..registerSingleton<SummaryRepository>(repository)
    // `lazySingleton` como em produção, e não `factory` como os outros: a
    // `HomePage` libera o controller no `dispose` com `resetLazySingleton`, e
    // esse método recusa qualquer registro que não seja lazySingleton. Cada
    // teste continua com um controller novo — o `unregister` acima roda no
    // `setUp`.
    ..registerLazySingleton<HomeController>(
      () => HomeController(
        getIt<SummaryRepository>(),
        getIt<SelectedMonthService>(),
      ),
      dispose: (controller) => controller.dispose(),
    )
    // O tema não é de feature nenhuma, mas o menu lateral o resolve — e o menu
    // aparece em todo teste que monta a home. Sem isto, qualquer tela com
    // drawer estoura com "ThemeController is not registered".
    ..registerFactory<ThemeController>(ThemeController.new);

  return repository;
}

/// Registra o repositório de tags, com a lista já stubada, e o
/// `NavigationService` dublê.
///
/// Vale para gastos e para ganhos: o formulário de gasto não abre sem tags
/// (TAG-06 as torna obrigatórias), e a lista de ganhos precisa do dublê de
/// navegação. Separado dos outros para poder ser chamado pelos dois.
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

  // A navegação como duplo: o `NavigationService` de verdade embrulha o
  // `appRouter`, que é único por processo — fechar um diálogo num teste mexeria
  // na pilha do teste seguinte.
  if (!getIt.isRegistered<NavigationService>()) {
    getIt.registerSingleton<NavigationService>(navigationServiceMock());
  }

  getIt
    ..registerSingleton<TagRepository>(repository)
    // `lazySingleton` com `dispose:`, espelhando o injector de produção — e isso
    // deixou de ser detalhe: a `TagListPage` chama `resetLazySingleton` no seu
    // `dispose`, e o get_it recusa isso em registro que não seja lazy. Como
    // `factory`, todo teste de tela estourava ao desmontar, com a mensagem
    // "There is no type Null registered as LazySingleton" — que não diz nada
    // sobre o tipo real, porque o get_it imprime ali o parâmetro `instance`,
    // que vem nulo.
    ..registerLazySingleton<TagListController>(
      () => TagListController(
        repository: getIt<TagRepository>(),
        nav: getIt<NavigationService>(),
      ),
      dispose: (controller) => controller.dispose(),
    );

  return repository;
}

/// O mesmo para as telas de ganhos.
MockIncomeRepository setupIncomeTestInjector({MockIncomeRepository? mock}) {
  final repository = mock ?? incomeRepositoryMock();
  // Pelo `NavigationService` dublê, não pelas tags: ganho não tem tag (TAG-07).
  setupTagTestInjector();

  if (!getIt.isRegistered<SelectedMonthService>()) setupSelectedMonth();

  if (getIt.isRegistered<IncomeRepository>()) {
    getIt.unregister<IncomeRepository>();
  }
  if (getIt.isRegistered<IncomeController>()) {
    getIt.unregister<IncomeController>();
  }
  if (getIt.isRegistered<IncomeDetailController>()) {
    getIt.unregister<IncomeDetailController>();
  }

  getIt
    ..registerSingleton<IncomeRepository>(repository)
    // `lazySingleton` com `dispose:`, e não `factory`: a `IncomeListPage` chama
    // `resetLazySingleton` no seu `dispose`, e o get_it recusa isso em registro
    // que não seja lazy. É também um controller só para a lista e o formulário —
    // a página do formulário não o libera.
    ..registerLazySingleton<IncomeController>(
      () => IncomeController(
        repository: getIt<IncomeRepository>(),
        selectedMonth: getIt<SelectedMonthService>(),
        navigationService: getIt<NavigationService>(),
      ),
      dispose: (controller) => controller.dispose(),
    )
    ..registerFactory<IncomeDetailController>(
      () => IncomeDetailController(
        repository: getIt<IncomeRepository>(),
        nav: getIt<NavigationService>(),
        selectedMonth: getIt<SelectedMonthService>(),
        incomeController: getIt<IncomeController>(),
      ),
    );

  return repository;
}

/// O mesmo para as telas de cartões.
MockCreditCardRepository setupCreditCardTestInjector({
  MockCreditCardRepository? mock,
}) {
  final repository = mock ?? creditCardRepositoryMock();

  if (!getIt.isRegistered<SelectedMonthService>()) setupSelectedMonth();

  if (getIt.isRegistered<CreditCardRepository>()) {
    getIt.unregister<CreditCardRepository>();
  }
  if (getIt.isRegistered<CreditCardController>()) {
    getIt.unregister<CreditCardController>();
  }
  if (getIt.isRegistered<CreditCardExpensesController>()) {
    getIt.unregister<CreditCardExpensesController>();
  }

  // A lista de cartões navega pelo `NavigationService`, e não pelo `context`.
  // Mesmo duplo que as tags usam, e pelo mesmo motivo — ver lá em cima.
  if (!getIt.isRegistered<NavigationService>()) {
    getIt.registerSingleton<NavigationService>(navigationServiceMock());
  }

  getIt
    ..registerSingleton<CreditCardRepository>(repository)
    // `lazySingleton` com `dispose:`, e não `factory`, pelo mesmo motivo do
    // `TagListController`: a `CreditCardListPage` chama `resetLazySingleton` no
    // seu `dispose`, e o get_it recusa isso em registro que não seja lazy.
    ..registerLazySingleton<CreditCardController>(
      () => CreditCardController(
        repository: getIt<CreditCardRepository>(),
        selectedMonth: getIt<SelectedMonthService>(),
        nav: getIt<NavigationService>(),
      ),
      dispose: (controller) => controller.dispose(),
    )
    // A tela do cartão mostra os gastos dele, então precisa do repositório de
    // gastos registrado também — na prática, [setupExpenseTestInjector]. Como é
    // lazy, a ordem entre os dois não importa: quem resolve é o `getIt` na hora
    // de construir.
    //
    // `lazySingleton` com `dispose:` porque é assim que o app registra, e a
    // `CreditCardExpensesPage` chama `resetLazySingleton` no seu `dispose` — em
    // registro `factory` o get_it recusa, e todo teste que monta a tela morria
    // ao desmontá-la.
    ..registerLazySingleton<CreditCardExpensesController>(
      () => CreditCardExpensesController(
        repository: getIt<CreditCardRepository>(),
        selectedMonth: getIt<SelectedMonthService>(),
      ),
      dispose: (controller) => controller.dispose(),
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
/// O mesmo para o dashboard.
MockDashboardRepository setupDashboardTestInjector({
  MockDashboardRepository? mock,
}) {
  final repository = mock ?? dashboardRepositoryMock();

  if (!getIt.isRegistered<SelectedMonthService>()) setupSelectedMonth();

  if (getIt.isRegistered<DashboardRepository>()) {
    getIt.unregister<DashboardRepository>();
  }
  if (getIt.isRegistered<DashboardController>()) {
    getIt.unregister<DashboardController>();
  }

  getIt
    ..registerSingleton<DashboardRepository>(repository)
    // `lazySingleton` com `dispose:`, como as outras listas: a `DashboardPage`
    // chama `resetLazySingleton` no seu `dispose`, e o get_it recusa isso em
    // registro que não seja lazy.
    ..registerLazySingleton<DashboardController>(
      () => DashboardController(
        repository: getIt<DashboardRepository>(),
        selectedMonth: getIt<SelectedMonthService>(),
      ),
      dispose: (controller) => controller.dispose(),
    );

  return repository;
}

MockExpenseRepository setupExpenseTestInjector({MockExpenseRepository? mock}) {
  final repository = mock ?? expenseRepositoryMock();
  setupTagTestInjector();

  // A lista e o detalhe de gasto leem o mês para saber qual valor mostrar, e
  // este setup é chamado por testes que não passam pela home.
  if (!getIt.isRegistered<SelectedMonthService>()) setupSelectedMonth();

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
      () => ExpenseListController(
        getIt<ExpenseRepository>(),
        getIt<SelectedMonthService>(),
      ),
    )
    ..registerFactory<ExpenseFormController>(
      () => ExpenseFormController(
        getIt<ExpenseRepository>(),
        getIt<CreditCardRepository>(),
        getIt<TagRepository>(),
        getIt<SelectedMonthService>(),
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

/// A tela de login: repositório de autenticação mockado e o controller
/// registrado como `factory`, igual ao injector de verdade.
MockAuthRepository setupAuthTestInjector({MockAuthRepository? mock}) {
  final repository = mock ?? authRepositoryMock();

  if (getIt.isRegistered<AuthRepository>()) {
    getIt.unregister<AuthRepository>();
  }
  if (getIt.isRegistered<LoginController>()) {
    getIt.unregister<LoginController>();
  }

  getIt
    ..registerSingleton<AuthRepository>(repository)
    ..registerFactory<LoginController>(
      () => LoginController(getIt<AuthRepository>()),
    );

  return repository;
}
