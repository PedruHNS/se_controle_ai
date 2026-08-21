// Resposta real de `/tags`, capturada do backend em Docker em 21/08/2026 —
// são as tags que a migration 005 criou a partir das categorias que já
// existiam.
const tagListJson = <Map<String, dynamic>>[
  {
    'id': '1519d248-272f-407c-9853-87fcfb7ff789',
    'name': 'Moradia',
    'color': '#4CAF50',
  },
  {
    'id': '5fa6134c-35e7-4341-8db0-54f00256c8bc',
    'name': 'Outros',
    'color': null,
  },
  {
    'id': '2aa154c8-9549-4ed4-bdd6-3254d91cca84',
    'name': 'Transporte',
    'color': '#42A5F5',
  },
];

/// A tag do aluguel — a que as fixtures de gasto usam.
const moradiaTagId = '1519d248-272f-407c-9853-87fcfb7ff789';

/// Uma segunda tag, para os testes que trocam a tag de um gasto.
const outraTagId = '2aa154c8-9549-4ed4-bdd6-3254d91cca84';
