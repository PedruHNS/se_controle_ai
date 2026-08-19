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
/// **O id não entra pelo construtor.** Ele é dado da rota, então quem o conhece
/// é a view: ela chama [start] no `initState` com o que veio em
/// `pathParameters`. Assim o registro no get_it é um `registerFactory` comum,
/// igual ao dos outros controllers, e construir o controller não depende de ter
/// um argumento em mãos.
class IncomeDetailController extends BaseController {
  IncomeDetailController(this._repository);

  final IncomeRepository _repository;

  /// Preenchido por [start]. Sem ele não há o que buscar, então [load],
  /// [refresh] e as quatro operações só existem depois que a view abriu a tela.
  late String _id;

  String get id => _id;

  final _state = signal<ViewState<IncomeModel>>(const Loading());
  final _working = signal<bool>(false);

  /// Cresce a cada requisição, para descartar resposta atrasada — ver [load].
  /// Mesmo contador do `HomeController` e do `IncomeListController`.
  int _requestId = 0;

  ReadonlySignal<ViewState<IncomeModel>> get state => _state;

  /// Alguma operação em andamento — a view desabilita os botões para não
  /// disparar duas vezes.
  ReadonlySignal<bool> get working => _working;

  /// Recebe o id da rota e faz a primeira busca.
  ///
  /// Diferente dos outros controllers, este **não** busca no `onInit`: ali o id
  /// ainda não chegou. A view chama isto no `initState`.
  Future<void> start(String id) {
    _id = id;
    return load();
  }

  Future<void> load({bool silent = false}) async {
    final requestId = ++_requestId;

    if (!silent) _state.value = const Loading();

    final result = await _repository.getById(id);

    // Cada ação termina numa recarga silenciosa, então duas ações em sequência
    // rápida deixam duas buscas em voo. Sem esta guarda, a que voltar por último
    // manda — e não é necessariamente a mais nova.
    if (requestId != _requestId) return;

    result.when(
      (success) => _state.value = Loaded(success),
      (err) => _state.value = Failed(err),
    );
  }

  Future<void> refresh() => load(silent: true);

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
      await load(silent: true);
      return null;
    }, (error) async => error);
  }

  /// Correção — o valor estava errado desde o início da vigência atual.
  Future<Failure?> correct({required int amountCents}) async {
    _working.value = true;

    final result = await _repository.correct(id, amountCents: amountCents);

    _working.value = false;

    return result.when((_) async {
      await load(silent: true);
      return null;
    }, (error) async => error);
  }

  /// Encerramento — [lastMonth] é o último mês recebido.
  Future<Failure?> close({required String lastMonth}) async {
    _working.value = true;

    final result = await _repository.close(id, lastMonth: lastMonth);

    _working.value = false;

    return result.when((_) async {
      await load(silent: true);
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
