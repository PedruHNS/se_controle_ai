import 'package:flutter_test/flutter_test.dart';
import 'package:se_controle_ai/core/utils/iso_date.dart';

void main() {
  group('label', () {
    test('corta dia e mês da data ISO', () {
      expect(IsoDate.label('2026-08-17'), '17/08');
    });

    test('preserva o zero à esquerda do dia e do mês', () {
      expect(IsoDate.label('2026-01-05'), '05/01');
    });

    test('último dia do mês, que é o ajuste do CAR-04', () {
      expect(IsoDate.label('2026-02-28'), '28/02');
    });

    // Um contrato quebrado no backend não pode virar exceção durante o build.
    test('devolve intacto o que não tem tamanho de data ISO', () {
      expect(IsoDate.label('2026-08'), '2026-08');
      expect(IsoDate.label(''), '');
    });
  });

  group('fullLabel', () {
    test('inclui o ano', () {
      expect(IsoDate.fullLabel('2026-08-17'), '17/08/2026');
    });

    test('devolve intacto o que não tem tamanho de data ISO', () {
      expect(IsoDate.fullLabel('17/08'), '17/08');
    });
  });
}
