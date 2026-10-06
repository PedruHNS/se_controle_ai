# Quadro de refatoração

Candidatos levantados por feature, **reconferidos contra o código em
01/09/2026**. Nenhum item é obrigatório: são pontos onde a repetição ou o tamanho
já incomodam, com o motivo ao lado, para a decisão ser tomada com a conta na mão.

A visão por feature, com status, está na seção **Refatoração** do
[`ROADMAP.md`](ROADMAP.md). Aqui fica o detalhe de cada item.

> Antes de puxar um item, veja **Decisões que parecem refatoração e não são**, no
> fim: algumas repetições estão lá de propósito, e desfazê-las por engano custa
> mais que mantê-las.

---

## `core/` — o que atravessa todas as features

- [ ] **`ViewStateBuilder`.** O `switch` de `Loading` / `Failed` / `Loaded`, com o
      `FailureCardWidget` e o `CircularProgressIndicator`, está em **11 telas** —
      eram 9 em 25/08. Um widget que receba o estado e o `onRetry` corta o mesmo
      bloco de 15 linhas em todas. **É o item de maior retorno do app.**
- [ ] **Guarda de corrida em um lugar só.** O par `_requestId` + `if (requestId
      != _requestId) return` vive em **8 controllers**, sempre igual. Cabe num
      mixin (`RaceGuard`) ou no `BaseController`. Cuidado: o teste de cada
      controller cobre essa guarda hoje — a extração precisa manter os testes
      passando sem reescrevê-los.
- [ ] **`_applyFailure` em um lugar só.** São **8 cópias**: 3 em controllers de
      formulário e 5 em diálogos. Todas fazem o mesmo — `issues[].path` que casa
      com campo vira erro do campo, o resto sobe como falha geral. Vira uma
      função que recebe `FormGroup` e `Failure` e devolve a mensagem que sobrou.
- [x] **`_serializationFailure` em um lugar só.** Feito em 11/09/2026: virou
      `serializationFailure` em `core/errors/serialization_failure.dart`. Eram
      **seis** cópias, e não cinco — o repositório do dashboard nasceu com a
      sétima e já usa a função.
- [ ] **`_ActionCard` compartilhado.** Duplicado entre o detalhe de ganho e o de
      gasto. Vira `core/shared/widgets/action_card.dart`.
- [ ] **`_openAndReload` compartilhado.** As **4 telas de lista** repetem
      "navega, volta, recarrega". Cabe num mixin de `State`.
- [ ] **Quebrar o `app_router.dart`** (276 linhas). Uma lista de rotas por
      feature, montada na raiz — como o injector já faz.
- [x] **Quebrar o `injector.dart`.** Feito: a raiz tem 79 linhas e o registro se
      divide em `part` por camada (`injector_repositories`,
      `injector_controllers`, `injector_services`). O `part` foi escolhido no
      lugar de arquivos com import porque o registro é um só, e não seis
      independentes.

## `auth`

- [x] **A decisão de rota saiu do router.** `rotaParaEstado`, em `auth_gate.dart`
      (48 linhas, 14 testes), é função de quatro entradas. Pelo router ela só era
      alcançável com injetor montado e router global — e aí a falha não diz qual
      combinação quebrou.
- [ ] O que sobra é tela: `login_page` (209) e `auth_repository` (225). Nenhum
      dos dois tem repetição, só tamanho.

## `data/`

- [ ] **`ExpenseModel` (213) acumulou dois tipos num só.** Campos de fixo
      (`history`), de parcelado (`installments`, `totalCents`,
      `installmentsCount`), mais tag e observação. Funciona porque o backend
      garante que só metade vem preenchida, mas a classe já não cabe na cabeça.
      Avaliar um `sealed` com dois filhos — sabendo que isso mexe em toda tela de
      gasto.
- [ ] **`ExpenseModel` e `IncomeModel` fora da regra dos models.** Desde
      11/09/2026 a regra está escrita em [`.claude/rules/models.md`](.claude/rules/models.md):
      model tem atributos, serialização, `copyWith`/`==`/`hashCode` quando
      necessário e `toString` sempre — nada derivado. O `ExpenseModel` tem
      **treze** membros derivados e o `IncomeModel` **sete**, e os dois
      compartilham o mesmo `amountCentsIn(month)`, que percorre vigências e cai
      nas parcelas quando não acha (GFX-09).

      São ~90 pontos de chamada: `amountCentsIn` em 21, `currentVersion` em 11,
      `isClosed` em 10. **Ele decidiu em 11/09 não refatorar agora.** Quando for:
      o que é enfeite (`isFixed`, `isInstallment`, `onCreditCard`) sai para quem
      usa; o que é regra de domínio vai para extension, que tira a conta do model
      sem reescrever as dezenas de chamadas.

      Menores, na mesma dívida: `isOpen` (`AmountVersionModel`), `label`
      (`AuthUserModel`, `InstallmentModel`), `limitUsage`
      (`CreditCardInvoiceModel`), `hasLimit` e `dueInNextMonth`
      (`CreditCardModel`), `isNegative` (`MonthlyBalanceModel` e
      `MonthlySummaryModel`), `isEmpty` (`SummarySectionModel`). E **falta
      `toString` em todos eles** — os nove do dashboard e o `TagModel` já têm.
- [ ] **`fromJson` manual em 12 models.** Sem codegen é uma escolha do projeto; o
      que dá para melhorar é o `Decode`, que hoje resolve só objeto e lista.
- [ ] **Conferir que nenhum repositório novo trouxe o `_guard` de volta.** O
      helper com closure foi removido em 20/08; o `try/catch` fica escrito em
      cada método.

## `home`

- [ ] **`home_page.dart` cresceu para 297 linhas** e ainda carrega o
      `_SummaryContent` inteiro (linha 173). Ele é conteúdo, não estrutura de
      tela — cabe em `widgets/`.
- [ ] **Três tiles com a mesma anatomia.** `LineItemTile`, `IncomeTile` e
      `ExpenseTile` são "título, subtítulo, valor à direita, selo". Um tile base
      com slots resolveria — mas veja a ressalva sobre tiles no fim.

## `incomes`

- [ ] **`submit` valida o grupo inteiro.** Em gastos a validação passou a ser por
      campo (por causa dos campos do tipo não escolhido); aqui continua
      `form.invalid`. Não está errado, mas são duas formas de fazer a mesma coisa
      no mesmo app — vale escolher uma.
- [ ] **`income_detail_page.dart`** (274).
- [ ] **Os dois diálogos são quase iguais aos de gasto** (207/154 contra
      211/158). Ver a ressalva no fim antes de unificar.

## `expenses`

- [ ] **`expense_form_page.dart` (541) e `expense_form_controller.dart` (527) são
      os maiores arquivos do app.** O formulário faz cadastro fixo, cadastro
      parcelado e edição, com campos que aparecem e somem. Separar por modo — ou
      ao menos extrair os blocos de campos — é o item de maior retorno da
      feature.
- [ ] **`expense_detail_page.dart`** (419). A escolha de ações por tipo e o
      `_periodLine` são lógica de apresentação misturada com layout.
- [ ] **Quatro diálogos na mesma pasta**, dois deles gêmeos dos de ganho.
- [ ] **`_createTag` está órfão** (linha 591): o botão que o chamava está
      comentado (linha 195). É o único aviso do `flutter analyze`. Decidir entre
      religar o botão e apagar a função — o controller e os testes de `createTag`
      continuam lá, então hoje a feature existe no código e não no app.

## `credit_cards`

**Refatorada em 06/10/2026**, quando ele fechou a revisão do `ExpenseTile`.

- [x] ~~**`credit_card_form_controller.dart`** (271)~~ — **saiu em 04/09**: o
      controller de formulário virou o lado de formulário do
      `CreditCardController`, e o diff do CAR-08 saiu junto — a edição manda o
      cartão inteiro, então não há mais `Patch` para montar.
- [x] ~~**`CreditCardExpensesController` dispara três requisições**~~ — **uma
      só desde 05/09**, com model no lugar do record. O controller tem 72
      linhas e a tela 197, com o card da fatura e o aviso de vazio em
      `widgets/`.

## `projection`

- [ ] **`projection_page.dart`** (243). `_MonthRow` cabe em `widgets/`.
- [ ] **O `ProjectionChart` não tem teste de desenho.** Hoje é verificado só por
      existir na árvore. Um golden test seria o primeiro do projeto — decidir se
      vale abrir essa porta.

## `tags` — ✅ refatorado

- [x] **`tag_list_page.dart` caiu de 359 para 172 linhas**, com `TagTile` (144) e
      o diálogo de criação (156) em `widgets/` e o controller em 157. Era a maior
      tela fora de gastos; hoje não está entre as vinte maiores.

## `notifications`

- [ ] **Tela de aviso, não feature.** Vira código de verdade quando a Etapa 8 do
      backend existir. Nada a refatorar antes disso.

## Testes

- [ ] **`fixtures/mocks.dart` foi de 566 para 787 linhas** e tem os mocks e stubs
      de seis repositórios e do `NavigationService`. Dividir por feature (`mocks/expense_mocks.dart`…) e
      manter um `mocks.dart` que reexporta.
- [ ] **`fixtures/test_injector.dart` foi de 207 para 309** e carrega uma
      divergência conhecida: os controllers de lista são `registerFactory` aqui e
      `registerLazySingleton` em produção, então o caminho de `dispose` real nunca
      é exercido em teste.
- [ ] **Helper de rolagem repetido.** `scrollUntilVisible(..., scrollable:
      find.byType(Scrollable).first)` aparece em 4 lugares, sempre com o mesmo
      comentário explicando o `.first`.
- [ ] **`pumpX` por arquivo de teste.** Cada suíte de tela reescreve o seu.

---

## Decisões que parecem refatoração e não são

Estão assim por escolha registrada. Mudar é possível — mas é decisão nova, não
limpeza.

- **Os diálogos de ganho e de gasto duplicados.** Mesma forma, conhecimento
  diferente: as mensagens falam de receber e de pagar, e as guardas não são as
  mesmas. É a mesma escolha que o backend fez entre `incomes` e `expenses`. Se
  for unificar, unifique o *esqueleto* (form + envio + erro), não o texto.
- **O `try/catch` escrito em cada método do repositório.** O `_guard` com closure
  foi tirado de propósito em 20/08: o tratamento de erro fica visível onde
  acontece.
- **O gráfico da projeção sem biblioteca.** Sessenta linhas de `CustomPainter`
  contra uma dependência que traz o que a tela não usa. Reabrir só se precisar de
  tooltip, zoom ou várias séries.
- **Um model por arquivo, sem barrel.** Cada consumidor importa a classe que usa.
- **Os tiles separados por feature.** Antes de unificar, note que cada um tem um
  selo com regra própria (parcela `3/10`, "Encerrado", uso do limite). O que dá
  para compartilhar é o layout, não a decisão do que exibir.
