import 'package:flutter_test/flutter_test.dart';
import 'package:se_controle_ai/core/utils/money.dart';

void main() {
  group('Money.format', () {
    test('centavos viram reais com duas casas', () {
      expect(Money.format(0), 'R\$ 0,00');
      expect(Money.format(5), 'R\$ 0,05');
      expect(Money.format(99), 'R\$ 0,99');
      expect(Money.format(100), 'R\$ 1,00');
      expect(Money.format(4550), 'R\$ 45,50');
    });

    test('agrupa milhar com ponto', () {
      expect(Money.format(100000), 'R\$ 1.000,00');
      expect(Money.format(180000), 'R\$ 1.800,00');
      expect(Money.format(123456789), 'R\$ 1.234.567,89');
      expect(Money.format(100000000000), 'R\$ 1.000.000.000,00');
    });

    test('negativo leva o sinal antes do símbolo', () {
      expect(Money.format(-4550), '-R\$ 45,50');
      expect(Money.format(-1), '-R\$ 0,01');
    });

    test('sem símbolo devolve só o número', () {
      expect(Money.format(180000, showSymbol: false), '1.800,00');
      expect(Money.format(-4550, showSymbol: false), '-45,50');
    });

    test(
      'teto do INTEGER do Postgres, que é o máximo que o backend aceita',
      () {
        expect(Money.format(2147483647), 'R\$ 21.474.836,47');
      },
    );
  });

  group('Money.formatSigned', () {
    test('positivo ganha +, negativo mantém -, zero fica neutro', () {
      expect(Money.formatSigned(100), '+R\$ 1,00');
      expect(Money.formatSigned(-100), '-R\$ 1,00');
      expect(Money.formatSigned(0), 'R\$ 0,00');
    });
  });

  group('Money.formatCompact', () {
    test('descarta os centavos', () {
      expect(Money.formatCompact(180000), 'R\$ 1.800');
      expect(Money.formatCompact(180099), 'R\$ 1.800');
      expect(Money.formatCompact(-180000), '-R\$ 1.800');
      expect(Money.formatCompact(180000, showSymbol: false), '1.800');
    });
  });

  group('conversão com double', () {
    test('toReais divide por cem', () {
      expect(Money.toReais(4550), 45.5);
      expect(Money.toReais(0), 0.0);
    });

    test('fromReais arredonda em vez de truncar', () {
      expect(Money.fromReais(45.5), 4550);
      // 8.7 * 100 dá 869.9999999999999; truncar devolveria 869.
      expect(Money.fromReais(8.7), 870);
      // 0.1 + 0.2 dá 0.30000000000000004.
      expect(Money.fromReais(0.1 + 0.2), 30);
    });

    test('arredondar não salva valor que nem existe em binário', () {
      // 0.145 chega como 0.1449999..., então o resultado correto para ESTE
      // double é 14. É a razão de a entrada do usuário usar tryParse, que lê os
      // dígitos do texto e não passa por double.
      expect(Money.fromReais(0.145), 14);
      expect(Money.tryParse('0,145'), 14);
    });
  });

  group('Money.tryParse', () {
    test('aceita o valor já formatado', () {
      expect(Money.tryParse('R\$ 1.800,00'), 180000);
      expect(Money.tryParse('R\$ 45,50'), 4550);
    });

    test('aceita o que o usuário digita sem formatação', () {
      expect(Money.tryParse('1800,50'), 180050);
      expect(Money.tryParse('1800'), 180000);
      expect(Money.tryParse('45,5'), 4550);
      expect(Money.tryParse(',50'), 50);
    });

    test('ponto é milhar, não decimal — 1.800 são mil e oitocentos', () {
      expect(Money.tryParse('1.800'), 180000);
      expect(Money.tryParse('1.234.567,89'), 123456789);
    });

    test('negativo', () {
      expect(Money.tryParse('-45,50'), -4550);
      expect(Money.tryParse('-R\$ 45,50'), -4550);
    });

    test('trunca além de dois decimais em vez de arredondar', () {
      // Arredondar '10,999' para 11,00 criaria um centavo que o usuário
      // não digitou.
      expect(Money.tryParse('10,999'), 1099);
    });

    test('sem dígito nenhum devolve null', () {
      expect(Money.tryParse(''), isNull);
      expect(Money.tryParse('   '), isNull);
      expect(Money.tryParse('abc'), isNull);
      expect(Money.tryParse('R\$ '), isNull);
    });

    test('formatar e reinterpretar não muda o valor', () {
      for (final cents in [0, 1, 99, 100, 4550, 180000, 123456789, -4550]) {
        expect(
          Money.tryParse(Money.format(cents)),
          cents,
          reason: 'falhou no round-trip de $cents',
        );
      }
    });
  });
}
