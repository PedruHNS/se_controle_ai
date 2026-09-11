import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:multiple_result/multiple_result.dart';
import 'package:se_controle_ai/core/errors/failure.dart';
import 'package:se_controle_ai/core/month/selected_month_service.dart';
import 'package:se_controle_ai/core/utils/month.dart';
import 'package:se_controle_ai/core/shared/view_state.dart';
import 'package:se_controle_ai/data/models/dashboard_model.dart';
import 'package:se_controle_ai/features/dashboard/controller/dashboard_controller.dart';

import '../../fixtures/dashboard_fixture.dart';
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

  List<String> mesesBuscados() =>
      verify(
            () => repository.getDashboard(month: captureAny(named: 'month')),
          ).captured
          .cast<String>();

  test('a inscrição no mês já é a carga inicial', () async {
    await pumpEventQueue();

    expect(controller.state.value, isA<Loaded<DashboardModel>>());
    // Uma busca, e não duas: o `effect` roda na criação, e não há `load` solto
    // no `onInit` além dele.
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

  test('refresh silencioso não apaga o que já está na tela', () async {
    final segurando = Completer<void>();
    await pumpEventQueue();
    final carregado = controller.state.value;

    when(() => repository.getDashboard(month: any(named: 'month'))).thenAnswer((
      _,
    ) async {
      await segurando.future;
      return Success(DashboardModel.fromJson(dashboardJson));
    });

    final pendente = controller.refresh();
    await pumpEventQueue();

    // Ainda o dashboard anterior, e não `Loading`: o `RefreshIndicator` já
    // mostra progresso, e piscar o esqueleto no lugar dos cards seria pior.
    expect(controller.state.value, same(carregado));

    segurando.complete();
    await pendente;
    expect(controller.state.value, isA<Loaded<DashboardModel>>());
  });

  test('carga sem silêncio passa por Loading', () async {
    final segurando = Completer<void>();
    await pumpEventQueue();

    when(() => repository.getDashboard(month: any(named: 'month'))).thenAnswer((
      _,
    ) async {
      await segurando.future;
      return Success(DashboardModel.fromJson(dashboardJson));
    });

    final pendente = controller.load();
    await pumpEventQueue();

    expect(controller.state.value, isA<Loading<DashboardModel>>());

    segurando.complete();
    await pendente;
  });

  // Toque rápido em duas setas: as respostas podem voltar fora de ordem, e a
  // do mês antigo não pode sobrescrever a que está na tela.
  test('resposta atrasada é descartada', () async {
    await pumpEventQueue();

    final atrasada = Completer<Result<DashboardModel, Failure>>();
    final noPrazo = DashboardModel.fromJson(dashboardVazioJson);
    var chamada = 0;

    when(() => repository.getDashboard(month: any(named: 'month'))).thenAnswer((
      _,
    ) async {
      chamada++;
      if (chamada == 1) return atrasada.future;
      return Success(noPrazo);
    });

    final primeira = controller.load();
    final segunda = controller.load();
    await segunda;

    atrasada.complete(
      Success(DashboardModel.fromJson(dashboardJson)),
    );
    await primeira;

    final state = controller.state.value as Loaded<DashboardModel>;
    expect(state.data.month, noPrazo.month);
  });
}
