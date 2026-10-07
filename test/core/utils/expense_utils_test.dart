import 'package:flutter_test/flutter_test.dart';
import 'package:se_controle_ai/core/utils/expense_utils.dart';
import 'package:se_controle_ai/data/models/expense_model.dart';

import '../../fixtures/expense_fixture.dart';

/// As contas sobre um gasto, vindas do `ExpenseModel` junto com os membros que
/// as respondiam — model não tem nada derivado.
///
/// Os gastos saem do `fromJson` das fixtures, que são respostas reais do
/// backend: a entrada da conta é o gasto inteiro, com as duas listas.
void main() {
  final aluguel = ExpenseModel.fromJson(aluguelJson);
  final presente = ExpenseModel.fromJson(presenteJson);
  final geladeira = ExpenseModel.fromJson(geladeiraJson);
  final reparcelada = ExpenseModel.fromJson(geladeiraReparceladaJson);

  group('amountCentsIn', () {
    // O critério da fase: o reajuste de julho não reescreveu junho.
    test('cada mês lê a vigência dele', () {
      expect(ExpenseUtils.amountCentsIn(aluguel, '2026-01'), 120000);
      expect(ExpenseUtils.amountCentsIn(aluguel, '2026-06'), 120000);
      expect(ExpenseUtils.amountCentsIn(aluguel, '2026-07'), 135000);
      expect(ExpenseUtils.amountCentsIn(aluguel, '2026-12'), 135000);
    });

    test('antes do início não há valor', () {
      expect(ExpenseUtils.amountCentsIn(aluguel, '2025-12'), isNull);
    });

    test('avulso não é cobrado fora do mês dele', () {
      expect(ExpenseUtils.amountCentsIn(presente, '2026-07'), isNull);
      expect(ExpenseUtils.amountCentsIn(presente, '2026-08'), 18000);
      expect(ExpenseUtils.amountCentsIn(presente, '2026-09'), isNull);
    });

    // O valor de um mês vem da parcela daquele mês, e não de vigência — é a
    // outra metade do GFX-09, e quem chama não precisa saber de que tipo é.
    test('em parcelado, o valor do mês sai da parcela', () {
      expect(ExpenseUtils.amountCentsIn(geladeira, '2026-03'), 30000);
      expect(ExpenseUtils.amountCentsIn(geladeira, '2026-11'), isNull);
    });

    // GPR-08 e GPR-10: as quatro primeiras ficaram com o valor antigo, e a
    // numeração continuou em 5.
    test('reparcelada, as antigas ficam e as novas mudam', () {
      expect(ExpenseUtils.amountCentsIn(reparcelada, '2026-04'), 30000);
      expect(ExpenseUtils.amountCentsIn(reparcelada, '2026-05'), 35000);
    });
  });

  group('latestAmountCents', () {
    test('gasto fixo: o valor da última vigência', () {
      expect(ExpenseUtils.latestAmountCents(aluguel), 135000);
    });

    // É o que a lista mostra para o gasto que não é cobrado na competência
    // exibida, onde `amountCentsIn` não tem resposta.
    test('avulso: o único valor que ele teve', () {
      expect(ExpenseUtils.latestAmountCents(presente), 18000);
    });

    test('parcelado: o valor da última parcela', () {
      expect(ExpenseUtils.latestAmountCents(geladeira), 30000);
      expect(ExpenseUtils.latestAmountCents(reparcelada), 35000);
    });

    test('sem vigência nem parcela, cai no amountCents do payload', () {
      final semListas = ExpenseModel.fromJson({
        ...aluguelJson,
        'history': null,
        'amountCents': 777,
      });

      expect(ExpenseUtils.latestAmountCents(semListas), 777);
    });
  });

  group('installmentLabelIn', () {
    test('é a parcela cobrada no mês', () {
      expect(ExpenseUtils.installmentLabelIn(geladeira, '2026-03'), '3/10');
    });

    test('mês sem parcela não tem rótulo', () {
      expect(ExpenseUtils.installmentLabelIn(geladeira, '2026-11'), isNull);
    });

    test('gasto fixo não tem parcela nenhuma', () {
      expect(ExpenseUtils.installmentLabelIn(aluguel, '2026-03'), isNull);
    });

    // GPR-11: é a mesma compra, agora em doze vezes, e o "de N" das antigas
    // acompanha.
    test('reparcelada, o "de N" das antigas passa a ser o novo', () {
      expect(ExpenseUtils.installmentLabelIn(reparcelada, '2026-01'), '1/12');
      expect(ExpenseUtils.installmentLabelIn(reparcelada, '2026-05'), '5/12');
    });
  });

  group('installmentLabel', () {
    test('é o número e o total da parcela', () {
      expect(
        ExpenseUtils.installmentLabel(geladeira.installments.first),
        '1/10',
      );
      expect(
        ExpenseUtils.installmentLabel(reparcelada.installments.last),
        '12/12',
      );
    });
  });
}
