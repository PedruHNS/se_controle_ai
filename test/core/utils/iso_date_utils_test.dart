import 'package:flutter_test/flutter_test.dart';
import 'package:se_controle_ai/core/utils/iso_date_utils.dart';

void main() {
  group('label', () {
    test('corta dia e mês da data ISO', () {
      expect(IsoDateUtils.label('2026-08-17'), '17/08');
    });

    test('preserva o zero à esquerda do dia e do mês', () {
      expect(IsoDateUtils.label('2026-01-05'), '05/01');
    });

    test('último dia do mês, que é o ajuste do CAR-04', () {
      expect(IsoDateUtils.label('2026-02-28'), '28/02');
    });

    // Um contrato quebrado no backend não pode virar exceção durante o build.
    test('devolve intacto o que não tem tamanho de data ISO', () {
      expect(IsoDateUtils.label('2026-08'), '2026-08');
      expect(IsoDateUtils.label(''), '');
    });
  });

  group('fromInstant', () {
    // Meio-dia em UTC é o que o backend grava quando a pessoa escolhe só o
    // dia. Nenhum fuso do mundo real move meio-dia para outra data, então
    // este é o caso que vale em qualquer máquina que rode o teste.
    test('instante ao meio-dia em UTC devolve o mesmo dia', () {
      expect(
        IsoDateUtils.fromInstant('2026-08-17T12:00:00.000Z'),
        '2026-08-17',
      );
    });

    // A expectativa sai de `toLocal()` para o teste valer em qualquer fuso em
    // que a suíte rode.
    test('converte o instante para o dia do fuso do aparelho', () {
      const instant = '2026-08-17T23:30:00.000Z';
      final local = DateTime.parse(instant).toLocal();
      final esperado =
          '${local.year.toString().padLeft(4, '0')}-'
          '${local.month.toString().padLeft(2, '0')}-'
          '${local.day.toString().padLeft(2, '0')}';

      expect(IsoDateUtils.fromInstant(instant), esperado);

      // Em qualquer fuso atrás de Greenwich — o do Brasil inclusive — 23h30
      // em UTC ainda é dia 17. É exatamente aqui que o corte de string erraria
      // por um dia, e é isto que a conversão existe para evitar.
      if (local.timeZoneOffset.isNegative) {
        expect(IsoDateUtils.fromInstant(instant), '2026-08-17');
      }
    });

    test('aceita data sem hora, tratada como dia local', () {
      expect(IsoDateUtils.fromInstant('2026-08-17'), '2026-08-17');
    });

    test('ganho não tem dia de compra, e nulo entra e sai nulo', () {
      expect(IsoDateUtils.fromInstant(null), isNull);
    });

    test('devolve nulo no que não é instante, em vez de estourar', () {
      expect(IsoDateUtils.fromInstant('ontem'), isNull);
      expect(IsoDateUtils.fromInstant(''), isNull);
    });
  });

  group('fullLabel', () {
    test('inclui o ano', () {
      expect(IsoDateUtils.fullLabel('2026-08-17'), '17/08/2026');
    });

    test('devolve intacto o que não tem tamanho de data ISO', () {
      expect(IsoDateUtils.fullLabel('17/08'), '17/08');
    });
  });

  group('isFuture', () {
    // O calendário do gasto aceita o futuro desde que o dia virou o único
    // campo de tempo do formulário. Quem escreve "Compra em" numa data que
    // não chegou está afirmando o que não aconteceu.
    test('amanhã é futuro, hoje não é', () {
      final hoje = DateTime.now();
      final amanha = hoje.add(const Duration(days: 1));

      String iso(DateTime d) =>
          '${d.year.toString().padLeft(4, '0')}-'
          '${d.month.toString().padLeft(2, '0')}-'
          '${d.day.toString().padLeft(2, '0')}';

      expect(IsoDateUtils.isFuture(iso(amanha)), isTrue);
      expect(IsoDateUtils.isFuture(iso(hoje)), isFalse);
      expect(
        IsoDateUtils.isFuture(iso(hoje.subtract(const Duration(days: 1)))),
        isFalse,
      );
    });

    test('lixo não é futuro, e não estoura', () {
      expect(IsoDateUtils.isFuture('ontem'), isFalse);
      expect(IsoDateUtils.isFuture(''), isFalse);
      expect(IsoDateUtils.isFuture('2026-09'), isFalse);
    });
  });
}
