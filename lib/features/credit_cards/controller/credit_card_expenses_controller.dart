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
  final CreditCardRepository _repository;
  final SelectedMonthService _selectedMonth;
  CreditCardExpensesController({
    required this._repository,
    required this._selectedMonth,
  });

  EffectCleanup? _watchingMonth;

  final _state = signal<ViewState<CreditCardBillModel>>(const Loading());
  ReadonlySignal<ViewState<CreditCardBillModel>> get state => _state;

  /// A inscrição no mês mora aqui, e não no `onInit`: sem o id ainda não há o
  /// que buscar.
  void start(String id) {
    _watchingMonth = effect(() {
      _selectedMonth.month.value;
      untracked(() => _load(id: id));
    });
  }

  @override
  void dispose() {
    _watchingMonth?.call();
    super.dispose();
    _state.dispose();
  }

  Future<void> _load({required String id}) async {
    _state.value = const Loading();
    final result = await _repository.getBill(
      id,
      month: _selectedMonth.month.value,
    );

    result.when(
      (success) => _state.value = Loaded(success),
      (err) => _state.value = Failed(err),
    );
  }

  Future<void> refresh({required String id}) async => await _load(id: id);
}
