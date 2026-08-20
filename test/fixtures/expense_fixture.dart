// Respostas reais de `/expenses`, capturadas do backend em Docker em
// 19/08/2026.
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
  'category': 'Moradia',
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
  'category': null,
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
  'category': 'Presentes',
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

/// Um parcelado, para o model provar que não engasga com ele: `history` vem
/// **null** e o dinheiro está em `installments`, que a Fase 4 não lê (GFX-09).
const geladeiraJson = <String, dynamic>{
  'id': '9c1f6b02-0f0e-4a1f-9d0a-2b3c4d5e6f70',
  'description': 'Geladeira',
  'category': 'Casa',
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
    {
      'number': 3,
      'total': 10,
      'amountCents': 30000,
      'referenceMonth': '2026-08',
    },
  ],
};

/// A lista como `GET /expenses` devolve, na ordem do backend.
const expenseListJson = <Map<String, dynamic>>[
  aluguelJson,
  presenteJson,
  youtubeJson,
];
