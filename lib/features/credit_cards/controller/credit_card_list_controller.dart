import 'package:se_controle_ai/core/shared/mixin/message_mixin.dart';
import 'package:signals/signals.dart';

import '../../../core/month/selected_month_controller.dart';
import '../../../core/shared/view_state.dart';
import '../../../core/utils/base_controller.dart';
import '../../../data/models/credit_card_model.dart';
import '../../../data/repositories/credit_card_repository.dart';

class CreditCardListController extends BaseController with MessageMixin {
  CreditCardListController(this._repository, this._selectedMonth);

  final CreditCardRepository _repository;
  final SelectedMonthController _selectedMonth;

  EffectCleanup? _watchingMonth;

  final _state = signal<ViewState<List<CreditCardModel>>>(const Loading());

  ReadonlySignal<ViewState<List<CreditCardModel>>> get state => _state;

  /// A inscrição no mês **é** a carga inicial: o `effect` roda uma vez ao ser
  /// criado, e de novo a cada troca de mês na home. Um `load()` aqui além dele
  /// só duplicaria a primeira requisição.
  @override
  void onInit() {
    super.onInit();

    _watchingMonth = effect(() {
      _selectedMonth.month.value;
      // `untracked` para o efeito depender **só** do mês: sem ele, qualquer
      // signal que o `load` venha a ler vira dependência sem querer, e a busca
      // passa a acontecer por motivos que ninguém escreveu aqui.
      untracked(load);
    });
  }

  Future<void> load() async {
    _state.value = const Loading();
    final result = await _repository.list(month: _selectedMonth.month.value);
    result.when(
      (success) => _state.value = Loaded(success),
      (err) => _state.value = Failed(err),
    );
  }

  Future<void> refresh() => load();

  Future<void> delete(String id) async {
    final current = _state.value;
    if (current is! Loaded<List<CreditCardModel>>) return;
    final result = await _repository.delete(id);

    return result.when(
      (_) async {
        _state.value = Loaded(current.data.where((e) => e.id != id).toList());
      },
      (error) async => Future.delayed(
        Duration(milliseconds: 300),
        () => toastError(error.message),
      ),
    );
  }

  @override
  void dispose() {
    _watchingMonth?.call();
    _state.dispose();
    super.dispose();
  }
}
