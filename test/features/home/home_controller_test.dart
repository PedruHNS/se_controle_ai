import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:multiple_result/multiple_result.dart';
import 'package:se_controle_ai/core/month/selected_month_controller.dart';
import 'package:se_controle_ai/core/errors/failure.dart';
import 'package:se_controle_ai/core/shared/view_state.dart';
import 'package:se_controle_ai/core/utils/month.dart';
import 'package:se_controle_ai/data/models/monthly_summary_model.dart';
import 'package:se_controle_ai/features/home/controller/home_controller.dart';

import '../../fixtures/mocks.dart';
import '../../fixtures/summary_fixture.dart';

void main() {
  late MockSummaryRepository repository;
  late HomeController controller;

  setUp(() {
    repository = summaryRepositoryMock();
    controller = HomeController(repository, SelectedMonthController());
  });

  tearDown(() => controller.dispose());

  group('estado inicial', () {
    // O BaseController chama onInit() no construtor, e o onInit do HomeController
    // dispara load(). Ou seja: construir já busca — quando o corpo do teste roda,
    // a busca do setUp terminou.
    test('busca sozinho ao ser construído', () {
      verify(() => repository.getMonthly(month: Month.current())).called(1);
      expect(controller.state.value, isA<Loaded<MonthlySummaryModel>>());
      expect(controller.month.value, Month.current());
      expect(controller.isCurrentMonth.value, isTrue);
    });

    test('fica em Loading enquanto a resposta não volta', () async {
      final slowRepository = summaryRepositoryMock(
        delay: const Duration(milliseconds: 100),
      );
      final slowController = HomeController(
        slowRepository,
        SelectedMonthController(),
      );
      addTearDown(slowController.dispose);

      expect(slowController.state.value, isA<Loading<MonthlySummaryModel>>());

      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(slowController.state.value, isA<Loaded<MonthlySummaryModel>>());
    });

    test('monthLabel é derivado do mês', () {
      expect(controller.monthLabel.value, Month.shortLabel(Month.current()));
    });
  });

  group('load', () {
    test('sucesso vira Loaded com os dados', () async {
      clearInteractions(repository);

      await controller.load();

      final state = controller.state.value;
      expect(state, isA<Loaded<MonthlySummaryModel>>());
      expect((state as Loaded<MonthlySummaryModel>).data.month, '2026-08');
      verify(() => repository.getMonthly(month: Month.current())).called(1);
    });

    test('falha vira Failed com a falha traduzida', () async {
      stubMonthly(repository, result: const Error(NetworkFailure()));

      await controller.load();

      final state = controller.state.value;
      expect(state, isA<Failed<MonthlySummaryModel>>());
      expect(
        (state as Failed<MonthlySummaryModel>).failure,
        isA<NetworkFailure>(),
      );
    });

    test('silent mantém o conteúdo na tela durante a busca', () async {
      stubMonthly(repository, delay: const Duration(milliseconds: 50));

      final pending = controller.load(silent: true);

      expect(controller.state.value, isA<Loaded<MonthlySummaryModel>>());
      await pending;
      expect(controller.state.value, isA<Loaded<MonthlySummaryModel>>());
    });
  });

  group('navegação entre meses', () {
    test('avança e volta pedindo o mês novo', () async {
      final start = controller.month.value;
      clearInteractions(repository);

      await controller.goToNextMonth();
      expect(controller.month.value, Month.next(start));

      await controller.goToPreviousMonth();
      expect(controller.month.value, start);

      expect(capturedMonths(repository), [Month.next(start), start]);
    });

    test('monthLabel acompanha a troca sem ninguém atualizar à mão', () async {
      final start = controller.month.value;

      await controller.goToNextMonth();

      expect(controller.monthLabel.value, Month.shortLabel(Month.next(start)));
    });

    test('goToCurrentMonth volta de qualquer lugar', () async {
      await controller.goToMonth('2026-01');
      expect(controller.isCurrentMonth.value, isFalse);

      await controller.goToCurrentMonth();
      expect(controller.month.value, Month.current());
    });

    test('já no mês corrente e com dado na tela, não refaz a busca', () async {
      clearInteractions(repository);

      await controller.goToCurrentMonth();

      verifyNever(() => repository.getMonthly(month: any(named: 'month')));
    });

    test('mesmo mês SEM dado na tela busca — não deixa preso no erro', () async {
      // A busca inicial falhou: o estado é Failed, não Loaded. Pedir o mesmo mês
      // tem de disparar a busca de novo, senão "voltar para o mês atual" estando
      // no mês atual não faria nada e a tela ficaria presa no erro.
      final failing = summaryRepositoryMock(
        result: const Error(NetworkFailure()),
      );
      final controllerInError = HomeController(
        failing,
        SelectedMonthController(),
      );
      addTearDown(controllerInError.dispose);
      await Future<void>.delayed(Duration.zero);

      expect(controllerInError.state.value, isA<Failed<MonthlySummaryModel>>());
      clearInteractions(failing);
      stubMonthly(failing);

      await controllerInError.goToCurrentMonth();

      verify(() => failing.getMonthly(month: Month.current())).called(1);
      expect(controllerInError.state.value, isA<Loaded<MonthlySummaryModel>>());
    });

    test('mesmo mês a partir de erro tenta de novo', () async {
      stubMonthly(repository, result: const Error(NetworkFailure()));
      await controller.load();
      clearInteractions(repository);

      stubMonthly(repository);
      await controller.goToMonth(controller.month.value);

      verify(() => repository.getMonthly(month: any(named: 'month'))).called(1);
      expect(controller.state.value, isA<Loaded<MonthlySummaryModel>>());
    });

    test('goToMonth recusa competência inválida', () async {
      final start = controller.month.value;
      clearInteractions(repository);

      await controller.goToMonth('2026-13');
      await controller.goToMonth('lixo');
      await controller.goToMonth('9999-12');

      expect(controller.month.value, start);
      verifyNever(() => repository.getMonthly(month: any(named: 'month')));
    });

    test('goToMonth para o mesmo mês já carregado não refaz a busca', () async {
      await controller.load();
      clearInteractions(repository);

      await controller.goToMonth(controller.month.value);

      verifyNever(() => repository.getMonthly(month: any(named: 'month')));
    });

    test('não passa dos limites que o backend aceita', () async {
      await controller.goToMonth('2100-12');
      clearInteractions(repository);

      expect(controller.canGoNext.value, isFalse);
      await controller.goToNextMonth();

      expect(controller.month.value, '2100-12');
      verifyNever(() => repository.getMonthly(month: any(named: 'month')));

      await controller.goToMonth('2000-01');
      clearInteractions(repository);

      expect(controller.canGoPrevious.value, isFalse);
      await controller.goToPreviousMonth();

      expect(controller.month.value, '2000-01');
      verifyNever(() => repository.getMonthly(month: any(named: 'month')));
    });
  });

  group('corrida', () {
    test('resposta atrasada de mês antigo não sobrescreve a atual', () async {
      // Duas buscas em voo; a primeira volta depois da segunda.
      stubMonthly(repository, delay: const Duration(milliseconds: 50));
      final slow = controller.load();

      stubMonthly(
        repository,
        result: Success(MonthlySummaryModel.fromJson(emptySummaryJson)),
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
