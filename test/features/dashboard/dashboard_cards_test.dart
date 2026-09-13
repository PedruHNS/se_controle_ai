import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:se_controle_ai/data/enums/dashboard_scope.dart';
import 'package:se_controle_ai/data/models/dashboard_allowance_model.dart';
import 'package:se_controle_ai/data/models/dashboard_model.dart';
import 'package:se_controle_ai/features/dashboard/widgets/allowance_card_widget.dart';
import 'package:se_controle_ai/features/dashboard/widgets/cards_limit_card_widget.dart';
import 'package:se_controle_ai/features/dashboard/widgets/daily_pace_card_widget.dart';
import 'package:se_controle_ai/features/dashboard/widgets/month_strip_card_widget.dart';
import 'package:se_controle_ai/features/dashboard/widgets/nature_card_widget.dart';
import 'package:se_controle_ai/features/dashboard/widgets/tag_amounts_card_widget.dart';
import 'package:se_controle_ai/features/dashboard/widgets/top_expenses_card_widget.dart';

import 'package:se_controle_ai/core/di/injector.dart';
import 'package:se_controle_ai/data/services/selected_month_service.dart';

import '../../fixtures/dashboard_fixture.dart';
import '../../fixtures/test_injector.dart';

void main() {
  final dashboard = DashboardModel.fromJson(dashboardJson);
  final estourado = DashboardModel.fromJson(dashboardEstouradoJson);

  Future<void> pump(WidgetTester tester, Widget card) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Padding(padding: const EdgeInsets.all(16), child: card),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('A6 · pode gastar por dia', () {
    testWidgets('mostra o valor por dia e quanto da renda já foi', (
      tester,
    ) async {
      await pump(
        tester,
        AllowanceCardWidget(
          allowance: dashboard.allowance,
          totals: dashboard.totals,
        ),
      );

      expect(find.text('Pode gastar por dia'), findsOneWidget);
      expect(find.text(r'R$ 89,33'), findsOneWidget);
      expect(find.text('62,5% da renda já comprometida'), findsOneWidget);
      expect(
        find.text('Dividido pelos 21 dias que faltam, contando hoje'),
        findsOneWidget,
      );
    });

    // DSH-07: o mês no vermelho troca a frase, não o sinal do número.
    testWidgets('mês estourado diz quanto passou, sem valor por dia', (
      tester,
    ) async {
      await pump(
        tester,
        AllowanceCardWidget(
          allowance: estourado.allowance,
          totals: estourado.totals,
        ),
      );

      expect(
        find.text(r'Você já passou R$ 380,00 do que tinha este mês.'),
        findsOneWidget,
      );
      expect(find.textContaining('contando hoje'), findsNothing);
    });

    // DSH-06: num mês que já acabou não existe "ainda cabe".
    testWidgets('mês passado fala em média realizada', (tester) async {
      await pump(
        tester,
        AllowanceCardWidget(
          allowance: const DashboardAllowanceModel(
            scope: DashboardScope.past,
            daysRemaining: 31,
            perDayCents: 10000,
            overspentCents: null,
          ),
          totals: dashboard.totals,
        ),
      );

      expect(find.text('Gastou por dia'), findsOneWidget);
      expect(
        find.text('Média dos 31 dias do mês, do que foi gasto'),
        findsOneWidget,
      );
    });
  });

  group('A7 · gasto por categoria', () {
    testWidgets('uma barra por tag, da maior para a menor', (tester) async {
      await pump(tester, TagAmountsCardWidget(byTag: dashboard.byTag));

      expect(find.text('Mercado'), findsOneWidget);
      expect(find.text(r'R$ 1.200,00'), findsOneWidget);
      expect(find.text('Lazer'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNWidgets(4));

      // A maior enche a barra; as outras são proporção dela.
      final barras = tester
          .widgetList<LinearProgressIndicator>(
            find.byType(LinearProgressIndicator),
          )
          .toList();
      expect(barras.first.value, 1.0);
      expect(barras.last.value! < barras.first.value!, isTrue);
    });
  });

  group('A8 · ritmo do mês', () {
    testWidgets('desenha a curva e diz a linha de base', (tester) async {
      await pump(
        tester,
        DailyPaceCardWidget(
          daily: dashboard.daily,
          allowance: dashboard.allowance,
        ),
      );

      expect(find.byType(LineChart), findsOneWidget);
      // DSH-12: sem dizer a linha de base, metade do mês some do desenho.
      expect(find.textContaining(r'R$ 2.100,00'), findsOneWidget);
    });

    // Com uma marca a cada sete dias, o rótulo do último dia caía em cima do
    // penúltimo num mês de 31 — "dia 28dia 31" na tela.
    testWidgets('o eixo marca só o primeiro dia, o 15 e o último', (
      tester,
    ) async {
      await pump(
        tester,
        DailyPaceCardWidget(
          daily: dashboard.daily,
          allowance: dashboard.allowance,
        ),
      );

      expect(find.text('dia 1'), findsOneWidget);
      expect(find.text('dia 15'), findsOneWidget);
      expect(find.text('dia 30'), findsOneWidget);
      expect(find.text('dia 7'), findsNothing);
      expect(find.text('dia 21'), findsNothing);
    });

    testWidgets('três linhas: o mês, o mês anterior e o ritmo que cabe', (
      tester,
    ) async {
      await pump(
        tester,
        DailyPaceCardWidget(
          daily: dashboard.daily,
          allowance: dashboard.allowance,
        ),
      );

      final chart = tester.widget<LineChart>(find.byType(LineChart));
      expect(chart.data.lineBarsData, hasLength(3));
    });
  });

  group('A9 · faturas e limite', () {
    testWidgets('cartão com limite ganha trilho; sem limite, não', (
      tester,
    ) async {
      await pump(tester, CardsLimitCardWidget(cards: dashboard.cards));

      expect(find.text('Nubank ••••1234'), findsOneWidget);
      expect(find.text(r'de R$ 5.000,00 de limite'), findsOneWidget);

      // DSH-16 e DSH-17: o cartão sem gasto aparece, e o sem limite não ganha
      // um trilho inventado.
      expect(find.text('Inter'), findsOneWidget);
      expect(find.text('Sem limite cadastrado'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });
  });

  group('A10 · composição do gasto', () {
    testWidgets('as três naturezas, com valor ao lado', (tester) async {
      await pump(tester, NatureCardWidget(byNature: dashboard.byNature));

      expect(find.text('Fixo recorrente'), findsOneWidget);
      expect(find.text(r'R$ 1.800,00'), findsOneWidget);
      expect(find.text('Parcelado'), findsOneWidget);
      expect(find.text(r'R$ 300,00'), findsOneWidget);
      expect(find.text('Avulso'), findsOneWidget);
      expect(find.text(r'R$ 1.024,00'), findsOneWidget);
    });
  });

  group('A11 · a régua de meses', () {
    // A régua é ancorada em hoje (DSH-20) e o toque só move o destaque: é o
    // que impede as barras de se reorganizarem debaixo do dedo.
    testWidgets('tocar num mês seleciona aquela competência', (tester) async {
      setupDashboardTestInjector();
      final mes = getIt<SelectedMonthService>();
      addTearDown(() => mes.select(SelectedMonthService.initial()));

      await pump(
        tester,
        MonthStripCardWidget(
          history: dashboard.history,
          month: dashboard.month,
        ),
      );

      // A régua cobre três anos, então 'JUL' aparece mais de uma vez; a
      // primeira desenhada é a de 2026, porque a lista abre no mês
      // selecionado.
      await tester.tap(find.text('JUL').first);
      await tester.pumpAndSettle();

      expect(mes.month.value, '2026-07');
    });

    testWidgets('rola na horizontal sem trocar de competência', (tester) async {
      setupDashboardTestInjector();
      final mes = getIt<SelectedMonthService>();
      addTearDown(() => mes.select(SelectedMonthService.initial()));
      final partida = mes.month.value;

      await pump(
        tester,
        MonthStripCardWidget(
          history: dashboard.history,
          month: dashboard.month,
        ),
      );

      await tester.drag(
        find.byType(MonthStripCardWidget),
        const Offset(-120, 0),
      );
      await tester.pumpAndSettle();

      expect(mes.month.value, partida);
    });

    // O ano aparece só em janeiro: repetido em toda barra viraria ruído, e sem
    // ele uma régua de três anos não diz de que "SET" se trata.
    testWidgets('o ano aparece em janeiro', (tester) async {
      setupDashboardTestInjector();

      await pump(
        tester,
        MonthStripCardWidget(
          history: dashboard.history,
          month: dashboard.month,
        ),
      );

      expect(find.text('JAN'), findsWidgets);
    });
  });

  group('A12 · maiores gastos', () {
    testWidgets('cinco linhas, com dia da compra e rótulo de parcela', (
      tester,
    ) async {
      await pump(
        tester,
        TopExpensesCardWidget(topExpenses: dashboard.topExpenses),
      );

      expect(find.text('Geladeira'), findsOneWidget);
      // GFX-12: o dia é o da compra, em julho, não o da cobrança.
      expect(find.text('10/07 · 3/10'), findsOneWidget);

      expect(find.text('Mercado do mês'), findsOneWidget);
      expect(find.text('05/09'), findsOneWidget);
    });
  });
}
