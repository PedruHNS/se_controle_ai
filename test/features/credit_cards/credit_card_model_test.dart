import 'package:flutter_test/flutter_test.dart';
import 'package:se_controle_ai/data/models/credit_card_model.dart';

import '../../fixtures/credit_card_fixture.dart';

void main() {
  group('fromJson', () {
    test('lê o cartão completo da resposta real', () {
      final card = CreditCardModel.fromJson(nubankJson);

      expect(card.id, '39e95359-97f2-441c-bc26-f68a8821ae5a');
      expect(card.name, 'Nubank');
      expect(card.label, 'Nubank ••••4321');
      expect(card.lastDigits, '4321');
      expect(card.closingDay, 10);
      expect(card.dueDay, 17);
      expect(card.limitCents, 800000);
      expect(card.dueDate, '2026-08-17');
      // CAR-09: o que já foi lançado no cartão na competência.
      expect(card.totalCents, 65590);
    });

    test('lê os dois opcionais como null, e o label cai para o nome', () {
      final card = CreditCardModel.fromJson(cartaoSimplesJson);

      expect(card.lastDigits, isNull);
      expect(card.limitCents, isNull);
      // CAR-06: sem dígitos, o label é o nome puro. Vem derivado do backend.
      expect(card.label, 'Cartão de teste');
      expect(card.label, card.name);
    });

    test('dueDate é null quando a busca vai sem competência', () {
      final card = CreditCardModel.fromJson(semCompetenciaJson);

      expect(card.dueDate, isNull);
      // O dia continua lá: é a regra, não a data.
      expect(card.dueDay, 5);
    });

    // Os dois nascem e morrem juntos: sem `?month` não há fatura para vencer
    // nem para somar. E zero não é null — é fatura limpa num mês consultado.
    test('totalCents acompanha o dueDate, e zero não vira null', () {
      expect(CreditCardModel.fromJson(semCompetenciaJson).totalCents, isNull);
      expect(CreditCardModel.fromJson(cartaoSimplesJson).totalCents, 0);
      expect(CreditCardModel.fromJson(nubankJson).totalCents, 65590);
    });
  });
  // O que era asserção de `dueDate` dentro dos grupos de conta derivada, e que
  // é contrato e não conta: o backend aplica a mesma CAR-03 do
  // `CreditCardMonthsUtils`, e as duas nomeações têm de concordar.
  group('dueDate confere com a regra do app', () {
    test('vencimento depois do fechamento: vence no mês consultado', () {
      final card = CreditCardModel.fromJson(nubankJson); // fecha 10, vence 17

      expect(card.dueDate, startsWith('2026-08'));
    });

    test('vencimento antes do fechamento: vence na própria competência', () {
      final card = CreditCardModel.fromJson(
        cartaoSimplesJson,
      ); // fecha 27, vence 5

      // Desde 12/09/2026 a fatura de março vence em 05/03, e o que ela cobra
      // são as compras até 27/02.
      expect(card.dueDate, '2026-03-05');
    });
  });

  group('toString', () {
    // A regra dos models pede `toString` sempre: é o que aparece quando um
    // teste falha, no lugar de `Instance of 'CreditCardModel'`.
    test('nomeia os campos', () {
      final texto = CreditCardModel.fromJson(nubankJson).toString();

      expect(texto, startsWith('CreditCardModel('));
      expect(texto, contains('name: Nubank'));
      expect(texto, contains('closingDay: 10'));
      expect(texto, contains('dueDay: 17'));
    });
  });
}
