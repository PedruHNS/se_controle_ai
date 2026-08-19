import 'package:signals/signals.dart';

import '../../../core/shared/view_state.dart';
import '../../../core/utils/base_controller.dart';
import '../../../data/models/income_model.dart';
import '../../../data/repositories/income_repository.dart';

/// Lista de ganhos. Mesmo molde do `HomeController`: signal privado, getter
/// `ReadonlySignal`, nenhum import de Flutter.
///
/// A listagem é sem `?month` de propósito — esta é a tela de cadastro, e
/// esconder um ganho encerrado porque hoje é dezembro deixaria o usuário sem
/// como consultar ou apagar o que cadastrou. O recorte por mês quem faz é a
/// home, em `/summary`.
class IncomeListController extends BaseController {
  IncomeListController(this._repository);

  final IncomeRepository _repository;

  final _state = signal<ViewState<List<IncomeModel>>>(const Loading());

  ReadonlySignal<ViewState<List<IncomeModel>>> get state => _state;

  @override
  void onInit() async {
    super.onInit();
    await load();
  }

  /// [silent] mantém a lista na tela durante a busca, para o pull-to-refresh
  /// não piscar e para a volta de uma ação não apagar o conteúdo.
  Future<void> load({bool silent = false}) async {
    if (!silent) _state.value = const Loading();

    final result = await _repository.list();

    result.when(
      (success) => _state.value = Loaded(success),
      (err) => _state.value = Failed(err),
    );
  }

  Future<void> refresh() => load(silent: true);
}
