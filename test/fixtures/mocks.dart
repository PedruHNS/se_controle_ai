import 'package:mocktail/mocktail.dart';
import 'package:multiple_result/multiple_result.dart';
import 'package:se_controle_ai/core/errors/failure.dart';
import 'package:se_controle_ai/core/shared/patch.dart';
import 'package:se_controle_ai/data/models/auth_user_model.dart';
import 'package:se_controle_ai/data/services/selected_month_service.dart';
import 'package:se_controle_ai/data/models/credit_card_bill_model.dart';
import 'package:se_controle_ai/data/models/credit_card_model.dart';
import 'package:se_controle_ai/data/models/expense_model.dart';
import 'package:se_controle_ai/data/models/income_model.dart';
import 'package:se_controle_ai/data/models/credit_card_invoice_model.dart';
import 'package:se_controle_ai/data/models/monthly_balance_model.dart';
import 'package:se_controle_ai/data/models/monthly_summary_model.dart';
import 'package:se_controle_ai/data/models/summary_section_model.dart';
import 'package:se_controle_ai/data/models/tag_model.dart';
import 'package:se_controle_ai/data/repositories/auth_repository.dart';
import 'package:se_controle_ai/data/repositories/credit_card_repository.dart';
import 'package:se_controle_ai/data/repositories/expense_repository.dart';
import 'package:se_controle_ai/data/repositories/income_repository.dart';
import 'package:se_controle_ai/data/repositories/summary_repository.dart';
import 'package:se_controle_ai/data/repositories/tag_repository.dart';
import 'package:se_controle_ai/data/services/navigation_service.dart';

import 'credit_card_fixture.dart';
import 'expense_fixture.dart';
import 'income_fixture.dart';
import 'summary_fixture.dart';
import 'tag_fixture.dart';
import 'package:se_controle_ai/data/enums/payment_method.dart';
import 'package:se_controle_ai/data/repositories/dashboard_repository.dart';
import 'package:se_controle_ai/data/models/dashboard_model.dart';
import 'dashboard_fixture.dart';

/// Os mocks de repositório do app.
///
/// Mock e não implementação falsa escrita à mão: com `verify` a asserção diz
/// **qual chamada** era esperada, com os argumentos no lugar. Em ganhos isso é
/// a diferença entre um teste que vale e um que não vale — reajuste e correção
/// devolvem o mesmo `Success`, e só o argumento os distingue.
class MockSummaryRepository extends Mock implements SummaryRepository {}

class MockIncomeRepository extends Mock implements IncomeRepository {}

class MockCreditCardRepository extends Mock implements CreditCardRepository {}

class MockDashboardRepository extends Mock implements DashboardRepository {}

class MockExpenseRepository extends Mock implements ExpenseRepository {}

class MockTagRepository extends Mock implements TagRepository {}

class MockAuthRepository extends Mock implements AuthRepository {}

/// A navegação como duplo.
///
/// Mock e não o `NavigationService` de verdade: ele embrulha o `GoRouter`
/// global, e um teste de controller que o tocasse mexeria na pilha de navegação
/// dos outros testes — o `appRouter` é único por processo. Com o duplo, "fechou
/// o diálogo" vira asserção em vez de efeito colateral.
class MockNavigationService extends Mock implements NavigationService {}

/// Uma navegação que aceita tudo calada.
MockNavigationService navigationServiceMock() {
  final mock = MockNavigationService();

  when(() => mock.pop<dynamic>(any<dynamic>())).thenReturn(null);
  when(() => mock.pop<dynamic>()).thenReturn(null);

  return mock;
}

/// Quem "entrou" nos testes.
const pedroLogado = AuthUserModel(
  uid: 'uid-do-pedro',
  email: 'pedro@exemplo.com',
  displayName: 'Pedro',
);

/// Um repositório de autenticação já respondendo a tudo.
///
/// [changes] fica vazio por padrão: quem quiser observar login e logout
/// acontecendo passa um `StreamController` próprio e empurra os eventos.
MockAuthRepository authRepositoryMock({
  AuthUserModel? current,
  Stream<AuthUserModel?>? changes,
  Result<AuthUserModel, Failure>? login,
}) {
  final mock = MockAuthRepository();

  when(() => mock.current).thenReturn(current);
  when(
    () => mock.changes,
  ).thenAnswer((_) => changes ?? const Stream<AuthUserModel?>.empty());
  when(
    () => mock.signInWithGoogle(),
  ).thenAnswer((_) async => login ?? const Success(pedroLogado));
  when(() => mock.signOut()).thenAnswer((_) async => const Success(true));
  when(
    () => mock.idToken(forceRefresh: any(named: 'forceRefresh')),
  ).thenAnswer((_) async => 'id-token');

  return mock;
}

/// Stub de `getMonthly` para qualquer mês.
///
/// [pendenteAte] segura a resposta até aquele future resolver, e é o que permite
/// observar o estado do meio — `Loading`, `saving`, duas buscas em voo. **Todo
/// stub deste arquivo que aceita o parâmetro segue esta mesma regra.**
///
/// Existiu como `delay` até 31/08, e a troca não foi estética. O `delay` era uma
/// corrida contra o relógio: o teste afirmava "ainda está carregando" contando
/// que 50 ms não tivessem passado, e o `flutter test` roda os arquivos em
/// paralelo — sob carga o isolate fica sem CPU por mais que isso, o
/// `Future.delayed` resolve antes da asserção e o estado já é o final. Um teste
/// de tags perdeu essa corrida e foi o que expôs o padrão, que estava em quinze
/// lugares.
///
/// Com um `Completer` não há corrida: pendente é pendente. Quem precisa ver o
/// desfecho completa o future antes do `await`; quem só quer o estado do meio
/// nunca o completa.
void stubMonthly(
  MockSummaryRepository mock, {
  Result<MonthlySummaryModel, Failure>? result,
  Future<void>? pendenteAte,
}) {
  final answer = result ?? Success(MonthlySummaryModel.fromJson(summaryJson));
  when(() => mock.getMonthly(month: any(named: 'month'))).thenAnswer((_) async {
    if (pendenteAte != null) await pendenteAte;
    return answer;
  });
}

/// Stubs das rotas de seção da home, derivados do **mesmo** [summaryJson].
///
/// Derivar em vez de escrever um fixture por seção é o que mantém o contrato
/// verificado num lugar só: o JSON continua sendo resposta real copiada do
/// backend, e as seções são recortes dele. Se o formato mudar, muda ali.
void stubBalance(
  MockSummaryRepository mock, {
  Map<String, dynamic>? json,
  Result<MonthlyBalanceModel, Failure>? result,
  Future<void>? pendenteAte,
}) {
  final answer =
      result ?? Success(MonthlyBalanceModel.fromJson(json ?? summaryJson));
  when(() => mock.getBalance(month: any(named: 'month'))).thenAnswer((_) async {
    if (pendenteAte != null) await pendenteAte;
    return answer;
  });
}

void stubIncomeSection(
  MockSummaryRepository mock, {
  Map<String, dynamic>? json,
  Result<SummarySectionModel, Failure>? result,
  Future<void>? pendenteAte,
}) {
  final fonte = json ?? summaryJson;
  final answer =
      result ??
      Success(
        SummarySectionModel.fromJson({
          'totalCents': fonte['incomeCents'],
          'items': fonte['incomes'],
        }),
      );
  when(() => mock.getIncomes(month: any(named: 'month'))).thenAnswer((_) async {
    if (pendenteAte != null) await pendenteAte;
    return answer;
  });
}

void stubExpenseSection(
  MockSummaryRepository mock, {
  Map<String, dynamic>? json,
  Result<SummarySectionModel, Failure>? result,
  Future<void>? pendenteAte,
}) {
  final fonte = json ?? summaryJson;
  final answer =
      result ??
      Success(
        SummarySectionModel.fromJson(fonte['expenses'] as Map<String, dynamic>),
      );
  when(() => mock.getExpenses(month: any(named: 'month'))).thenAnswer((
    _,
  ) async {
    if (pendenteAte != null) await pendenteAte;
    return answer;
  });
}

void stubDebitSection(
  MockSummaryRepository mock, {
  Map<String, dynamic>? json,
  Result<SummarySectionModel, Failure>? result,
  Future<void>? pendenteAte,
}) {
  final fonte = json ?? summaryJson;
  final answer =
      result ??
      Success(
        SummarySectionModel.fromJson(fonte['debit'] as Map<String, dynamic>),
      );
  when(() => mock.getDebit(month: any(named: 'month'))).thenAnswer((_) async {
    if (pendenteAte != null) await pendenteAte;
    return answer;
  });
}

void stubCreditCardSections(
  MockSummaryRepository mock, {
  Map<String, dynamic>? json,
  Result<List<CreditCardInvoiceModel>, Failure>? result,
  Future<void>? pendenteAte,
}) {
  final fonte = json ?? summaryJson;
  final answer =
      result ??
      Success(
        (fonte['creditCards'] as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .map(CreditCardInvoiceModel.fromJson)
            .toList(),
      );
  when(() => mock.getCreditCards(month: any(named: 'month'))).thenAnswer((
    _,
  ) async {
    if (pendenteAte != null) await pendenteAte;
    return answer;
  });
}

/// Todas de uma vez, que é como a home as pede.
///
/// [failure] derruba todas — é a falha de rede, que não escolhe endpoint. Para
/// derrubar só uma seção, chame o stub dela depois deste com o erro que quiser:
/// o `when` mais recente vence.
void stubHome(
  MockSummaryRepository mock, {
  Map<String, dynamic>? json,
  Failure? failure,
  Future<void>? pendenteAte,
}) {
  stubBalance(
    mock,
    json: json,
    result: failure == null ? null : Error(failure),
    pendenteAte: pendenteAte,
  );
  stubIncomeSection(
    mock,
    json: json,
    result: failure == null ? null : Error(failure),
    pendenteAte: pendenteAte,
  );
  stubExpenseSection(
    mock,
    json: json,
    result: failure == null ? null : Error(failure),
    pendenteAte: pendenteAte,
  );
  stubDebitSection(
    mock,
    json: json,
    result: failure == null ? null : Error(failure),
    pendenteAte: pendenteAte,
  );
  stubCreditCardSections(
    mock,
    json: json,
    result: failure == null ? null : Error(failure),
    pendenteAte: pendenteAte,
  );
}

/// Mock de resumo pronto para uso: responde o mês de exemplo em qualquer mês
/// pedido.
MockSummaryRepository summaryRepositoryMock({
  Map<String, dynamic>? json,
  Failure? failure,
  Future<void>? pendenteAte,
}) {
  final mock = MockSummaryRepository();
  stubHome(mock, json: json, failure: failure, pendenteAte: pendenteAte);
  stubMonthly(mock);
  return mock;
}

/// Os meses pedidos ao mock, na ordem.
///
/// `verify` **consome** o que foi gravado, então chamar duas vezes no mesmo
/// teste devolve lista vazia na segunda. Use uma vez, no fim.
/// Sai do `getBalance` e não de todas: elas partem juntas do mesmo `load`,
/// então uma basta para descrever a sequência de meses pedidos.
List<String?> capturedMonths(MockSummaryRepository mock) => verify(
  () => mock.getBalance(month: captureAny(named: 'month')),
).captured.cast<String?>();

/// Stub de `list` de ganhos.
void stubIncomeList(
  MockIncomeRepository mock, {
  Result<List<IncomeModel>, Failure>? result,
  Future<void>? pendenteAte,
}) {
  final answer =
      result ?? Success(incomeListJson.map(IncomeModel.fromJson).toList());
  when(() => mock.list(month: any(named: 'month'))).thenAnswer((_) async {
    if (pendenteAte != null) await pendenteAte;
    return answer;
  });
}

/// Stub do cadastro, das três operações de valor e da exclusão. Quando importa
/// falhar, [result] derruba as quatro últimas juntas (o teste de 422). No
/// sucesso, reajuste, correção e encerramento devolvem [updateResult] — o
/// salário, se o teste não passar outro.
void stubIncomeOperations(
  MockIncomeRepository mock, {
  Result<bool, Failure> result = const Success(true),
  // Nullable com o padrão resolvido no corpo: desde que o `create` devolve o
  // ganho (GAN-11), o padrão sai de um `fromJson` — que não é const, e
  // parâmetro opcional exige const.
  Result<IncomeModel, Failure>? createResult,
  Result<IncomeModel, Failure>? updateResult,
  Future<void>? pendenteAte,
}) {
  final criado =
      createResult ?? Success(IncomeModel.fromJson(createdIncomeJson));
  final atualizado =
      updateResult ??
      result.when<Result<IncomeModel, Failure>>(
        (_) => Success(IncomeModel.fromJson(salaryJson)),
        Error.new,
      );

  Future<T> answer<T>(T value) async {
    if (pendenteAte != null) await pendenteAte;
    return value;
  }

  when(
    () => mock.create(
      description: any(named: 'description'),
      amountCents: any(named: 'amountCents'),
      startMonth: any(named: 'startMonth'),
      recurring: any(named: 'recurring'),
    ),
  ).thenAnswer((_) => answer(criado));

  when(
    () => mock.adjust(
      any(),
      amountCents: any(named: 'amountCents'),
      effectiveFrom: any(named: 'effectiveFrom'),
      month: any(named: 'month'),
    ),
  ).thenAnswer((_) => answer(atualizado));

  when(
    () => mock.correct(
      any(),
      amountCents: any(named: 'amountCents'),
      month: any(named: 'month'),
    ),
  ).thenAnswer((_) => answer(atualizado));

  when(
    () => mock.close(
      any(),
      lastMonth: any(named: 'lastMonth'),
      month: any(named: 'month'),
    ),
  ).thenAnswer((_) => answer(atualizado));

  when(() => mock.delete(any())).thenAnswer((_) => answer(result));
}

/// Mock de ganhos pronto: lista de exemplo e as operações respondendo
/// sucesso.
MockIncomeRepository incomeRepositoryMock({
  Result<List<IncomeModel>, Failure>? list,
  Result<bool, Failure> operations = const Success(true),
  Result<IncomeModel, Failure>? create,
  Future<void>? pendenteAte,
}) {
  final mock = MockIncomeRepository();
  stubIncomeList(mock, result: list, pendenteAte: pendenteAte);
  stubIncomeOperations(
    mock,
    result: operations,
    createResult: create,
    pendenteAte: pendenteAte,
  );
  return mock;
}

/// Stub de `list` de cartões.
/// Stub de `/tags` — o formulário de gasto não abre sem a lista, porque a tag
/// é obrigatória (TAG-06).
/// [pendenteAte] segura o `GET` até aquele future resolver — ou para sempre, se
/// ninguém o resolver. O porquê está no [stubMonthly].
void stubTagList(
  MockTagRepository mock, {
  Result<List<TagModel>, Failure>? result,
  Future<void>? pendenteAte,
}) {
  // O dublê devolve o que o backend devolve: `/tags` traz só as ativas, sem
  // parâmetro para pedir outra coisa. A arquivada da fixture continua lá de
  // propósito — um stub que a entregasse esconderia o bug de o seletor de
  // lançamento oferecer tag aposentada.
  final ativas = tagListJson
      .map(TagModel.fromJson)
      .where((tag) => !tag.archived)
      .toList();

  when(() => mock.list()).thenAnswer((_) async {
    if (pendenteAte != null) await pendenteAte;
    return result ?? Success(ativas);
  });
}

/// Stub de exclusão e restauração.
///
/// [archived] escolhe o desfecho da TAG-08: tag sem uso é apagada, tag em uso é
/// arquivada, e a tela diz coisas diferentes para cada um.
void stubTagDelete(
  MockTagRepository mock, {
  bool archived = false,
  Result<TagDeleteOutcome, Failure>? result,
}) {
  when(
    () => mock.delete(any()),
  ).thenAnswer((_) async => result ?? Success((archived: archived)));
}

/// Stub de edição de tag.
///
/// Devolve a tag como o `200` devolve: a mesma linha da fixture com o nome e a
/// cor que foram mandados, e o `usageCount` intacto — editar rótulo não mexe em
/// quantos lançamentos usam a tag. Um stub que devolvesse `usageCount: 0`
/// esconderia a linha voltando da edição dizendo "sem uso".
///
/// Sem `registerFallbackValue`: desde que a edição virou substituição, os dois
/// parâmetros são `String`, e mocktail já sabe inventar um. O [Patch] segue nos
/// stubs de cartão e de gasto, que continuam com `PATCH`.
void stubTagUpdate(
  MockTagRepository mock, {
  Result<TagModel, Failure>? result,
}) {
  when(
    () => mock.update(
      any(),
      name: any(named: 'name'),
      color: any(named: 'color'),
    ),
  ).thenAnswer((invocation) async {
    if (result != null) return result;

    final id = invocation.positionalArguments.first as String;
    final anterior = tagListJson.firstWhere(
      (tag) => tag['id'] == id,
      orElse: () => tagCriadaJson,
    );

    return Success(
      TagModel.fromJson({
        ...anterior,
        'name': invocation.namedArguments[const Symbol('name')],
        'color': invocation.namedArguments[const Symbol('color')],
      }),
    );
  });
}

/// Stub de criação de tag, para o caminho "criar sem sair do formulário".
///
/// Devolve a tag inteira, como o `201` faz: é dela que a lista se atualiza sem
/// recarregar, então um stub que devolvesse só o `id` esconderia justamente o
/// que os testes de criação verificam.
void stubTagCreate(
  MockTagRepository mock, {
  Result<TagModel, Failure>? result,
}) {
  when(
    () => mock.create(
      name: any(named: 'name'),
      color: any(named: 'color'),
    ),
  ).thenAnswer(
    (_) async => result ?? Success(TagModel.fromJson(tagCriadaJson)),
  );
}

void stubCreditCardList(
  MockCreditCardRepository mock, {
  Result<List<CreditCardModel>, Failure>? result,
  Future<void>? pendenteAte,
}) {
  final answer =
      result ??
      Success(creditCardListJson.map(CreditCardModel.fromJson).toList());
  when(() => mock.list(month: any(named: 'month'))).thenAnswer((_) async {
    if (pendenteAte != null) await pendenteAte;
    return answer;
  });
}

void stubCreditCardDetail(
  MockCreditCardRepository mock, {
  Result<CreditCardModel, Failure>? result,
}) {
  when(() => mock.getById(any(), month: any(named: 'month'))).thenAnswer(
    (_) async => result ?? Success(CreditCardModel.fromJson(nubankJson)),
  );
}

/// Stub da fatura: `GET /credit-cards/:id/invoice`, que é a tela do cartão
/// inteira numa resposta.
///
/// O total sai da soma dos gastos, como o backend o calcula — assim o teste que
/// mexe na lista não precisa lembrar de acertar o total à mão.
void stubCreditCardBill(
  MockCreditCardRepository mock, {
  Result<CreditCardBillModel, Failure>? result,
  List<ExpenseModel>? expenses,
  Future<void>? pendenteAte,
}) {
  final gastos =
      expenses ?? expenseListJson.map(ExpenseModel.fromJson).toList();
  final answer =
      result ??
      Success(
        CreditCardBillModel(
          card: CreditCardModel.fromJson(nubankJson),
          expenses: gastos,
          month: SelectedMonthService.initial(),
          totalCents: gastos.fold(
            0,
            (total, expense) => total + (expense.amountCents ?? 0),
          ),
        ),
      );

  when(() => mock.getBill(any(), month: any(named: 'month'))).thenAnswer((
    _,
  ) async {
    if (pendenteAte != null) await pendenteAte;
    return answer;
  });
}

/// Stub de criação, edição e exclusão.
void stubCreditCardOperations(
  MockCreditCardRepository mock, {
  Result<bool, Failure> result = const Success(true),
  // Nullable com o padrão resolvido no corpo, e não um valor no cabeçalho:
  // desde que o `create` devolve o cartão, o padrão sai de um `fromJson` — que
  // não é const, e parâmetro opcional exige const.
  Result<CreditCardModel, Failure>? createResult,
  // O `update` devolve o cartão editado (CAR-08/CAR-10), como o de tag. Sem um
  // valor aqui o padrão é o Nubank da listagem — o cartão que a maioria dos
  // testes edita.
  Result<CreditCardModel, Failure>? updateResult,
  Future<void>? pendenteAte,
}) {
  final criado =
      createResult ?? Success(CreditCardModel.fromJson(cartaoCriadoJson));
  final editado = updateResult ?? Success(CreditCardModel.fromJson(nubankJson));

  Future<T> answer<T>(T value) async {
    if (pendenteAte != null) await pendenteAte;
    return value;
  }

  when(
    () => mock.create(
      name: any(named: 'name'),
      closingDay: any(named: 'closingDay'),
      dueDay: any(named: 'dueDay'),
      lastDigits: any(named: 'lastDigits'),
      limitCents: any(named: 'limitCents'),
    ),
  ).thenAnswer((_) => answer(criado));

  when(
    () => mock.update(
      any(),
      name: any(named: 'name'),
      closingDay: any(named: 'closingDay'),
      dueDay: any(named: 'dueDay'),
      lastDigits: any(named: 'lastDigits'),
      limitCents: any(named: 'limitCents'),
      month: any(named: 'month'),
    ),
  ).thenAnswer((invocation) {
    _recordUpdateBody(mock, invocation);
    return answer(editado);
  });

  when(() => mock.delete(any())).thenAnswer((_) => answer(result));
}

/// Mock de cartões pronto: a lista de exemplo, o detalhe do Nubank e as
/// operações respondendo sucesso.
MockCreditCardRepository creditCardRepositoryMock({
  Result<List<CreditCardModel>, Failure>? list,
  Result<CreditCardModel, Failure>? detail,
  Result<CreditCardBillModel, Failure>? bill,
  Result<bool, Failure> operations = const Success(true),
  // O `create` devolve o cartão inteiro desde 04/09; null aqui é "o cartão
  // recém-criado padrão", montado no stub a partir de `cartaoCriadoJson`.
  Result<CreditCardModel, Failure>? create,
  Future<void>? pendenteAte,
}) {
  final mock = MockCreditCardRepository();
  stubCreditCardList(mock, result: list, pendenteAte: pendenteAte);
  stubCreditCardDetail(mock, result: detail);
  stubCreditCardBill(mock, result: bill, pendenteAte: pendenteAte);
  stubCreditCardOperations(
    mock,
    result: operations,
    createResult: create,
    pendenteAte: pendenteAte,
  );
  return mock;
}

/// Os corpos de edição que o mock recebeu, na ordem, montados como o repositório
/// os montaria.
///
/// Escrito pelo próprio stub, e não lido do `captured` do mocktail: lá os
/// argumentos nomeados voltam numa ordem que não é a da declaração, e reconstruir
/// o corpo por posição trocava um campo pelo outro.
///
/// As cinco chaves saem **sempre**, inclusive as nulas: desde o CAR-08 a edição
/// é substituição, e um corpo com chave faltando não é "não mexi" — seria um
/// campo apagado sem querer. É exatamente isso que estes testes vigiam.
final _updateBodies = <MockCreditCardRepository, List<Map<String, dynamic>>>{};

void _recordUpdateBody(MockCreditCardRepository mock, Invocation invocation) {
  final named = invocation.namedArguments;

  (_updateBodies[mock] ??= []).add(<String, dynamic>{
    'name': named[const Symbol('name')],
    'closingDay': named[const Symbol('closingDay')],
    'dueDay': named[const Symbol('dueDay')],
    'lastDigits': named[const Symbol('lastDigits')],
    'limitCents': named[const Symbol('limitCents')],
  });
}

/// Todos os corpos de `update` recebidos por este mock.
List<Map<String, dynamic>> updateBodies(MockCreditCardRepository mock) =>
    _updateBodies[mock] ?? const [];

/// O corpo do último `update`. É o que os testes do CAR-08 afirmam: o cartão
/// inteiro foi enviado, e com quê.
Map<String, dynamic> capturedUpdateBody(MockCreditCardRepository mock) =>
    updateBodies(mock).last;

/// Stub de `list` de gastos.
void stubExpenseList(
  MockExpenseRepository mock, {
  Result<List<ExpenseModel>, Failure>? result,
  Future<void>? pendenteAte,
}) {
  final answer =
      result ?? Success(expenseListJson.map(ExpenseModel.fromJson).toList());
  when(
    () => mock.list(
      month: any(named: 'month'),
      activeFrom: any(named: 'activeFrom'),
      type: any(named: 'type'),
      paymentMethod: any(named: 'paymentMethod'),
      creditCardId: any(named: 'creditCardId'),
    ),
  ).thenAnswer((_) async {
    if (pendenteAte != null) await pendenteAte;
    return answer;
  });
}

void stubExpenseDetail(
  MockExpenseRepository mock, {
  Result<ExpenseModel, Failure>? result,
}) {
  when(() => mock.getById(any(), month: any(named: 'month'))).thenAnswer(
    (_) async => result ?? Success(ExpenseModel.fromJson(aluguelJson)),
  );
}

/// Stub de criação, edição de dados e as quatro operações de 204.
///
/// O `updateDetails` casa com qualquer `Patch` pela mesma razão do cartão: o
/// teste que verifica o corpo olha o argumento capturado, em vez de precisar de
/// um stub por combinação de estados.
void stubExpenseOperations(
  MockExpenseRepository mock, {
  Result<bool, Failure> result = const Success(true),
  Result<String, Failure> createResult = const Success('novo-gasto'),
  Future<void>? pendenteAte,
}) {
  // `Patch` e `PaymentMethod` não são anuláveis nesta interface, e para esses o
  // mocktail precisa de um valor de reserva antes de aceitar `any()`.
  registerFallbackValue(const Patch<String>.keep());
  registerFallbackValue(PaymentMethod.debit);

  Future<T> answer<T>(T value) async {
    if (pendenteAte != null) await pendenteAte;
    return value;
  }

  when(
    () => mock.createFixed(
      description: any(named: 'description'),
      paymentMethod: any(named: 'paymentMethod'),
      amountCents: any(named: 'amountCents'),
      startMonth: any(named: 'startMonth'),
      tagId: any(named: 'tagId'),
      notes: any(named: 'notes'),
      creditCardId: any(named: 'creditCardId'),
      recurring: any(named: 'recurring'),
      spentAt: any(named: 'spentAt'),
    ),
  ).thenAnswer((_) => answer(createResult));

  when(
    () => mock.updateDetails(
      any(),
      description: any(named: 'description'),
      paymentMethod: any(named: 'paymentMethod'),
      tagId: any(named: 'tagId'),
      notes: any(named: 'notes'),
      creditCardId: any(named: 'creditCardId'),
    ),
  ).thenAnswer((invocation) {
    _recordExpenseUpdateBody(mock, invocation);
    return answer(result);
  });

  when(
    () => mock.createInstallment(
      description: any(named: 'description'),
      paymentMethod: any(named: 'paymentMethod'),
      totalCents: any(named: 'totalCents'),
      installmentsCount: any(named: 'installmentsCount'),
      firstMonth: any(named: 'firstMonth'),
      tagId: any(named: 'tagId'),
      notes: any(named: 'notes'),
      creditCardId: any(named: 'creditCardId'),
      spentAt: any(named: 'spentAt'),
    ),
  ).thenAnswer((_) => answer(createResult));

  when(
    () => mock.adjust(
      any(),
      amountCents: any(named: 'amountCents'),
      effectiveFrom: any(named: 'effectiveFrom'),
    ),
  ).thenAnswer((_) => answer(result));

  when(
    () => mock.correct(any(), amountCents: any(named: 'amountCents')),
  ).thenAnswer((_) => answer(result));

  when(
    () => mock.close(any(), lastMonth: any(named: 'lastMonth')),
  ).thenAnswer((_) => answer(result));

  when(
    () => mock.reschedule(
      any(),
      newTotalCents: any(named: 'newTotalCents'),
      newInstallmentsCount: any(named: 'newInstallmentsCount'),
      fromMonth: any(named: 'fromMonth'),
    ),
  ).thenAnswer((_) => answer(result));

  when(
    () => mock.settle(any(), fromMonth: any(named: 'fromMonth')),
  ).thenAnswer((_) => answer(result));

  when(() => mock.delete(any())).thenAnswer((_) => answer(result));
}

/// Mock de gastos pronto: a lista de exemplo, o detalhe do aluguel e as
/// operações respondendo sucesso.
MockExpenseRepository expenseRepositoryMock({
  Result<List<ExpenseModel>, Failure>? list,
  Result<ExpenseModel, Failure>? detail,
  Result<bool, Failure> operations = const Success(true),
  Result<String, Failure> create = const Success('novo-gasto'),
  Future<void>? pendenteAte,
}) {
  final mock = MockExpenseRepository();
  stubExpenseList(mock, result: list, pendenteAte: pendenteAte);
  stubExpenseDetail(mock, result: detail);
  stubExpenseOperations(
    mock,
    result: operations,
    createResult: create,
    pendenteAte: pendenteAte,
  );
  return mock;
}

/// Os corpos de `PATCH /expenses/:id` que o mock recebeu, montados como o
/// repositório os montaria — mesma técnica do `updateBodies` do cartão, e pelo
/// mesmo motivo: o `captured` do mocktail devolve os nomeados fora de ordem.
final _expenseUpdateBodies =
    <MockExpenseRepository, List<Map<String, dynamic>>>{};

void _recordExpenseUpdateBody(
  MockExpenseRepository mock,
  Invocation invocation,
) {
  final named = invocation.namedArguments;

  final body = <String, dynamic>{
    'description': ?named[const Symbol('description')] as String?,
    'paymentMethod':
        ?(named[const Symbol('paymentMethod')] as PaymentMethod?)?.wire,
    // Tag não usa Patch: sendo obrigatória (TAG-06), null é "não mexi".
    'tagId': ?named[const Symbol('tagId')] as String?,
  };

  (named[const Symbol('notes')] as Patch<String>? ?? const Patch<String>.keep())
      .writeTo(body, 'notes');
  (named[const Symbol('creditCardId')] as Patch<String>? ??
          const Patch<String>.keep())
      .writeTo(body, 'creditCardId');

  (_expenseUpdateBodies[mock] ??= []).add(body);
}

/// Todos os corpos de `updateDetails` recebidos por este mock.
List<Map<String, dynamic>> expenseUpdateBodies(MockExpenseRepository mock) =>
    _expenseUpdateBodies[mock] ?? const [];

/// O corpo do último `updateDetails`.
Map<String, dynamic>? lastExpenseUpdateBody(MockExpenseRepository mock) {
  final bodies = expenseUpdateBodies(mock);
  return bodies.isEmpty ? null : bodies.last;
}

// ---------------------------------------------------------------- dashboard

/// Stub de `GET /dashboard`. Sem [result], devolve o payload da spec.
void stubDashboard(
  MockDashboardRepository mock, {
  Result<DashboardModel, Failure>? result,
  Future<void>? pendenteAte,
}) {
  final answer = result ?? Success(DashboardModel.fromJson(dashboardJson));

  when(() => mock.getDashboard(month: any(named: 'month'))).thenAnswer((
    _,
  ) async {
    if (pendenteAte != null) await pendenteAte;
    return answer;
  });
}

MockDashboardRepository dashboardRepositoryMock({
  Result<DashboardModel, Failure>? dashboard,
  Future<void>? pendenteAte,
}) {
  final mock = MockDashboardRepository();
  stubDashboard(mock, result: dashboard, pendenteAte: pendenteAte);
  return mock;
}
