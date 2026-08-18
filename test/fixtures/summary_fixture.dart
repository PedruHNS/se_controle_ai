/// Resposta real de `GET /summary?month=2026-08`, copiada do backend rodando em
/// Docker — não é JSON inventado. É o que garante que o model bate com o
/// contrato de verdade, incluindo os campos que vêm nulos.
const summaryJson = <String, dynamic>{
  'month': '2026-08',
  'incomeCents': 500000,
  'expenseCents': 245590,
  'balanceCents': 254410,
  'committedPercent': 49.1,
  'incomes': [
    {
      'id': '14835b6d-6a94-4141-95ab-b415642066d2',
      'description': 'Salário',
      'amountCents': 500000,
      'installmentLabel': null,
    },
  ],
  'debit': {
    'totalCents': 180000,
    'items': [
      {
        'id': '6a78f6a7-7b40-4175-9f46-8e76437cc6b9',
        'description': 'Aluguel',
        'amountCents': 180000,
        'installmentLabel': null,
      },
    ],
  },
  'creditCards': [
    {
      'cardId': '39e95359-97f2-441c-bc26-f68a8821ae5a',
      'name': 'Nubank',
      'label': 'Nubank ••••4321',
      'dueDate': '2026-08-17',
      'limitCents': 800000,
      'totalCents': 65590,
      'items': [
        {
          'id': '9181aacb-7609-4354-82ad-2cdfc51af015',
          'description': 'Netflix',
          'amountCents': 5590,
          'installmentLabel': null,
        },
        {
          'id': 'a0843022-eea2-48ef-8c43-2ab4e4f9bc1f',
          'description': 'Notebook',
          'amountCents': 60000,
          'installmentLabel': '3/10',
        },
      ],
    },
  ],
};

/// Mês sem nada lançado — o backend devolve as listas vazias e
/// `committedPercent` nulo, porque não há ganho para dividir.
const emptySummaryJson = <String, dynamic>{
  'month': '2026-09',
  'incomeCents': 0,
  'expenseCents': 0,
  'balanceCents': 0,
  'committedPercent': null,
  'incomes': <dynamic>[],
  'debit': {'totalCents': 0, 'items': <dynamic>[]},
  'creditCards': <dynamic>[],
};

/// Mês no vermelho, para exercitar saldo negativo e limite estourado.
const negativeSummaryJson = <String, dynamic>{
  'month': '2026-10',
  'incomeCents': 300000,
  'expenseCents': 450000,
  'balanceCents': -150000,
  'committedPercent': 150.0,
  'incomes': [
    {
      'id': 'i1',
      'description': 'Salário',
      'amountCents': 300000,
      'installmentLabel': null,
    },
  ],
  'debit': {'totalCents': 0, 'items': <dynamic>[]},
  'creditCards': [
    {
      'cardId': 'c1',
      'name': 'Cartão',
      'label': 'Cartão ••••0001',
      'dueDate': '2026-10-05',
      'limitCents': 400000,
      'totalCents': 450000,
      'items': [
        {
          'id': 'e1',
          'description': 'Compra grande',
          'amountCents': 450000,
          'installmentLabel': null,
        },
      ],
    },
  ],
};
