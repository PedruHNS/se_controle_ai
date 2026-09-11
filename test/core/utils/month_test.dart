import 'package:flutter_test/flutter_test.dart';
import 'package:se_controle_ai/core/utils/month.dart';

void main() {
  group('formatação', () {
    test('label em português', () {
      expect(Month.label('2026-08'), 'Agosto 2026');
      expect(Month.label('2026-01'), 'Janeiro 2026');
      expect(Month.label('2026-12'), 'Dezembro 2026');
      expect(Month.label('2026-03'), 'Março 2026');
    });

    test('shortLabel e monthName', () {
      expect(Month.shortLabel('2026-08'), 'AGO/2026');
      expect(Month.monthName('2026-08'), 'Agosto');
    });

    test('entrada inválida devolve a própria string, sem lançar', () {
      // Um build não pode explodir por causa de dado inesperado.
      expect(Month.label('lixo'), 'lixo');
      expect(Month.label('2026-13'), '2026-13');
      expect(Month.label(''), '');
    });
  });

  group('aritmética', () {
    test('avança e recua dentro do ano', () {
      expect(Month.next('2026-08'), '2026-09');
      expect(Month.previous('2026-08'), '2026-07');
    });

    test('vira o ano corretamente', () {
      expect(Month.next('2026-12'), '2027-01');
      expect(Month.previous('2026-01'), '2025-12');
    });

    test('offset de vários meses cruza anos', () {
      expect(Month.offset('2026-08', 5), '2027-01');
      expect(Month.offset('2026-08', 12), '2027-08');
      expect(Month.offset('2026-08', -8), '2025-12');
      expect(Month.offset('2026-08', -20), '2024-12');
      expect(Month.offset('2026-08', 0), '2026-08');
    });

    test('para nos limites que o backend aceita, em vez de gerar 400', () {
      // O zod recusa ano fora de 2000–2100.
      expect(Month.next('2100-12'), '2100-12');
      expect(Month.previous('2000-01'), '2000-01');
      expect(Month.hasNext('2100-12'), isFalse);
      expect(Month.hasPrevious('2000-01'), isFalse);
      expect(Month.hasNext('2026-12'), isTrue);
      expect(Month.hasPrevious('2026-01'), isTrue);
    });
  });

  group('validação', () {
    test('aceita formato e faixa corretos', () {
      expect(Month.isValid('2026-08'), isTrue);
      expect(Month.isValid('2000-01'), isTrue);
      expect(Month.isValid('2100-12'), isTrue);
    });

    test('recusa formato errado', () {
      expect(Month.isValid('2026-8'), isFalse);
      expect(Month.isValid('2026/08'), isFalse);
      expect(Month.isValid('2026-00'), isFalse);
      expect(Month.isValid('2026-13'), isFalse);
      expect(Month.isValid('abcd-ef'), isFalse);
      expect(Month.isValid(''), isFalse);
    });

    test('recusa ano fora da faixa do backend', () {
      expect(Month.isValid('1999-12'), isFalse);
      expect(Month.isValid('9999-12'), isFalse);
    });
  });

  group('comparação e sequência', () {
    test('ordem cronológica bate com ordem de string', () {
      expect(Month.isBefore('2026-01', '2026-02'), isTrue);
      expect(Month.isBefore('2025-12', '2026-01'), isTrue);
      expect(Month.isAfter('2027-01', '2026-12'), isTrue);
      expect(Month.compare('2026-08', '2026-08'), 0);
    });

    test('ordenar lista de competências funciona sem parser', () {
      final months = ['2026-10', '2025-12', '2026-02', '2027-01']..sort();
      expect(months, ['2025-12', '2026-02', '2026-10', '2027-01']);
    });

    test('range gera meses consecutivos', () {
      expect(Month.range('2026-11', 4), [
        '2026-11',
        '2026-12',
        '2027-01',
        '2027-02',
      ]);
      expect(Month.range('2026-01', 0), isEmpty);
    });
  });

  group('mês corrente', () {
    test('current tem formato válido e isCurrent concorda', () {
      final current = Month.current();

      expect(Month.isValid(current), isTrue);
      expect(Month.isCurrent(current), isTrue);
      expect(Month.isCurrent(Month.next(current)), isFalse);
    });

    test('current bate com o relógio do sistema', () {
      final now = DateTime.now();
      expect(Month.current(), Month.of(now.year, now.month));
    });
  });

  test('of preenche zero à esquerda, como o backend exige', () {
    expect(Month.of(2026, 1), '2026-01');
    expect(Month.of(2026, 12), '2026-12');
  });

  group('Month.periodLabel', () {
    test('vigência em aberto', () {
      expect(Month.periodLabel('2026-01', null), 'Desde janeiro 2026');
    });

    test('intervalo fechado põe o segundo mês em minúscula', () {
      // O label capitaliza; no meio da frase isso leria como erro.
      expect(
        Month.periodLabel('2026-01', '2026-10'),
        'Janeiro 2026 a outubro 2026',
      );
    });

    test('mês único não se repete', () {
      expect(Month.periodLabel('2026-12', '2026-12'), 'Dezembro 2026');
    });
  });
}
