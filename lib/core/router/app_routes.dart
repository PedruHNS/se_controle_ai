/// Caminhos e nomes de rota em um lugar só.
///
/// Navegar por **nome** (`context.goNamed(AppRoutes.expenseDetail, ...)`) e não
/// por string montada à mão: assim mudar a URL de uma tela não exige caçar
/// concatenação espalhada pelo código, e o compilador ajuda no resto.
abstract final class AppRoutes {
  /// Resumo do mês — tela inicial.
  static const home = 'home';
  static const homePath = '/';

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
  static const incomeDetailPath = ':id';

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

  /// Edição usa a mesma tela do cadastro, com o id na rota. É **filha** da tela
  /// do cartão (`/credit-cards/:id/edit`): fechar a edição volta para o cartão,
  /// que é de onde se entra nela.
  static const creditCardEdit = 'credit-card-edit';
  static const creditCardEditPath = 'edit';

  // Gastos — Fases 4 e 5
  static const expenses = 'expenses';
  static const expensesPath = '/expenses';
  static const expenseForm = 'expense-form';
  static const expenseFormPath = 'form';
  static const expenseDetail = 'expense-detail';
  static const expenseDetailPath = ':id';

  /// Edição usa a mesma tela do cadastro, com o id na rota — como em cartões.
  /// Aqui ela é **filha do detalhe** (`/expenses/:id/edit`), e não irmã: o
  /// gasto tem tela de detalhe, e sair da edição tem que voltar para ela, não
  /// para a lista.
  static const expenseEdit = 'expense-edit';
  static const expenseEditPath = 'edit';

  // Projeção — Fase 6
  static const projection = 'projection';
  static const projectionPath = '/projection';

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
