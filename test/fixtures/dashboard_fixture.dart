// Payload de `GET /dashboard?month=2026-09` montado campo a campo a partir do
// exemplo da spec (`expense-tracker-api/docs/specs/09-dashboard.md`), e **não**
// capturado do backend — a rota ainda não foi exercitada com token real.
//
// Vale como contrato mesmo assim: os números foram escolhidos para respeitar os
// cinco invariantes que a spec cobra, e é isso que o teste confere. Quando o
// payload real for capturado, é este arquivo que muda, e o teste diz na hora se
// o backend discordou da spec.

/// Setembro de 2026, um mês normal: R$ 5.000,00 de ganho, R$ 3.124,00 de gasto.
///
/// - `byTag` soma o gasto do mês (DSH-10), e "Lazer" vem **sem cor**, que é a
///   tag anterior à migration `010` (DSH-10).
/// - `daily` tem os 30 dias, com buracos zerados, e a linha de base fecha o
///   DSH-12 com a curva.
/// - `cards` traz o Inter **sem limite e sem fatura**, os dois casos de borda
///   do card 4 (DSH-16 e DSH-17).
/// - `topExpenses` tem parcelado e à vista lado a lado.
final dashboardJson = <String, dynamic>{
  'month': '2026-09',
  'totals': {
    'incomeCents': 500000,
    'expenseCents': 312400,
    'balanceCents': 187600,
    'committedPercent': 62.5,
  },
  // Dia 10 de um mês de 30: 21 dias contando hoje (DSH-05), e
  // 187600 ÷ 21 = 8933,33 arredondado para baixo (DSH-08).
  'allowance': {
    'scope': 'current',
    'daysRemaining': 21,
    'perDayCents': 8933,
    'overspentCents': null,
  },
  'byTag': [
    {'id': 'tag-mercado', 'name': 'Mercado', 'color': '#E53935', 'amountCents': 120000},
    {'id': 'tag-casa', 'name': 'Casa', 'color': '#43A047', 'amountCents': 98000},
    {'id': 'tag-transporte', 'name': 'Transporte', 'color': '#1E88E5', 'amountCents': 54400},
    {'id': 'tag-lazer', 'name': 'Lazer', 'color': null, 'amountCents': 40000},
  ],
  'daily': {
    // Fixos e parcelas de compras antigas: 210000 + 102400 = 312400 (DSH-12).
    'baselineCents': 210000,
    'days': [
      {'day': 1, 'amountCents': 0},
      {'day': 2, 'amountCents': 15990},
      {'day': 3, 'amountCents': 0},
      {'day': 4, 'amountCents': 0},
      {'day': 5, 'amountCents': 24500},
      {'day': 6, 'amountCents': 0},
      {'day': 7, 'amountCents': 0},
      {'day': 8, 'amountCents': 0},
      {'day': 9, 'amountCents': 8900},
      {'day': 10, 'amountCents': 0},
      {'day': 11, 'amountCents': 0},
      {'day': 12, 'amountCents': 0},
      {'day': 13, 'amountCents': 0},
      {'day': 14, 'amountCents': 12000},
      {'day': 15, 'amountCents': 0},
      {'day': 16, 'amountCents': 0},
      {'day': 17, 'amountCents': 0},
      {'day': 18, 'amountCents': 31010},
      {'day': 19, 'amountCents': 0},
      {'day': 20, 'amountCents': 0},
      {'day': 21, 'amountCents': 0},
      {'day': 22, 'amountCents': 0},
      {'day': 23, 'amountCents': 0},
      {'day': 24, 'amountCents': 0},
      // Compra com data futura é permitida (GFX-12), então a série não para
      // em "hoje" — quem trunca a linha é a tela (DSH-13).
      {'day': 25, 'amountCents': 10000},
      {'day': 26, 'amountCents': 0},
      {'day': 27, 'amountCents': 0},
      {'day': 28, 'amountCents': 0},
      {'day': 29, 'amountCents': 0},
      {'day': 30, 'amountCents': 0},
    ],
    // Agosto tem 31 dias — a curva apagada do fundo é do mês anterior inteiro.
    'previousDays': [
      {'day': 1, 'amountCents': 4500},
      {'day': 2, 'amountCents': 0},
      {'day': 3, 'amountCents': 22000},
      {'day': 4, 'amountCents': 0},
      {'day': 5, 'amountCents': 0},
      {'day': 6, 'amountCents': 13400},
      {'day': 7, 'amountCents': 0},
      {'day': 8, 'amountCents': 0},
      {'day': 9, 'amountCents': 0},
      {'day': 10, 'amountCents': 9900},
      {'day': 11, 'amountCents': 0},
      {'day': 12, 'amountCents': 0},
      {'day': 13, 'amountCents': 0},
      {'day': 14, 'amountCents': 0},
      {'day': 15, 'amountCents': 18000},
      {'day': 16, 'amountCents': 0},
      {'day': 17, 'amountCents': 0},
      {'day': 18, 'amountCents': 0},
      {'day': 19, 'amountCents': 0},
      {'day': 20, 'amountCents': 7600},
      {'day': 21, 'amountCents': 0},
      {'day': 22, 'amountCents': 0},
      {'day': 23, 'amountCents': 0},
      {'day': 24, 'amountCents': 0},
      {'day': 25, 'amountCents': 0},
      {'day': 26, 'amountCents': 11200},
      {'day': 27, 'amountCents': 0},
      {'day': 28, 'amountCents': 0},
      {'day': 29, 'amountCents': 0},
      {'day': 30, 'amountCents': 0},
      {'day': 31, 'amountCents': 0},
    ],
  },
  'cards': [
    {
      'cardId': 'id-nubank',
      'label': 'Nubank ••••1234',
      'totalCents': 82400,
      'limitCents': 500000,
    },
    {'cardId': 'id-inter', 'label': 'Inter', 'totalCents': 0, 'limitCents': null},
  ],
  // 180000 + 30000 + 102400 = 312400 (DSH-19).
  'byNature': {
    'recurringCents': 180000,
    'installmentCents': 30000,
    'oneOffCents': 102400,
  },
  // Seis meses terminando na competência pedida, e a última entrada bate com
  // o `totals` (DSH-22).
  'history': [
    {'month': '2026-04', 'incomeCents': 500000, 'expenseCents': 288000},
    {'month': '2026-05', 'incomeCents': 500000, 'expenseCents': 301500},
    // Mês sem movimento vem zerado, não omitido (DSH-21).
    {'month': '2026-06', 'incomeCents': 0, 'expenseCents': 0},
    {'month': '2026-07', 'incomeCents': 520000, 'expenseCents': 344900},
    {'month': '2026-08', 'incomeCents': 500000, 'expenseCents': 286600},
    {'month': '2026-09', 'incomeCents': 500000, 'expenseCents': 312400},
  ],
  'topExpenses': [
    {
      'id': 'exp-geladeira',
      'description': 'Geladeira',
      'amountCents': 30000,
      'spentAt': '2026-07-10T12:00:00.000Z',
      'installmentLabel': '3/10',
    },
    {
      'id': 'exp-mercado',
      'description': 'Mercado do mês',
      'amountCents': 24500,
      'spentAt': '2026-09-05T12:00:00.000Z',
      'installmentLabel': null,
    },
    {
      'id': 'exp-farmacia',
      'description': 'Farmácia',
      'amountCents': 15990,
      'spentAt': '2026-09-02T12:00:00.000Z',
      'installmentLabel': null,
    },
    {
      'id': 'exp-passagem',
      'description': 'Passagem',
      'amountCents': 12000,
      'spentAt': '2026-09-14T12:00:00.000Z',
      'installmentLabel': null,
    },
    {
      'id': 'exp-internet',
      'description': 'Internet',
      'amountCents': 10000,
      'spentAt': '2026-09-25T12:00:00.000Z',
      'installmentLabel': null,
    },
  ],
};

/// Mês sem nenhum lançamento — resposta válida, não erro (DSH-25). Todos os
/// blocos vêm, vazios ou zerados; nenhuma chave falta (DSH-02).
final dashboardVazioJson = <String, dynamic>{
  'month': '2026-11',
  'totals': {
    'incomeCents': 0,
    'expenseCents': 0,
    'balanceCents': 0,
    'committedPercent': null,
  },
  'allowance': {
    'scope': 'future',
    'daysRemaining': 30,
    'perDayCents': null,
    'overspentCents': null,
  },
  'byTag': <Map<String, dynamic>>[],
  'daily': {
    'baselineCents': 0,
    'days': <Map<String, dynamic>>[],
    'previousDays': <Map<String, dynamic>>[],
  },
  'cards': <Map<String, dynamic>>[],
  'byNature': {
    'recurringCents': 0,
    'installmentCents': 0,
    'oneOffCents': 0,
  },
  'history': <Map<String, dynamic>>[],
  'topExpenses': <Map<String, dynamic>>[],
};

/// Um mês que fechou no vermelho: a sobra não vira número negativo por dia
/// (DSH-07). `perDayCents` é null e `overspentCents` traz o quanto passou,
/// inteiro positivo.
final dashboardEstouradoJson = <String, dynamic>{
  ...dashboardJson,
  'totals': {
    'incomeCents': 500000,
    'expenseCents': 538000,
    'balanceCents': -38000,
    'committedPercent': 107.6,
  },
  'allowance': {
    'scope': 'current',
    'daysRemaining': 21,
    'perDayCents': null,
    'overspentCents': 38000,
  },
};
