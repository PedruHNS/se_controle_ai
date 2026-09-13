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

  group('closesInPreviousMonth', () {
    // CAR-03, revista em 12/09/2026: a fatura leva o nome do mês em que é paga.
    // Este getter diz se ela fechou no mês anterior ao do próprio nome — é o
    // que a tela de cadastro de cartão explica enquanto a pessoa escolhe os
    // dias.
    test('vencimento depois do fechamento: fecha e vence no mesmo mês', () {
      final card = CreditCardModel.fromJson(nubankJson); // fecha 10, vence 17

      expect(card.closesInPreviousMonth, isFalse);
      // E o backend concorda: a fatura de agosto vence em agosto.
      expect(card.dueDate, startsWith('2026-08'));
    });

    test('vencimento antes do fechamento: cobra o mês anterior', () {
      final card = CreditCardModel.fromJson(
        cartaoSimplesJson,
      ); // fecha 27, vence 5

      expect(card.closesInPreviousMonth, isTrue);
      // O vencimento agora cai na própria competência: fatura de março vence
      // em 05/03, e o que ela cobra são as compras até 27/02.
      expect(card.dueDate, '2026-03-05');
    });

    test('dias iguais também cobram o mês anterior', () {
      final card = CreditCardModel.fromJson({
        ...cartaoSimplesJson,
        'closingDay': 10,
        'dueDay': 10,
      });

      expect(card.closesInPreviousMonth, isTrue);
    });
  });

  group('closingMonthFor', () {
    // A primeira das duas contas: em qual fatura a compra entra, pelo
    // fechamento, sem ainda dizer quando ela é paga.
    test('o próprio dia do fechamento ainda entra', () {
      final card = CreditCardModel.fromJson(nubankJson); // fecha 10

      expect(card.closingMonthFor('2026-09-10'), '2026-09');
      expect(card.closingMonthFor('2026-09-11'), '2026-10');
    });

    // Fechamento 31 num mês de 30 dias: nenhum dia passa do fechamento, e a
    // fatura é sempre a que fecha no próprio mês. Sem tabela de dias, sem
    // `DateTime`.
    test('fechamento no dia 31 nunca empurra para o mês seguinte', () {
      final card = CreditCardModel.fromJson({...nubankJson, 'closingDay': 31});

      expect(card.closingMonthFor('2026-04-30'), '2026-04');
      expect(card.closingMonthFor('2026-02-28'), '2026-02');
    });
  });

  group('invoiceMonthFor', () {
    // A competência: o mês em que a fatura da compra é **paga**. São as duas
    // contas em sequência — fechamento, depois vencimento.

    // O bug de 10/09/2026: a compra do dia 12 num cartão que fecha dia 10 ia
    // para a fatura de setembro, que fechou dois dias antes da compra.
    test('depois do fechamento a compra é da fatura seguinte', () {
      final card = CreditCardModel.fromJson(nubankJson); // fecha 10, vence 17

      expect(card.invoiceMonthFor('2026-09-12'), '2026-10');
    });

    test('antes do fechamento a compra é da fatura do mês', () {
      final card = CreditCardModel.fromJson(nubankJson);

      expect(card.invoiceMonthFor('2026-09-09'), '2026-09');
    });

    test('a virada do ano acompanha', () {
      final card = CreditCardModel.fromJson(nubankJson);

      expect(card.invoiceMonthFor('2026-12-28'), '2027-01');
    });

    // O bug de 12/09/2026, que é o motivo desta segunda conta existir. Inter:
    // fecha 31, vence 5. A compra do dia 12 entra na fatura que fecha em 30/09
    // — e essa fatura é paga em 05/10. Antes ela virava competência de
    // setembro, o mês da fatura que a pessoa já tinha pagado.
    test(
      'quando a fatura vence depois de fechar, a competência anda junto',
      () {
        final inter = CreditCardModel.fromJson({
          ...cartaoSimplesJson,
          'closingDay': 31,
          'dueDay': 5,
        });

        expect(inter.closingMonthFor('2026-09-12'), '2026-09');
        expect(inter.invoiceMonthFor('2026-09-12'), '2026-10');
      },
    );

    test(
      'o dia do fechamento ainda entra, e a competência é a do pagamento',
      () {
        final inter = CreditCardModel.fromJson({
          ...cartaoSimplesJson,
          'closingDay': 31,
          'dueDay': 5,
        });

        // Dia 30 num mês de 30 dias é o próprio fechamento (CAR-04).
        expect(inter.invoiceMonthFor('2026-09-30'), '2026-10');
        expect(inter.invoiceMonthFor('2026-10-01'), '2026-11');
      },
    );

    test(
      'cada cartão tem o seu dia, e a mesma compra cai em faturas diferentes',
      () {
        final nubank = CreditCardModel.fromJson(
          nubankJson,
        ); // fecha 10/vence 17
        final outro = CreditCardModel.fromJson(
          cartaoSimplesJson,
        ); // fecha 27/vence 5

        // O mesmo mês nos dois, por caminhos opostos: no Nubank a compra passou
        // do fechamento e foi para a fatura seguinte; no outro ela coube na
        // fatura que fecha em 27/09, que é paga em outubro.
        expect(nubank.invoiceMonthFor('2026-09-12'), '2026-10');
        expect(outro.invoiceMonthFor('2026-09-12'), '2026-10');
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
    /// Vencimento cinco dias depois do fechamento, de propósito: assim a fatura
    /// é paga no mês em que fecha, a segunda conta do [invoiceMonthFor] não
    /// desloca nada, e o que sobra sendo testado aqui é só o empurrão da fatura
    /// fechada. O cartão deslocado tem teste próprio no fim do grupo.
    CreditCardModel cartao(int closingDay) => CreditCardModel.fromJson({
      ...nubankJson,
      'closingDay': closingDay,
      'dueDay': closingDay + 5,
    });

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

    // As duas contas juntas: o empurrão acha a fatura aberta pelo fechamento, e
    // a competência dela continua sendo a do pagamento.
    test('num cartão que vence antes de fechar, o empurrão acompanha', () {
      final inter = CreditCardModel.fromJson({
        ...nubankJson,
        'closingDay': 31,
        'dueDay': 5,
      });

      // Compra de maio, lançada em 12/09: a fatura de maio fechou há muito. A
      // aberta é a que fecha em 30/09, e essa é paga em outubro.
      expect(
        inter.chargeMonthFor('2026-05-03', now: DateTime(2026, 9, 12)),
        '2026-10',
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
