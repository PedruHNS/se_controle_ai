# Regra dos models

Vale para tudo em `lib/data/models/`. Combinada em 11/09/2026.

## O que um model pode ter

1. **Atributos** — campos `final`, e o construtor `const`.
2. **Desserialização** — `factory X.fromJson(Map<String, dynamic> json)`.
3. **Serialização** — `toJson()` **quando houver o que enviar** ao backend.
   Model que só é resposta não ganha um.
4. **`copyWith`** — quando necessário, isto é, quando alguém precisa de uma
   cópia com um campo trocado. Não criar "por via das dúvidas".
5. **`operator ==`** — quando necessário: comparação por valor em teste, em
   `Set`, ou para o Flutter decidir se um widget mudou.
6. **`hashCode`** — sempre que houver `==`, nunca sozinho.
7. **`toString`** — **sempre**. É o que aparece quando um teste falha ou um
   `log` imprime o objeto; sem ele sai `Instance of 'ExpenseModel'`, que não
   ajuda ninguém.

## O que um model não pode ter

**Nada derivado.** Sem getter que calcula, sem método que decide, sem
formatação.

```dart
// não
bool get isNegative => balanceCents < 0;
int get totalCents => a + b + c;
Color get parsedColor { ... }
int? amountCentsIn(String month) { ... }

// sim — a conta é de quem usa: controller, card ou teste
```

Onde a conta mora, em ordem de preferência:

- **Quem usa**, quando é uma linha e serve a um lugar só.
- **Um utilitário em `lib/core/utils/`**, quando a mesma regra serve a telas
  diferentes — é o caso do `TagColorUtils.parse`, que pinta a tag no formulário, no
  tile e no card do dashboard.
- **Uma extension**, quando é regra de domínio com muitos pontos de chamada e
  mover para fora reescreveria dezenas de linhas.

**Nada de `import 'package:flutter/...'` num model.** Se precisou de `Color`,
`Icon` ou `TextStyle`, a conta está no lugar errado.

## Enums

Enum de dado mora em **`lib/data/enums/`**, um por arquivo, nunca dentro do
model. Segue o padrão dos que já estão lá: valor `wire` explícito (o texto como
o backend escreve) e um `fromWire` estático.

Enum que só existe dentro de um widget (`_Acao`, `ExpenseAmountMode`) não é
disso que a regra fala — continua no arquivo do widget.

## Estado atual

Os nove models do dashboard e o `TagModel` já seguem a regra. **Os outros ainda
não**: `ExpenseModel` e `IncomeModel` concentram a maior parte da dívida
(`amountCentsIn`, `currentVersion`, `isClosed`…), e há um getter solto em
`amount_version_model`, `auth_user_model`, `credit_card_model`,
`credit_card_invoice_model`, `installment_model`, `monthly_balance_model`,
`monthly_summary_model` e `summary_section_model`.

Ao mexer num deles por outro motivo, alinhar. Não sair refatorando todos de uma
vez sem combinar — são ~90 pontos de chamada.
