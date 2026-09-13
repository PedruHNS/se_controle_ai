import 'package:se_controle_ai/core/utils/base_controller.dart';
import 'package:multiple_result/multiple_result.dart';
import 'package:signals/signals.dart';

import '../../../data/services/selected_month_service.dart';
import '../../../core/shared/view_state.dart';
import '../../../core/utils/month_utils.dart';
import '../../../core/errors/failure.dart';
import '../../../data/models/credit_card_invoice_model.dart';
import '../../../data/models/monthly_balance_model.dart';
import '../../../data/models/summary_section_model.dart';
import '../../../data/repositories/summary_repository.dart';

/// Estado do resumo mensal.
///
/// Padrão a repetir nas próximas features:
///
/// - `signal` privado, getter `ReadonlySignal` público. A view lê, só o
///   controller escreve — assim não aparece `controller.state.value = ...`
///   espalhado por widget.
/// - `computed` para o que é derivado. Não guarde rótulo formatado em signal
///   próprio: ele sairia de sincronia com a fonte na primeira distração.
/// - nenhum `import` de Flutter aqui. O controller é testável sem `pumpWidget`.
///
/// **O mês não é dele.** As setas ficam na AppBar da home, mas a competência
/// mora no [SelectedMonthService], que o app inteiro lê — ver a explicação
/// lá. Aqui ficaram os atalhos que a home já usava, agora delegando: a view não
/// mudou de interlocutor.
class HomeController extends BaseController {
  HomeController(this._repository, this._selectedMonth);

  final SummaryRepository _repository;
  final SelectedMonthService _selectedMonth;

  EffectCleanup? _watchingMonth;

  // Um estado por seção e não um só: cada seção tem rota própria e pinta
  // quando chega. Um estado só obrigaria a tela a esperar a resposta mais lenta
  // para mostrar qualquer coisa — e uma falha em faturas apagaria os ganhos que
  // já tinham chegado.
  final _balance = signal<ViewState<MonthlyBalanceModel>>(const Loading());
  final _incomes = signal<ViewState<SummarySectionModel>>(const Loading());
  final _expenses = signal<ViewState<SummarySectionModel>>(const Loading());
  final _debit = signal<ViewState<SummarySectionModel>>(const Loading());
  final _creditCards = signal<ViewState<List<CreditCardInvoiceModel>>>(
    const Loading(),
  );

  /// Cresce a cada requisição. Serve para descartar resposta atrasada — ver
  /// [load]. É um contador só para todas as buscas: elas saem juntas e são a
  /// mesma pergunta, "o que aconteceu neste mês".
  int _requestId = 0;

  ReadonlySignal<ViewState<MonthlyBalanceModel>> get balance => _balance;
  ReadonlySignal<ViewState<SummarySectionModel>> get incomes => _incomes;

  /// Tudo que sai no mês, débito e cartão juntos (RES-18). É a seção que a
  /// [debit] não consegue ser: um gasto lançado no cartão aparece aqui, e não
  /// só enterrado dentro da fatura.
  ReadonlySignal<ViewState<SummarySectionModel>> get expenses => _expenses;

  /// Só o que sai do dinheiro — o recorte de [expenses] que não vai na fatura.
  ReadonlySignal<ViewState<SummarySectionModel>> get debit => _debit;
  ReadonlySignal<ViewState<List<CreditCardInvoiceModel>>> get creditCards =>
      _creditCards;

  /// A falha quando **todas** as seções falharam; null se ao menos uma foi.
  ///
  /// Buscas separadas trocam um erro de tela inteira por um erro por seção — o
  /// que é ganho quando só uma cai, e perda quando a rede some: seriam cinco
  /// cartões empilhados dizendo "Sem conexão". Neste caso a notícia é uma só e a
  /// tela volta a mostrá-la uma vez.
  late final ReadonlySignal<Failure?> wholeScreenFailure = computed(() {
    final states = <ViewState<Object?>>[
      _balance.value,
      _incomes.value,
      _expenses.value,
      _debit.value,
      _creditCards.value,
    ];

    if (states.any((state) => state is! Failed)) return null;
    return (states.first as Failed).failure;
  });

  ReadonlySignal<String> get month => _selectedMonth.month;

  /// A competência exibida é a de hoje? A UI usa para destacar o "hoje" e
  /// habilitar um atalho de voltar ao mês corrente.
  ReadonlySignal<bool> get isCurrentMonth => _selectedMonth.isCurrent;

  @override
  void onInit() {
    super.onInit();

    // A inscrição no mês **é** a carga inicial, como nas outras telas: o
    // `effect` roda uma vez ao ser criado e de novo a cada troca de
    // competência. É o que permite o seletor da AppBar falar direto com o
    // serviço, sem precisar avisar este controller.
    _watchingMonth = effect(() {
      _selectedMonth.month.value;
      // `untracked` para o efeito depender só do mês: sem ele, qualquer signal
      // que o `load` venha a ler vira dependência sem querer.
      untracked(load);
    });
  }

  /// Busca as seções da competência selecionada.
  ///
  /// Elas saem juntas e cada uma se publica quando volta — não há `Future.wait`
  /// antes de escrever no signal, senão a tela voltaria a esperar a mais lenta.
  /// O `await` no fim existe só para quem chamou saber que acabou, que é o que
  /// o `RefreshIndicator` precisa para recolher a rosquinha.
  ///
  /// [silent] mantém o conteúdo na tela durante a busca — é o que o
  /// pull-to-refresh quer, já que o `RefreshIndicator` já mostra progresso e
  /// piscar um spinner no lugar da lista seria pior.
  Future<void> load({bool silent = false}) async {
    final requestId = ++_requestId;
    final month = _selectedMonth.month.value;

    if (!silent) {
      _balance.value = const Loading();
      _incomes.value = const Loading();
      _expenses.value = const Loading();
      _debit.value = const Loading();
      _creditCards.value = const Loading();
    }

    await Future.wait([
      _fill(_balance, requestId, () => _repository.getBalance(month: month)),
      _fill(_incomes, requestId, () => _repository.getIncomes(month: month)),
      _fill(_expenses, requestId, () => _repository.getExpenses(month: month)),
      _fill(_debit, requestId, () => _repository.getDebit(month: month)),
      _fill(
        _creditCards,
        requestId,
        () => _repository.getCreditCards(month: month),
      ),
    ]);
  }

  /// Publica o resultado de uma seção, se ela ainda for a busca corrente.
  ///
  /// Toque rápido em duas setas dispara dois `load`, e as respostas podem voltar
  /// fora de ordem — sem esta guarda, a seção do mês antigo sobrescreveria a do
  /// mês que está na tela. A guarda é por seção porque é por seção que se
  /// escreve: a de ganhos pode chegar depois da troca de mês mesmo com a de
  /// débito tendo chegado antes.
  Future<void> _fill<T>(
    Signal<ViewState<T>> target,
    int requestId,
    Future<Result<T, Failure>> Function() fetch,
  ) async {
    final result = await fetch();
    if (requestId != _requestId) return;

    result.when(
      (success) => target.value = Loaded(success),
      (err) => target.value = Failed(err),
    );
  }

  /// Só trocam a competência: quem rebusca é o `effect` de [onInit].
  Future<void> goToPreviousMonth() async => _selectedMonth.goToPrevious();

  Future<void> goToNextMonth() async => _selectedMonth.goToNext();

  Future<void> goToCurrentMonth() => goToMonth(MonthUtils.current());

  Future<void> goToMonth(String month) async {
    if (!MonthUtils.isValid(month)) return;

    // Pedir o mês que já está selecionado só é no-op se o dado dele estiver na
    // tela. Em Loading ou Failed a busca ainda precisa acontecer — senão um
    // "voltar para o mês atual" a partir de uma tela de erro no próprio mês
    // atual não faria nada, e a tela ficaria presa no erro.
    //
    // "Na tela" exige todas: com uma seção em erro, repetir o mês tem que
    // rebuscar, que é o caminho de quem toca em "Tentar de novo" ali.
    final alreadyLoaded = [
      _balance.value,
      _incomes.value,
      _expenses.value,
      _debit.value,
      _creditCards.value,
    ].every((state) => state is Loaded);
    // Mês novo: o `effect` já recarrega, e um `load` aqui seria a segunda
    // requisição do mesmo toque. Mês repetido sem dado na tela ainda precisa
    // buscar — é o caminho de quem volta ao mês atual a partir de um erro.
    if (_selectedMonth.select(month)) return;
    if (alreadyLoaded) return;

    await load();
  }

  Future<void> refresh() => load(silent: true);

  /// `BaseController.dispose` só loga — sem este override os signals nunca são
  /// liberados, e o `computed` continua inscrito na fonte. O get_it chama isto
  /// pelo `dispose:` do registro.
  ///
  /// O mês **não** é liberado aqui: ele é do [SelectedMonthService], que
  /// vive mais que esta tela. Liberá-lo derrubaria o resto do app junto.
  @override
  void dispose() {
    _watchingMonth?.call();
    _balance.dispose();
    _incomes.dispose();
    _expenses.dispose();
    _debit.dispose();
    _creditCards.dispose();
    super.dispose();
  }
}
