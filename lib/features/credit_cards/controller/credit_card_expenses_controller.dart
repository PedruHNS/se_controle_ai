import 'package:signals/signals.dart';

import '../../../data/services/selected_month_service.dart';
import '../../../core/shared/view_state.dart';
import '../../../core/utils/base_controller.dart';
import '../../../data/models/credit_card_bill_model.dart';
import '../../../data/repositories/credit_card_repository.dart';

/// Um cartão e os gastos cobrados nele na competência selecionada.
///
/// **Uma busca só.** `GET /credit-cards/:id/invoice?month` devolve o cartão, os
/// gastos da fatura e o total juntos — é uma tela, e passou a ser uma resposta.
///
/// Antes eram duas, disparadas lado a lado: o cartão com `?month`, para o
/// vencimento vir resolvido (CAR-03), e a lista de gastos com `?month`, para
/// trazer só o que é cobrado no mês. Duas idas à rede para montar uma tela, com
/// o total somado no cliente e a tela em erro se qualquer uma falhasse.
///
/// Houve ainda uma terceira, sem `?month`, que trazia tudo que já passou pelo
/// cartão inclusive o encerrado. Ela saiu antes: um avulso de setembro
/// reaparecendo na tela de outubro com o selo "Encerrado" responde uma pergunta
/// que ninguém fez ali, e o cabeçalho da tela é uma fatura, de um mês só. Quem
/// quer o histórico do que existe cadastrado tem a lista de gastos, que
/// continua sem recorte.
///
/// O valor vem do backend e não é somado aqui: sem competência ele manda
/// `amountCents: null`, e num gasto parcelado o valor do mês nem sequer está no
/// `history` — está nas parcelas (GFX-09).
class CreditCardExpensesController extends BaseController {
  CreditCardExpensesController(this._cards, this._selectedMonth);

  final CreditCardRepository _cards;
  final SelectedMonthService _selectedMonth;

  /// Preenchido por [start]. Id é dado de rota, então quem o conhece é a view.
  late String _id;

  String get id => _id;

  final _state = signal<ViewState<CreditCardBillModel>>(const Loading());

  /// Cresce a cada requisição, para descartar resposta atrasada.
  int _requestId = 0;

  ReadonlySignal<ViewState<CreditCardBillModel>> get state => _state;

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

    final result = await _cards.getBill(_id, month: month);

    if (requestId != _requestId) return;

    result.when(
      (bill) => _state.value = Loaded(bill),
      (failure) => _state.value = Failed(failure),
    );
  }

  Future<void> refresh() => load(silent: true);

  @override
  void dispose() {
    _state.dispose();
    super.dispose();
  }
}
