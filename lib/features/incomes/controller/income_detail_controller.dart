import 'package:signals/signals.dart';

import '../../../core/errors/failure.dart';
import '../../../core/shared/view_state.dart';
import '../../../core/utils/base_controller.dart';
import '../../../data/models/income_model.dart';
import '../../../data/repositories/income_repository.dart';

/// Um ganho e suas quatro operações: reajuste, correção, encerramento e
/// exclusão.
///
/// As três primeiras devolvem `Failure?` em vez de guardarem o erro num signal:
/// elas são disparadas de dentro de um diálogo, e é lá que o erro precisa
/// aparecer — inclusive o 422 de regra de negócio, que traz a mensagem pronta
/// do backend ("reajuste retroativo", "mesmo valor já vigente").
///
/// Cada uma, se der certo, **busca o ganho de novo**: o backend responde `204`
/// sem corpo, e o histórico novo só se sabe refazendo a conta que ele faz.
///
/// **O ganho não entra pelo construtor.** Ele chega pelo `extra` da rota, então
/// quem o conhece é a view: ela chama [start] no `initState` com o ganho que a
/// lista já tinha. Assim o registro no get_it é um `registerFactory` comum, e
/// construir o controller não depende de ter um argumento em mãos.
class IncomeDetailController extends BaseController {
  final IncomeRepository _repository;

  IncomeDetailController({required this._repository});

  /// Preenchido por [start]. Sem ele não há o que buscar, então [refresh] e as
  /// quatro operações só existem depois que a view abriu a tela.
  late String _id;

  String get id => _id;

  final _state = signal<ViewState<IncomeModel>>(const Loading());
  ReadonlySignal<ViewState<IncomeModel>> get state => _state;

  final _working = signal<bool>(false);

  /// Alguma operação em andamento — a view desabilita os botões para não
  /// disparar duas vezes.
  ReadonlySignal<bool> get working => _working;

  /// Mostra o ganho que veio da lista, sem buscar de novo — ele já traz o
  /// histórico. O id dele é o que [refresh] e as operações usam.
  void start(IncomeModel income) {
    _id = income.id;
    _state.value = Loaded(income);
  }

  @override
  void dispose() {
    super.dispose();
    _state.dispose();
    _working.dispose();
  }

  Future<void> _load() async {
    _state.value = const Loading();

    final result = await _repository.getById(id);

    // A página libera o controller ao sair, e a resposta pode chegar depois.
    // Escrever num signal liberado lança.
    if (_state.disposed) return;

    result.when(
      (success) => _state.value = Loaded(success),
      (err) => _state.value = Failed(err),
    );
  }

  Future<void> refresh() => _load();

  /// Reajuste — o valor novo passa a valer de [effectiveFrom] em diante, e os
  /// meses anteriores ficam como estavam.
  Future<Failure?> adjust({
    required int amountCents,
    required String effectiveFrom,
  }) async {
    _working.value = true;

    final result = await _repository.adjust(
      id,
      amountCents: amountCents,
      effectiveFrom: effectiveFrom,
    );

    _working.value = false;

    return result.when((_) async {
      await _load();
      return null;
    }, (error) async => error);
  }

  /// Correção — o valor estava errado desde o início da vigência atual.
  Future<Failure?> correct({required int amountCents}) async {
    _working.value = true;

    final result = await _repository.correct(id, amountCents: amountCents);

    _working.value = false;

    return result.when((_) async {
      await _load();
      return null;
    }, (error) async => error);
  }

  /// Encerramento — [lastMonth] é o último mês recebido.
  Future<Failure?> close({required String lastMonth}) async {
    _working.value = true;

    final result = await _repository.close(id, lastMonth: lastMonth);

    _working.value = false;

    return result.when((_) async {
      await _load();
      return null;
    }, (error) async => error);
  }

  /// Exclusão. Sem recarregar depois: o ganho deixou de existir, e quem chamou
  /// sai da tela.
  Future<Failure?> delete() async {
    _working.value = true;

    final result = await _repository.delete(id);

    _working.value = false;

    return result.when((_) async => null, (error) async => error);
  }
}
