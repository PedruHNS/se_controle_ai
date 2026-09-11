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

  final _state = signal<ViewState<DashboardModel>>(const Loading());
  ReadonlySignal<ViewState<DashboardModel>> get state => _state;

  @override
  void onInit() {
    super.onInit();

    // A inscrição no mês **é** a carga inicial: o `effect` roda uma vez ao ser
    // criado e de novo a cada troca de competência, venha ela do seletor desta
    // tela ou de outra. Um `_load()` aqui além dele duplicaria a primeira
    // requisição.
    _watchingMonth = effect(() {
      _selectedMonth.month.value;
      // `untracked` para o efeito depender só do mês: sem ele, qualquer signal
      // que o `_load` venha a ler vira dependência sem querer.
      untracked(_load);
    });
  }

  @override
  void dispose() {
    _watchingMonth?.call();
    super.dispose();
    _state.dispose();
  }

  Future<void> _load() async {
    _state.value = const Loading();

    final result = await _repository.getDashboard(
      month: _selectedMonth.month.value,
    );

    result.when(
      (success) => _state.value = Loaded(success),
      (err) => _state.value = Failed(err),
    );
  }

  Future<void> refresh() => _load();
}
