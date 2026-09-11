import 'package:flutter_test/flutter_test.dart';
import 'package:se_controle_ai/data/enums/dashboard_scope.dart';
import 'package:se_controle_ai/data/models/dashboard_model.dart';

import '../../fixtures/dashboard_fixture.dart';

/// O contrato de `GET /dashboard` visto do lado do app.
///
/// Os cinco invariantes da spec — DSH-03, DSH-10, DSH-12, DSH-19 e DSH-22 —
/// são somas que precisam bater por caminhos diferentes. Conferi-los aqui não
/// prova que o backend acerta, prova que o **fixture** descreve um payload
/// coerente; no dia em que ele for trocado pelo payload real, é este teste que
/// diz se o backend discordou da spec.
void main() {
  group('DashboardModel.fromJson', () {
    test('lê os oito blocos da resposta', () {
      final dashboard = DashboardModel.fromJson(dashboardJson);

      expect(dashboard.month, '2026-09');
      expect(dashboard.totals.expenseCents, 312400);
      expect(dashboard.allowance.perDayCents, 8933);
      expect(dashboard.byTag, hasLength(4));
      expect(dashboard.daily.days, hasLength(30));
      expect(dashboard.cards, hasLength(2));
      expect(dashboard.byNature.recurringCents, 180000);
      expect(dashboard.history, hasLength(6));
      expect(dashboard.topExpenses, hasLength(5));
    });

    test('totals traz saldo e comprometimento', () {
      final totals = DashboardModel.fromJson(dashboardJson).totals;

      expect(totals.incomeCents, 500000);
      expect(totals.balanceCents, totals.incomeCents - totals.expenseCents);
      expect(totals.committedPercent, 62.5);
    });
  });

  group('invariantes da spec', () {
    late DashboardModel dashboard;

    setUp(() => dashboard = DashboardModel.fromJson(dashboardJson));

    // DSH-10: todo gasto tem exatamente uma tag, então o bloco cobre o mês.
    test('a soma das tags é o gasto do mês', () {
      final soma = dashboard.byTag.fold(0, (t, tag) => t + tag.amountCents);

      expect(soma, dashboard.totals.expenseCents);
    });

    // DSH-12: sem a linha de base, metade do mês some do gráfico.
    test('a linha de base mais a curva é o gasto do mês', () {
      final curva = dashboard.daily.days.fold(
        0,
        (total, day) => total + day.amountCents,
      );

      expect(
        dashboard.daily.baselineCents + curva,
        dashboard.totals.expenseCents,
      );
    });

    // DSH-19: todo gasto cai em exatamente uma natureza.
    test('as três naturezas somam o gasto do mês', () {
      final natureza = dashboard.byNature;

      expect(
        natureza.recurringCents +
            natureza.installmentCents +
            natureza.oneOffCents,
        dashboard.totals.expenseCents,
      );
    });

    // DSH-22: é a barra que o card 6 destaca.
    test('a última entrada do histórico bate com o topo', () {
      final atual = dashboard.history.last;

      expect(atual.month, dashboard.month);
      expect(atual.incomeCents, dashboard.totals.incomeCents);
      expect(atual.expenseCents, dashboard.totals.expenseCents);
      expect(
        atual.incomeCents - atual.expenseCents,
        dashboard.totals.balanceCents,
      );
    });
  });

  group('allowance', () {
    test('o scope vira enum', () {
      expect(
        DashboardModel.fromJson(dashboardJson).allowance.scope,
        DashboardScope.current,
      );
      expect(
        DashboardModel.fromJson(dashboardVazioJson).allowance.scope,
        DashboardScope.future,
      );
      expect(DashboardScope.fromWire('past'), DashboardScope.past);
    });

    // Um `scope` novo no backend não pode derrubar a tela do app instalado.
    test('scope desconhecido cai no mês corrente, sem lançar', () {
      expect(DashboardScope.fromWire('semana'), DashboardScope.current);
    });

    // DSH-07: o mês no vermelho troca a frase do card, não o sinal do número.
    test('mês estourado não tem valor por dia, e sim o quanto passou', () {
      final allowance =
          DashboardModel.fromJson(dashboardEstouradoJson).allowance;

      expect(allowance.perDayCents, isNull);
      expect(allowance.overspentCents, 38000);
    });
  });

  group('byTag', () {
    test('vem do maior para o menor', () {
      final valores = DashboardModel.fromJson(
        dashboardJson,
      ).byTag.map((tag) => tag.amountCents).toList();

      expect(valores, orderedEquals([...valores]..sort((a, b) => b - a)));
    });

    test('a cor vem como texto, para o card traduzir', () {
      final mercado = DashboardModel.fromJson(dashboardJson).byTag.first;

      expect(mercado.name, 'Mercado');
      expect(mercado.color, '#E53935');
    });

    // DSH-10: tag anterior à migration 010 não tem cor, e aí quem escolhe é o
    // app.
    test('tag sem cor chega com o campo nulo', () {
      final lazer = DashboardModel.fromJson(
        dashboardJson,
      ).byTag.firstWhere((tag) => tag.name == 'Lazer');

      expect(lazer.color, isNull);
    });
  });

  group('daily', () {
    test('a série cobre o mês inteiro, em ordem e sem buracos', () {
      final days = DashboardModel.fromJson(dashboardJson).daily.days;

      expect(days.first.day, 1);
      expect(days.last.day, 30);
      expect(
        days.map((d) => d.day),
        orderedEquals(List.generate(30, (i) => i + 1)),
      );
    });

    // DSH-14: dia sem compra aparece zerado, não é omitido.
    test('dia sem compra vem zerado', () {
      final days = DashboardModel.fromJson(dashboardJson).daily.days;

      expect(days[0].amountCents, 0);
      expect(days[1].amountCents, 15990);
    });

    // DSH-15: a curva apagada do fundo, do mês anterior inteiro.
    test('previousDays traz o mês anterior, com os 31 dias de agosto', () {
      final anterior = DashboardModel.fromJson(dashboardJson).daily.previousDays;

      expect(anterior, hasLength(31));
      expect(anterior.first.amountCents, 4500);
    });
  });

  group('cards', () {
    test('cartão com limite traz fatura e limite', () {
      final nubank = DashboardModel.fromJson(dashboardJson).cards.first;

      expect(nubank.label, 'Nubank ••••1234');
      expect(nubank.totalCents, 82400);
      expect(nubank.limitCents, 500000);
    });

    // DSH-16 e DSH-17: o cartão sem gasto aparece, e o sem limite não ganha um
    // trilho inventado.
    test('cartão sem limite e sem fatura aparece, sem trilho', () {
      final inter = DashboardModel.fromJson(dashboardJson).cards.last;

      expect(inter.totalCents, 0);
      expect(inter.limitCents, isNull);
    });
  });

  group('topExpenses', () {
    test('a parcela traz o rótulo que explica o valor', () {
      final geladeira = DashboardModel.fromJson(dashboardJson).topExpenses.first;

      expect(geladeira.description, 'Geladeira');
      expect(geladeira.amountCents, 30000);
      expect(geladeira.installmentLabel, '3/10');
      // DSH-23: o dia é o da compra (GFX-12), não o da cobrança — a geladeira
      // foi comprada em julho e é cobrada em setembro.
      expect(geladeira.spentAt, startsWith('2026-07-10'));
    });

    test('gasto à vista não tem rótulo de parcela', () {
      final mercado = DashboardModel.fromJson(dashboardJson).topExpenses[1];

      expect(mercado.installmentLabel, isNull);
    });
  });

  // DSH-25 e DSH-02: mês vazio é resposta válida, e nenhum bloco falta.
  group('mês sem lançamento', () {
    test('todos os blocos vêm, vazios ou zerados', () {
      final dashboard = DashboardModel.fromJson(dashboardVazioJson);

      expect(dashboard.totals.expenseCents, 0);
      expect(dashboard.totals.committedPercent, isNull);
      expect(dashboard.allowance.perDayCents, isNull);
      expect(dashboard.byTag, isEmpty);
      expect(dashboard.daily.days, isEmpty);
      expect(dashboard.daily.baselineCents, 0);
      expect(dashboard.cards, isEmpty);
      expect(dashboard.byNature.recurringCents, 0);
      expect(dashboard.byNature.oneOffCents, 0);
      expect(dashboard.history, isEmpty);
      expect(dashboard.topExpenses, isEmpty);
    });
  });
}
