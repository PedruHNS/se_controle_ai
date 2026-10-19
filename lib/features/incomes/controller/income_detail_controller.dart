import 'package:signals/signals.dart';

import '../../../core/shared/mixin/message_mixin.dart';
import '../../../core/utils/base_controller.dart';
import '../../../data/models/income_model.dart';
import '../../../data/repositories/income_repository.dart';
import '../../../data/services/navigation_service.dart';
import '../../../data/services/selected_month_service.dart';
import 'income_controller.dart';

/// As três operações de dinheiro de um ganho: reajuste, correção e
/// encerramento. A exclusão é do [IncomeController], porque quem perde o ganho
/// é a lista.
///
/// O detalhe não busca nada: o ganho chega pelo `extra` da rota, e cada
/// operação devolve o ganho como ficou (GAN-12). No sucesso ele vai para a
/// lista no lugar do antigo, e o diálogo e a tela fecham — quem mostra o valor
/// novo é a lista. Na falha o diálogo fica aberto com o que foi digitado, e o
/// recado sai por toast, inclusive o 422 com a regra de negócio em português.
///
/// **O ganho não entra pelo construtor.** Quem o conhece é a view: ela chama
/// [start] no `initState`. Assim o registro no get_it é um `registerFactory`
/// comum.
class IncomeDetailController extends BaseController with MessageMixin {
  final IncomeRepository _repository;
  final NavigationService _nav;
  final SelectedMonthService _selectedMonth;
  final IncomeController _incomeController;
  IncomeDetailController({
    required this._repository,
    required this._nav,
    required this._selectedMonth,
    required this._incomeController,
  });

  /// Preenchido por [start]. As operações só existem depois que a view abriu a
  /// tela.
  late String _id;

  String get id => _id;

  final _working = signal<bool>(false);

  /// Alguma operação em andamento — a view desabilita os botões para não
  /// disparar duas vezes.
  ReadonlySignal<bool> get working => _working;

  void start(IncomeModel income) => _id = income.id;

  @override
  void dispose() {
    super.dispose();
    _working.dispose();
  }

  /// Reajuste — o valor novo passa a valer de [effectiveFrom] em diante, e os
  /// meses anteriores ficam como estavam.
  Future<void> adjust({
    required int amountCents,
    required String effectiveFrom,
  }) async {
    _working.value = true;

    final result = await _repository.adjust(
      _id,
      amountCents: amountCents,
      effectiveFrom: effectiveFrom,
      month: _selectedMonth.month.value,
    );

    _working.value = false;

    result.when(_done, (err) => toastError(err.message));
  }

  /// Correção — o valor estava errado desde o início da vigência atual.
  Future<void> correct({required int amountCents}) async {
    _working.value = true;

    final result = await _repository.correct(
      _id,
      amountCents: amountCents,
      month: _selectedMonth.month.value,
    );

    _working.value = false;

    result.when(_done, (err) => toastError(err.message));
  }

  /// Encerramento — [lastMonth] é o último mês recebido.
  Future<void> close({required String lastMonth}) async {
    _working.value = true;

    final result = await _repository.close(
      _id,
      lastMonth: lastMonth,
      month: _selectedMonth.month.value,
    );

    _working.value = false;

    result.when(_done, (err) => toastError(err.message));
  }

  /// O ganho como ficou entra na lista, e os dois `pop` fecham o diálogo e a
  /// tela do detalhe.
  void _done(IncomeModel income) {
    _incomeController.replace(income);
    _nav.pop();
    _nav.pop();
  }
}
