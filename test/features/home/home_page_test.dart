import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multiple_result/multiple_result.dart';
import 'package:se_controle_ai/core/errors/failure.dart';
import 'package:se_controle_ai/core/utils/month.dart';
import 'package:se_controle_ai/data/models/monthly_summary_model.dart';
import 'package:se_controle_ai/features/home/view/home_page.dart';

import 'package:mocktail/mocktail.dart';

import '../../fixtures/mocks.dart';
import '../../fixtures/summary_fixture.dart';
import '../../fixtures/test_injector.dart';

void main() {
  late MockSummaryRepository repository;

  setUp(() => repository = setupTestInjector());
  // tearDown(resetInjector);

  Future<void> pumpHome(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomePage()));
    await tester.pumpAndSettle();
  }

  group('carregamento', () {
    testWidgets('mostra spinner antes da resposta', (tester) async {
      stubMonthly(repository, delay: const Duration(milliseconds: 100));

      await tester.pumpWidget(const MaterialApp(home: HomePage()));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  group('conteúdo', () {
    testWidgets('mostra os totais formatados em real', (tester) async {
      await pumpHome(tester);

      // 5.000,00 aparece 3x: no cartão de saldo, no total da seção Ganhos e na
      // linha do Salário — que é o único ganho do mês.
      expect(find.text('R\$ 5.000,00'), findsNWidgets(3));
      expect(find.text('R\$ 2.455,90'), findsOneWidget); // gasto
      expect(find.text('R\$ 2.544,10'), findsOneWidget); // saldo
      expect(find.text('Sobram'), findsOneWidget);
      // Rótulos do cartão são curtos, para não repetir o nome das seções.
      expect(find.text('Entra'), findsOneWidget);
      expect(find.text('Sai'), findsOneWidget);
    });

    testWidgets('mostra o comprometido do mês', (tester) async {
      await pumpHome(tester);

      expect(find.text('Comprometido'), findsOneWidget);
      expect(find.text('49.1%'), findsOneWidget);
    });

    testWidgets('lista ganhos e débito', (tester) async {
      await pumpHome(tester);

      expect(find.text('Ganhos'), findsOneWidget);
      expect(find.text('Salário'), findsOneWidget);
      expect(find.text('Débito e dinheiro'), findsOneWidget);
      expect(find.text('Aluguel'), findsOneWidget);
    });

    testWidgets('mostra a fatura do cartão com vencimento e limite', (
      tester,
    ) async {
      await pumpHome(tester);

      expect(find.text('Nubank ••••4321'), findsOneWidget);
      expect(find.text('Vence em 17/08'), findsOneWidget);
      expect(find.text('R\$ 655,90'), findsOneWidget);
      expect(find.textContaining('do limite de R\$ 8.000,00'), findsOneWidget);
    });

    testWidgets('item parcelado mostra a parcela; fixo não', (tester) async {
      await pumpHome(tester);

      expect(find.text('Notebook'), findsOneWidget);
      expect(find.text('Parcela 3/10'), findsOneWidget);
      // Netflix é gasto fixo — installmentLabel nulo, nada de "Parcela".
      expect(find.text('Netflix'), findsOneWidget);
      expect(find.textContaining('Parcela'), findsOneWidget);
    });
  });

  group('mês no vermelho', () {
    testWidgets('troca o rótulo do saldo e avisa do estouro', (tester) async {
      stubMonthly(
        repository,
        result: Success(MonthlySummaryModel.fromJson(negativeSummaryJson)),
      );

      await pumpHome(tester);

      expect(find.text('Faltam'), findsOneWidget);
      expect(find.text('-R\$ 1.500,00'), findsOneWidget);
      expect(
        find.text('Os gastos passaram do que entra neste mês.'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Acima do limite de R\$ 4.000,00'),
        findsOneWidget,
      );
    });
  });

  group('mês vazio', () {
    testWidgets('mantém o acesso aos ganhos mesmo sem lançamentos', (
      tester,
    ) async {
      stubMonthly(
        repository,
        result: Success(MonthlySummaryModel.fromJson(emptySummaryJson)),
      );

      await pumpHome(tester);

      expect(find.text('Ganhos'), findsOneWidget);
      expect(
        find.text('Nenhum ganho cadastrado. Toque para adicionar um.'),
        findsOneWidget,
      );
      expect(find.text('Comprometido'), findsNothing);
    });
  });

  group('erro', () {
    testWidgets('falha de rede mostra mensagem e botão de tentar de novo', (
      tester,
    ) async {
      stubMonthly(repository, result: const Error(NetworkFailure()));

      await pumpHome(tester);

      expect(find.text('Sem conexão'), findsOneWidget);
      expect(find.text('Tentar de novo'), findsOneWidget);
    });

    testWidgets('tentar de novo refaz a busca e mostra o conteúdo', (
      tester,
    ) async {
      stubMonthly(repository, result: const Error(NetworkFailure()));
      await pumpHome(tester);

      stubMonthly(
        repository,
        result: Success(MonthlySummaryModel.fromJson(summaryJson)),
      );
      await tester.tap(find.text('Tentar de novo'));
      await tester.pumpAndSettle();

      expect(find.text('Salário'), findsOneWidget);
      expect(find.text('Tentar de novo'), findsNothing);
      verify(() => repository.getMonthly(month: any(named: 'month'))).called(2);
    });

    testWidgets('erro que não vale repetir não oferece o botão', (
      tester,
    ) async {
      // 422 é regra de negócio: repetir daria o mesmo resultado.
      stubMonthly(
        repository,
        result: const Error(
          DomainRuleFailure(message: 'Gasto no cartão exige informar o cartão'),
        ),
      );

      await pumpHome(tester);

      expect(find.text('Operação não permitida'), findsOneWidget);
      expect(find.text('Tentar de novo'), findsNothing);
    });
  });

  group('navegação entre meses', () {
    testWidgets('título mostra a competência em português', (tester) async {
      await pumpHome(tester);

      expect(find.text(Month.label(Month.current())), findsOneWidget);
    });

    testWidgets('seta avança o mês e refaz a busca', (tester) async {
      await pumpHome(tester);
      final start = Month.current();

      // Escopo na AppBar: a seção de ganhos também tem um chevron, o dela
      // levando para a tela de ganhos.
      await tester.tap(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byIcon(Icons.chevron_right),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(Month.label(Month.next(start))), findsOneWidget);
      expect(capturedMonths(repository), [start, Month.next(start)]);
    });

    testWidgets('atalho de voltar ao mês atual aparece só fora dele', (
      tester,
    ) async {
      await pumpHome(tester);

      expect(find.text('Voltar para o mês atual'), findsNothing);

      await tester.tap(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byIcon(Icons.chevron_left),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Voltar para o mês atual'), findsOneWidget);

      await tester.tap(find.text('Voltar para o mês atual'));
      await tester.pumpAndSettle();
      expect(find.text('Voltar para o mês atual'), findsNothing);
      expect(find.text(Month.label(Month.current())), findsOneWidget);
    });
  });
}
