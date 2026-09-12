// Respostas reais de `/credit-cards`, capturadas do backend em Docker em
// 19/08/2026.
//
// JSON copiado, não escrito à mão: fixture inventada concorda com o que o app
// espera por construção, e é justamente a discordância entre app e backend que
// o teste de model precisa pegar.
//
// **Exceção, e a única:** o `totalCents` do CAR-09 foi escrito à mão em
// 01/09/2026 — capturar de novo exigiria um token do Firebase, que não existe
// fora do aparelho. Os valores seguem o resto da fixture: o do Nubank é o mesmo
// da fatura dele em `summary_fixture.dart`, que é o mesmo cartão na mesma
// competência.

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
  'totalCents': 65590,
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
  'dueDate': '2026-03-05',
  // Competência consultada, fatura limpa: zero, e não null.
  'totalCents': 0,
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
  // Sem competência não há fatura para somar, como não há o que vencer.
  'totalCents': null,
};

const creditCardListJson = <Map<String, dynamic>>[
  nubankJson,
  cartaoSimplesJson,
];

/// O que o `POST /credit-cards` devolve desde 04/09/2026: o cartão inteiro, no
/// formato da listagem, e não mais só o `id`. É o que deixa a tela inserir na
/// lista o que ela acabou de cadastrar, sem uma segunda volta ao servidor.
///
/// `dueDate` null, e `totalCents` **ausente**: cadastrar não é perguntar por
/// fatura de mês nenhum, então não há competência para calcular nem para somar.
const cartaoCriadoJson = <String, dynamic>{
  'id': 'c0ffee00-1111-4222-8333-444444444444',
  'name': 'Inter',
  'label': 'Inter ••••9999',
  'lastDigits': '9999',
  'closingDay': 3,
  'dueDay': 12,
  'limitCents': 1200000,
  'dueDate': null,
};
