import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:multiple_result/multiple_result.dart';
import 'package:se_controle_ai/core/errors/failure.dart';
import 'package:se_controle_ai/data/services/selected_month_service.dart';
import 'package:se_controle_ai/core/shared/view_state.dart';
import 'package:se_controle_ai/core/utils/month.dart';
import 'package:se_controle_ai/data/models/dashboard_model.dart';
import 'package:se_controle_ai/features/dashboard/controller/dashboard_controller.dart';

import '../../fixtures/mocks.dart';

void main() {
  late MockDashboardRepository repository;
  late SelectedMonthService month;
  late DashboardController controller;

  DashboardController build() =>
      DashboardController(repository: repository, selectedMonth: month);

  setUp(() {
    repository = dashboardRepositoryMock();
    month = SelectedMonthService();
    controller = build();
  });

  tearDown(() => controller.dispose());

  List<String> mesesBuscados() => verify(
    () => repository.getDashboard(month: captureAny(named: 'month')),
  ).captured.cast<String>();

  test('a inscrição no mês já é a carga inicial', () async {
    await pumpEventQueue();

    expect(controller.state.value, isA<Loaded<DashboardModel>>());
    // Uma busca, e não duas: o `effect` roda na criação, e não há `_load`
    // solto no `onInit` além dele.
    expect(mesesBuscados(), [SelectedMonthService.initial()]);
  });

  test('trocar a competência rebusca', () async {
    await pumpEventQueue();

    month.goToNext();
    await pumpEventQueue();

    expect(mesesBuscados(), [
      SelectedMonthService.initial(),
      Month.next(SelectedMonthService.initial()),
    ]);
  });

  test('falha vira Failed, com a mensagem do backend', () async {
    repository = dashboardRepositoryMock(
      dashboard: const Error(NetworkFailure(message: 'Sem conexão.')),
    );
    controller = build();
    await pumpEventQueue();

    final state = controller.state.value;
    expect(state, isA<Failed<DashboardModel>>());
    expect((state as Failed<DashboardModel>).failure.message, 'Sem conexão.');
  });

  test('refresh busca de novo a competência da tela', () async {
    await pumpEventQueue();

    await controller.refresh();

    expect(controller.state.value, isA<Loaded<DashboardModel>>());
    expect(mesesBuscados(), [
      SelectedMonthService.initial(),
      SelectedMonthService.initial(),
    ]);
  });
}
