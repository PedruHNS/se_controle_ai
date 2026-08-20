// Respostas reais de `GET /summary/projection`, capturadas do backend em Docker
// em 20/08/2026.

/// Seis meses no azul: R$ 6.000,00 de ganho por mês, um gasto de R$ 980,00 só
/// no primeiro. O acumulado é a soma dos saldos, e é ele que a tela desenha.
const projectionJson = <Map<String, dynamic>>[
  {
    'month': '2026-08',
    'incomeCents': 600000,
    'expenseCents': 98000,
    'balanceCents': 502000,
    'cumulativeBalanceCents': 502000,
  },
  {
    'month': '2026-09',
    'incomeCents': 600000,
    'expenseCents': 0,
    'balanceCents': 600000,
    'cumulativeBalanceCents': 1102000,
  },
  {
    'month': '2026-10',
    'incomeCents': 600000,
    'expenseCents': 0,
    'balanceCents': 600000,
    'cumulativeBalanceCents': 1702000,
  },
  {
    'month': '2026-11',
    'incomeCents': 600000,
    'expenseCents': 0,
    'balanceCents': 600000,
    'cumulativeBalanceCents': 2302000,
  },
  {
    'month': '2026-12',
    'incomeCents': 600000,
    'expenseCents': 0,
    'balanceCents': 600000,
    'cumulativeBalanceCents': 2902000,
  },
  {
    'month': '2027-01',
    'incomeCents': 600000,
    'expenseCents': 0,
    'balanceCents': 600000,
    'cumulativeBalanceCents': 3502000,
  },
];

/// A mesma projeção com um gasto avulso de R$ 50.000,00 em agosto — uma reforma.
///
/// O acumulado afunda no primeiro mês e sobe de volta sem cruzar o zero dentro
/// do horizonte: é o caso que a tela precisa saber contar, porque o número
/// grande do topo (o último acumulado) continua negativo enquanto o saldo
/// mensal já voltou a ser positivo.
const projectionNegativeJson = <Map<String, dynamic>>[
  {
    'month': '2026-08',
    'incomeCents': 600000,
    'expenseCents': 5098000,
    'balanceCents': -4498000,
    'cumulativeBalanceCents': -4498000,
  },
  {
    'month': '2026-09',
    'incomeCents': 600000,
    'expenseCents': 0,
    'balanceCents': 600000,
    'cumulativeBalanceCents': -3898000,
  },
  {
    'month': '2026-10',
    'incomeCents': 600000,
    'expenseCents': 0,
    'balanceCents': 600000,
    'cumulativeBalanceCents': -3298000,
  },
  {
    'month': '2026-11',
    'incomeCents': 600000,
    'expenseCents': 0,
    'balanceCents': 600000,
    'cumulativeBalanceCents': -2698000,
  },
  {
    'month': '2026-12',
    'incomeCents': 600000,
    'expenseCents': 0,
    'balanceCents': 600000,
    'cumulativeBalanceCents': -2098000,
  },
  {
    'month': '2027-01',
    'incomeCents': 600000,
    'expenseCents': 0,
    'balanceCents': 600000,
    'cumulativeBalanceCents': -1498000,
  },
];
