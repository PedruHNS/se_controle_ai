import 'package:signals/signals.dart';

import '../../../core/month/selected_month_service.dart';
import '../../../core/shared/view_state.dart';
import '../../../core/utils/base_controller.dart';
import '../../../data/models/dashboard_model.dart';
import '../../../data/repositories/dashboard_repository.dart';

/// A tela do dashboard: um estado só, porque é uma requisição só.
///
/// Diferente da home, que tem um `ViewState` por seção — lá cada card vem de
/// uma rota e pinta quando chega. Aqui os oito blocos vêm juntos, então dividir
/// o estado só daria a ilusão de independência.
class DashboardController extends BaseController {
  final DashboardRepository _repository;
  final SelectedMonthService _selectedMonth;

  DashboardController({
    required this._repository,
    required this._selectedMonth,
  });

  EffectCleanup? _watchingMonth;

  /// Cresce a cada busca, para descartar resposta atrasada.
  int _requestId = 0;

  final _state = signal<ViewState<DashboardModel>>(const Loading());

  ReadonlySignal<ViewState<DashboardModel>> get state => _state;

  @override
  void onInit() {
    super.onInit();

    // A inscrição no mês **é** a carga inicial: o `effect` roda uma vez ao ser
    // criado e de novo a cada troca de competência, venha ela do seletor desta
    // tela ou de outra. Um `load()` aqui além dele duplicaria a primeira
    // requisição.
    _watchingMonth = effect(() {
      _selectedMonth.month.value;
      // `untracked` para o efeito depender só do mês: sem ele, qualquer signal
      // que o `load` venha a ler vira dependência sem querer.
      untracked(load);
    });
  }

  @override
  void dispose() {
    _watchingMonth?.call();
    _state.dispose();
    super.dispose();
  }

  /// [silent] mantém o conteúdo na tela durante a busca — é o que o
  /// pull-to-refresh quer, já que o `RefreshIndicator` já mostra progresso e
  /// piscar o esqueleto no lugar dos cards seria pior.
  Future<void> load({bool silent = false}) async {
    final requestId = ++_requestId;
    final month = _selectedMonth.month.value;

    if (!silent) _state.value = const Loading();

    final result = await _repository.getDashboard(month: month);

    // Toque rápido em duas setas dispara duas buscas, e as respostas podem
    // voltar fora de ordem — sem esta guarda, o mês antigo sobrescreveria o que
    // está na tela.
    if (requestId != _requestId) return;

    result.when(
      (success) => _state.value = Loaded(success),
      (failure) => _state.value = Failed(failure),
    );
  }

  Future<void> refresh() => load(silent: true);
}
