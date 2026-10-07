import 'package:flutter_test/flutter_test.dart';
import 'package:se_controle_ai/core/utils/amount_version_utils.dart';
import 'package:se_controle_ai/data/models/amount_version_model.dart';

/// As contas sobre o histórico de vigências, vindas do `IncomeModel` junto com
/// os membros que as respondiam — model não tem nada derivado.
///
/// Os testes montam as vigências direto, em vez de sair de um `fromJson`: o que
/// está sob teste é a conta, e o histórico é a entrada dela inteira. O que era
/// asserção sobre o que o backend devolve ficou no teste do model, onde é
/// contrato e não conta.
AmountVersionModel _version(int cents, String from, [String? to]) =>
    AmountVersionModel(amountCents: cents, validFrom: from, validTo: to);

void main() {
  // 5.000 até outubro, 5.500 de novembro em diante.
  final adjusted = [
    _version(500000, '2026-01', '2026-10'),
    _version(550000, '2026-11'),
  ];

  // Mês único: a vigência abre e fecha na mesma competência.
  final single = [_version(500000, '2026-12', '2026-12')];

  group('amountCentsIn', () {
    test('lê o valor da vigência que cobre o mês, não o mais recente', () {
      // O `amountCents` do payload seria 550000 — o da vigência aberta. Somar
      // ele para maio daria um total diferente do que a home mostra para maio.
      expect(AmountVersionUtils.amountCentsIn(adjusted, '2026-05'), 500000);
      expect(AmountVersionUtils.amountCentsIn(adjusted, '2026-11'), 550000);
    });

    test('as pontas de uma vigência são inclusivas', () {
      expect(AmountVersionUtils.amountCentsIn(adjusted, '2026-01'), 500000);
      expect(AmountVersionUtils.amountCentsIn(adjusted, '2026-10'), 500000);
    });

    test('mês antes do início não tem valor', () {
      expect(AmountVersionUtils.amountCentsIn(adjusted, '2025-12'), isNull);
    });

    test('avulso entra só no mês dele', () {
      expect(AmountVersionUtils.amountCentsIn(single, '2026-11'), isNull);
      expect(AmountVersionUtils.amountCentsIn(single, '2026-12'), 500000);
      expect(AmountVersionUtils.amountCentsIn(single, '2027-01'), isNull);
    });

    test('vigência em aberto vale para qualquer mês dali em diante', () {
      expect(AmountVersionUtils.amountCentsIn(adjusted, '2030-06'), 550000);
    });

    test('histórico vazio não cobre mês nenhum', () {
      expect(AmountVersionUtils.amountCentsIn(const [], '2026-01'), isNull);
    });
  });

  group('openVersion', () {
    test('é a vigência sem fim, a mais nova', () {
      final open = AmountVersionUtils.openVersion(adjusted);

      expect(open?.amountCents, 550000);
      expect(open?.validFrom, '2026-11');
    });

    test('sem reajuste, a única vigência é a aberta', () {
      final open = AmountVersionUtils.openVersion([
        _version(500000, '2026-01'),
      ]);

      expect(open?.validFrom, '2026-01');
    });

    test('ganho de mês único não tem vigência aberta', () {
      expect(AmountVersionUtils.openVersion(single), isNull);
    });

    test('histórico vazio não tem vigência aberta', () {
      expect(AmountVersionUtils.openVersion(const []), isNull);
    });
  });
}
