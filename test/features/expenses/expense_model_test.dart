import 'package:flutter_test/flutter_test.dart';
import 'package:se_controle_ai/data/models/expense_model.dart';

import '../../fixtures/expense_fixture.dart';
import 'package:se_controle_ai/data/enums/payment_method.dart';
import 'package:se_controle_ai/data/enums/expense_type.dart';

void main() {
  group('parse do JSON real', () {
    test('gasto no débito, com categoria e duas vigências', () {
      final expense = ExpenseModel.fromJson(aluguelJson);

      expect(expense.description, 'Aluguel');
      expect(expense.tag.name, 'Moradia');
      expect(expense.type, ExpenseType.fixed);
      expect(expense.paymentMethod, PaymentMethod.debit);
      expect(expense.creditCardId, isNull);
      expect(expense.recurring, isTrue);
      expect(expense.history, hasLength(2));
    });

    test('gasto no cartão sem categoria', () {
      final expense = ExpenseModel.fromJson(youtubeJson);

      expect(expense.tag.name, 'Outros');
      expect(expense.onCreditCard, isTrue);
      expect(expense.creditCardId, isNotNull);
    });

    // O que a lista recebe: sem `?month`, o backend não escolhe uma vigência
    // por conta própria. Ler `amountCents` direto daria null, e é por isso que
    // existe `amountCentsIn`.
    test('sem competência, amountCents vem null', () {
      expect(ExpenseModel.fromJson(aluguelJson).amountCents, isNull);
    });

    test('com competência, amountCents é o daquele mês', () {
      expect(ExpenseModel.fromJson(aluguelEmMarcoJson).amountCents, 120000);
    });

    // GFX-09: em parcelado o dinheiro está nas parcelas, e `history` vem null.
    // O model não pode engasgar com isso — a Fase 5 é que vai ler `installments`.
    test('parcelado chega com history null e vira histórico vazio', () {
      final expense = ExpenseModel.fromJson(geladeiraJson);

      expect(expense.type, ExpenseType.installment);
      expect(expense.isInstallment, isTrue);
      expect(expense.history, isEmpty);
      expect(expense.totalCents, 300000);
      expect(expense.installmentsCount, 10);
      expect(expense.installmentLabel, '3/10');
    });
  });

  group('valor por competência', () {
    final aluguel = ExpenseModel.fromJson(aluguelJson);

    // O critério da fase, no model: o reajuste de julho não reescreveu junho.
    test('cada mês lê a vigência dele', () {
      expect(aluguel.amountCentsIn('2026-01'), 120000);
      expect(aluguel.amountCentsIn('2026-06'), 120000);
      expect(aluguel.amountCentsIn('2026-07'), 135000);
      expect(aluguel.amountCentsIn('2026-12'), 135000);
    });

    test('antes do início não há valor', () {
      expect(aluguel.amountCentsIn('2025-12'), isNull);
      expect(aluguel.isActiveIn('2025-12'), isFalse);
      expect(aluguel.isActiveIn('2026-01'), isTrue);
    });

    test('fora de qualquer vigência, cai para a mais recente', () {
      final presente = ExpenseModel.fromJson(presenteJson);

      expect(presente.amountCentsIn('2026-09'), isNull);
      expect(presente.latestAmountCents, 18000);
    });

    test('a vigência em aberto é a última sem validTo', () {
      expect(aluguel.currentVersion?.validFrom, '2026-07');
      expect(aluguel.currentVersion?.amountCents, 135000);
      expect(aluguel.hasAdjustments, isTrue);
    });

    test('gasto de mês único não tem vigência em aberto', () {
      final presente = ExpenseModel.fromJson(presenteJson);

      expect(presente.currentVersion, isNull);
      expect(presente.hasAdjustments, isFalse);
    });
  });

  group('estado do gasto', () {
    test('avulso nasce fechado e é de mês único', () {
      final presente = ExpenseModel.fromJson(presenteJson);

      expect(presente.recurring, isFalse);
      expect(presente.isClosed, isTrue);
      expect(presente.isSingleMonth, isTrue);
    });

    // "Encerrado" e "não é mais cobrado" são perguntas diferentes: em agosto o
    // presente de agosto ainda sai, mesmo com endMonth preenchido.
    test('endedBefore separa o mês do fim dos meses seguintes', () {
      final presente = ExpenseModel.fromJson(presenteJson);

      expect(presente.endedBefore('2026-08'), isFalse);
      expect(presente.endedBefore('2026-09'), isTrue);
    });

    test('recorrente em aberto não está encerrado', () {
      final aluguel = ExpenseModel.fromJson(aluguelJson);

      expect(aluguel.isClosed, isFalse);
      expect(aluguel.isSingleMonth, isFalse);
      expect(aluguel.endedBefore('2030-01'), isFalse);
    });
  });

  group('forma de pagamento e tipo', () {
    test('as duas formas do backend viram enum', () {
      expect(PaymentMethod.fromWire('DEBIT'), PaymentMethod.debit);
      expect(PaymentMethod.fromWire('CREDIT_CARD'), PaymentMethod.creditCard);
      expect(PaymentMethod.debit.wire, 'DEBIT');
      expect(PaymentMethod.creditCard.wire, 'CREDIT_CARD');
    });

    test('os dois tipos do backend viram enum', () {
      expect(ExpenseType.fromWire('FIXED'), ExpenseType.fixed);
      expect(ExpenseType.fromWire('INSTALLMENT'), ExpenseType.installment);
      expect(ExpenseType.fixed.wire, 'FIXED');
      expect(ExpenseType.installment.wire, 'INSTALLMENT');
    });
  });

  group('dia da compra (GFX-12)', () {
    test('o instante do backend vira o dia no fuso do aparelho', () {
      expect(ExpenseModel.fromJson(aluguelComDiaJson).spentAt, '2026-08-17');
    });

    // O app roda contra o backend que estiver no ar. Enquanto a GFX-12 não
    // subir, a chave não vem — e a tela some com a linha, não quebra.
    test('resposta anterior à GFX-12 chega sem o dia', () {
      expect(ExpenseModel.fromJson(aluguelJson).spentAt, isNull);
    });

    // Duas datas diferentes que é fácil confundir: a compra é do dia 17 de
    // agosto, e o valor sai da competência de janeiro em diante.
    test('o dia da compra não é a competência de início', () {
      final aluguel = ExpenseModel.fromJson(aluguelComDiaJson);

      expect(aluguel.spentAt, '2026-08-17');
      expect(aluguel.startMonth, '2026-01');
    });
  });
}
