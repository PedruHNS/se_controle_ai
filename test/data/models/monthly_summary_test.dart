import 'package:flutter_test/flutter_test.dart';
import 'package:se_controle_ai/data/models/credit_card_invoice_model.dart';
import 'package:se_controle_ai/data/models/month_projection_model.dart';
import 'package:se_controle_ai/data/models/monthly_summary_model.dart';
import 'package:se_controle_ai/data/models/summary_line_item_model.dart';

import '../../fixtures/summary_fixture.dart';

void main() {
  group('MonthlySummaryModel.fromJson', () {
    test('lê os totais do mês', () {
      final summary = MonthlySummaryModel.fromJson(summaryJson);

      expect(summary.month, '2026-08');
      expect(summary.incomeCents, 500000);
      expect(summary.expenseCents, 245590);
      expect(summary.balanceCents, 254410);
      expect(summary.committedPercent, 49.1);
      expect(summary.isNegative, isFalse);
    });

    test('saldo bate com ganho menos gasto', () {
      final summary = MonthlySummaryModel.fromJson(summaryJson);

      expect(summary.balanceCents, summary.incomeCents - summary.expenseCents);
    });

    test('lê ganhos e débito', () {
      final summary = MonthlySummaryModel.fromJson(summaryJson);

      expect(summary.incomes, hasLength(1));
      expect(summary.incomes.first.description, 'Salário');
      expect(summary.incomes.first.installmentLabel, isNull);

      expect(summary.debit.totalCents, 180000);
      expect(summary.debit.items, hasLength(1));
      expect(summary.debit.items.first.description, 'Aluguel');
      expect(summary.debit.isEmpty, isFalse);
    });

    test('lê a fatura do cartão, com a parcela do item parcelado', () {
      final summary = MonthlySummaryModel.fromJson(summaryJson);
      final invoice = summary.creditCards.single;

      expect(invoice.label, 'Nubank ••••4321');
      expect(invoice.dueDate, '2026-08-17');
      expect(invoice.totalCents, 65590);
      expect(invoice.items, hasLength(2));

      // Netflix é fixo: sem rótulo de parcela. Notebook é parcelado: 3/10.
      expect(invoice.items.first.installmentLabel, isNull);
      expect(invoice.items.last.installmentLabel, '3/10');
    });

    test('total da fatura é a soma dos itens', () {
      final invoice = MonthlySummaryModel.fromJson(
        summaryJson,
      ).creditCards.single;
      final sum = invoice.items.fold(0, (acc, item) => acc + item.amountCents);

      expect(invoice.totalCents, sum);
    });

    test('committedPercent nulo quando não há ganho no mês', () {
      final summary = MonthlySummaryModel.fromJson(emptySummaryJson);

      expect(summary.committedPercent, isNull);
      expect(summary.incomes, isEmpty);
      expect(summary.debit.isEmpty, isTrue);
      expect(summary.creditCards, isEmpty);
    });

    test('mês no vermelho', () {
      final summary = MonthlySummaryModel.fromJson(negativeSummaryJson);

      expect(summary.balanceCents, -150000);
      expect(summary.isNegative, isTrue);
    });
  });

  group('CreditCardInvoiceModel.limitUsage', () {
    test('proporção entre fatura e limite', () {
      final invoice = MonthlySummaryModel.fromJson(
        summaryJson,
      ).creditCards.single;

      // 65590 de 800000.
      expect(invoice.limitUsage, closeTo(0.0819, 0.0001));
    });

    test('passa de 1 quando a fatura estoura o limite', () {
      final invoice = MonthlySummaryModel.fromJson(
        negativeSummaryJson,
      ).creditCards.single;

      // 450000 de 400000.
      expect(invoice.limitUsage, closeTo(1.125, 0.0001));
    });

    test('nulo quando o cartão não tem limite cadastrado', () {
      final invoice = CreditCardInvoiceModel.fromJson({
        'cardId': 'c1',
        'name': 'Sem limite',
        'label': 'Sem limite',
        'dueDate': '2026-08-10',
        'limitCents': null,
        'totalCents': 5000,
        'items': <dynamic>[],
      });

      expect(invoice.limitUsage, isNull);
    });

    test('nulo com limite zero, em vez de dividir por zero', () {
      final invoice = CreditCardInvoiceModel.fromJson({
        'cardId': 'c1',
        'name': 'Limite zero',
        'label': 'Limite zero',
        'dueDate': '2026-08-10',
        'limitCents': 0,
        'totalCents': 5000,
        'items': <dynamic>[],
      });

      expect(invoice.limitUsage, isNull);
    });
  });

  group('MonthProjectionModel.fromJson', () {
    test('lê saldo do mês e acumulado', () {
      final projection = MonthProjectionModel.fromJson({
        'month': '2026-09',
        'incomeCents': 500000,
        'expenseCents': 245590,
        'balanceCents': 254410,
        'cumulativeBalanceCents': 508820,
      });

      expect(projection.month, '2026-09');
      expect(projection.balanceCents, 254410);
      expect(projection.cumulativeBalanceCents, 508820);
    });
  });

  group('dia da compra na linha do resumo (GFX-12)', () {
    Map<String, dynamic> linha(Object? spentAt) => <String, dynamic>{
      'id': 'a0843022-eea2-48ef-8c43-2ab4e4f9bc1f',
      'description': 'Notebook',
      'amountCents': 60000,
      'installmentLabel': '3/10',
      'spentAt': spentAt,
      'tag': null,
    };

    // A parcela 3/10 aparece no resumo de agosto, mas a compra é de julho —
    // é essa distância que o dia na linha revela.
    test('gasto traz o dia da compra, já no fuso do aparelho', () {
      final item = SummaryLineItemModel.fromJson(
        linha('2026-07-04T12:00:00.000Z'),
      );

      expect(item.spentAt, '2026-07-04');
    });

    test('ganho não é compra, e chega sem dia', () {
      expect(SummaryLineItemModel.fromJson(linha(null)).spentAt, isNull);
    });

    test('resposta anterior à GFX-12 não tem a chave', () {
      final summary = MonthlySummaryModel.fromJson(summaryJson);

      expect(summary.debit.items.first.spentAt, isNull);
      expect(summary.incomes.first.spentAt, isNull);
    });
  });
}
