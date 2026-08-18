import 'package:flutter_test/flutter_test.dart';
import 'package:multiple_result/multiple_result.dart';
import 'package:se_controle_ai/core/errors/failure.dart';
import 'package:se_controle_ai/core/shared/view_state.dart';
import 'package:se_controle_ai/core/utils/month.dart';
import 'package:se_controle_ai/data/models/monthly_summary_model.dart';
import 'package:se_controle_ai/features/home/controller/home_controller.dart';

import '../../fixtures/fake_summary_repository.dart';
import '../../fixtures/summary_fixture.dart';

void main() {
  late FakeSummaryRepository repository;
  late HomeController controller;

  setUp(() {
    repository = FakeSummaryRepository();
    controller = HomeController(repository);
  });

  tearDown(() => controller.dispose());

  group('estado inicial', () {
    // O BaseController chama onInit() no construtor, e o onInit do HomeController
    // dispara load(). Ou seja: construir já busca — quando o corpo do teste roda,
    // a busca do setUp terminou.
    test('busca sozinho ao ser construído', () {
      expect(repository.requestedMonths, [Month.current()]);
      expect(controller.state.value, isA<Loaded<MonthlySummaryModel>>());
      expect(controller.month.value, Month.current());
      expect(controller.isCurrentMonth.value, isTrue);
    });

    test('fica em Loading enquanto a resposta não volta', () async {
      final slowRepository = FakeSummaryRepository()
        ..delay = const Duration(milliseconds: 100);
      final slowController = HomeController(slowRepository);
      addTearDown(slowController.dispose);

      expect(slowController.state.value, isA<Loading<MonthlySummaryModel>>());

      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(slowController.state.value, isA<Loaded<MonthlySummaryModel>>());
    });

    test('monthLabel é derivado do mês', () {
      expect(controller.monthLabel.value, Month.label(Month.current()));
    });
  });

  group('load', () {
    test('sucesso vira Loaded com os dados', () async {
      repository.requestedMonths.clear();

      await controller.load();

      final state = controller.state.value;
      expect(state, isA<Loaded<MonthlySummaryModel>>());
      expect((state as Loaded<MonthlySummaryModel>).data.month, '2026-08');
      expect(repository.requestedMonths, [Month.current()]);
    });

    test('falha vira Failed com o Failure', () async {
      repository.response = const Error(NetworkFailure(message: 'Sem conexão'));

      await controller.load();

      final state = controller.state.value;
      expect(state, isA<Failed<MonthlySummaryModel>>());
      expect(
        (state as Failed<MonthlySummaryModel>).failure,
        isA<NetworkFailure>(),
      );
    });

    test('load silencioso não volta para Loading', () async {
      await controller.load();
      final loaded = controller.state.value;

      final future = controller.refresh();
      // Antes do await: o estado tem de continuar sendo o conteúdo antigo, senão
      // o pull-to-refresh piscaria a tela em branco.
      expect(controller.state.value, same(loaded));

      await future;
      expect(controller.state.value, isA<Loaded<MonthlySummaryModel>>());
    });
  });

  group('navegação entre meses', () {
    test('avança e recua, consultando o mês novo', () async {
      final start = controller.month.value;
      repository.requestedMonths.clear();

      await controller.goToNextMonth();
      expect(controller.month.value, Month.next(start));
      expect(controller.isCurrentMonth.value, isFalse);

      await controller.goToPreviousMonth();
      expect(controller.month.value, start);
      expect(controller.isCurrentMonth.value, isTrue);

      expect(repository.requestedMonths, [Month.next(start), start]);
    });

    test('monthLabel acompanha a troca sem ninguém atualizar à mão', () async {
      final start = controller.month.value;

      await controller.goToNextMonth();

      expect(controller.monthLabel.value, Month.label(Month.next(start)));
    });

    test('goToCurrentMonth volta de qualquer lugar', () async {
      await controller.goToMonth('2026-01');
      expect(controller.isCurrentMonth.value, isFalse);

      await controller.goToCurrentMonth();
      expect(controller.month.value, Month.current());
    });

    test('já no mês corrente e com dado na tela, não refaz a busca', () async {
      repository.requestedMonths.clear();

      await controller.goToCurrentMonth();

      expect(repository.requestedMonths, isEmpty);
    });

    test('mesmo mês SEM dado na tela busca — não deixa preso no erro', () async {
      // A busca inicial falhou: o estado é Failed, não Loaded. Pedir o mesmo mês
      // tem de disparar a busca de novo, senão "voltar para o mês atual" estando
      // no mês atual não faria nada e a tela ficaria presa no erro.
      final failing = FakeSummaryRepository()
        ..response = const Error(NetworkFailure());
      final controllerInError = HomeController(failing);
      addTearDown(controllerInError.dispose);
      await Future<void>.delayed(Duration.zero);

      expect(controllerInError.state.value, isA<Failed<MonthlySummaryModel>>());
      failing.requestedMonths.clear();
      failing.response = Success(MonthlySummaryModel.fromJson(summaryJson));

      await controllerInError.goToCurrentMonth();

      expect(failing.requestedMonths, [Month.current()]);
      expect(controllerInError.state.value, isA<Loaded<MonthlySummaryModel>>());
    });

    test('mesmo mês a partir de erro tenta de novo', () async {
      repository.response = const Error(NetworkFailure());
      await controller.load();
      repository.requestedMonths.clear();

      repository.response = Success(MonthlySummaryModel.fromJson(summaryJson));
      await controller.goToMonth(controller.month.value);

      expect(repository.requestedMonths, hasLength(1));
      expect(controller.state.value, isA<Loaded<MonthlySummaryModel>>());
    });

    test('goToMonth recusa competência inválida', () async {
      final start = controller.month.value;
      repository.requestedMonths.clear();

      await controller.goToMonth('2026-13');
      await controller.goToMonth('lixo');
      await controller.goToMonth('9999-12');

      expect(controller.month.value, start);
      expect(repository.requestedMonths, isEmpty);
    });

    test('goToMonth para o mesmo mês já carregado não refaz a busca', () async {
      await controller.load();
      repository.requestedMonths.clear();

      await controller.goToMonth(controller.month.value);

      expect(repository.requestedMonths, isEmpty);
    });

    test('não passa dos limites que o backend aceita', () async {
      await controller.goToMonth('2100-12');
      repository.requestedMonths.clear();

      expect(controller.canGoNext.value, isFalse);
      await controller.goToNextMonth();

      expect(controller.month.value, '2100-12');
      expect(repository.requestedMonths, isEmpty);

      await controller.goToMonth('2000-01');
      repository.requestedMonths.clear();

      expect(controller.canGoPrevious.value, isFalse);
      await controller.goToPreviousMonth();

      expect(controller.month.value, '2000-01');
      expect(repository.requestedMonths, isEmpty);
    });
  });

  group('corrida', () {
    test('resposta atrasada de mês antigo não sobrescreve a atual', () async {
      // Duas buscas em voo; a primeira volta depois da segunda.
      repository.delay = const Duration(milliseconds: 50);
      final slow = controller.load();

      repository.delay = null;
      repository.response = Success(
        MonthlySummaryModel.fromJson(emptySummaryJson),
      );
      await controller.load();

      expect(
        (controller.state.value as Loaded<MonthlySummaryModel>).data.month,
        '2026-09',
      );

      // A lenta chega agora e precisa ser descartada.
      await slow;
      expect(
        (controller.state.value as Loaded<MonthlySummaryModel>).data.month,
        '2026-09',
        reason: 'a resposta atrasada sobrescreveu a mais nova',
      );
    });
  });
}
