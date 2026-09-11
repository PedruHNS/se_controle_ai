import 'package:signals/signals.dart';

import '../../../core/month/selected_month_service.dart';
import '../../../core/shared/view_state.dart';
import '../../../core/utils/base_controller.dart';
import '../../../data/models/dashboard_model.dart';
import '../../../data/repositories/dashboard_repository.dart';

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

    _watchingMonth = effect(() {
      _selectedMonth.month.value;

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
