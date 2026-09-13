import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:multiple_result/multiple_result.dart';
import 'package:se_controle_ai/core/di/injector.dart';
import 'package:se_controle_ai/core/errors/failure.dart';
import 'package:se_controle_ai/data/services/selected_month_service.dart';
import 'package:se_controle_ai/core/shared/widgets/failure_card_widget.dart';
import 'package:se_controle_ai/core/shared/widgets/month_selector_widget.dart';
import 'package:se_controle_ai/core/utils/month.dart';
import 'package:se_controle_ai/features/dashboard/view/dashboard_page.dart';

import '../../fixtures/mocks.dart';
import '../../fixtures/test_injector.dart';

void main() {
  late MockDashboardRepository repository;

  setUp(() => repository = setupDashboardTestInjector());

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: DashboardPage()));
    await tester.pumpAndSettle();
  }

  testWidgets('mostra os totais da competência', (tester) async {
    await pump(tester);

    // O `totals` do fixture: R$ 5.000,00 de ganho, R$ 3.124,00 de gasto.
    expect(find.text(r'R$ 1.876,00'), findsOneWidget);
    expect(find.text(r'R$ 5.000,00'), findsOneWidget);
    expect(find.text(r'R$ 3.124,00'), findsOneWidget);
    expect(find.text('Sobra deste mês'), findsOneWidget);
  });

  testWidgets('busca a competência selecionada, uma vez só', (tester) async {
    await pump(tester);

    verify(
      () => repository.getDashboard(month: SelectedMonthService.initial()),
    ).called(1);
  });

  testWidgets('a falha mostra o card de erro, com tentar de novo', (
    tester,
  ) async {
    repository = setupDashboardTestInjector(
      mock: dashboardRepositoryMock(
        dashboard: const Error(NetworkFailure(message: 'Sem conexão.')),
      ),
    );
    await pump(tester);

    expect(find.byType(FailureCardWidget), findsOneWidget);
    expect(find.text('Sem conexão.'), findsOneWidget);
  });

  // O seletor fica fora do `switch` de propósito: trocar o mês põe a tela em
  // `Loading`, e sumir com o controle no toque que a pessoa acabou de dar
  // pareceria tela travada.
  testWidgets('o seletor de mês continua na tela durante a busca', (
    tester,
  ) async {
    repository = setupDashboardTestInjector(
      mock: dashboardRepositoryMock(
        dashboard: const Error(NetworkFailure(message: 'Sem conexão.')),
      ),
    );
    await pump(tester);

    expect(find.byType(MonthSelectorWidget), findsOneWidget);
  });

  testWidgets('a seta troca a competência e rebusca', (tester) async {
    addTearDown(
      () =>
          getIt<SelectedMonthService>().select(SelectedMonthService.initial()),
    );
    await pump(tester);

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();

    final proximo = Month.next(SelectedMonthService.initial());
    verify(() => repository.getDashboard(month: proximo)).called(1);
    expect(find.text(Month.label(proximo)), findsOneWidget);
  });
}
