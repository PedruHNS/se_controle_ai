// Respostas reais de `/credit-cards`, capturadas do backend em Docker em
// 19/08/2026.
//
// JSON copiado, não escrito à mão: fixture inventada concorda com o que o app
// espera por construção, e é justamente a discordância entre app e backend que
// o teste de model precisa pegar.

/// Cartão completo, com dígitos e limite. `dueDay > closingDay`, então a fatura
/// de agosto vence em agosto (CAR-03).
const nubankJson = <String, dynamic>{
  'id': '39e95359-97f2-441c-bc26-f68a8821ae5a',
  'name': 'Nubank',
  'label': 'Nubank ••••4321',
  'lastDigits': '4321',
  'closingDay': 10,
  'dueDay': 17,
  'limitCents': 800000,
  'dueDate': '2026-08-17',
};

/// Cartão mínimo: sem dígitos e sem limite, os dois campos opcionais em null.
/// O `label` cai para o nome puro (CAR-06).
///
/// `dueDay` (5) menor que `closingDay` (27), então a fatura de **março** vence em
/// **abril** — a virada do CAR-03, conferida contra o backend.
const cartaoSimplesJson = <String, dynamic>{
  'id': 'e0a0cdba-9f48-45d5-9843-90ddc4ef1cbf',
  'name': 'Cartão de teste',
  'label': 'Cartão de teste',
  'lastDigits': null,
  'closingDay': 27,
  'dueDay': 5,
  'limitCents': null,
  'dueDate': '2026-04-05',
};

/// O mesmo cartão buscado **sem** `?month`: sem competência não há fatura, então
/// `dueDate` vem null. Quem exibe precisa dar conta dos dois casos.
const semCompetenciaJson = <String, dynamic>{
  'id': 'e0a0cdba-9f48-45d5-9843-90ddc4ef1cbf',
  'name': 'Cartão de teste',
  'label': 'Cartão de teste',
  'lastDigits': null,
  'closingDay': 27,
  'dueDay': 5,
  'limitCents': null,
  'dueDate': null,
};

const creditCardListJson = <Map<String, dynamic>>[
  nubankJson,
  cartaoSimplesJson,
];
