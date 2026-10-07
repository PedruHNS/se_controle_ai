import 'package:flutter_test/flutter_test.dart';
import 'package:se_controle_ai/data/models/expense_model.dart';

import '../../fixtures/expense_fixture.dart';
import 'package:se_controle_ai/data/enums/payment_method.dart';
import 'package:se_controle_ai/data/enums/expense_type.dart';

/// O contrato do `ExpenseModel`: o que ele lê do JSON e como se mostra num log.
///
/// As perguntas que viviam aqui — quanto cobra em um mês, qual foi o último
/// valor, que parcela cai nele, qual vigência está aberta — saíram do model
/// junto com os membros que as respondiam (`.claude/rules/models.md`). O valor
/// e a parcela de um mês estão no teste do `ExpenseUtils`, a vigência aberta no
/// do `AmountVersionUtils`, e o selo "Encerrado" no teste do `ExpenseTile`.
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
      expect(expense.paymentMethod, PaymentMethod.creditCard);
      expect(expense.creditCardId, isNotNull);
    });

    // O que a lista recebe: sem `?month`, o backend não escolhe uma vigência
    // por conta própria. Ler `amountCents` direto daria null, e é por isso que
    // existe o `ExpenseUtils.amountCentsIn`.
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
      expect(expense.history, isEmpty);
      expect(expense.totalCents, 300000);
      expect(expense.installmentsCount, 10);
      expect(expense.installmentLabel, '3/10');
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

  // Sem ele, um teste que falha imprime `Instance of 'ExpenseModel'`.
  group('toString', () {
    test('mostra o gasto e as vigências', () {
      final text = ExpenseModel.fromJson(aluguelJson).toString();

      expect(text, startsWith('ExpenseModel(id: '));
      expect(text, contains('description: Aluguel'));
      expect(text, contains('tag: TagModel('));
      expect(text, contains('type: ExpenseType.fixed'));
      expect(text, contains('history: [AmountVersionModel('));
      expect(text, isNot(contains('Instance of')));
    });

    test('mostra as parcelas de um parcelado', () {
      final text = ExpenseModel.fromJson(geladeiraJson).toString();

      expect(text, contains('installments: [InstallmentModel(number: 1'));
      expect(text, contains('total: 10'));
    });
  });

  group('InstallmentModel', () {
    test('lê a parcela e mostra os quatro campos no toString', () {
      final installment = ExpenseModel.fromJson(
        geladeiraJson,
      ).installments.first;

      expect(installment.number, 1);
      expect(installment.total, 10);
      expect(installment.referenceMonth, '2026-01');
      expect(
        installment.toString(),
        'InstallmentModel(number: 1, total: 10, '
        'amountCents: ${installment.amountCents}, referenceMonth: 2026-01)',
      );
    });
  });
}
