// Respostas reais de `/expenses`, capturadas do backend em Docker em
// 19/08/2026 e atualizadas em 21/08 para o formato com tag e observação.
//
// JSON copiado, não escrito à mão: fixture inventada concorda com o que o app
// espera por construção, e é justamente a discordância entre app e backend que
// o teste de model precisa pegar.

/// Aluguel no débito, reajustado de R$ 1.200,00 para R$ 1.350,00 em julho.
///
/// Buscado **sem** `?month`, que é como a lista busca: repare no
/// `amountCents: null` — diferente de ganhos, o backend não cai para a vigência
/// mais recente, e quem quiser um valor tem que lê-lo do `history`.
const aluguelJson = <String, dynamic>{
  'id': 'bd9e15e7-e489-4f09-938d-028b96047cc3',
  'description': 'Aluguel',
  'tag': {
    'id': '1519d248-272f-407c-9853-87fcfb7ff789',
    'name': 'Moradia',
    'color': '#4CAF50',
  },
  'notes': 'reajuste anual em julho',
  'type': 'FIXED',
  'paymentMethod': 'DEBIT',
  'creditCardId': null,
  'recurring': true,
  'startMonth': '2026-01',
  'endMonth': null,
  'amountCents': null,
  'totalCents': null,
  'installmentsCount': null,
  'installmentLabel': null,
  'history': <Map<String, dynamic>>[
    {'amountCents': 120000, 'validFrom': '2026-01', 'validTo': '2026-06'},
    {'amountCents': 135000, 'validFrom': '2026-07', 'validTo': null},
  ],
  'installments': null,
};

/// O mesmo aluguel buscado **com** `?month=2026-03`: aí `amountCents` vem
/// preenchido, e com o valor **daquele** mês (R$ 1.200,00), não com o de hoje.
/// É a prova de que o reajuste de julho não reescreveu março.
/// `final` e não `const`: a sobreposição de uma chave já presente no spread só
/// é permitida fora de um literal constante.
final aluguelEmMarcoJson = <String, dynamic>{
  ...aluguelJson,
  'amountCents': 120000,
};

/// Assinatura no cartão, sem categoria — os dois campos opcionais no mínimo.
const youtubeJson = <String, dynamic>{
  'id': '1fb725a4-a0de-4269-895a-ab4f9b5093af',
  'description': 'Youtube Music',
  'tag': {
    'id': '5fa6134c-35e7-4341-8db0-54f00256c8bc',
    'name': 'Outros',
    'color': null,
  },
  'notes': 'guardar a nota fiscal',
  'type': 'FIXED',
  'paymentMethod': 'CREDIT_CARD',
  'creditCardId': '7d0c3c51-cc34-4dbe-8abd-f8487377a8b3',
  'recurring': true,
  'startMonth': '2026-03',
  'endMonth': null,
  'amountCents': null,
  'totalCents': null,
  'installmentsCount': null,
  'installmentLabel': null,
  'history': <Map<String, dynamic>>[
    {'amountCents': 2490, 'validFrom': '2026-03', 'validTo': null},
  ],
  'installments': null,
};

/// Gasto avulso: `recurring: false` no cadastro, e o backend devolve
/// `endMonth` igual ao `startMonth` (GFX-03). Não existe tipo "avulso" — é um
/// fixo que dura um mês.
const presenteJson = <String, dynamic>{
  'id': 'f4da0ef4-c036-405c-bfba-1b752b3f6ac1',
  'description': 'Presente do João',
  'tag': {
    'id': '123c98f8-2ec5-47e8-add8-e1295ae94d1d',
    'name': 'Presentes',
    'color': null,
  },
  'notes': null,
  'type': 'FIXED',
  'paymentMethod': 'CREDIT_CARD',
  'creditCardId': '7d0c3c51-cc34-4dbe-8abd-f8487377a8b3',
  'recurring': false,
  'startMonth': '2026-08',
  'endMonth': '2026-08',
  'amountCents': null,
  'totalCents': null,
  'installmentsCount': null,
  'installmentLabel': null,
  'history': <Map<String, dynamic>>[
    {'amountCents': 18000, 'validFrom': '2026-08', 'validTo': '2026-08'},
  ],
  'installments': null,
};

/// Geladeira em 10x de R$ 300,00, buscada com `?month=2026-03` — daí o
/// `amountCents` da parcela do mês e o `installmentLabel: '3/10'`.
///
/// `history` vem **null**: em parcelado o dinheiro está nas parcelas (GFX-09).
/// `final` e não `const`: o `for` que gera as dez parcelas não é constante.
final geladeiraJson = <String, dynamic>{
  'id': '9c1f6b02-0f0e-4a1f-9d0a-2b3c4d5e6f70',
  'description': 'Geladeira',
  'tag': {
    'id': '2aa154c8-9549-4ed4-bdd6-3254d91cca84',
    'name': 'Casa',
    'color': '#42A5F5',
  },
  'notes': null,
  'type': 'INSTALLMENT',
  'paymentMethod': 'CREDIT_CARD',
  'creditCardId': '7d0c3c51-cc34-4dbe-8abd-f8487377a8b3',
  'recurring': false,
  'startMonth': '2026-06',
  'endMonth': '2027-03',
  'amountCents': 30000,
  'totalCents': 300000,
  'installmentsCount': 10,
  'installmentLabel': '3/10',
  'history': null,
  'installments': <Map<String, dynamic>>[
    for (var n = 1; n <= 10; n++)
      {
        'number': n,
        'total': 10,
        'amountCents': 30000,
        'referenceMonth': '2026-0$n',
      },
  ],
};

/// A mesma compra depois de reparcelada: 12x de R$ 4.000,00 a partir de maio.
///
/// É a resposta real do backend, e mostra as três regras juntas — as quatro
/// primeiras ficaram com o valor antigo porque já foram cobradas (GPR-08), a
/// numeração continuou em 5 (GPR-10), e o "de N" das antigas virou 12 (GPR-11).
final geladeiraReparceladaJson = <String, dynamic>{
  ...geladeiraJson,
  'endMonth': '2026-12',
  'amountCents': 35000,
  'totalCents': 400000,
  'installmentsCount': 12,
  'installmentLabel': '5/12',
  'installments': <Map<String, dynamic>>[
    {
      'number': 1,
      'total': 12,
      'amountCents': 30000,
      'referenceMonth': '2026-01',
    },
    {
      'number': 2,
      'total': 12,
      'amountCents': 30000,
      'referenceMonth': '2026-02',
    },
    {
      'number': 3,
      'total': 12,
      'amountCents': 30000,
      'referenceMonth': '2026-03',
    },
    {
      'number': 4,
      'total': 12,
      'amountCents': 30000,
      'referenceMonth': '2026-04',
    },
    {
      'number': 5,
      'total': 12,
      'amountCents': 35000,
      'referenceMonth': '2026-05',
    },
    {
      'number': 6,
      'total': 12,
      'amountCents': 35000,
      'referenceMonth': '2026-06',
    },
    {
      'number': 7,
      'total': 12,
      'amountCents': 35000,
      'referenceMonth': '2026-07',
    },
    {
      'number': 8,
      'total': 12,
      'amountCents': 35000,
      'referenceMonth': '2026-08',
    },
    {
      'number': 9,
      'total': 12,
      'amountCents': 35000,
      'referenceMonth': '2026-09',
    },
    {
      'number': 10,
      'total': 12,
      'amountCents': 35000,
      'referenceMonth': '2026-10',
    },
    {
      'number': 11,
      'total': 12,
      'amountCents': 35000,
      'referenceMonth': '2026-11',
    },
    {
      'number': 12,
      'total': 12,
      'amountCents': 35000,
      'referenceMonth': '2026-12',
    },
  ],
};

/// A lista como `GET /expenses` devolve, na ordem do backend.
const expenseListJson = <Map<String, dynamic>>[
  aluguelJson,
  presenteJson,
  youtubeJson,
];
