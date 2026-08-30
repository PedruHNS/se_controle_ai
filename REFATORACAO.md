# Quadro de refatoração

Candidatos levantados do código em **25/08/2026**, por feature. Nenhum item é
obrigatório: são pontos onde a repetição ou o tamanho já incomodam, com o motivo
ao lado, para a decisão ser tomada com a conta na mão.

Marque o check conforme for fazendo. Item feito não precisa sair da lista — o
histórico de "o que já foi endireitado" vale tanto quanto o do que falta.

> Antes de puxar um item, veja **Decisões que parecem refatoração e não são**, no
> fim: algumas repetições estão lá de propósito, e desfazê-las por engano custa
> mais que mantê-las.

---

## `core/` — o que atravessa todas as features

- [ ] **`ViewStateBuilder`.** O `switch` de `Loading` / `Failed` / `Loaded`, com
      o `FailureCardWidget` e o `CircularProgressIndicator`, está copiado em
      **9 telas**. Um widget que receba o estado e o `onRetry` corta o mesmo
      bloco de 15 linhas nove vezes. É o item de maior retorno da lista.
- [ ] **Guarda de corrida em um lugar só.** O par `_requestId` + `if (requestId
      != _requestId) return` vive em **9 controllers**, sempre igual. Cabe num
      mixin (`RaceGuard`) ou no `BaseController`. Cuidado: o teste de cada
      controller cobre essa guarda hoje — a extração precisa manter os testes
      passando sem reescrevê-los.
- [ ] **`_applyFailure` em um lugar só.** São **8 cópias**: 3 em controllers de
      formulário e 5 em diálogos. Todas fazem o mesmo — `issues[].path` que
      casa com campo vira erro do campo, o resto sobe como falha geral. Vira
      uma função que recebe `FormGroup` e `Failure` e devolve a mensagem que
      sobrou.
- [ ] **`_serializationFailure` em um lugar só.** Idêntico nos **5
      repositórios**. É função pura de duas linhas; sobe para `core/errors`.
- [ ] **`_ActionCard` compartilhado.** Duplicado entre o detalhe de ganho e o de
      gasto. Vira `core/shared/widgets/action_card.dart`.
- [ ] **`_openAndReload` compartilhado.** As **4 telas de lista** repetem
      "navega, volta, recarrega". Cabe num mixin de `State`.
- [ ] **Quebrar o `injector.dart`** (168 linhas). Ele cresce a cada feature, e
      hoje mistura rede, repositórios e controllers de seis features. Um
      `registerX()` por feature deixa o arquivo raiz com seis linhas.
- [ ] **Quebrar o `app_router.dart`** (219 linhas). Mesma razão: uma lista de
      rotas por feature, montada na raiz.

## `data/`

- [ ] **`ExpenseModel` acumulou dois tipos num só.** Campos de fixo
      (`history`), de parcelado (`installments`, `totalCents`,
      `installmentsCount`) e agora tag e observação. Funciona porque o backend
      garante que só metade vem preenchida, mas a classe já não cabe na cabeça.
      Avaliar um `sealed` com dois filhos — sabendo que isso mexe em toda tela
      de gasto.
- [ ] **`fromJson` manual em 12 models.** Sem codegen é uma escolha do projeto;
      o que dá para melhorar é o `Decode`, que hoje resolve só objeto e lista.
- [ ] **Conferir que nenhum repositório novo trouxe o `_guard` de volta.** O
      helper com closure foi removido em 20/08; o `try/catch` fica escrito em
      cada método.

## `home`

- [ ] **`home_page.dart`** (221 linhas) ainda carrega o `_SummaryContent`
      inteiro. Ele é conteúdo, não estrutura de tela — cabe em `widgets/`.
- [ ] **Três tiles com a mesma anatomia.** `LineItemTile`, `IncomeTile` e
      `ExpenseTile` são "título, subtítulo, valor à direita, selo". Um tile base
      com slots resolveria — mas veja a ressalva sobre tiles no fim.

## `incomes`

- [ ] **`submit` valida o grupo inteiro.** Em gastos a validação passou a ser
      por campo (por causa dos campos do tipo não escolhido); aqui continua
      `form.invalid`. Não está errado, mas são duas formas de fazer a mesma
      coisa no mesmo app — vale escolher uma.
- [ ] **Os dois diálogos são quase iguais aos de gasto** (207/154 linhas contra
      211/158). Ver a ressalva no fim antes de unificar.

## `expenses`

- [ ] **`expense_form_page.dart` (537) e `expense_form_controller.dart` (510)
      são os maiores arquivos do app.** O formulário faz cadastro fixo,
      cadastro parcelado e edição, com campos que aparecem e somem. Separar por
      modo — ou ao menos extrair os blocos de campos — é o item de maior
      retorno da feature.
- [ ] **`expense_detail_page.dart`** (405). A escolha de ações por tipo e o
      `_periodLine` são lógica de apresentação misturada com layout.
- [ ] **Quatro diálogos na mesma pasta**, dois deles gêmeos dos de ganho.

## `credit_cards`

- [ ] **`credit_card_form_controller.dart`** (271). O diff do CAR-08 —
      comparar o formulário com o cartão de abertura e montar os `Patch` — é a
      parte com regra de verdade e está no meio do controller. Extraída, vira
      função pura testável sem `FormGroup`.
- [ ] **`CreditCardExpensesController` dispara três requisições** e monta um
      record. Funciona e está comentado, mas é o único controller do app com
      essa forma — avaliar se vira padrão ou se simplifica.

## `projection`

- [ ] **`projection_page.dart`** (243). `_MonthRow` cabe em `widgets/`.
- [ ] **O `ProjectionChart` não tem teste de desenho.** Hoje é verificado só por
      existir na árvore. Um golden test seria o primeiro do projeto — decidir se
      vale abrir essa porta.

## `tags`

- [ ] **`tag_list_page.dart`** (359). É a maior tela fora de gastos, e concentra
      lista, edição, arquivamento e restauração.

## `notifications`

- [ ] **Tela de aviso, não feature.** Vira código de verdade quando a etapa
      correspondente do backend existir. Nada a refatorar antes disso.

## Testes

- [ ] **`fixtures/mocks.dart`** (566 linhas) tem os mocks e stubs de cinco
      repositórios. Dividir por feature (`mocks/expense_mocks.dart`…) e manter
      um `mocks.dart` que reexporta.
- [ ] **`fixtures/test_injector.dart`** (207) tem o mesmo problema, e ainda
      carrega uma divergência conhecida: os controllers de lista são
      `registerFactory` aqui e `registerLazySingleton` em produção, então o
      caminho de `dispose` real nunca é exercido em teste.
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
  mesmas. É a mesma escolha que o backend fez entre `incomes` e `expenses`.
  Se for unificar, unifique o *esqueleto* (form + envio + erro), não o texto.
- **O `try/catch` escrito em cada método do repositório.** O `_guard` com
  closure foi tirado de propósito em 20/08: o tratamento de erro fica visível
  onde acontece.
- **O gráfico da projeção sem biblioteca.** Sessenta linhas de `CustomPainter`
  contra uma dependência que traz o que a tela não usa. Reabrir só se precisar
  de tooltip, zoom ou várias séries.
- **Um model por arquivo, sem barrel.** Cada consumidor importa a classe que
  usa.
- **Os tiles separados por feature.** Antes de unificar, note que cada um tem um
  selo com regra própria (parcela `3/10`, "Encerrado", uso do limite). O que dá
  para compartilhar é o layout, não a decisão do que exibir.
