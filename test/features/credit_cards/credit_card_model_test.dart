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

  group('invoiceMonthFor', () {
    // O bug de 10/09/2026: a compra do dia 12 num cartão que fecha dia 10 ia
    // para a fatura de setembro, que fechou dois dias antes da compra.
    test('depois do fechamento a compra é da fatura seguinte', () {
      final card = CreditCardModel.fromJson(nubankJson); // fecha dia 10

      expect(card.invoiceMonthFor('2026-09-12'), '2026-10');
    });

    test('antes do fechamento a compra é da fatura do mês', () {
      final card = CreditCardModel.fromJson(nubankJson);

      expect(card.invoiceMonthFor('2026-09-09'), '2026-09');
    });

    // A fatura que fecha no dia 10 fecha **com** o dia 10 dentro.
    test('o próprio dia do fechamento ainda entra', () {
      final card = CreditCardModel.fromJson(nubankJson);

      expect(card.invoiceMonthFor('2026-09-10'), '2026-09');
    });

    test('a virada do ano acompanha', () {
      final card = CreditCardModel.fromJson(nubankJson);

      expect(card.invoiceMonthFor('2026-12-28'), '2027-01');
    });

    // Fechamento 31 num mês de 30 dias: nenhum dia passa do fechamento, e a
    // fatura é sempre a do próprio mês. Sem tabela de dias, sem `DateTime`.
    test('fechamento no dia 31 nunca empurra para o mês seguinte', () {
      final card = CreditCardModel.fromJson({...nubankJson, 'closingDay': 31});

      expect(card.invoiceMonthFor('2026-04-30'), '2026-04');
      expect(card.invoiceMonthFor('2026-02-28'), '2026-02');
    });

    test(
      'cada cartão tem o seu dia, e a mesma compra cai em faturas diferentes',
      () {
        final nubank = CreditCardModel.fromJson(nubankJson); // fecha 10
        final outro = CreditCardModel.fromJson(cartaoSimplesJson); // fecha 27

        expect(nubank.invoiceMonthFor('2026-09-12'), '2026-10');
        expect(outro.invoiceMonthFor('2026-09-12'), '2026-09');
      },
    );

    // Um contrato quebrado não pode virar exceção durante o build.
    test('data estranha devolve o que der, sem estourar', () {
      final card = CreditCardModel.fromJson(nubankJson);

      expect(card.invoiceMonthFor('2026-09'), '2026-09');
    });
  });

  // O bug de 10/09/2026, exatamente como aconteceu: cartão "Teste" fecha dia
  // 1, compra lançada no dia 1 de setembro, e a fatura de setembro tinha
  // fechado naquele mesmo dia. A primeira parcela foi parar num mês já
  // encerrado, e a segunda em outubro.
  group('chargeMonthFor', () {
    CreditCardModel cartao(int closingDay) =>
        CreditCardModel.fromJson({...nubankJson, 'closingDay': closingDay});

    test('fatura já fechada empurra para a primeira aberta', () {
      final card = cartao(1);

      expect(
        card.chargeMonthFor('2026-09-01', now: DateTime(2026, 9, 10)),
        '2026-10',
      );
    });

    test('fatura ainda aberta recebe a compra normalmente', () {
      final card = cartao(20);

      // Hoje é dia 10 e a fatura de setembro fecha dia 20: ainda dá tempo.
      expect(
        card.chargeMonthFor('2026-09-01', now: DateTime(2026, 9, 10)),
        '2026-09',
      );
    });

    // O empurrão é só para frente. Uma compra que já pertence a uma fatura
    // futura não é puxada para a aberta.
    test('compra do fim do mês continua na fatura seguinte', () {
      final card = cartao(10);

      expect(
        card.chargeMonthFor('2026-09-28', now: DateTime(2026, 9, 10)),
        '2026-10',
      );
    });

    test('compra atrasada de meses entra na fatura aberta', () {
      final card = cartao(10);

      expect(
        card.chargeMonthFor('2026-05-03', now: DateTime(2026, 9, 10)),
        '2026-09',
      );
    });

    test('a compra de hoje entra na fatura aberta de hoje', () {
      final card = cartao(10);

      expect(
        card.chargeMonthFor('2026-09-10', now: DateTime(2026, 9, 10)),
        '2026-09',
      );
      expect(
        card.chargeMonthFor('2026-09-11', now: DateTime(2026, 9, 11)),
        '2026-10',
      );
    });
  });

  group('openInvoiceMonth', () {
    test('depois do fechamento a fatura aberta já é a do mês que vem', () {
      final card = CreditCardModel.fromJson({...nubankJson, 'closingDay': 1});

      expect(card.openInvoiceMonth(DateTime(2026, 9, 10)), '2026-10');
      expect(card.openInvoiceMonth(DateTime(2026, 9, 1)), '2026-09');
    });
  });
}
