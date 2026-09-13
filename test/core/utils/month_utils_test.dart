import 'package:flutter_test/flutter_test.dart';
import 'package:se_controle_ai/core/utils/month_utils.dart';

void main() {
  group('formatação', () {
    test('label em português', () {
      expect(MonthUtils.label('2026-08'), 'Agosto 2026');
      expect(MonthUtils.label('2026-01'), 'Janeiro 2026');
      expect(MonthUtils.label('2026-12'), 'Dezembro 2026');
      expect(MonthUtils.label('2026-03'), 'Março 2026');
    });

    test('shortLabel e monthName', () {
      expect(MonthUtils.shortLabel('2026-08'), 'AGO/2026');
      expect(MonthUtils.monthName('2026-08'), 'Agosto');
    });

    test('entrada inválida devolve a própria string, sem lançar', () {
      // Um build não pode explodir por causa de dado inesperado.
      expect(MonthUtils.label('lixo'), 'lixo');
      expect(MonthUtils.label('2026-13'), '2026-13');
      expect(MonthUtils.label(''), '');
    });
  });

  group('aritmética', () {
    test('avança e recua dentro do ano', () {
      expect(MonthUtils.next('2026-08'), '2026-09');
      expect(MonthUtils.previous('2026-08'), '2026-07');
    });

    test('vira o ano corretamente', () {
      expect(MonthUtils.next('2026-12'), '2027-01');
      expect(MonthUtils.previous('2026-01'), '2025-12');
    });

    test('offset de vários meses cruza anos', () {
      expect(MonthUtils.offset('2026-08', 5), '2027-01');
      expect(MonthUtils.offset('2026-08', 12), '2027-08');
      expect(MonthUtils.offset('2026-08', -8), '2025-12');
      expect(MonthUtils.offset('2026-08', -20), '2024-12');
      expect(MonthUtils.offset('2026-08', 0), '2026-08');
    });

    test('para nos limites que o backend aceita, em vez de gerar 400', () {
      // O zod recusa ano fora de 2000–2100.
      expect(MonthUtils.next('2100-12'), '2100-12');
      expect(MonthUtils.previous('2000-01'), '2000-01');
      expect(MonthUtils.hasNext('2100-12'), isFalse);
      expect(MonthUtils.hasPrevious('2000-01'), isFalse);
      expect(MonthUtils.hasNext('2026-12'), isTrue);
      expect(MonthUtils.hasPrevious('2026-01'), isTrue);
    });
  });

  group('validação', () {
    test('aceita formato e faixa corretos', () {
      expect(MonthUtils.isValid('2026-08'), isTrue);
      expect(MonthUtils.isValid('2000-01'), isTrue);
      expect(MonthUtils.isValid('2100-12'), isTrue);
    });

    test('recusa formato errado', () {
      expect(MonthUtils.isValid('2026-8'), isFalse);
      expect(MonthUtils.isValid('2026/08'), isFalse);
      expect(MonthUtils.isValid('2026-00'), isFalse);
      expect(MonthUtils.isValid('2026-13'), isFalse);
      expect(MonthUtils.isValid('abcd-ef'), isFalse);
      expect(MonthUtils.isValid(''), isFalse);
    });

    test('recusa ano fora da faixa do backend', () {
      expect(MonthUtils.isValid('1999-12'), isFalse);
      expect(MonthUtils.isValid('9999-12'), isFalse);
    });
  });

  group('comparação e sequência', () {
    test('ordem cronológica bate com ordem de string', () {
      expect(MonthUtils.isBefore('2026-01', '2026-02'), isTrue);
      expect(MonthUtils.isBefore('2025-12', '2026-01'), isTrue);
      expect(MonthUtils.isAfter('2027-01', '2026-12'), isTrue);
      expect(MonthUtils.compare('2026-08', '2026-08'), 0);
    });

    test('ordenar lista de competências funciona sem parser', () {
      final months = ['2026-10', '2025-12', '2026-02', '2027-01']..sort();
      expect(months, ['2025-12', '2026-02', '2026-10', '2027-01']);
    });

    test('range gera meses consecutivos', () {
      expect(MonthUtils.range('2026-11', 4), [
        '2026-11',
        '2026-12',
        '2027-01',
        '2027-02',
      ]);
      expect(MonthUtils.range('2026-01', 0), isEmpty);
    });
  });

  group('mês corrente', () {
    test('current tem formato válido e isCurrent concorda', () {
      final current = MonthUtils.current();

      expect(MonthUtils.isValid(current), isTrue);
      expect(MonthUtils.isCurrent(current), isTrue);
      expect(MonthUtils.isCurrent(MonthUtils.next(current)), isFalse);
    });

    test('current bate com o relógio do sistema', () {
      final now = DateTime.now();
      expect(MonthUtils.current(), MonthUtils.of(now.year, now.month));
    });
  });

  test('of preenche zero à esquerda, como o backend exige', () {
    expect(MonthUtils.of(2026, 1), '2026-01');
    expect(MonthUtils.of(2026, 12), '2026-12');
  });

  group('MonthUtils.periodLabel', () {
    test('vigência em aberto', () {
      expect(MonthUtils.periodLabel('2026-01', null), 'Desde janeiro 2026');
    });

    test('intervalo fechado põe o segundo mês em minúscula', () {
      // O label capitaliza; no meio da frase isso leria como erro.
      expect(
        MonthUtils.periodLabel('2026-01', '2026-10'),
        'Janeiro 2026 a outubro 2026',
      );
    });

    test('mês único não se repete', () {
      expect(MonthUtils.periodLabel('2026-12', '2026-12'), 'Dezembro 2026');
    });
  });
}
