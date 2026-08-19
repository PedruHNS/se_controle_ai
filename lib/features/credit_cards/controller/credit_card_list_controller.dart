import 'package:signals/signals.dart';

import '../../../core/errors/failure.dart';
import '../../../core/shared/view_state.dart';
import '../../../core/utils/base_controller.dart';
import '../../../core/utils/month.dart';
import '../../../data/models/credit_card_model.dart';
import '../../../data/repositories/credit_card_repository.dart';

/// Lista de cartões, e a exclusão a partir dela.
///
/// A busca leva a competência corrente para o `dueDate` vir resolvido (CAR-03) —
/// sem `?month` cada cartão vem com `dueDate` null e a lista não teria vencimento
/// para mostrar. O mês é fixo no atual: cartão é cadastro, e navegar mês a mês
/// aqui só mudaria a data de vencimento exibida, não o conjunto de cartões.
class CreditCardListController extends BaseController {
  CreditCardListController(this._repository);

  final CreditCardRepository _repository;

  final _state = signal<ViewState<List<CreditCardModel>>>(const Loading());
  final _working = signal<bool>(false);

  /// Cresce a cada requisição, para descartar resposta atrasada — ver [load].
  int _requestId = 0;

  ReadonlySignal<ViewState<List<CreditCardModel>>> get state => _state;

  /// Exclusão em andamento. A view desabilita o botão para não pedir duas vezes.
  ReadonlySignal<bool> get working => _working;

  @override
  void onInit() async {
    super.onInit();
    await load();
  }

  Future<void> load({bool silent = false}) async {
    final requestId = ++_requestId;

    if (!silent) _state.value = const Loading();

    final result = await _repository.list(month: Month.current());

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
    _state.dispose();
    _working.dispose();
    super.dispose();
  }
}
