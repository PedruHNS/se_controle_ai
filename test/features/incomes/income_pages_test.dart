import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:multiple_result/multiple_result.dart';
import 'package:se_controle_ai/core/di/injector.dart';
import 'package:se_controle_ai/core/errors/app_exception.dart';
import 'package:se_controle_ai/data/services/selected_month_service.dart';
import 'package:se_controle_ai/core/errors/failure.dart';
import 'package:se_controle_ai/core/utils/month.dart';
import 'package:se_controle_ai/data/models/income_model.dart';
import 'package:se_controle_ai/features/incomes/view/income_detail_page.dart';
import 'package:se_controle_ai/features/incomes/view/income_list_page.dart';

import '../../fixtures/income_fixture.dart';
import '../../fixtures/mocks.dart';
import '../../fixtures/test_injector.dart';

void main() {
  late MockIncomeRepository repository;

  setUp(() {
    repository = setupIncomeTestInjector();
  });

  Future<void> pumpList(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: IncomeListPage()));
    await tester.pumpAndSettle();
  }

  Future<void> pumpDetail(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: IncomeDetailPage(id: 'income-1')),
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
          of: find.widgetWithText(ListTile, 'Entra em ${Month.label(month)}'),
          matching: find.text(r'R$ 5.800,00'),
        ),
        findsOneWidget,
      );
      // E a parte que se repete fica explícita, para os dois não se confundirem.
      expect(
        find.descendant(
          of: find.widgetWithText(ListTile, 'Recorrente por mês'),
          matching: find.text(r'R$ 5.000,00'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('ganho que acabou em mês passado é marcado como encerrado', (
      tester,
    ) async {
      final past = Month.previous(Month.current());
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
            ListTile,
            'Entra em ${Month.label(SelectedMonthService.initial())}',
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
      final proximo = Month.next(atual);
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
          of: find.widgetWithText(ListTile, 'Entra em ${Month.label(atual)}'),
          matching: find.text(r'R$ 5.000,00'),
        ),
        findsOneWidget,
      );

      getIt<SelectedMonthService>().select(proximo);
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.widgetWithText(ListTile, 'Entra em ${Month.label(proximo)}'),
          matching: find.text(r'R$ 5.800,00'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('sem avulso no mês, o total aparece sozinho', (tester) async {
      stubIncomeList(
        repository,
        result: Success([IncomeModel.fromJson(salaryJson)]),
      );
      await pumpList(tester);

      expect(find.text('Recorrente por mês'), findsNothing);
    });

    testWidgets('lista vazia explica o que fazer', (tester) async {
      stubIncomeList(repository, result: const Success([]));
      await pumpList(tester);

      expect(find.text('Nenhum ganho cadastrado'), findsOneWidget);
      expect(find.textContaining('Entra em'), findsNothing);
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
    testWidgets('ganho aberto oferece as quatro ações', (tester) async {
      await pumpDetail(tester);

      expect(find.text('Reajustar'), findsOneWidget);
      expect(find.text('Corrigir valor'), findsOneWidget);
      expect(find.text('Encerrar'), findsOneWidget);
      expect(find.text('Excluir'), findsOneWidget);
    });

    testWidgets('ganho encerrado só oferece excluir', (tester) async {
      stubIncomeDetail(
        repository,
        result: Success(IncomeModel.fromJson(bonusJson)),
      );
      await pumpDetail(tester);

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
        stubIncomeDetail(
          repository,
          result: Success(IncomeModel.fromJson(adjustedSalaryJson)),
        );
        await pumpDetail(tester);

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
          effectiveFrom: Month.current(),
        ),
      ).called(1);
      expect(find.byType(AlertDialog), findsNothing);
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
        () => repository.correct('income-1', amountCents: 480000),
      ).called(1);
      verifyNever(
        () => repository.adjust(
          any(),
          amountCents: any(named: 'amountCents'),
          effectiveFrom: any(named: 'effectiveFrom'),
        ),
      );
    });

    testWidgets('422 aparece dentro do diálogo, que continua aberto', (
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
      expect(
        find.text('Reajuste para o mesmo valor já vigente.'),
        findsOneWidget,
      );
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
  });
}
