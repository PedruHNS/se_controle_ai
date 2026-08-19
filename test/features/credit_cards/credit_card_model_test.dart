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
  });

  group('hasLimit', () {
    test('distingue limite ausente de limite zero', () {
      expect(CreditCardModel.fromJson(nubankJson).hasLimit, isTrue);
      expect(CreditCardModel.fromJson(cartaoSimplesJson).hasLimit, isFalse);
    });
  });

  group('dueInNextMonth', () {
    // CAR-03. Existe para a tela explicar a data enquanto a pessoa escolhe os
    // dias; a data que vale continua sendo o `dueDate` do backend.
    test('vencimento depois do fechamento vence no próprio mês', () {
      final card = CreditCardModel.fromJson(nubankJson); // fecha 10, vence 17

      expect(card.dueInNextMonth, isFalse);
      // E o backend concorda: fatura de agosto vence em agosto.
      expect(card.dueDate, startsWith('2026-08'));
    });

    test('vencimento antes do fechamento vence no mês seguinte', () {
      final card = CreditCardModel.fromJson(
        cartaoSimplesJson,
      ); // fecha 27, vence 5

      expect(card.dueInNextMonth, isTrue);
      // Confirmado contra o Docker: competência de março, vencimento em abril.
      expect(card.dueDate, '2026-04-05');
    });

    test('dias iguais vencem no mês seguinte', () {
      final card = CreditCardModel.fromJson({
        ...cartaoSimplesJson,
        'closingDay': 10,
        'dueDay': 10,
      });

      expect(card.dueInNextMonth, isTrue);
    });
  });
}
