import 'package:se_controle_ai/core/utils/base_controller.dart';
import 'package:multiple_result/multiple_result.dart';
import 'package:signals/signals.dart';

import '../../../core/month/selected_month_controller.dart';
import '../../../core/shared/view_state.dart';
import '../../../core/utils/month.dart';
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
/// mora no [SelectedMonthController], que o app inteiro lê — ver a explicação
/// lá. Aqui ficaram os atalhos que a home já usava, agora delegando: a view não
/// mudou de interlocutor.
class HomeController extends BaseController {
  HomeController(this._repository, this._selectedMonth);

  final SummaryRepository _repository;
  final SelectedMonthController _selectedMonth;

  // Quatro estados e não um: cada seção tem rota própria e pinta quando
  // chega. Um estado só obrigaria a tela a esperar a resposta mais lenta para
  // mostrar qualquer coisa — e uma falha em faturas apagaria os ganhos que já
  // tinham chegado.
  final _balance = signal<ViewState<MonthlyBalanceModel>>(const Loading());
  final _incomes = signal<ViewState<SummarySectionModel>>(const Loading());
  final _debit = signal<ViewState<SummarySectionModel>>(const Loading());
  final _creditCards = signal<ViewState<List<CreditCardInvoiceModel>>>(
    const Loading(),
  );

  /// Cresce a cada requisição. Serve para descartar resposta atrasada — ver
  /// [load]. É um contador só para as quatro buscas: elas saem juntas e são a
  /// mesma pergunta, "o que aconteceu neste mês".
  int _requestId = 0;

  ReadonlySignal<ViewState<MonthlyBalanceModel>> get balance => _balance;
  ReadonlySignal<ViewState<SummarySectionModel>> get incomes => _incomes;
  ReadonlySignal<ViewState<SummarySectionModel>> get debit => _debit;
  ReadonlySignal<ViewState<List<CreditCardInvoiceModel>>> get creditCards =>
      _creditCards;

  /// A falha quando **as quatro** seções falharam; null se ao menos uma foi.
  ///
  /// Quatro buscas separadas trocam um erro de tela inteira por quatro erros de
  /// seção — o que é ganho quando só uma cai, e perda quando a rede some: seriam
  /// quatro cartões empilhados dizendo "Sem conexão". Neste caso a notícia é uma
  /// só e a tela volta a mostrá-la uma vez.
  late final ReadonlySignal<Failure?> wholeScreenFailure = computed(() {
    final states = <ViewState<Object?>>[
      _balance.value,
      _incomes.value,
      _debit.value,
      _creditCards.value,
    ];

    if (states.any((state) => state is! Failed)) return null;
    return (states.first as Failed).failure;
  });

  ReadonlySignal<String> get month => _selectedMonth.month;

  /// `'ago/2026'`. Derivado de [month]: trocar o mês reformata sozinho.
  ///
  /// Abreviado e não `Month.label`: o título divide a AppBar com o botão do menu,
  /// as duas setas de mês e o sino, e por extenso ("Agosto 2026") não cabe —
  /// aparecia cortado em "Agost…", sem o ano.
  ReadonlySignal<String> get monthLabel => _selectedMonth.shortLabel;

  /// A competência exibida é a de hoje? A UI usa para destacar o "hoje" e
  /// habilitar um atalho de voltar ao mês corrente.
  ReadonlySignal<bool> get isCurrentMonth => _selectedMonth.isCurrent;

  /// Falsos nos limites que o backend aceita (2000–2100), para a seta ficar
  /// desabilitada em vez de disparar uma requisição que voltaria 400.
  ReadonlySignal<bool> get canGoPrevious => _selectedMonth.canGoPrevious;

  ReadonlySignal<bool> get canGoNext => _selectedMonth.canGoNext;

  @override
  void onInit() async {
    super.onInit();
    await load();
  }

  /// Busca as quatro seções da competência selecionada.
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
      _debit.value = const Loading();
      _creditCards.value = const Loading();
    }

    await Future.wait([
      _fill(_balance, requestId, () => _repository.getBalance(month: month)),
      _fill(_incomes, requestId, () => _repository.getIncomes(month: month)),
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

  Future<void> goToPreviousMonth() async {
    if (!_selectedMonth.goToPrevious()) return;
    await load();
  }

  Future<void> goToNextMonth() async {
    if (!_selectedMonth.goToNext()) return;
    await load();
  }

  Future<void> goToCurrentMonth() => goToMonth(Month.current());

  Future<void> goToMonth(String month) async {
    if (!Month.isValid(month)) return;

    // Pedir o mês que já está selecionado só é no-op se o dado dele estiver na
    // tela. Em Loading ou Failed a busca ainda precisa acontecer — senão um
    // "voltar para o mês atual" a partir de uma tela de erro no próprio mês
    // atual não faria nada, e a tela ficaria presa no erro.
    //
    // "Na tela" agora exige as quatro: com uma seção em erro, repetir o mês
    // tem que rebuscar, que é o caminho de quem toca em "Tentar de novo" ali.
    final alreadyLoaded = [
      _balance.value,
      _incomes.value,
      _debit.value,
      _creditCards.value,
    ].every((state) => state is Loaded);
    if (!_selectedMonth.select(month) && alreadyLoaded) return;

    await load();
  }

  Future<void> refresh() => load(silent: true);

  /// `BaseController.dispose` só loga — sem este override os signals nunca são
  /// liberados, e o `computed` continua inscrito na fonte. O get_it chama isto
  /// pelo `dispose:` do registro.
  ///
  /// O mês **não** é liberado aqui: ele é do [SelectedMonthController], que
  /// vive mais que esta tela. Liberá-lo derrubaria o resto do app junto.
  @override
  void dispose() {
    _balance.dispose();
    _incomes.dispose();
    _debit.dispose();
    _creditCards.dispose();
    super.dispose();
  }
}
