/// JSON de `/incomes`, no formato que o backend devolve.
///
/// O primeiro é a resposta real capturada de `GET /incomes` com o banco de
/// desenvolvimento; os outros seguem o exemplo documentado em
/// `docs/specs/01-ganhos.md`. Fixture copiada do contrato, e não inventada, é o
/// que faz o teste de parse valer alguma coisa.
const Map<String, dynamic> salaryJson = {
  'id': '14835b6d-6a94-4141-95ab-b415642066d2',
  'description': 'Salário',
  'recurring': true,
  'startMonth': '2026-01',
  'endMonth': null,
  'amountCents': 500000,
  'history': [
    {'amountCents': 500000, 'validFrom': '2026-01', 'validTo': null},
  ],
};

/// Salário com um reajuste: 5.000 até outubro, 5.500 de novembro em diante.
const Map<String, dynamic> adjustedSalaryJson = {
  'id': 'b1a7c0de-0000-4000-8000-000000000001',
  'description': 'Salário',
  'recurring': true,
  'startMonth': '2026-01',
  'endMonth': null,
  'amountCents': 550000,
  'history': [
    {'amountCents': 500000, 'validFrom': '2026-01', 'validTo': '2026-10'},
    {'amountCents': 550000, 'validFrom': '2026-11', 'validTo': null},
  ],
};

/// Ganho de mês único, já encerrado por construção — 13º.
const Map<String, dynamic> bonusJson = {
  'id': 'b1a7c0de-0000-4000-8000-000000000002',
  'description': '13º salário',
  'recurring': false,
  'startMonth': '2026-12',
  'endMonth': '2026-12',
  'amountCents': 500000,
  'history': [
    {'amountCents': 500000, 'validFrom': '2026-12', 'validTo': '2026-12'},
  ],
};

const List<Map<String, dynamic>> incomeListJson = [salaryJson, bonusJson];

/// Ganho avulso em [month]: venda, presente, freela. O backend fecha a vigência
/// na hora, então `endMonth` já vem preenchido — é o caso que fazia a lista
/// marcar como "Encerrado" algo que ainda ia entrar.
///
/// Recebe o mês em vez de fixar um porque o comportamento depende de o mês ser
/// passado, corrente ou futuro; um mês cravado tornaria o teste dependente do
/// dia em que roda.
Map<String, dynamic> singleMonthIncomeJson({
  required String month,
  String id = 'b1a7c0de-0000-4000-8000-000000000003',
  String description = 'Venda da bicicleta',
  int amountCents = 80000,
}) => {
  'id': id,
  'description': description,
  'recurring': false,
  'startMonth': month,
  'endMonth': month,
  'amountCents': amountCents,
  'history': [
    {'amountCents': amountCents, 'validFrom': month, 'validTo': month},
  ],
};
