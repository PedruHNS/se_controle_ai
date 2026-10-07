import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:se_controle_ai/core/utils/money_utils.dart';
import 'package:se_controle_ai/data/models/expense_model.dart';
import 'package:se_controle_ai/features/expenses/widgets/expense_tile.dart';

import '../../fixtures/expense_fixture.dart';

/// O tile responde duas perguntas sobre o gasto na competência exibida: quanto
/// ele cobra e se ainda é cobrado. As duas contas viviam no `ExpenseModel`, e
/// saíram dele (`.claude/rules/models.md`) — o `ExpenseUtils` guarda a do valor,
/// e a do selo é do tile.
void main() {
  final aluguel = ExpenseModel.fromJson(aluguelJson);
  final presente = ExpenseModel.fromJson(presenteJson);
  final geladeira = ExpenseModel.fromJson(geladeiraJson);

  Future<void> pumpTile(
    WidgetTester tester,
    ExpenseModel expense,
    String month,
  ) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ExpenseTile(expense: expense, monthSelected: month),
      ),
    ),
  );

  group('selo', () {
    testWidgets('parcelado mostra a parcela do mês', (tester) async {
      await pumpTile(tester, geladeira, '2026-03');

      expect(find.text('3/10'), findsOneWidget);
      expect(find.text('Encerrado'), findsNothing);
      expect(find.text('Mês único'), findsNothing);
    });

    // "Encerrado" e "não é mais cobrado" são perguntas diferentes: em agosto o
    // presente de agosto ainda sai, mesmo com `endMonth` preenchido.
    testWidgets('avulso no mês dele não está encerrado', (tester) async {
      await pumpTile(tester, presente, '2026-08');

      expect(find.text('Mês único'), findsOneWidget);
      expect(find.text('Encerrado'), findsNothing);
    });

    testWidgets('avulso depois do mês dele está encerrado', (tester) async {
      await pumpTile(tester, presente, '2026-09');

      expect(find.text('Encerrado'), findsOneWidget);
      expect(find.text('Mês único'), findsNothing);
    });
  });

  group('valor', () {
    // O critério da fase: o reajuste de julho não reescreveu junho.
    testWidgets('mostra o valor da vigência do mês exibido', (tester) async {
      await pumpTile(tester, aluguel, '2026-06');
      expect(find.text(MoneyUtils.format(120000)), findsOneWidget);

      await pumpTile(tester, aluguel, '2026-07');
      expect(find.text(MoneyUtils.format(135000)), findsOneWidget);
    });

    testWidgets('parcelado mostra o valor da parcela do mês', (tester) async {
      await pumpTile(tester, geladeira, '2026-03');

      expect(find.text(MoneyUtils.format(30000)), findsOneWidget);
    });

    // Onde `amountCentsIn` não tem resposta, a lista mostra o último valor em
    // vez de zero.
    testWidgets('fora do período, cai no último valor que teve', (
      tester,
    ) async {
      await pumpTile(tester, presente, '2026-09');

      expect(find.text(MoneyUtils.format(18000)), findsOneWidget);
    });
  });

  group('ícone', () {
    testWidgets('parcelado', (tester) async {
      await pumpTile(tester, geladeira, '2026-03');

      expect(find.byIcon(Icons.view_week_outlined), findsOneWidget);
    });

    testWidgets('no cartão', (tester) async {
      await pumpTile(tester, presente, '2026-08');

      expect(find.byIcon(Icons.credit_card), findsOneWidget);
    });

    testWidgets('no débito', (tester) async {
      await pumpTile(tester, aluguel, '2026-07');

      expect(find.byIcon(Icons.payments_outlined), findsOneWidget);
    });
  });
}
