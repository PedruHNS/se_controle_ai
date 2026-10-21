/// Caminhos e nomes de rota em um lugar só.
///
/// Navegar por **nome** (`context.goNamed(AppRoutes.expenseDetail, ...)`) e não
/// por string montada à mão: assim mudar a URL de uma tela não exige caçar
/// concatenação espalhada pelo código, e o compilador ajuda no resto.
abstract final class AppRoutes {
  /// Resumo do mês — tela inicial.
  static const home = 'home';
  static const homePath = '/';

  /// A espera da abertura, enquanto o SDK do Firebase diz se há sessão.
  ///
  /// Não é tela de produto: ninguém navega para cá de propósito, e ela só
  /// aparece nos primeiros quadros do app. Existe porque a resposta "quem está
  /// logado" não é instantânea, e sem um lugar para esperar o app decidia com a
  /// resposta errada — mandava ao login quem já estava dentro.
  static const splash = 'splash';
  static const splashPath = '/splash';

  /// Onde a pessoa queria chegar, guardado na query do splash.
  ///
  /// Sem isto, abrir o app por um link (uma notificação da Fase 10, por
  /// exemplo) sempre terminaria na home: o destino se perderia nos quadros em
  /// que ainda não se sabia se havia sessão.
  static const deParam = 'de';

  /// Login — Etapa 7.
  ///
  /// Fora do `/auth/...` de propósito: não existe família de telas de conta
  /// aqui. Não há cadastro, nem recuperação de senha, nem perfil — a identidade
  /// é do Firebase (AUT-01) e o que o app tem é uma porta só.
  static const login = 'login';
  static const loginPath = '/login';

  // As rotas abaixo estão declaradas mas ainda não registradas no router: cada
  // uma entra junto com a tela da sua fase (veja ROADMAP.md). Ficam aqui para o
  // padrão de nome/caminho ser decidido uma vez, não a cada feature.
  //
  // Ganhos — Fase 2
  static const incomes = 'incomes';
  static const incomesPath = '/incomes';
  static const incomeForm = 'income-form';
  static const incomeFormPath = 'form';
  static const incomeDetail = 'income-detail';
  static const incomeDetailPath = 'detail';

  // Cartões — Fase 3
  static const creditCards = 'credit-cards';
  static const creditCardsPath = '/credit-cards';
  static const creditCardForm = 'credit-card-form';
  static const creditCardFormPath = 'form';

  /// A tela do cartão: o que foi lançado nele, e a fatura do mês.
  ///
  /// A Fase 3 decidiu não ter tela de cartão — cinco campos não valem uma tela
  /// só de leitura no caminho do formulário. A Fase 4 mudou a conta: com gasto
  /// no cartão existindo, esta tela responde algo que a lista não responde.
  static const creditCardExpenses = 'credit-card-expenses';
  static const creditCardExpensesPath = ':id';

  /// Edição usa a mesma tela do cadastro, e **sem id na rota**
  /// (`/credit-cards/edit`): quem preenche a tela é o cartão que vai por
  /// `extra`, e um id no caminho seria um segundo endereço para o mesmo
  /// cartão, sem ninguém para lê-lo.
  ///
  /// Irmã do cadastro, e não filha da tela do cartão: a edição se abre pelo
  /// menu da lista, e é para a lista que ela volta.
  static const creditCardEdit = 'credit-card-edit';
  static const creditCardEditPath = 'edit';

  // Gastos — Fases 4 e 5
  static const expenses = 'expenses';
  static const expensesPath = '/expenses';
  static const expenseForm = 'expense-form';
  static const expenseFormPath = 'form';
  static const expenseDetail = 'expense-detail';
  static const expenseDetailPath = 'detail';

  static const expenseEdit = 'expense-edit';
  static const expenseEditPath = 'edit';

  /// Filtro da lista de gastos por forma de pagamento, na query
  /// (`/expenses?paymentMethod=DEBIT`). O valor é o do backend — `DEBIT`,
  /// `CREDIT_CARD` —, o mesmo que a rota do backend recebe, para não haver duas
  /// grafias da mesma coisa entre a URL da tela e a da API.
  ///
  /// Na query e não no caminho: filtrar não cria outra tela, e uma rota
  /// `/expenses/debito` diria que cria. Sem o parâmetro a lista é a de sempre,
  /// com tudo.
  static const paymentMethodParam = 'paymentMethod';

  // Projeção — Fase 6
  /// O dashboard mensal — sete cards numa tela. Substitui a projeção.
  static const dashboard = 'dashboard';
  static const dashboardPath = '/dashboard';

  /// Tags — sem fase no ROADMAP e sem endpoint no backend. A rota existe porque
  /// a tela existe: um aviso de "em desenvolvimento" alcançável pelo menu.
  static const tags = 'tags';
  static const tagsPath = '/tags';

  /// Notificações — mesma situação das tags: nada no backend, tela só com o
  /// estado vazio. Fica na AppBar da home, não no menu.
  static const notifications = 'notifications';
  static const notificationsPath = '/notifications';
}

/// Nomes dos parâmetros de rota, para não repetir a string `'id'` em cada
/// `pathParameters` e cada leitura.
abstract final class RouteParams {
  static const id = 'id';
  static const month = 'month';
}
