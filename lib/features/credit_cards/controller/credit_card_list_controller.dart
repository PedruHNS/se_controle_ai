import 'package:signals/signals.dart';

import '../../../core/errors/failure.dart';
import '../../../core/month/selected_month_controller.dart';
import '../../../core/shared/view_state.dart';
import '../../../core/utils/base_controller.dart';
import '../../../data/models/credit_card_model.dart';
import '../../../data/repositories/credit_card_repository.dart';

/// Lista de cartões, e a exclusão a partir dela.
///
/// A busca leva a competência para o `dueDate` vir resolvido (CAR-03) — sem
/// `?month` cada cartão vem com `dueDate` null e a lista não teria vencimento
/// para mostrar.
///
/// A competência é a **selecionada** (`SelectedMonthController`), e não a de
/// hoje: o conjunto de cartões não muda com o mês, mas o vencimento exibido
/// muda — e mostrar o vencimento de agosto para quem está olhando setembro é o
/// mesmo desencontro que a lista de gastos tinha.
class CreditCardListController extends BaseController {
  CreditCardListController(this._repository, this._selectedMonth);

  final CreditCardRepository _repository;
  final SelectedMonthController _selectedMonth;

  /// Desfaz a inscrição no mês. Sem isto o `effect` continua vivo depois do
  /// `dispose`, buscando para um controller que ninguém mais lê.
  EffectCleanup? _watchingMonth;

  final _state = signal<ViewState<List<CreditCardModel>>>(const Loading());
  final _working = signal<bool>(false);

  /// Cresce a cada requisição, para descartar resposta atrasada — ver [load].
  int _requestId = 0;

  ReadonlySignal<ViewState<List<CreditCardModel>>> get state => _state;

  /// Exclusão em andamento. A view desabilita o botão para não pedir duas vezes.
  ReadonlySignal<bool> get working => _working;

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

  Future<void> load({bool silent = false}) async {
    final requestId = ++_requestId;

    if (!silent) _state.value = const Loading();

    final result = await _repository.list(month: _selectedMonth.month.value);

    if (requestId != _requestId) return;

    result.when(
      (success) => _state.value = Loaded(success),
      (err) => _state.value = Failed(err),
    );
  }

  Future<void> refresh() => load(silent: true);

  /// Exclui e devolve a falha para quem chamou, em vez de guardá-la em signal —
  /// mesma escolha das ações de ganho, e aqui ela pesa mais: o 409 do CAR-07
  /// ("cartão com gastos vinculados") precisa aparecer no diálogo de
  /// confirmação, sobre a lista que continua correta.
  Future<Failure?> delete(String id) async {
    _working.value = true;

    final result = await _repository.delete(id);

    _working.value = false;

    return result.when((_) async {
      await load(silent: true);
      return null;
    }, (error) async => error);
  }

  @override
  void dispose() {
    _watchingMonth?.call();
    _state.dispose();
    _working.dispose();
    super.dispose();
  }
}
