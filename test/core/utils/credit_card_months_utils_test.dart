import 'package:flutter_test/flutter_test.dart';
import 'package:se_controle_ai/core/utils/credit_card_months_utils.dart';

/// As contas de competência do cartão, vindas do `CreditCardModel` em
/// 13/09/2026 junto com elas — model não tem nada derivado.
///
/// Os testes passaram a montar os dias direto, em vez de sair de um
/// `fromJson`: o que está sob teste é a conta, e o fechamento e o vencimento
/// são a entrada dela inteira. O que era asserção sobre o `dueDate` que o
/// backend devolve ficou no teste do model, onde é contrato e não conta.
void main() {
  group('closesInPreviousMonth', () {
    // CAR-03, revista em 12/09/2026: a fatura leva o nome do mês em que é paga.
    // Isto diz se ela fechou no mês anterior ao do próprio nome — é o que a
    // tela de cadastro de cartão explica enquanto a pessoa escolhe os dias.
    test('vencimento depois do fechamento: fecha e vence no mesmo mês', () {
      expect(
        CreditCardMonthsUtils.closesInPreviousMonth(closingDay: 10, dueDay: 17),
        isFalse,
      );
    });

    test('vencimento antes do fechamento: cobra o mês anterior', () {
      expect(
        CreditCardMonthsUtils.closesInPreviousMonth(closingDay: 27, dueDay: 5),
        isTrue,
      );
    });

    test('dias iguais também cobram o mês anterior', () {
      expect(
        CreditCardMonthsUtils.closesInPreviousMonth(closingDay: 10, dueDay: 10),
        isTrue,
      );
    });
  });

  group('closingMonthFor', () {
    // A primeira das duas contas: em qual fatura a compra entra, pelo
    // fechamento, sem ainda dizer quando ela é paga.
    test('o próprio dia do fechamento ainda entra', () {
      expect(
        CreditCardMonthsUtils.closingMonthFor('2026-09-10', closingDay: 10),
        '2026-09',
      );
      expect(
        CreditCardMonthsUtils.closingMonthFor('2026-09-11', closingDay: 10),
        '2026-10',
      );
    });

    // Fechamento 31 num mês de 30 dias: nenhum dia passa do fechamento, e a
    // fatura é sempre a que fecha no próprio mês. Sem tabela de dias, sem
    // `DateTime`.
    test('fechamento no dia 31 nunca empurra para o mês seguinte', () {
      expect(
        CreditCardMonthsUtils.closingMonthFor('2026-04-30', closingDay: 31),
        '2026-04',
      );
      expect(
        CreditCardMonthsUtils.closingMonthFor('2026-02-28', closingDay: 31),
        '2026-02',
      );
    });
  });

  group('invoiceMonthFor', () {
    // A competência: o mês em que a fatura da compra é **paga**. São as duas
    // contas em sequência — fechamento, depois vencimento.

    // O bug de 10/09/2026: a compra do dia 12 num cartão que fecha dia 10 ia
    // para a fatura de setembro, que fechou dois dias antes da compra.
    test('depois do fechamento a compra é da fatura seguinte', () {
      expect(
        CreditCardMonthsUtils.invoiceMonthFor(
          '2026-09-12',
          closingDay: 10,
          dueDay: 17,
        ),
        '2026-10',
      );
    });

    test('antes do fechamento a compra é da fatura do mês', () {
      expect(
        CreditCardMonthsUtils.invoiceMonthFor(
          '2026-09-09',
          closingDay: 10,
          dueDay: 17,
        ),
        '2026-09',
      );
    });

    test('a virada do ano acompanha', () {
      expect(
        CreditCardMonthsUtils.invoiceMonthFor(
          '2026-12-28',
          closingDay: 10,
          dueDay: 17,
        ),
        '2027-01',
      );
    });

    // O bug de 12/09/2026, que é o motivo desta segunda conta existir. Inter:
    // fecha 31, vence 5. A compra do dia 12 entra na fatura que fecha em 30/09
    // — e essa fatura é paga em 05/10. Antes ela virava competência de
    // setembro, o mês da fatura que a pessoa já tinha pagado.
    test(
      'quando a fatura vence depois de fechar, a competência anda junto',
      () {
        expect(
          CreditCardMonthsUtils.closingMonthFor('2026-09-12', closingDay: 31),
          '2026-09',
        );
        expect(
          CreditCardMonthsUtils.invoiceMonthFor(
            '2026-09-12',
            closingDay: 31,
            dueDay: 5,
          ),
          '2026-10',
        );
      },
    );

    test(
      'o dia do fechamento ainda entra, e a competência é a do pagamento',
      () {
        // Dia 30 num mês de 30 dias é o próprio fechamento (CAR-04).
        expect(
          CreditCardMonthsUtils.invoiceMonthFor(
            '2026-09-30',
            closingDay: 31,
            dueDay: 5,
          ),
          '2026-10',
        );
        expect(
          CreditCardMonthsUtils.invoiceMonthFor(
            '2026-10-01',
            closingDay: 31,
            dueDay: 5,
          ),
          '2026-11',
        );
      },
    );

    test(
      'cada cartão tem o seu dia, e a mesma compra cai em faturas diferentes',
      () {
        // O mesmo mês nos dois, por caminhos opostos: no primeiro a compra
        // passou do fechamento e foi para a fatura seguinte; no segundo ela
        // coube na fatura que fecha em 27/09, que é paga em outubro.
        expect(
          CreditCardMonthsUtils.invoiceMonthFor(
            '2026-09-12',
            closingDay: 10,
            dueDay: 17,
          ),
          '2026-10',
        );
        expect(
          CreditCardMonthsUtils.invoiceMonthFor(
            '2026-09-12',
            closingDay: 27,
            dueDay: 5,
          ),
          '2026-10',
        );
      },
    );

    // Um contrato quebrado não pode virar exceção durante o build.
    test('data estranha devolve o que der, sem estourar', () {
      expect(
        CreditCardMonthsUtils.invoiceMonthFor(
          '2026-09',
          closingDay: 10,
          dueDay: 17,
        ),
        '2026-09',
      );
    });
  });

  // O bug de 10/09/2026, exatamente como aconteceu: cartão "Teste" fecha dia
  // 1, compra lançada no dia 1 de setembro, e a fatura de setembro tinha
  // fechado naquele mesmo dia. A primeira parcela foi parar num mês já
  // encerrado, e a segunda em outubro.
  group('chargeMonthFor', () {
    /// Vencimento cinco dias depois do fechamento, de propósito: assim a fatura
    /// é paga no mês em que fecha, a segunda conta do [CreditCardMonths
    /// .invoiceMonthFor] não desloca nada, e o que sobra sendo testado aqui é
    /// só o empurrão da fatura fechada. O cartão deslocado tem teste próprio no
    /// fim do grupo.
    String cobranca(int closingDay, String isoDate, DateTime now) =>
        CreditCardMonthsUtils.chargeMonthFor(
          isoDate,
          closingDay: closingDay,
          dueDay: closingDay + 5,
          now: now,
        );

    test('fatura já fechada empurra para a primeira aberta', () {
      expect(cobranca(1, '2026-09-01', DateTime(2026, 9, 10)), '2026-10');
    });

    test('fatura ainda aberta recebe a compra normalmente', () {
      // Hoje é dia 10 e a fatura de setembro fecha dia 20: ainda dá tempo.
      expect(cobranca(20, '2026-09-01', DateTime(2026, 9, 10)), '2026-09');
    });

    // O empurrão é só para frente. Uma compra que já pertence a uma fatura
    // futura não é puxada para a aberta.
    test('compra do fim do mês continua na fatura seguinte', () {
      expect(cobranca(10, '2026-09-28', DateTime(2026, 9, 10)), '2026-10');
    });

    test('compra atrasada de meses entra na fatura aberta', () {
      expect(cobranca(10, '2026-05-03', DateTime(2026, 9, 10)), '2026-09');
    });

    // As duas contas juntas: o empurrão acha a fatura aberta pelo fechamento, e
    // a competência dela continua sendo a do pagamento.
    test('num cartão que vence antes de fechar, o empurrão acompanha', () {
      // Compra de maio, lançada em 12/09: a fatura de maio fechou há muito. A
      // aberta é a que fecha em 30/09, e essa é paga em outubro.
      expect(
        CreditCardMonthsUtils.chargeMonthFor(
          '2026-05-03',
          closingDay: 31,
          dueDay: 5,
          now: DateTime(2026, 9, 12),
        ),
        '2026-10',
      );
    });

    test('a compra de hoje entra na fatura aberta de hoje', () {
      expect(cobranca(10, '2026-09-10', DateTime(2026, 9, 10)), '2026-09');
      expect(cobranca(10, '2026-09-11', DateTime(2026, 9, 11)), '2026-10');
    });
  });

  group('openInvoiceMonth', () {
    test('depois do fechamento a fatura aberta já é a do mês que vem', () {
      expect(
        CreditCardMonthsUtils.openInvoiceMonth(
          closingDay: 1,
          dueDay: 17,
          now: DateTime(2026, 9, 10),
        ),
        '2026-10',
      );
      expect(
        CreditCardMonthsUtils.openInvoiceMonth(
          closingDay: 1,
          dueDay: 17,
          now: DateTime(2026, 9, 1),
        ),
        '2026-09',
      );
    });
  });
}
