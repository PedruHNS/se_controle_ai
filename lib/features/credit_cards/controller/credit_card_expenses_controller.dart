import 'package:signals/signals.dart';

import '../../../core/errors/failure.dart';
import '../../../core/month/selected_month_controller.dart';
import '../../../core/shared/view_state.dart';
import '../../../core/utils/base_controller.dart';
import '../../../data/models/credit_card_model.dart';
import '../../../data/models/expense_model.dart';
import '../../../data/repositories/credit_card_repository.dart';
import '../../../data/repositories/expense_repository.dart';

/// O que a tela de um cartão mostra: o cartão, tudo que foi lançado nele, e
/// quanto disso cai na fatura do mês.
typedef CardWithExpenses = ({
  CreditCardModel card,
  List<ExpenseModel> expenses,
  String month,
  int monthTotalCents,
});

/// Um cartão e os gastos lançados nele.
///
/// **Três buscas, e cada uma responde uma pergunta diferente:**
///
/// - o cartão com `?month` traz o vencimento da fatura já resolvido (CAR-03);
/// - a lista **sem** `?month` traz tudo que já foi lançado no cartão, inclusive
///   o que foi encerrado — é a pergunta "o que existe neste cartão";
/// - a lista **com** `?month` traz só o que é cobrado neste mês, e com o valor
///   preenchido, que é a pergunta "quanto vem na fatura".
///
/// A terceira não dá para deduzir da segunda: sem competência o backend manda
/// `amountCents: null`, e num gasto parcelado o valor do mês nem sequer está no
/// `history` — está nas parcelas (GFX-09). Somar o que dá localmente daria um
/// total que passa a mentir no dia em que existir parcelado.
class CreditCardExpensesController extends BaseController {
  CreditCardExpensesController(
    this._expenses,
    this._cards,
    this._selectedMonth,
  );

  final ExpenseRepository _expenses;
  final CreditCardRepository _cards;
  final SelectedMonthController _selectedMonth;

  /// Preenchido por [start]. Id é dado de rota, então quem o conhece é a view.
  late String _id;

  String get id => _id;

  final _state = signal<ViewState<CardWithExpenses>>(const Loading());

  /// Cresce a cada requisição, para descartar resposta atrasada.
  int _requestId = 0;

  ReadonlySignal<ViewState<CardWithExpenses>> get state => _state;

  Future<void> start(String id) {
    _id = id;
    return load();
  }

  Future<void> load({bool silent = false}) async {
    final requestId = ++_requestId;
    // A fatura do mês que a pessoa está olhando, não a de hoje. Não precisa de
    // `effect` como a lista de cartões: este controller é `factory`, nasce
    // quando a tela abre e morre com ela, e o mês não muda no meio disso.
    final month = _selectedMonth.month.value;

    if (!silent) _state.value = const Loading();

    // Disparadas juntas e colhidas em seguida: são independentes, e esperar uma
    // de cada vez triplicaria o tempo de abertura da tela.
    final cardCall = _cards.getById(_id, month: month);
    final allCall = _expenses.list(creditCardId: _id);
    final monthCall = _expenses.list(creditCardId: _id, month: month);

    final cardResult = await cardCall;
    final allResult = await allCall;
    final monthResult = await monthCall;

    if (requestId != _requestId) return;

    final card = cardResult.tryGetSuccess();
    final all = allResult.tryGetSuccess();
    final ofMonth = monthResult.tryGetSuccess();

    if (card == null || all == null || ofMonth == null) {
      // A primeira falha manda. As três buscas são a mesma tela: sem o cartão
      // não há título nem limite, e sem uma das listas o número exibido estaria
      // errado — mostrar meia tela seria pior que a tela de erro.
      _state.value = Failed(
        cardResult.tryGetError() ??
            allResult.tryGetError() ??
            monthResult.tryGetError() ??
            const UnexpectedFailure(),
      );
      return;
    }

    _state.value = Loaded((
      card: card,
      expenses: all,
      month: month,
      monthTotalCents: ofMonth.fold(
        0,
        (total, expense) => total + (expense.amountCents ?? 0),
      ),
    ));
  }

  Future<void> refresh() => load(silent: true);

  @override
  void dispose() {
    _state.dispose();
    super.dispose();
  }
}
