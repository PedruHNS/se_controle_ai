import 'package:another_flushbar/flushbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:multiple_result/multiple_result.dart';
import 'package:se_controle_ai/core/config/globals.dart';
import 'package:se_controle_ai/core/di/injector.dart';
import 'package:se_controle_ai/core/errors/app_exception.dart';
import 'package:se_controle_ai/data/services/selected_month_service.dart';
import 'package:se_controle_ai/core/errors/failure.dart';
import 'package:se_controle_ai/core/utils/month_utils.dart';
import 'package:se_controle_ai/data/models/income_model.dart';
import 'package:se_controle_ai/data/services/navigation_service.dart';
import 'package:se_controle_ai/features/incomes/view/income_detail_page.dart';
import 'package:se_controle_ai/features/incomes/view/income_list_page.dart';

import '../../fixtures/income_fixture.dart';
import '../../fixtures/mocks.dart';
import '../../fixtures/test_injector.dart';

void main() {
  late MockIncomeRepository repository;
  late MockNavigationService nav;

  setUp(() {
    repository = setupIncomeTestInjector();
    // O dublê é um só para a suíte inteira: sem limpar, o `pop` de um teste
    // contaria no seguinte.
    nav = getIt<NavigationService>() as MockNavigationService;
    clearInteractions(nav);
  });

  Future<void> pumpList(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: IncomeListPage()));
    await tester.pumpAndSettle();
  }

  /// Abre o detalhe com o ganho que a lista entregaria pelo `extra` da rota —
  /// o salário, a não ser que o teste passe outro. O `navigatorKey` é o do app
  /// porque a falha sai em toast, e o toast procura o contexto por ele. Quem
  /// fecha diálogo e tela é o `NavigationService` dublê, então os dois ficam
  /// montados e o teste confere o `pop`.
  Future<void> pumpDetail(WidgetTester tester, {IncomeModel? income}) async {
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: Globals.navigatorKey,
        home: IncomeDetailPage(
          income:
              income ?? IncomeModel.fromJson({...salaryJson, 'id': 'income-1'}),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('lista', () {
    testWidgets('mostra os ganhos com valor formatado', (tester) async {
      await pumpList(tester);

      expect(find.text('Salário'), findsOneWidget);
      expect(find.text('13º salário'), findsOneWidget);
      expect(find.text(r'R$ 5.000,00'), findsWidgets);
    });

    testWidgets('avulso do mês exibido entra no total, sem selo de encerrado', (
      tester,
    ) async {
      final month = SelectedMonthService.initial();
      stubIncomeList(
        repository,
        result: Success(
          [
            salaryJson,
            singleMonthIncomeJson(month: month),
          ].map(IncomeModel.fromJson).toList(),
        ),
      );
      await pumpList(tester);

      // A venda tem `endMonth` preenchido, mas o mês dela é agora: ela está
      // entrando, e chamá-la de encerrada seria mentira.
      expect(find.text('Encerrado'), findsNothing);
      expect(find.text('Mês único'), findsOneWidget);

      // 5.000 do salário + 800 da venda — o mesmo número que a home mostra.
      expect(
        find.descendant(
          of: find.widgetWithText(Row, 'Entra em ${MonthUtils.label(month)}'),
          matching: find.text(r'R$ 5.800,00'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('ganho que acabou em mês passado é marcado como encerrado', (
      tester,
    ) async {
      final past = MonthUtils.previous(MonthUtils.current());
      stubIncomeList(
        repository,
        result: Success(
          [
            salaryJson,
            singleMonthIncomeJson(month: past, description: 'Freela antigo'),
          ].map(IncomeModel.fromJson).toList(),
        ),
      );
      await pumpList(tester);

      expect(find.text('Encerrado'), findsOneWidget);
      expect(find.text('Mês único'), findsNothing);
      // Não entra mais, então não conta no total do mês.
      expect(
        find.descendant(
          of: find.widgetWithText(
            Row,
            'Entra em ${MonthUtils.label(SelectedMonthService.initial())}',
          ),
          matching: find.text(r'R$ 5.000,00'),
        ),
        findsOneWidget,
      );
    });

    // Mesmo bug da lista de gastos, mesma correção: o rodapé seguia o relógio
    // do aparelho em vez do mês escolhido na home.
    testWidgets('o total segue o mês selecionado na home', (tester) async {
      final atual = SelectedMonthService.initial();
      final proximo = MonthUtils.next(atual);
      stubIncomeList(
        repository,
        result: Success(
          [
            salaryJson,
            singleMonthIncomeJson(month: proximo, description: 'Bônus'),
          ].map(IncomeModel.fromJson).toList(),
        ),
      );
      await pumpList(tester);

      expect(
        find.descendant(
          of: find.widgetWithText(Row, 'Entra em ${MonthUtils.label(atual)}'),
          matching: find.text(r'R$ 5.000,00'),
        ),
        findsOneWidget,
      );

      getIt<SelectedMonthService>().select(proximo);
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.widgetWithText(Row, 'Entra em ${MonthUtils.label(proximo)}'),
          matching: find.text(r'R$ 5.800,00'),
        ),
        findsOneWidget,
      );
    });

    // O seletor continua na tela: sem ele, num mês sem ganho não haveria como
    // ir para outro.
    testWidgets('mês sem ganho explica o que fazer e mantém o seletor', (
      tester,
    ) async {
      stubIncomeList(repository, result: const Success([]));
      await pumpList(tester);

      final month = MonthUtils.label(getIt<SelectedMonthService>().month.value);
      expect(find.text('Nenhum ganho em $month'), findsOneWidget);
      expect(find.byTooltip('Próximo mês'), findsOneWidget);
    });

    testWidgets('trocar o mês no seletor busca os ganhos do novo mês', (
      tester,
    ) async {
      await pumpList(tester);
      final proximo = MonthUtils.next(
        getIt<SelectedMonthService>().month.value,
      );

      await tester.tap(find.byTooltip('Próximo mês'));
      await tester.pumpAndSettle();

      verify(() => repository.list(month: proximo)).called(1);
      expect(
        find.text('Entra em ${MonthUtils.label(proximo)}'),
        findsOneWidget,
      );
    });

    testWidgets('erro de rede oferece tentar de novo', (tester) async {
      stubIncomeList(
        repository,
        result: Error(
          Failure.fromException(const NetworkException(message: 'sem rede')),
        ),
      );
      await pumpList(tester);

      expect(find.text('Tentar de novo'), findsOneWidget);

      stubIncomeList(
        repository,
        result: Success(incomeListJson.map(IncomeModel.fromJson).toList()),
      );
      await tester.tap(find.text('Tentar de novo'));
      await tester.pumpAndSettle();

      expect(find.text('Salário'), findsOneWidget);
    });
  });

  group('detalhe', () {
    testWidgets('abre com o ganho da lista, sem buscar de novo', (
      tester,
    ) async {
      await pumpDetail(tester);

      expect(find.text('Salário'), findsOneWidget);
    });

    testWidgets('ganho aberto oferece as quatro ações', (tester) async {
      await pumpDetail(tester);

      expect(find.text('Reajustar'), findsOneWidget);
      expect(find.text('Corrigir valor'), findsOneWidget);
      expect(find.text('Encerrar'), findsOneWidget);
      expect(find.text('Excluir'), findsOneWidget);
    });

    testWidgets('ganho encerrado só oferece excluir', (tester) async {
      await pumpDetail(tester, income: IncomeModel.fromJson(bonusJson));

      // GAN-08: reajustar, corrigir ou encerrar um ganho encerrado dá 422.
      expect(find.text('Reajustar'), findsNothing);
      expect(find.text('Corrigir valor'), findsNothing);
      expect(find.text('Encerrar'), findsNothing);
      expect(find.text('Excluir'), findsOneWidget);
    });

    testWidgets('sem reajuste, não há histórico para mostrar', (tester) async {
      await pumpDetail(tester);

      expect(find.text('Histórico de valores'), findsNothing);
    });

    testWidgets(
      'histórico lista as vigências, da mais nova para a mais antiga',
      (tester) async {
        await pumpDetail(
          tester,
          income: IncomeModel.fromJson(adjustedSalaryJson),
        );

        expect(find.text('Histórico de valores'), findsOneWidget);
        expect(find.text('Janeiro 2026 a outubro 2026'), findsOneWidget);
        expect(find.text('Desde novembro 2026'), findsOneWidget);
      },
    );

    testWidgets('reajuste manda valor e mês de vigência', (tester) async {
      await pumpDetail(tester);

      await tester.tap(find.text('Reajustar'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '5500');
      await tester.tap(find.widgetWithText(FilledButton, 'Reajustar'));
      await tester.pumpAndSettle();

      verify(
        () => repository.adjust(
          'income-1',
          amountCents: 550000,
          effectiveFrom: MonthUtils.current(),
          month: any(named: 'month'),
        ),
      ).called(1);
      // O diálogo e a tela do detalhe: quem mostra o valor novo é a lista.
      verify(() => nav.pop()).called(2);
    });

    testWidgets('correção manda só o valor, e já vem preenchida', (
      tester,
    ) async {
      await pumpDetail(tester);

      await tester.tap(find.text('Corrigir valor'));
      await tester.pumpAndSettle();

      // Corrigir parte do valor atual — é ele que está errado.
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller?.text, '5.000,00');

      await tester.enterText(find.byType(TextField), '4800');
      await tester.tap(find.widgetWithText(FilledButton, 'Corrigir'));
      await tester.pumpAndSettle();

      verify(
        () => repository.correct(
          'income-1',
          amountCents: 480000,
          month: any(named: 'month'),
        ),
      ).called(1);
      verifyNever(
        () => repository.adjust(
          any(),
          amountCents: any(named: 'amountCents'),
          effectiveFrom: any(named: 'effectiveFrom'),
          month: any(named: 'month'),
        ),
      );
    });

    testWidgets('422 avisa por toast, e o diálogo continua aberto', (
      tester,
    ) async {
      stubIncomeOperations(
        repository,
        result: Error(
          Failure.fromException(
            const UnprocessableEntityException(
              message: 'Reajuste para o mesmo valor já vigente.',
            ),
          ),
        ),
      );
      await pumpDetail(tester);

      await tester.tap(find.text('Reajustar'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '5000');
      await tester.tap(find.widgetWithText(FilledButton, 'Reajustar'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      verifyNever(() => nav.pop());
      expect(find.byType(Flushbar), findsOneWidget);
      expect(
        find.text('Reajuste para o mesmo valor já vigente.'),
        findsOneWidget,
      );

      // O toast some sozinho em 3s; sem esperar, o teste acaba com o timer do
      // Flushbar pendente.
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
    });

    testWidgets('excluir pede confirmação antes de apagar', (tester) async {
      await pumpDetail(tester);

      await tester.tap(find.text('Excluir'));
      await tester.pumpAndSettle();

      verifyNever(() => repository.delete(any()));
      expect(find.textContaining('todo o histórico'), findsWidgets);

      await tester.tap(find.widgetWithText(TextButton, 'Cancelar'));
      await tester.pumpAndSettle();

      verifyNever(() => repository.delete(any()));
    });

    // Quem exclui é o controller da lista: o ganho sai dela, e o `pop` tira a
    // tela do detalhe.
    testWidgets('excluir confirmado apaga e sai da tela', (tester) async {
      await pumpDetail(tester);

      await tester.tap(find.text('Excluir'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Excluir'));
      await tester.pumpAndSettle();

      verify(() => repository.delete('income-1')).called(1);
      verify(() => nav.pop()).called(1);
    });
  });
}
