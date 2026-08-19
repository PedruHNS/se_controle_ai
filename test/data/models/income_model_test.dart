import 'package:flutter_test/flutter_test.dart';
import 'package:se_controle_ai/data/models/income_model.dart';

import '../../fixtures/income_fixture.dart';

void main() {
  group('IncomeModel.fromJson', () {
    test('lê o ganho e a vigência única', () {
      final income = IncomeModel.fromJson(salaryJson);

      expect(income.description, 'Salário');
      expect(income.amountCents, 500000);
      expect(income.startMonth, '2026-01');
      expect(income.endMonth, isNull);
      expect(income.recurring, isTrue);
      expect(income.history, hasLength(1));
    });

    test(
      'history vem na ordem do backend, da mais antiga para a mais nova',
      () {
        final income = IncomeModel.fromJson(adjustedSalaryJson);

        expect(income.history.map((v) => v.validFrom), ['2026-01', '2026-11']);
        expect(income.history.map((v) => v.amountCents), [500000, 550000]);
      },
    );

    test('amountCents é o da vigência aberta, não o da primeira', () {
      final income = IncomeModel.fromJson(adjustedSalaryJson);

      // É o que garante que a lista mostra o valor de hoje, e não o de quando
      // o ganho foi cadastrado.
      expect(income.amountCents, 550000);
      expect(income.currentVersion?.amountCents, 550000);
      expect(income.currentVersion?.validFrom, '2026-11');
    });

    test('ganho de mês único não tem vigência aberta', () {
      final income = IncomeModel.fromJson(bonusJson);

      expect(income.recurring, isFalse);
      expect(income.isClosed, isTrue);
      expect(income.currentVersion, isNull);
      expect(income.history.single.isOpen, isFalse);
      expect(income.history.single.validTo, '2026-12');
    });

    test('hasAdjustments separa quem já foi reajustado de quem não foi', () {
      expect(IncomeModel.fromJson(salaryJson).hasAdjustments, isFalse);
      expect(IncomeModel.fromJson(adjustedSalaryJson).hasAdjustments, isTrue);
    });

    test('isClosed é endMonth preenchido, não recurring falso', () {
      // Um ganho encerrado vira recurring: false (GAN-07), mas o que a tela usa
      // para esconder as ações é o endMonth.
      expect(IncomeModel.fromJson(salaryJson).isClosed, isFalse);
      expect(IncomeModel.fromJson(bonusJson).isClosed, isTrue);
    });
  });

  group('quanto entra em um mês', () {
    test('lê o valor da vigência que cobre o mês, não o mais recente', () {
      final income = IncomeModel.fromJson(adjustedSalaryJson);

      // O `amountCents` do payload é 550000 — o da vigência aberta. Somar ele
      // para maio daria um total diferente do que a home mostra para maio.
      expect(income.amountCents, 550000);
      expect(income.amountCentsIn('2026-05'), 500000);
      expect(income.amountCentsIn('2026-11'), 550000);
    });

    test('mês fora do período não tem valor', () {
      final income = IncomeModel.fromJson(adjustedSalaryJson);

      expect(income.amountCentsIn('2025-12'), isNull);
      expect(income.isActiveIn('2025-12'), isFalse);
      expect(income.isActiveIn('2026-01'), isTrue);
    });

    test('avulso entra só no mês dele', () {
      final income = IncomeModel.fromJson(
        singleMonthIncomeJson(month: '2026-08'),
      );

      expect(income.isActiveIn('2026-07'), isFalse);
      expect(income.isActiveIn('2026-08'), isTrue);
      expect(income.isActiveIn('2026-09'), isFalse);
      expect(income.amountCentsIn('2026-08'), 80000);
    });
  });

  group('acabou ou ainda entra', () {
    test('avulso do mês corrente não está encerrado — ele está entrando', () {
      final income = IncomeModel.fromJson(
        singleMonthIncomeJson(month: '2026-08'),
      );

      // Tem fim marcado, mas o fim não passou.
      expect(income.isClosed, isTrue);
      expect(income.isSingleMonth, isTrue);
      expect(income.endedBefore('2026-08'), isFalse);
      expect(income.endedBefore('2026-09'), isTrue);
    });

    test('ganho em aberto nunca acabou', () {
      final income = IncomeModel.fromJson(salaryJson);

      expect(income.isSingleMonth, isFalse);
      expect(income.endedBefore('2030-01'), isFalse);
    });
  });
}
