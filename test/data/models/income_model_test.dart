import 'package:flutter_test/flutter_test.dart';
import 'package:se_controle_ai/data/models/amount_version_model.dart';
import 'package:se_controle_ai/data/models/income_model.dart';

import '../../fixtures/income_fixture.dart';

/// O contrato do `IncomeModel`: o que ele lê do JSON e como se mostra num log.
///
/// As perguntas que viviam aqui — quanto entra em um mês, qual vigência está
/// aberta, se o ganho já acabou — saíram do model junto com os membros que as
/// respondiam (`.claude/rules/models.md`). O valor de um mês e a vigência
/// aberta estão no teste do `AmountVersionUtils`; o selo "Encerrado" e o
/// "Mês único" estão nos testes de tela dos ganhos.
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
      expect(income.history.last.amountCents, 550000);
      expect(income.history.last.validFrom, '2026-11');
      expect(income.history.last.validTo, isNull);
    });

    test('ganho de mês único chega com fim marcado e sem vigência aberta', () {
      final income = IncomeModel.fromJson(bonusJson);

      expect(income.recurring, isFalse);
      expect(income.endMonth, '2026-12');
      expect(income.history.single.validTo, '2026-12');
    });
  });

  group('toString', () {
    // Sem ele, um teste que falha imprime `Instance of 'IncomeModel'`.
    test('mostra o ganho e o histórico inteiro', () {
      final income = IncomeModel.fromJson(adjustedSalaryJson);

      expect(
        income.toString(),
        'IncomeModel(id: b1a7c0de-0000-4000-8000-000000000001, '
        'description: Salário, tag: null, recurring: true, '
        'startMonth: 2026-01, endMonth: null, amountCents: 550000, '
        'history: [AmountVersionModel(amountCents: 500000, '
        'validFrom: 2026-01, validTo: 2026-10), '
        'AmountVersionModel(amountCents: 550000, validFrom: 2026-11, '
        'validTo: null)])',
      );
    });
  });

  group('AmountVersionModel', () {
    test('lê a vigência e mostra os três campos no toString', () {
      final version = AmountVersionModel.fromJson(const {
        'amountCents': 500000,
        'validFrom': '2026-01',
        'validTo': null,
      });

      expect(version.amountCents, 500000);
      expect(version.validFrom, '2026-01');
      expect(version.validTo, isNull);
      expect(
        version.toString(),
        'AmountVersionModel(amountCents: 500000, validFrom: 2026-01, '
        'validTo: null)',
      );
    });
  });
}
