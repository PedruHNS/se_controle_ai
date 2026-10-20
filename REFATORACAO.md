# Quadro de refatoração

Candidatos levantados por feature, **reconferidos contra o código em
01/09/2026**; `core/`, `data/`, `incomes`, `projection` e testes revistos em
**20/10/2026**. Nenhum item é obrigatório: são pontos onde a repetição ou o tamanho
já incomodam, com o motivo ao lado, para a decisão ser tomada com a conta na mão.

A visão por feature, com status, está na seção **Refatoração** do
[`ROADMAP.md`](ROADMAP.md). Aqui fica o detalhe de cada item.

> Antes de puxar um item, veja **Decisões que parecem refatoração e não são**, no
> fim: algumas repetições estão lá de propósito, e desfazê-las por engano custa
> mais que mantê-las.

---

## `core/` — o que atravessa todas as features

- [ ] **`ViewStateBuilder`.** O `switch` de `Loading` / `Failed` / `Loaded` está
      em **7 telas**. Contando do mesmo jeito (`Loading(` e `Failed(` no mesmo
      arquivo de `view/`), eram 9 em 01/09 — saíram a projeção e o detalhe de
      ganho. O "11" anotado antes vinha de outra contagem. Um widget que receba o estado e o `onRetry` corta o mesmo
      bloco de 15 linhas em todas. **É o item de maior retorno do app.**
- [ ] **Guarda de corrida em um lugar só.** O par `_requestId` + `if (requestId
      != _requestId) return` vive em **3 controllers** (eram 8): `home`,
      `expense_list` e `expense_detail`. Como a regra dos controllers proíbe o
      `requestId`, o caminho agora é tirá-lo, e não extraí-lo. Cabe num
      mixin (`RaceGuard`) ou no `BaseController`. Cuidado: o teste de cada
      controller cobre essa guarda hoje — a extração precisa manter os testes
      passando sem reescrevê-los.
- [ ] **`_applyFailure` em um lugar só.** São **4 cópias** (eram 8), todas em
      gastos: o `ExpenseFormController` e três diálogos. Ganhos deixou de usar em
      outubro — toda falha sai por toast. Todas fazem o mesmo — `issues[].path` que casa
      com campo vira erro do campo, o resto sobe como falha geral. Vira uma
      função que recebe `FormGroup` e `Failure` e devolve a mensagem que sobrou.
- [x] **`_serializationFailure` em um lugar só.** Feito em 11/09/2026: virou
      `serializationFailure` em `core/errors/serialization_failure.dart`. Eram
      **seis** cópias, e não cinco — o repositório do dashboard nasceu com a
      sétima e já usa a função.
- [ ] **`_ActionCard` compartilhado.** Meio caminho feito em 20/10: o de ganho
      virou `ActionCardWidget`, mas em `incomes/widgets/`. O detalhe de gasto
      segue com o `_ActionCard` dele (`expense_detail_page.dart:415`). Subir o
      widget para `core/shared/widgets/` e apagar o privado fecha o item.
- [ ] ~~**`_openAndReload` compartilhado.**~~ Sobrou **uma** tela, a lista de
      gastos (eram 4) — com um só uso, um mixin não se paga.
- [ ] **Tirar `Patch` e `TextOrderUtils`.** Os dois estão `@Deprecated` (19/10 e
      15/10), marcados para sair do código.
- [ ] **Quebrar o `app_router.dart`** (300 linhas). Uma lista de rotas por
      feature, montada na raiz — como o injector já faz.
- [x] **Quebrar o `injector.dart`.** Feito: a raiz tem 57 linhas e o registro se
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

- [ ] **`ExpenseModel` (83) acumulou dois tipos num só.** Campos de fixo
      (`history`), de parcelado (`installments`, `totalCents`,
      `installmentsCount`), mais tag e observação. Funciona porque o backend
      garante que só metade vem preenchida, mas a classe já não cabe na cabeça.
      Avaliar um `sealed` com dois filhos — sabendo que isso mexe em toda tela de
      gasto.
- [x] ~~**`ExpenseModel` e `IncomeModel` fora da regra dos models.**~~ **Feito
      em 07/10/2026**, com a revisão de ganhos: os dois ficaram com atributos,
      `fromJson` e `toString`. As contas foram para quem usa — o `IncomeTile`
      calcula o próprio selo — e para `ExpenseUtils` e `AmountVersionUtils`.
      Saíram juntos o `isOpen` (`AmountVersionModel`) e o `label`
      (`InstallmentModel`).

      Ainda na mesma dívida, um membro cada: `label` (`AuthUserModel`),
      `limitUsage` (`CreditCardInvoiceModel`), `isNegative`
      (`MonthlyBalanceModel` e `MonthlySummaryModel`) e `isEmpty`
      (`SummarySectionModel`). Falta `toString` em seis: esses quatro últimos,
      `CreditCardBillModel` e `SummaryLineItemModel`.
- [ ] **`fromJson` manual em 12 models.** Sem codegen é uma escolha do projeto; o
      que dá para melhorar é o `Decode`, que hoje resolve só objeto e lista.
- [ ] **Conferir que nenhum repositório novo trouxe o `_guard` de volta.** O
      helper com closure foi removido em 20/08; o `try/catch` fica escrito em
      cada método.

## `home`

- [ ] **`home_page.dart` cresceu para 379 linhas** (eram 297 em 01/09) e ainda carrega o
      `_SummaryContent` inteiro (linha 173). Ele é conteúdo, não estrutura de
      tela — cabe em `widgets/`.
- [ ] **Três tiles com a mesma anatomia.** `LineItemTile`, `IncomeTile` e
      `ExpenseTile` são "título, subtítulo, valor à direita, selo". Um tile base
      com slots resolveria — mas veja a ressalva sobre tiles no fim.

## `incomes` — ✅ refatorado

**Refatorada em 20/10/2026**, depois de duas semanas de revisão — o passo a passo
está em "Ganhos, revistos" no [`ROADMAP.md`](ROADMAP.md).

- [x] ~~**`submit` valida o grupo inteiro.**~~ Continua assim, e ficou por
      decisão: em gastos a validação por campo existe por causa dos campos do
      tipo não escolhido, e em ganhos todo campo vale para todo ganho.
- [x] ~~**`income_detail_page.dart`** (274)~~ — **143 linhas**, com o
      `IncomeDetailCardWidget` e o `ActionCardWidget` em `widgets/`.
- [x] **Três controllers viraram um** (07/10): o `IncomeController` (231), no
      desenho do `TagListController`, sem `requestId` nem `silent`.
- [ ] **Os dois diálogos ainda se parecem com os de gasto** (180/130 contra
      217/161), mas divergiram de comportamento: os de ganho mandam a falha para
      o toast e giram no botão; os de gasto recebem `Failure?` do controller e
      aplicam o erro no campo. Ver a ressalva no fim antes de unificar.

## `expenses`

- [ ] **`expense_form_page.dart` (629) e `expense_form_controller.dart` (733) são
      os maiores arquivos do app**, e cresceram desde setembro (541 e 527). O formulário faz cadastro fixo, cadastro
      parcelado e edição, com campos que aparecem e somem. Separar por modo — ou
      ao menos extrair os blocos de campos — é o item de maior retorno da
      feature.
- [ ] **`expense_detail_page.dart`** (445). A escolha de ações por tipo e o
      `_periodLine` são lógica de apresentação misturada com layout.
- [ ] **Quatro diálogos na mesma pasta**, dois deles parecidos com os de ganho —
      e hoje com outro tratamento de erro (ver `incomes`).
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

## `projection` — removida

A feature inteira saiu em 11/09/2026, com a A13 do dashboard. Os dois itens que
estavam aqui (`projection_page.dart` e o teste de desenho do `ProjectionChart`)
foram junto.

## `tags` — ✅ refatorado

- [x] **`tag_list_page.dart` caiu de 359 para 172 linhas**, com `TagTile` (144) e
      o diálogo de criação (156) em `widgets/` e o controller em 157. Era a maior
      tela fora de gastos; hoje não está entre as vinte maiores.

## `notifications`

- [ ] **Tela de aviso, não feature.** Vira código de verdade quando a Etapa 8 do
      backend existir. Nada a refatorar antes disso.

## Testes

- [ ] **`fixtures/mocks.dart` foi de 566 para 874 linhas** e tem os mocks e stubs
      de seis repositórios e do `NavigationService`. Dividir por feature (`mocks/expense_mocks.dart`…) e
      manter um `mocks.dart` que reexporta.
- [ ] **`fixtures/test_injector.dart` foi de 207 para 351** e carrega uma
      divergência conhecida, hoje num controller só: o `ExpenseListController` é
      `registerFactory` aqui e `registerLazySingleton` em produção, então o
      caminho de `dispose` real dele nunca é exercido em teste.
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
- ~~**O gráfico da projeção sem biblioteca.**~~ Saiu com a projeção, em 11/09. O
  dashboard entrou com o `fl_chart` — ver "O gráfico vem do `fl_chart`" no
  `ROADMAP.md`.
- **Um model por arquivo, sem barrel.** Cada consumidor importa a classe que usa.
- **Os tiles separados por feature.** Antes de unificar, note que cada um tem um
  selo com regra própria (parcela `3/10`, "Encerrado", uso do limite). O que dá
  para compartilhar é o layout, não a decisão do que exibir.
