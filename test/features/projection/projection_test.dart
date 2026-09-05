import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:multiple_result/multiple_result.dart';
import 'package:se_controle_ai/core/month/selected_month_service.dart';
import 'package:se_controle_ai/core/errors/failure.dart';
import 'package:se_controle_ai/core/shared/view_state.dart';
import 'package:se_controle_ai/core/utils/month.dart';
import 'package:se_controle_ai/data/models/month_projection_model.dart';
import 'package:se_controle_ai/features/projection/controller/projection_controller.dart';
import 'package:se_controle_ai/features/projection/view/projection_page.dart';
import 'package:se_controle_ai/features/projection/widgets/projection_chart.dart';

import '../../fixtures/mocks.dart';
import '../../fixtures/projection_fixture.dart';
import '../../fixtures/test_injector.dart';

void main() {
  late MockSummaryRepository repository;

  setUp(() => repository = setupTestInjector());

  group('controller', () {
    late ProjectionController controller;

    setUp(
      () => controller = ProjectionController(
        repository,
        SelectedMonthService(),
      ),
    );
    tearDown(() => controller.dispose());

    test('abre em doze meses, a partir do mês em que o app abre', () async {
      await controller.load();

      expect(controller.months.value, 12);
      verify(
        () => repository.getProjection(from: SelectedMonthService.initial(), months: 12),
      ).called(greaterThanOrEqualTo(1));
    });

    test('carrega e fica em Loaded', () async {
      await controller.load();

      final state = controller.state.value;
      expect(state, isA<Loaded<List<MonthProjectionModel>>>());
      expect((state as Loaded<List<MonthProjectionModel>>).data, hasLength(6));
    });

    test('trocar o horizonte busca de novo', () async {
      await controller.load();

      await controller.setMonths(24);

      expect(controller.months.value, 24);
      verify(
        () => repository.getProjection(from: any(named: 'from'), months: 24),
      ).called(1);
    });

    // O SegmentedButton avisa mesmo quando a escolha é a mesma, e uma
    // requisição por toque repetido seria desperdício.
    test('escolher o horizonte atual não busca nada', () async {
      await controller.load();
      clearInteractions(repository);

      await controller.setMonths(12);

      verifyNever(
        () => repository.getProjection(
          from: any(named: 'from'),
          months: any(named: 'months'),
        ),
      );
    });

    test('falha vira Failed', () async {
      stubProjection(
        repository,
        result: const Error(NetworkFailure(message: 'sem rede')),
      );

      await controller.load();

      expect(controller.state.value, isA<Failed<List<MonthProjectionModel>>>());
    });

    // Trocar o horizonte duas vezes é um toque rápido, e a resposta de 24 meses
    // pode chegar depois da de 6.
    test('resposta atrasada não sobrescreve a mais nova', () async {
      final presa = Completer<void>();
      stubProjection(repository, pendenteAte: presa.future);
      final slow = controller.load();

      stubProjection(
        repository,
        result: const Error(NetworkFailure(message: 'a mais nova')),
      );
      await controller.load();

      expect(controller.state.value, isA<Failed<List<MonthProjectionModel>>>());

      presa.complete();
      await slow;

      expect(
        controller.state.value,
        isA<Failed<List<MonthProjectionModel>>>(),
        reason: 'a busca antiga voltou depois e reescreveu o estado',
      );
    });
  });

  group('tela', () {
    Future<void> pump(WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: ProjectionPage()));
      await tester.pumpAndSettle();
    }

    testWidgets('mostra o acumulado do último mês e o gráfico', (tester) async {
      await pump(tester);

      expect(find.textContaining('Acumulado até'), findsOneWidget);
      expect(find.text(r'R$ 35.020,00'), findsOneWidget);
      expect(find.byType(ProjectionChart), findsOneWidget);
    });

    testWidgets('lista mês a mês, com entra e sai', (tester) async {
      await pump(tester);

      expect(find.text(Month.label('2026-08')), findsOneWidget);
      expect(find.textContaining('Entra'), findsWidgets);
    });

    // A pergunta que só esta tela responde.
    testWidgets('avisa o primeiro mês no vermelho', (tester) async {
      stubProjection(
        repository,
        result: Success(
          projectionNegativeJson.map(MonthProjectionModel.fromJson).toList(),
        ),
      );

      await pump(tester);

      expect(
        find.text('No vermelho em ${Month.label('2026-08')}'),
        findsOneWidget,
      );
    });

    testWidgets('sem mês negativo, não há aviso', (tester) async {
      await pump(tester);

      expect(find.textContaining('No vermelho'), findsNothing);
    });

    // Sem esta linha o número do topo é uma promessa que o app não fez.
    testWidgets('avisa que a conta começa do zero', (tester) async {
      await pump(tester);

      // A ressalva fica no fim da lista dos meses, fora da tela do teste.
      await tester.scrollUntilVisible(
        find.textContaining('começa do zero'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('começa do zero'), findsOneWidget);
    });

    testWidgets('o seletor de horizonte troca a busca', (tester) async {
      await pump(tester);

      await tester.tap(find.text('6 meses'));
      await tester.pumpAndSettle();

      verify(
        () => repository.getProjection(from: any(named: 'from'), months: 6),
      ).called(1);
    });

    testWidgets('falha mostra o card de erro', (tester) async {
      stubProjection(
        repository,
        result: const Error(NetworkFailure(message: 'Sem conexão.')),
      );

      await pump(tester);

      expect(find.text('Sem conexão.'), findsOneWidget);
    });
  });
}
