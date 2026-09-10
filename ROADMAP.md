# Roadmap — se_controle_ai

App Flutter do controle de gastos, cliente da API `expense-tracker-api`
(Node + Express + Postgres). O backend tem o roadmap dele no
[`README.md`](../expense-tracker-api/README.md).

## Onde estamos

*Atualizado em 09/09/2026.*

Flutter 3.47.1 · Dart 3.13.1 · **550 testes verdes e 11 pulados, nenhum
vermelho** · `flutter analyze` com **1 aviso** (`_createTag` não referenciado —
veja "O que falta").

| Fase | Status |
|---|---|
| 0 Fundação · 1 Resumo · 2 Ganhos · 3 Cartões | **concluídas** |
| 4 Gastos fixos · 5 Parcelados · 6 Projeção · 7 Acabamento | **concluídas** |
| 8 Qualidade | não iniciada — não bloqueia nada, e é por isso que foi pulada |
| 9 Login | **em andamento** — falta só o SHA-1 de release |
| 10 Notificações | bloqueada pela **Etapa 8** do backend |
| 11 Offline-first | bloqueada pela **Etapa 9** do backend |
| 12 Cofrinho | não iniciada — depende da **Etapa 11** do backend |
| 13 Perfil da conta | não iniciada — só a exclusão depende do backend |

O app entra pelo Google (Firebase Auth) antes de qualquer tela; a home mostra o
resumo do mês; ganhos, gastos, cartões e tags têm CRUD completo com reajuste,
correção e encerramento; parcelado tem reparcelamento e quitação; a projeção
mostra para onde o saldo caminha. **O ID token é a única credencial que o app
manda** — a `x-api-key` saiu em 31/08 (decisão 5).

A **Fase 11 é a última por motivo técnico**: offline-first é uma segunda fonte da
verdade, não um cache, e só sai barata com o contrato parado. O **cofrinho**
(Fase 12, decidido em 09/09/2026) é feature nova e mexe no contrato, então na
prática entra **antes** da 11, apesar do número maior — numerar por ordem de
chegada é mais barato que renumerar fase citada em comentário de código.

---

## Um campo só no formulário de gasto (GFX-12) — feito em 10/09/2026

Fica registrado inteiro, e não só como linha de histórico, porque as **perdas
aceitas** no fim são restrições vivas: quem for mexer no formulário depois
precisa saber o que foi trocado por quê.

Decidido em 10/09/2026: o seletor de competência (`A partir de` / `Primeira
parcela`) sai do formulário, e o **dia da compra passa a ser o único campo de
tempo**. A competência vira consequência dele — no cartão pela regra de
fechamento, no débito pelo mês do dia.

O motivo é que as duas perguntas se sobrepõem: quem informa o dia já informou o
mês, e a segunda pergunta só existia porque a primeira era opcional.

**Já resolvido, e é o que tornou a remoção possível:**

- [x] **A regra do fechamento** — `CreditCardModel.invoiceMonthFor`: até o dia
      do fechamento entra nesta fatura, depois dele na próxima.
- [x] **A trava de fatura fechada** — `chargeMonthFor`: nunca lança numa fatura
      que já fechou; cai na primeira aberta.
- [x] **A competência se move sozinha** no cartão (`applyInvoiceMonth`), e a
      correção manual não é desfeita.
- [x] **A tela explica a conta** embaixo do calendário (`spentAtHelper`), com o
      texto mudando quando a fatura da compra já fechou.
- [x] **O calendário soltou da competência** — era preso ao mês escolhido, o
      que bloqueava justamente a compra que precisa mudá-lo.
- [x] **O calendário aceita futuro**, um ano para cada lado, com teto. Sem isso
      não haveria como lançar o IPVA de janeiro depois que o campo de mês sair.
- [x] **O dia aparece em todas as telas** — resumo, fatura, lista e detalhe.
      Sem isso, tirar o mês da tela deixaria a pessoa sem nenhuma pista de
      quando o gasto aconteceu.

**Também resolvido, na virada de 10/09/2026 que tirou o campo:**

- [x] **Dia obrigatório, nascendo em hoje.** `ExpenseFormController.today()`, e
      o `X` que limpava sumiu — num campo obrigatório ele só serviria para
      deixar o formulário inválido de propósito.
- [x] **O débito também deriva.** `derivedMonth` tem três regras: débito é o
      mês do dia, cartão pontual é `chargeMonthFor`, cartão recorrente é
      `invoiceMonthFor`.
- [x] **A conta roda na abertura.** `applyDerivedMonth()` no fim do `start` e
      na troca de forma de pagamento — sem isso o formulário abriria mostrando
      o mês da home, que não manda mais em nada.
- [x] **Recorrente é outra coisa.** Rótulo `Começou em` e trava de fatura
      fechada desligada: cadastrar hoje o aluguel de janeiro é registro
      retroativo, não lançamento novo numa fatura encerrada.
- [x] **O rótulo segue a data.** `IsoDate.isFuture` decide entre `Compra em` e
      `Previsto para` na lista e no detalhe. A linha do resumo mostra a data
      pelada, sem verbo, e por isso não mente em nenhum dos dois casos.
- [x] **O `MonthFieldWidget` saiu dos dois blocos.** O que sobrou no lugar é o
      texto embaixo do calendário, que desde então é a única coisa na tela que
      diz onde o gasto vai cair — `Fecha dia 10 · entra na fatura de outubro
      2026`, ou `Entra na competência de setembro 2026` no débito.
- [x] **Salvar leva a home para o mês onde o gasto caiu**, com um
      `Lançado em outubro 2026`. Sem isso, um almoço de hoje lançado enquanto
      se olha outubro sumiria da tela, e a leitura seria "não salvou".
- [x] **Testes.** 608 verdes.

**Perdas aceitas** (decididas em 10/09/2026, com o levantamento na mão):

- **Carência no parcelado** — comprar em setembro com a primeira parcela em
  dezembro deixa de ser possível, e hoje é. A perda é consciente: no Brasil
  isso é crediário de loja, não cartão. Foi ela que quase justificou manter um
  "ajustar" revelando o seletor escondido; sem ela, não sobrou caso que
  justificasse a segunda pergunta na tela. O reparcelamento não substitui — ele
  mantém as parcelas anteriores ao mês informado e recusa mês posterior ao fim
  do plano.

- **Competência errada não tem conserto.** O `PATCH /expenses/:id` aceita
  descrição, tag, observação, forma de pagamento e cartão — competência não
  está lá, e agora não há campo na tela para corrigir antes de salvar. Dia
  errado, apagar e refazer.
- **Início a mais de doze meses para trás** não é alcançável pelo calendário.

## O que falta

### Dashboard — substitui a projeção

Decidido em 10/09/2026: **a tela de projeção deixa de existir** e o lugar dela
passa a ser um dashboard **mensal**, feito de cards com gráficos. Não é
remodelagem da projeção — é outra tela, com outra pergunta.

A projeção respondia "quanto vou ter juntado". O dashboard responde **"como
está este mês, e quanto ainda posso gastar"**. O que era o assunto inteiro da
tela antiga vira, no máximo, uma linha de contexto.

#### Os sete cards, na ordem da tela

1. **Pode gastar por dia** — o card que justifica a tela. Número grande, com a
   barra da renda consumida embaixo.

   ```
   sobra   = renda da competência − tudo já lançado nela  (= balanceCents)
   por dia = sobra ÷ dias que faltam, contando hoje
   ```

   A sobra já reserva aluguel, assinaturas e parcelas do mês, porque tudo isso
   está lançado na competência — o que resta é dinheiro livre de verdade. E se
   ajusta sozinho: cada avulso cadastrado derruba os dois números.

   Quatro regras que o card não pode errar:

   - **Contar hoje.** Dia 10 de um mês de 30 são 21 dias, não 20. Sem isso o
     valor vive apertado e no dia 30 é divisão por zero.
   - **Saldo negativo troca a frase**, não o sinal: "você já passou R$ 380 do
     que tinha este mês". Número negativo dividido por dias é aritmética certa
     e conselho inútil.
   - **Mês passado mostra a média diária realizada**; mês futuro divide pelo
     mês inteiro, como orçamento; só o corrente fala em "ainda cabe".
   - **É competência, não extrato.** A fatura de setembro é lançada em setembro
     e paga em outubro. O número é "o que sobra da renda deste mês", coerente
     com o resto do app — o número de caixa é outra conta.

2. **Gasto por categoria** — barras horizontais ordenadas da maior para a
   menor, na cor da própria tag, com rótulo direto ao lado (e não legenda).
   É o dado mais valioso que hoje já chega e ninguém soma. **Nada de pizza**:
   com oito categorias vira um disco ilegível.

3. **Ritmo do mês** — linha do gasto acumulado por dia, com a **reta do "ritmo
   que cabe"** por baixo e a curva do mês anterior apagada atrás. Responde, no
   mesmo desenho, "quanto cabe hoje" e "estou acima da linha desde quando".

   A armadilha: a parcela 3/10 é cobrada neste mês mas foi comprada em julho, e
   gasto fixo não tem dia. A curva é só das **compras feitas neste mês**, com
   fixos e parcelas como linha de base — senão metade do mês some do desenho.

4. **Faturas e limite** — uma barra por cartão dentro do trilho do limite.
   Comparar os cartões de relance é leitura que o carrossel da home não dá.

5. **Composição do gasto** — fixo recorrente × parcelado × avulso. Responde
   "quanto do mês já estava vendido antes de ele começar"; dois meses de total
   idêntico podem ser vidas diferentes.

6. **Contexto dos últimos 6 meses** — barrinhas baixas com o mês corrente
   destacado. "R$ 4.200" não significa nada sozinho; significa se for o maior
   dos últimos seis.

7. **Maiores gastos do mês** — top 5 com nome, dia e valor. É o detalhe do
   card 2, e ficou melhor depois da GFX-12, que deu o dia a cada linha.

#### O que fica de fora, e por quê

- **Pizza de qualquer coisa** — comparar ângulos é pior que comparar
  comprimentos.
- **Dois eixos no mesmo gráfico** — é a forma mais fácil de mentir sem querer.
- **Saldo acumulado projetado** — era a tela antiga. Se "quando fico no
  vermelho" ainda importar, cabe como uma linha de texto, não como gráfico.
- **Qualquer coisa que a home já mostra igual** — lista de ganhos, itens de
  fatura. Repetir faz as duas telas parecerem rascunho uma da outra.
- **Reserva ("quero terminar o mês com R$ 500")** — muda o card 1 e precisa de
  onde guardar o valor. É praticamente o cofrinho da Fase 12; fica para lá.

#### O que muda no backend

Uma rota só, `GET /dashboard?month=YYYY-MM`, com tudo agregado:

```
totals       { incomeCents, expenseCents, balanceCents, committedPercent }
allowance    { scope, daysRemaining, perDayCents, overspentCents } → card 1
byTag        [ { id, name, color, amountCents } ]  → card 2
daily        { baselineCents, days[], previousDays[] } → card 3
cards        [ { cardId, label, totalCents, limitCents } ] → card 4
byNature     { recurringCents, installmentCents, oneOffCents } → card 5
history      [ { month, incomeCents, expenseCents } ] (6 meses)  → card 6
topExpenses  [ { description, spentAt, amountCents, installmentLabel } ] → card 7
```

O formato final está em `docs/specs/09-dashboard.md` (B1), com as regras
`DSH-01` a `DSH-25`.

Motivo de agregar lá: `byTag` é um `GROUP BY` de uma linha em SQL e vira
dezenas de linhas de agrupamento no app; `history` sem endpoint são seis
requisições. E `byNature` **não é computável hoje** — os itens do resumo não
carregam o tipo do gasto.

`GET /summary/projection` sai junto com a tela. **Atenção ao APK que está no
telefone**: ele ainda chama essa rota, então ou ela fica de pé até o app novo
subir, ou a tela de projeção do aparelho quebra até a atualização.

#### O que sai do app

`lib/features/projection/` inteira — controller, página e o `ProjectionChart`
—, mais `AppRoutes.projection`, o item do menu, `month_projection_model.dart`
(vira o `history`) e `test/features/projection/projection_test.dart`.

#### O gráfico vem do `fl_chart`

Decidido em 10/09/2026: **`fl_chart`**, e nada de `CustomPainter` novo. O
único gráfico do app até aqui é o da projeção — sessenta linhas à mão, e a
dartdoc dele já dizia que a conta mudava quando aparecesse várias séries ou
interação. Três séries no mesmo desenho e tooltip por toque é exatamente isso,
e a tela antiga sai junto com o painter.

A resolução de hoje dá **`fl_chart 1.2.0`**, que traz `equatable 2.1.0` e
**rebaixa `vector_math` de 2.4.2 para 2.2.0** — conferir a suíte inteira logo
depois de adicionar, porque `vector_math` é dependência do próprio SDK.

Onde ele entra, e onde não:

| Card | Widget |
|---|---|
| 3 · ritmo do mês | `LineChart` — três `LineChartBarData` (real, ritmo que cabe, mês anterior) e tooltip por dia |
| 6 · últimos seis meses | `BarChart` — seis barras, a do mês corrente destacada |
| 1, 2, 4, 5 | widget comum: barra colorida dentro de um trilho |

Os quatro últimos **não são gráfico** — são preenchimento dentro de um trilho,
que em Flutter é um `Container` com `borderRadius`. Passá-los pelo `fl_chart`
custaria mais código para desenhar menos.

#### As tarefas, na ordem de fazer

Cada uma fecha sozinha e deixa a suíte verde. As do backend vêm primeiro
porque a rota destrava os sete cards de uma vez.

**Backend — `expense-tracker-api`, em branch própria**

- [x] **B1 · Spec.** `docs/specs/09-dashboard.md`, `DSH-01` a `DSH-25`, uma
      regra por bloco do payload. Três coisas que ela fechou e que valem para
      as tarefas seguintes:
      **(a)** "compra do mês" é `spentAt` dentro da competência e nada mais —
      então um recorrente entra na curva no mês em que foi cadastrado, e só
      nele; o que sobra vira `baselineCents`, com invariante contra o
      `expenseCents`. **(b)** o card 1 virou o bloco `allowance`, com `scope`
      (`current`/`past`/`future`) dizendo o que o número significa,
      `perDayCents` nulo quando não há o que distribuir e `overspentCents` no
      lugar do negativo. **(c)** entrou `previousDays` no `daily`, que não
      estava no desenho — sem ele o card 3 não desenha a curva do mês anterior.
- [ ] **B2 · `recurring` no `MonthlyExpense`.** É o único dado que hoje não
      existe achatado. **Correção que a B1 trouxe:** não é `v.valid_to IS NULL`
      da vigência que o `generate_series` casou — recorrência é do gasto, e um
      aluguel reajustado tem as vigências antigas fechadas. É um `EXISTS` sobre
      `expense_versions` do gasto (DSH-18), e `false` no ramo parcelado.
      *Pronto quando:* Pg e InMemory concordam, um teste prova que avulso não
      conta como recorrente, e outro que o mês anterior a um reajuste continua
      contando.
- [ ] **B3 · Caso de uso `GetDashboard`.** Compõe o que já existe —
      `findActiveBetween` do mês e dos seis meses, ganhos e cartões — e agrega
      em memória. **Sem SQL novo:** um mês são dezenas de linhas, e o
      `findActiveBetween` já traz tag, tipo, forma de pagamento e `spentAt`.
  - [ ] B3a `byTag` — soma por tag, ordenada da maior para a menor
  - [ ] B3b `byNature` — recorrente × parcelado × avulso
  - [ ] B3c `daily` — só compras com `spentAt` dentro da competência, mais
        `baselineCents` e a série do mês anterior (DSH-11 a DSH-15)
  - [ ] B3d `topExpenses` — cinco maiores, com dia
  - [ ] B3e `history` — seis meses de renda e gasto (o que a projeção fazia)
- [ ] **B4 · Presenter.** `DashboardResponse` com os sete blocos mais o
      `allowance`, centavos inteiros e `YYYY-MM` nas competências.
- [ ] **B5 · Rota.** `GET /dashboard?month=YYYY-MM`, competência corrente por
      padrão, no mesmo schema de mês das outras rotas.
- [ ] **B6 · Testes.** Agregação (mês sem renda, mês vazio, parcela comprada
      em outro mês ficando fora do `daily`, cartão sem limite) e a rota.
- [x] **B7 · Docs.** Feita antes das outras, em 10/09/2026: a rota
      `GET /summary/projection` **foi removida**, e não só marcada — o APK
      instalado vai ser desinstalado, então não havia janela de compatibilidade
      a respeitar. Saíram o handler, o `projectionQuerySchema`, a linha da
      tabela de rotas do README (trocada pela do `/dashboard`) e o `months`
      dos limites de entrada; as regras RES-10 a RES-14 viraram "série mensal"
      e apontam para o dashboard. A classe `GetBalanceProjection` **fica**: é a
      conta do B3e, e continua montada no container e coberta pelo teste.
- [ ] **B8 · Merge e deploy**, com autorização.

**App — `se_controle_ai`**

- [ ] **A1 · `fl_chart 1.2.0` no `pubspec`** e os 610 testes rodando logo em
      seguida, por causa do rebaixamento do `vector_math`.
- [ ] **A2 · Models.** `DashboardModel` e os sete sub-modelos, com `fromJson`
      e teste de contrato contra um payload real capturado do Docker.
- [ ] **A3 · Repositório.** Interface, implementação e o duplo nos fixtures.
- [ ] **A4 · Controller.** Um `ViewState<DashboardModel>`, seguindo o
      `SelectedMonthService` — trocar o mês na AppBar recarrega.
- [ ] **A5 · Casca da tela.** `AppRoutes.dashboard`, item do menu, e a página
      com carregando, erro com "tentar de novo" e pull-to-refresh.
- [ ] **A6 · Card 1 — pode gastar por dia.** Com as quatro regras: contar
      hoje, frase própria no negativo, mês passado e futuro mudando a
      pergunta, competência e não extrato.
- [ ] **A7 · Card 2 — gasto por categoria.**
- [ ] **A8 · Card 3 — ritmo do mês.** `LineChart`, três séries, tooltip.
- [ ] **A9 · Card 4 — faturas e limite.**
- [ ] **A10 · Card 5 — composição do gasto.**
- [ ] **A11 · Card 6 — últimos seis meses.** `BarChart`.
- [ ] **A12 · Card 7 — maiores gastos.**
- [ ] **A13 · Enterro da projeção.** `lib/features/projection/` inteira,
      `AppRoutes.projection`, `month_projection_model.dart`, o item do menu e
      `projection_test.dart`. **Por último**, quando o dashboard já estiver de
      pé.
- [ ] **A14 · Testes de widget** dos sete cards e do controller; `analyze`
      limpo.
- [ ] **A15 · Roadmap e commits.**

### Fase 9 — para fechar

- [ ] **SHA-1 de release.** Sem ele o login funciona no `flutter run` e falha no
      APK publicado. É o único item que separa a fase de concluída.
- [ ] **Não há como revogar acesso.** Nem rota nem coluna — o `approved_at`
      existiu por um dia e saiu com a `009`. Quem entrou, entrou. Apagar a
      identidade no console do Firebase impede novos logins e deixa a linha e os
      dados no banco; é o mais perto que existe.

### Dívidas sem fase

- [ ] **O botão "nova categoria" está comentado** no formulário de gasto
      (`expense_form_page.dart:176`), e é ele o único aviso do `analyze`
      (`_createTag`, declarado na 510):
      `_createTag` existe, tem teste de controller passando e **não tem como ser
      chamado pela tela**. Ou o botão volta, ou a função sai — hoje "criar tag
      sem sair do formulário" está no código e não no app.
- [ ] **A home recarrega a cada volta, mesmo sem mudança.** O `routeObserver`
      chama `refresh()` no `didPopNext`, e isso são cinco requisições toda vez
      que você volta do menu — mesmo tendo só olhado. A alternativa desenhada
      em 10/09/2026 e adiada: um contador de escritas alimentado por um
      interceptor do Dio (todo método que não seja `GET` incrementa), a home
      guardando o valor de quando carregou e comparando no retorno. Deixado
      para quando o custo incomodar.
- [ ] **Três comentários citam "Fase 10" para offline-first** (`app.dart`,
      `selected_month_service.dart`, `theme_controller.dart`). Offline-first é
      a **11**; a 10 é notificações.
- [ ] **Trocar o FAB da home pelo `flutter_expandable_fab` 3.0.0.** Hoje o menu
      é feito à mão em `home_fab.dart` (144 linhas): `AnimationController`,
      `CurvedAnimation` e um `didUpdateWidget` que segue o `expanded` vindo de
      fora, mais a cortina que a `HomePage` desenha por conta própria — é por
      ela que existe o `fabMenuDuration` exportado, para as duas animações
      terminarem juntas. A lib faz o menu **e** o escurecimento no mesmo widget,
      e a versão a fixar é a **3.0.0** (ainda não está no `pubspec`). Ao trocar,
      decidir o que acontece com o estado controlado — o `_fabExpanded` mora na
      `HomePage` (`home_page.dart:36`) — e refazer o `home_fab_test.dart` (106
      linhas), que acha as ações pelo ícone. Sem pressa: o botão de hoje
      funciona e está coberto.
- [ ] **Fase 8 — Qualidade.** Testes de model, repositório, controller e widget
      nas telas principais, com `flutter analyze` sem issue como porta de
      entrada. Boa parte já entrou junto com cada fase; o que a fase 8 seria hoje
      é fechar as lacunas anotadas em cada uma.

### Obrigações da Play

A publicação está a uns 6 meses, então nada disso é para agora — mas a exclusão
de conta encosta em todas as tabelas, e é a que menos aceita ficar para o fim.

A tela que hospeda as duas primeiras é a **Fase 13**, o perfil da conta.

- [ ] **Exclusão de conta.** Obrigatória para todo app que cria conta, dentro do
      app **e** por link web acessível sem instalar. Não existe rota, e as FKs
      são `ON DELETE RESTRICT` em 8 tabelas: é spec nova, com ordem de remoção
      definida.
- [ ] **Política de privacidade e formulário de Data Safety**, porque o app
      coleta e-mail e nome pelo Google. Página estática, o Caddy serve.
- [ ] **Firebase App Check.** É o que substitui a chave de API sem embutir
      segredo no binário, mas a atestação exige um build que o Google reconheça
      — só vale a pena com track interno na Play.

### Lacunas de teste conhecidas

- **Fake não protege a camada que ele substitui.** Os testes de tela entram pelo
  repositório fake e seguiram verdes com o `ApiClient` quebrado. Quem guarda essa
  fronteira é `api_client_test.dart`, com `HttpClientAdapter` trocado — método
  novo no client entra com caso novo no grupo `devolve o Response do Dio`.
- **O `dispose` de produção não é exercitado.** No `test_injector` os controllers
  de lista são `registerFactory`; em produção são `registerLazySingleton` com
  `dispose:`. Divergência de propósito, mas o caminho real fica sem prova.
- **O `ProjectionChart` é verificado só por existir na árvore.** Comparar pixel
  exigiria golden test, que o projeto não usa em lugar nenhum.
- **O rateio de parcelas não é testado aqui**, de propósito: está coberto no
  backend, exaustivamente. Reimplementar duplicaria conhecimento.

---

## Refatoração

Situação por feature, conferida contra o código em **05/09/2026**. O detalhe de
cada item — e a lista de repetições que estão lá **de propósito** — fica em
[`REFATORACAO.md`](REFATORACAO.md).

| Feature | Status | O que ainda pesa |
|---|---|---|
| `tags` | ✅ **refatorado** | Nada. A tela caiu de 359 para 172 linhas, com `TagTile` e o diálogo de criação extraídos |
| `core` (DI) | ✅ **refatorado** | `injector.dart` virou 79 linhas com um `part` por camada (rede, repositórios, controllers, services) |
| `core` (resto) | 🟡 parcial | `ViewStateBuilder` não existe — o `switch` de `Loading`/`Failed`/`Loaded` com `FailureCardWidget` e `CircularProgressIndicator` está em **11 telas** (eram 9 em 25/08), e é o item de maior retorno do app. Faltam também `RaceGuard` (7 controllers, era 8), `applyFailure` (8 cópias), `serializationFailure` (5), `ActionCard` (2 detalhes), `openAndReload` (4 listas), e `app_router.dart` (291) por feature |
| `auth` | 🟡 parcial | A parte com regra já saiu do router: `rotaParaEstado` em `auth_gate.dart` (48 linhas, 14 testes). O que sobra é tela — `login_page` 209, `auth_repository` 225 |
| `expenses` | ⬜ pendente | **Os dois maiores arquivos do app**: `expense_form_page` (548) e `expense_form_controller` (527), que fazem cadastro fixo, cadastro parcelado e edição num só lugar. `expense_detail_page` (419) mistura escolha de ação por tipo com layout |
| `home` | ⬜ pendente | `home_page.dart` **cresceu para 364** (eram 297 em 01/09) e ainda carrega o `_SummaryContent` inteiro — é conteúdo, não estrutura de tela |
| `incomes` | ⬜ pendente | `income_detail_page` (274). E o `submit` valida `form.invalid`, enquanto gastos valida por campo: duas formas para a mesma coisa |
| `credit_cards` | 🟡 parcial | **Um controller só (04/09):** o `CreditCardFormController` deixou de existir e virou o lado de formulário do `CreditCardController` (165). O diff do CAR-08 saiu junto — a edição manda o cartão inteiro, e o `Patch<T>` não é mais usado aqui. O `CreditCardExpensesController` caiu de 3 buscas para 1 e de record para model: 78 linhas. A tela dele tem 254 |
| `projection` | ⬜ **em remodelagem** | `projection_page` (243) — `_MonthRow` cabe em `widgets/`. Sem teste de desenho. A feature inteira vai ser remodelada (05/09); refatorar antes do desenho novo é trabalho jogado fora |
| `data` | ⬜ pendente | `ExpenseModel` (219) acumula os dois tipos de gasto num só; avaliar `sealed` com dois filhos, sabendo que mexe em toda tela de gasto. `fromJson` manual em 12 models |
| `test/fixtures` | ⬜ pendente | **Segue piorando**: `mocks.dart` foi de 566 (25/08) para **853** e `test_injector.dart` de 207 para **314**. Dividir por feature e manter um arquivo que reexporta |
| `notifications` | — | Só o estado vazio. Vira código de verdade com a Etapa 8 do backend; nada a refatorar antes |

---

## Stack

| Lib | Versão | Papel |
|---|---|---|
| `dio` | ^5.11.0 | HTTP: baseUrl, timeouts, interceptors |
| `multiple_result` | ^5.3.0 | `Result<Sucesso, Falha>` — erro como retorno, não exceção |
| `get_it` | ^9.2.1 | Service locator: Dio, ApiClient, repositórios, controllers |
| `go_router` | ^17.5.0 | Navegação declarativa por rota nomeada + deep link |
| `signals` | ^7.1.0 | Estado reativo: `signal` no controller, `SignalBuilder` na view |
| `reactive_forms` | 18.2.2 | Campo, validação e erro como estado, não como widget |
| `pretty_dio_logger` | ^1.4.0 | Log de requisição em debug, só quando `AppConfig.logHttp` |
| `firebase_core` | ^4.14.0 | Inicializa o SDK antes do `runApp` |
| `firebase_auth` | ^6.6.0 | A sessão: guarda, restaura e renova o ID token |
| `google_sign_in` | ^7.2.0 | A escolha de conta do Android |
| `mocktail` | ^1.0.5 | Dev: mocks de repositório e do `HttpClientAdapter` |

---

## Convenções

Toda feature nova copia estas escolhas. Elas são o que mantém o app com uma
forma só de fazer cada coisa.

### Erro: exceção na infra, valor na aplicação

```
Dio --DioException--> exception_mapper --AppException--> ApiClient (lança)
                                                              |
                          repositório: try/catch + decode  <--+
                                                              |
                                        Result<T, Failure>  <-+ --> controller/UI
```

- **Repositório é o único lugar com decode e com `try/catch`.** Nunca escreva
  `try/catch` em controller ou widget.
- **`AppException` só circula entre `ApiClient` e repositório**; `Failure` só
  circula dali para cima. `AppException` num widget significa camada furada.
- **O decode fica dentro do `try`, com um `catch` genérico depois do
  `on AppException`** — que não pega o `TypeError` de um cast. Sem essa rede, um
  contrato quebrado no backend viraria crash em vez de `Failure`.
- **O `try/catch` fica escrito em cada método**, não num helper com closure — o
  `_guard` foi removido em 20/08 de propósito. O único trecho compartilhado é o
  `_serializationFailure`, função pura de duas linhas.
- O mapper **classifica** (qual falha técnica), o `Failure` **traduz** (o que a
  pessoa lê). É como um 500 com `TypeError` vira "O servidor falhou ao
  processar" na tela e guarda o stack do Node em `failure.exception`.

### `ApiClient` devolve `Response`, não JSON cru

O corpo está em `response.data`, e **esquecer o `.data` é silencioso**: o retorno
é `dynamic`, então passa pelo `analyze` e só aparece como `TypeError` em runtime
— capturado pelo `catch` genérico e servido como `SerializationFailure`, ou seja,
tela de erro sem pista da causa. Já quebrou a home uma vez.

```dart
final response = await _api.get('/summary', queryParameters: {'month': month});
return Success(MonthlySummaryModel.fromJson(Decode.object(response.data)));
```

### Controller

- **`registerLazySingleton`, e quem libera é o get_it.** A página faz
  `getIt<XController>()` e **não** chama `dispose`. Quando a mesma rota pode ser
  empilhada duas vezes com estados diferentes, vira `registerFactory` e o
  `dispose` passa para o `State` — é o caso do formulário e do detalhe de ganho.
- **No construtor entram só dependências — repositório ou service. Nunca um
  valor.** Nem id, nem mês, nem filtro. Dado de rota é entregue **pela view**,
  depois da construção: `controller.start(widget.id)` no `initState`.
  Consequência aceita: esse controller não busca no `onInit`, porque ali o valor
  ainda não chegou. `registerFactoryParam` não é usado em lugar nenhum.
- **`Result` é consumido com `.when`, nunca com `switch`.** Uma forma só. Efeito
  colateral bem-vindo: o controller não importa `multiple_result`.
- **Todo controller que busca tem a guarda de `_requestId`.** Duas buscas em voo
  voltam fora de ordem, e sem o contador a resposta velha ganha da nova.

  ```dart
  final requestId = ++_requestId;
  ...
  if (requestId != _requestId) return;   // resposta atrasada: descarta
  ```
- **Ação disparada de dentro de diálogo devolve `Failure?`**, em vez de guardar
  em signal: o erro precisa aparecer no diálogo, e a tela de trás continua certa
  — quem falhou foi a ação, não a busca.

### Cadastro sem recarregar

O `POST` devolve o **objeto inteiro**, não o id (CAR-10 no backend; tag já era
assim). O controller insere o que voltou na lista que já está na tela, e ninguém
volta ao servidor para ler o que acabou de escrever.

**Cartão entra no fim, sem ordenar.** Tag é ordenada alfabeticamente porque a
lista dela é um vocabulário que se consulta pelo nome. Cartão é um punhado de
itens reconhecidos de relance, e reordenar faria o recém-criado pular para o
meio no instante em que a pessoa o procura.

**Lista e formulário no mesmo controller.** Separados, o formulário salvava num
lugar e a lista relia de outro, e a única forma de concordarem era uma volta ao
servidor. O preço é o reset no começo do `startForm`: o controller agora
sobrevive entre uma abertura e a seguinte, e sem limpar, cadastrar depois de
editar abriria a tela com o cartão anterior nos campos.

### Menu de ações do card

O `more_vert` com **Editar** e **Excluir** estreou na `TagTile` e agora é também
o do `CreditCardWidget`: `PopupMenuButton` com `tooltip: 'Mais opções'`, o item
de excluir pintado com `colorScheme.error`, e `enabled` amarrado a ter ao menos
um callback — o esqueleto do `Skeletonizer` passa os dois nulos e o menu nasce
desligado sozinho.

**Uma ação mora em um lugar só.** Editar cartão saiu da AppBar da fatura quando
entrou no menu do card: a lista conhece o cadastro, a fatura é sobre o mês.

### Formulário

- **É estado, não widget.** O `FormGroup` mora no controller com os campos e as
  regras declarados uma vez; a view só faz `bind` pelo nome.
- **Dinheiro é `FormControl<int>` em centavos**, com o `MoneyValueAccessor`.
  `double` não aparece em ponto nenhum do caminho.
- **`issues[].path` de um 400 vira `setErrors({'backend': mensagem})`** no
  control de mesmo nome, e se limpa na validação seguinte. `path` que não casa
  com campo sobe como falha geral.
- **A validação é por campo, não pelo grupo** (em gastos): os campos do tipo não
  escolhido nascem vazios e travariam o `form.invalid`. Ganhos ainda valida o
  grupo inteiro — é a divergência anotada na tabela de refatoração.
- **Competência e dia são seletor de setas, nunca campo de texto.** Nascem
  válidos por construção, e o `minMonth` trava no que a regra do backend
  permitiria: requisição que voltaria 422 nem sai.
- **A máscara de moeda ao vivo não entra** (decidido na Fase 7). O campo já tem
  prefixo, teclado numérico e filtro; reformatar enquanto digita briga com o
  `reactive_forms` e dá cursor pulando. Reabrir só com reclamação concreta.

### Model e navegação

- **Todo model termina em `Model`**, um por arquivo, **sem barrel**. O sufixo
  separa o dado do widget de mesmo assunto: `CreditCardInvoiceModel` é o dado,
  `CreditCardInvoiceCard` é a tela.
- **O menu lateral mora só na home**, que é a única tela não empilhada. Os itens
  navegam com `pushNamed` (não `go`), para o "voltar" devolver à home, e fecham o
  menu antes de navegar.
- **A competência é do app, não da home.** `SelectedMonthController` é
  `lazySingleton` em `core/month`: abrir Gastos em setembro e ver o total de
  agosto seriam duas telas com fontes diferentes. Não persiste — guardar exige
  armazenamento local, que chega na Fase 11.
- **O tema tem três opções no menu** (`ThemeController`), com "Sistema" como
  padrão, e também não persiste, pelo mesmo motivo.
- **As rotas ficam com a transição padrão da plataforma.**
  `CustomTransitionPage` remove o gesto de voltar deslizando no iOS — seria
  trocar função por enfeite. O que ganhou animação foi a troca entre carregando,
  erro e conteúdo, via `StateTransition`.

---

## O contrato do backend

Dinheiro **sempre em centavos (int)**; competência **sempre string `YYYY-MM`**.

**Toda rota exige `Authorization: Bearer <ID token>`, menos `/health`** (AUT-05).
Não há rota de login, cadastro, refresh nem logout — a identidade vem do
Firebase. A única rota que a Etapa 7 acrescentou é `GET /me`.

- **401** é token ausente, expirado ou inválido; o interceptor renova e repete
  **uma** vez antes de deixá-lo subir.
- **403 não existe.** "Não é você" é 401, "não é seu" é 404, e não há terceiro caso.
- **Nenhum corpo de resposta tem `userId`** — o dono é implícito.
- **Mutação responde 204, sem corpo.** Quem precisa do estado novo relê. Só
  `POST` de criação foge disso, com 201 e o corpo do que foi criado.
- **A ordem dos itens do resumo é contrato.** Dentro de cada competência, do
  lançamento criado mais recentemente para o mais antigo, com a descrição como
  desempate. É o que permite à home cortar a lista nas primeiras linhas sem
  esconder o que acabou de ser cadastrado — e é por isso que o app **não**
  reordena: `createdAt` não vem no payload.

### Resumo
| Método | Rota | Observação |
|---|---|---|
| GET | `/summary?month=` | Sem `month`, usa o mês corrente. Devolve `incomeCents`, `expenseCents`, `balanceCents`, `committedPercent`, ganhos, `debit` e `creditCards[]` com a fatura de cada cartão |
| GET | `/summary/projection?from=&months=N` | `N` de 1 a 60, default 12 |

### Ganhos
| Método | Rota | Semântica |
|---|---|---|
| POST | `/incomes` | `{description, amountCents, startMonth, recurring?, tagId?}` |
| GET | `/incomes?month=` · `/incomes/:id?month=` | `amountCents` = valor vigente no mês |
| POST | `/incomes/:id/adjustments` | **Reajuste**: preserva os meses anteriores |
| PATCH | `/incomes/:id/amount` | **Correção**: o valor estava errado desde o início |
| POST | `/incomes/:id/closure` | `{lastMonth}` — parei de receber |
| DELETE | `/incomes/:id` | |

**Reajuste e correção são operações diferentes**, e a UI precisa deixar isso
explícito — não são dois caminhos para "editar valor".

### Gastos
| Método | Rota | Semântica |
|---|---|---|
| POST | `/expenses` | Discriminado por `type`: `FIXED` ou `INSTALLMENT`. `tagId` **obrigatório**, `notes` e `spentAt` opcionais |
| GET | `/expenses?month=&type=&paymentMethod=&creditCardId=` | Filtros combináveis |
| GET | `/expenses/:id?month=` | |
| PATCH | `/expenses/:id` | Só descrição/tag/observação/forma de pagamento |
| POST | `/:id/adjustments` · PATCH `/:id/amount` · POST `/:id/closure` | Só `FIXED` |
| POST | `/:id/reschedule` · POST `/:id/settlement` | Só `INSTALLMENT` |
| DELETE | `/expenses/:id` | |

**Os dois tipos não compartilham operação de dinheiro.** `FIXED` tem vigências
(`history`), `INSTALLMENT` tem parcelas (`installments`), e o campo do outro tipo
vem `null`. O tipo é escolhido no cadastro e nunca muda — o backend nem oferece a
operação.

**GFX-12 — o dia da compra (`spentAt`).** Opcional no cadastro; quem não informa
recebe o instante em que cadastrou. Volta em toda leitura de gasto **e em toda
linha do resumo** (`items[].spentAt`, nulo em ganho), sempre em ISO 8601 com
fuso — é a única data do contrato que não é `DATE`, porque é instante. Do lado
do app ela é convertida uma vez, em `IsoDate.fromInstant`, e daí em diante
circula como `YYYY-MM-DD`: cortar a string em dez caracteres daria o dia em UTC,
e às 21h de Brasília isso já é amanhã.

**No cartão, é o dia que decide a fatura** — e nunca uma fatura já fechada.
São duas contas, nesta ordem (`CreditCardModel`):

1. `invoiceMonthFor` — onde a compra **caberia**: até o dia do fechamento, na
   fatura que fecha naquele mês; do dia seguinte em diante, na próxima.
2. `chargeMonthFor` — onde ela **cabe**: a da conta acima, ou a primeira ainda
   aberta hoje, se aquela já fechou.

O formulário aplica as duas sozinho e move a competência, explicando a conta
embaixo do calendário. Sem a segunda, um cartão que fecha dia 1 mandava a
compra lançada no dia 10 para a fatura de setembro, fechada nove dias antes: a
primeira parcela caía num mês encerrado e a segunda no mês corrente (visto em
10/09/2026, cartão "Teste", `closing_day = 1`).

Cinco consequências aceitas, e nenhuma delas é bug:

- **O calendário só olha para trás**: de doze meses atrás até hoje, porque não
  há como ter comprado numa data que ainda não chegou. Substituiu a primeira
  versão, presa ao mês da competência — prender o calendário à competência
  bloquearia justamente a compra que precisa mudá-la.
- **A competência continua editável à mão.** O cálculo só roda quando muda o
  dia, o cartão ou o tipo: um campo que se corrige sozinho depois de a pessoa
  corrigi-lo é campo brigando com quem o edita.
- **A compra atrasada entra na fatura aberta**, e não naquela em que ela foi
  cobrada de verdade. Entre mexer numa fatura fechada e adiar para a aberta, a
  segunda é a que ainda dá para pagar.
- **A regra mora no app, não no backend.** Um gasto criado por fora — outro
  cliente, uma versão antiga — ainda pode cair na fatura errada, porque o
  backend continua tratando a competência como escolha explícita de quem chama.
- **Backend sem a GFX-12 no ar não quebra o app.** `spentAt` chega nulo, e a
  linha da data some da tela em vez de estourar no `build`.

### Tags
| Método | Rota | Semântica |
|---|---|---|
| POST | `/tags` | `{name, color}` → a tag inteira + `restored`. **A cor é obrigatória** desde a migration `010`. Nome repetido ignorando caixa é 409; nome de arquivada ressuscita aquela linha (TAG-17) com o `usageCount` que ela tinha |
| GET | `/tags?includeArchived=` | Por nome, com `usageCount`. Sem o parâmetro, só as ativas |
| POST | `/tags/:id` | **Substitui**: nome e cor vão sempre os dois, e omitir um é 400. Devolve a tag pronta, para a tela trocar a linha sem recarregar |
| DELETE | `/tags/:id` | Sem uso apaga; em uso **arquiva**. 200 com `{archived}` |
| POST | `/tags/:id/restore` | Traz a arquivada de volta |

**A tag é a categoria, e é obrigatória no gasto** — `category`, que era texto
livre, não existe mais. No ganho é opcional. Arquivada continua nos lançamentos
que já a usam e sai das escolhas de lançamento novo (422).

**"Sem cor" não é mais um estado.** A `010` tornou a cor obrigatória (revisando a
TAG-02) porque a paleta do diálogo é o único jeito de mexer nela: sem valor
sempre presente, dava para pôr cor e não para tirar. Some com isso qualquer
`Patch` no caminho de tag — o app já manda os dois campos.

**O backend guarda um retrato do rótulo** em cada lançamento
(`tag_name_snapshot`, `tag_color_snapshot`, migration `007`, TAG-16), e **nada o
lê ainda** — nem aqui, nem lá. Renomear tag continua valendo para trás (TAG-03).
O retrato existe para que essa decisão possa ser revista com o dado já coletado;
o app não deve começar a usá-lo sem que o backend passe a devolvê-lo.

### Cartões
| Método | Rota | Observação |
|---|---|---|
| POST · GET · GET/:id · DELETE/:id | `/credit-cards` | `?month=` resolve `dueDate` e `totalCents` |
| POST | `/credit-cards/:id` | Edição. Responde **200 com o cartão**, não 204 |
| GET | `/credit-cards/:id/invoice?month=` | O cartão, os gastos da fatura e o total. **`month` obrigatório** |

**Dígito vazio é traduzido pelo backend, não pelo app (09/09).** O campo de
texto devolve `''` depois de tocado, e é o `optionalDigitsSchema` que lê `''`,
`'   '`, `null` e campo ausente como a mesma coisa (CAR-01). O controller manda
o que está no campo — normalizar dos dois lados seriam duas verdades para a
mesma regra, e a segunda envelheceria calada.

**A edição é `POST` e não `PATCH` (04/09).** O corpo traz o cartão inteiro e ele
passa a ser aquilo — não é remendo. Some com isso a distinção entre campo ausente
e campo `null` que o CAR-08 exigia: os dois anuláveis têm `default(null)` no
schema, então omiti-los limpa. O `Patch<T>` continua existindo para gastos, mas
**não é mais usado em cartões**, e com ele saiu o `_cardOnOpen` do controller.

**A fatura é uma rota só (05/09).** Antes a tela do cartão pedia `/credit-cards/:id`
e `/expenses?creditCardId&month` lado a lado e somava o total no cliente. O
`totalCents` da resposta é a soma dos `expenses` que ela mesma devolve — e não o
`totalCents` do cartão — para o cabeçalho da tela nunca discordar das linhas
abaixo dele.

### Erros
Envelope único: `{code, message, issues?: [{path, message}]}`.

| Status | Significa | O que a UI faz |
|---|---|---|
| 400 | Dados inválidos (zod) | `issues[].path` → erro embaixo do campo |
| 404 | Não existe | Volta e avisa que sumiu |
| 409 | Vigências sobrepostas | Explica o conflito |
| 422 | Regra de negócio violada | Mensagem do backend, direto |
| 5xx | Falha do servidor | "Tente novamente" |

---

## Fases

Ordem escolhida para que cada fase só dependa das anteriores, e para que a
primeira tela já valide a stack inteira antes de existir formulário.

| Fase | Entregou | Provado quando |
|---|---|---|
| **0** Fundação | `core/` inteiro: config, rede, erros, DI, router, `ViewState`, `Money`, `Month` e o padrão de controller | `/health` devolveu `Success`, e 404/400 reais viraram `NotFoundFailure`/`ValidationFailure` com as issues do zod |
| **1** Resumo | `GET /summary`, navegação de mês, cartão de saldo, fatura por cartão, os três estados e pull-to-refresh que não pisca | A home mostrou o mês corrente com dados reais e trocar de mês refez a busca sem travar |
| **2** Ganhos | CRUD, reajuste e correção como ações distintas, histórico de vigências, `MoneyField` e `MonthField` | Ganho de 3.000 reajustado para 4.000 em 2026-08: maio ficou em 800.000 e agosto foi para 900.000; reajuste retroativo voltou 422 |
| **3** Cartões | CRUD, seletor de dia, limite limpável, `Patch<T>` do CAR-08, 409 do CAR-07 no diálogo | `PATCH` só com o nome deixou dígitos e limite intactos; com `limitCents: null` limpou o limite e não tocou nos dígitos |
| **4** Gastos fixos | `FIXED` no débito ou no cartão, edição cadastral, o motor de vigência de ganhos reaproveitado, e a **tela do cartão** | Aluguel de 1.200 reajustado para 1.350 em julho: junho devolveu 120000 e julho 135000 |
| **5** Parcelados | `INSTALLMENT` no mesmo formulário, plano de parcelas, reparcelamento e quitação; as ações de um tipo somem no outro (GPR-17) | Geladeira de 3.000 em 10x reparcelada para 4.000 em 12x: as 4 primeiras seguiram a 300 e as 8 novas saíram a 350 |
| **6** Projeção | Saldo acumulado em gráfico e lista, horizonte de 6/12/24 meses, aviso do primeiro mês no vermelho | Com um gasto de 50.000 em agosto a projeção afundou e voltou sem cruzar o zero, e o aviso apontou o mês certo |
| **7** Acabamento | Tema claro/escuro do mesmo seed, `StateTransition` em 8 telas, `EmptyStateWidget` com o scroll embutido, identificador `com.secontroleai.app` nos **dois** sistemas | Conferido no APK compilado, não só no fonte |
| **9** Login | Firebase Auth só pelo Google, `AuthInterceptor` com Bearer, `redirect` alimentado pelo `AuthRefresh`, tela de espera na abertura, sair no menu, 38 testes | Login provado em aparelho em 27/08: 401 sem token, 200 com ele |

**Três decisões da Fase 6 que continuam valendo:** o gráfico é `CustomPainter` de
sessenta linhas, sem biblioteca (reabrir só se precisar de tooltip, zoom ou
várias séries); a barra é o **acumulado**, não o saldo do mês, e a escala inclui
sempre o zero; e a tela avisa que a conta começa do zero, porque o backend não
sabe o que existe em conta.

**Duas da Fase 9:** o `redirect` é alimentado por `authStateChanges()`, não por
`idTokenChanges()` — a navegação precisa saber se **há alguém**, e o segundo
dispararia de hora em hora a cada renovação. E o `AuthRefresh` guarda um
**contador**, não o usuário: com o usuário dentro, o primeiro evento de quem não
está logado seria `null → null`, mudança nenhuma, e o app ficaria preso na espera
para sempre. A decisão em si virou `rotaParaEstado`, função de quatro entradas em
`auth_gate.dart`, com 14 testes — pelo router ela só era alcançável com injetor
montado e router global, e aí a falha não diz qual combinação quebrou.

**Sem armazenamento de token, e é a economia grande da Fase 9.** O SDK guarda a
sessão em armazenamento seguro da plataforma e renova o ID token sozinho. Cai
fora o `flutter_secure_storage`, cai fora guardar refresh, e **cai fora o
interceptor single-flight** — a parte genuinamente difícil nos dois desenhos
anteriores desta fase.

### Fase 10 — Notificações
Depende da **Etapa 8 do backend**, e não começa antes: quem decide *quando*
notificar é o servidor. Com o app fechado não existe timer que o sistema garanta
— o Android mata alarme exato em Doze e o iOS não roda código arbitrário em
background —, e o que dispara estes avisos muda o tempo todo.

- `firebase_messaging` para o push e `flutter_local_notifications` para exibir em
  foreground, onde o FCM **não** desenha nada sozinho
- Permissão (iOS sempre; Android 13+ pelo `POST_NOTIFICATIONS`), com o app
  funcionando inteiro sem ela
- Registro do token a cada abertura e a cada `onTokenRefresh`, **junto com o fuso
  do aparelho** — "3 dias antes do dia 17" é uma janela diferente em cada fuso
- Handler de background com `@pragma('vm:entry-point')`, que roda em isolate
  separada e **não enxerga o `getIt`** do app
- Toque na notificação abre a tela certa: o payload leva rota e id
- Tela de preferências: quais avisos, e com quantos dias de antecedência

**Pronto quando:** com o app **fechado**, uma fatura que vence em três dias chega
como notificação, e tocá-la abre o cartão certo.

### Fase 11 — Offline-first
Depende da **Etapa 9 do backend**. É a última de propósito: não é um cache que se
liga no fim, é uma segunda fonte da verdade, com escrita própria, e cada tela
passa a existir em dois modos.

- **Base local** (drift, provavelmente), com as mesmas tabelas e um `updated_at`
  por linha
- **Leitura cache-first**: a tela abre com o disco e revalida depois. O
  `Result<T, Failure>` já é a costura — a UI não muda, quem muda é o repositório
- **Escrita por outbox**: a mutação grava local, entra na fila e a tela responde
  na hora; um sincronizador esvazia a fila com retry
- **Sincronização por delta**, com `?since=` e **soft delete** no backend

Quatro problemas que só existem nesta fase:

1. **O id deixa de vir do backend.** Item criado offline precisa de id antes de
   existir no servidor: o app gera UUID e o `POST` tem de aceitá-lo de forma
   idempotente.
2. **Vigência não aceita last-write-wins.** Dois aparelhos reajustando o mesmo
   gasto geram vigências sobrepostas, e o `EXCLUDE USING gist` recusa a segunda —
   corretamente. Precisa de política explícita, provavelmente rejeitar e mostrar
   o conflito a quem escreveu.
3. **O resumo é derivado, e o app não sabe derivá-lo.** `buildMonthlySummary`
   mora no backend; portá-lo duplicaria conhecimento. A saída barata é cachear a
   resposta por competência e marcar quando ela é velha, e é a certa até prova em
   contrário.
4. **"Atualizado quando?" vira informação de tela.** Um número velho sem aviso é
   pior que tela de erro.

**Pronto quando:** com o Docker desligado, o app abre, mostra o mês avisando que
está desatualizado, aceita cadastrar um gasto, e ao religar o backend o gasto
aparece lá sem duplicar.

### Fase 12 — Cofrinho

Guardar dinheiro com destino: a pessoa define uma **meta** (nome, valor-alvo e,
se quiser, o mês em que quer chegar lá) e vai **registrando o que guardou**. O
progresso é a soma do que entrou, e a tela mostra quanto falta.

Depende da **Etapa 11 do backend** — a meta e os depósitos são dado do servidor,
como todo o resto.

- Lista de cofrinhos com barra de progresso: é a mesma barra do limite do cartão
  (`CreditCardWidget`), com o alvo no lugar do limite
- Detalhe com o histórico de depósitos, e o menu `more_vert` de editar/excluir
  que já é padrão em tag e cartão
- Formulário de meta com `MoneyField` para o alvo e `MonthField` (opcional) para
  o prazo — os dois já existem, e o seletor de mês já nasce válido
- Ação **"guardar"** num diálogo: valor e competência. Ação de dentro de diálogo
  devolve `Failure?`, como manda a convenção de controller
- **Retirar é operação própria**, não depósito negativo: o histórico precisa
  dizer o que houve, e "-200" não diz

**A decisão que trava as outras: o que é guardado sai do mês?** Se sair, o
`/summary` desconta e a projeção acompanha — o dinheiro guardado realmente não
está disponível para gastar. Se não sair, o saldo do mês passa a mentir para
quem usa cofrinho, e o app ganha dois números que não fecham. A inclinação é
**sair, em seção própria** — nem ganho, nem gasto —, mas é decisão do backend
junto com o `buildMonthlySummary`, e é ela que diz se esta fase mexe na home e
na projeção ou só acrescenta tela.

**O que não fazer: reaproveitar `expenses`.** Cofrinho não tem vigência nem
parcela, e enfiá-lo no `ExpenseModel` — que já acumula dois tipos e está na fila
de refatoração — piora os dois lados. Módulo próprio, do model à tela.

**Pronto quando:** uma meta de R$ 5.000 para dezembro, com três depósitos de
R$ 500, mostra 30% na barra, as três linhas no histórico, e o mês de cada
depósito reflete a decisão acima.

### Fase 13 — Perfil da conta

Decidida em **09/09/2026**. Uma tela para a conta, com quatro coisas: **foto e
nome** vindos do Google, **política de privacidade**, **excluir conta** e
**encerrar sessão**.

**Três dos quatro itens são só tela.** O `AuthUserModel` já carrega
`displayName`, `photoUrl`, `email` e o getter `label` — e o `photoUrl` **nunca
foi exibido em lugar nenhum**: o cabeçalho do menu mostra "Se Controle" e nada
mais. Não há chamada de backend a fazer; o `GET /me` não acrescenta nada que o
Firebase já não entregue.

- **A foto pode não existir.** Conta Google sem foto devolve `photoUrl` nulo, e
  é imagem de rede: precisa de estado de carregando, de erro, e de um fallback
  com as iniciais do `label`
- **Sair muda de lugar, não ganha um segundo.** A ação já existe no menu
  lateral (`_Sair`, chave `drawer-sair`). Pela convenção de que **uma ação mora
  em um lugar só**, ao ganhar a tela de perfil ela sai do menu — do mesmo jeito
  que editar cartão saiu da AppBar da fatura quando entrou no menu do card
- **Os outros dois são obrigação da Play**, e esta é a tela que os torna
  alcançáveis: a política é página estática que o Caddy serve, e a exclusão de
  conta é o único item aqui que **não** é só tela — depende de rota nova, com
  ordem de remoção definida, porque as FKs são `ON DELETE RESTRICT` em 8
  tabelas

**Vale fazer antes da rota de exclusão existir.** Foto, nome, política e sair
entregam a tela inteira; o botão de excluir entra depois, no lugar já reservado.
Esperar o backend para começar é adiar três itens por causa de um.

**Pronto quando:** a tela abre com a foto e o nome reais da conta, sair funciona
a partir dela e some do menu, a política abre, e excluir conta apaga os dados e
volta para o login sem deixar sessão de pé.

---

## Armadilhas

### Ambiente e build

- **No emulador Android, `localhost` é o emulador.** O backend em Docker fica em
  `http://10.0.2.2:3333`; em device físico, no IP da máquina na rede local.
- **O IP da rede local vive em dois arquivos, e os dois andam juntos:**
  `AppConfig._defaultBaseUrl` e `network_security_config.xml`, que autoriza HTTP
  sem TLS. **Timeout, neste app, quase sempre é endereço errado, não servidor
  lento.**
- **A configuração de build é arquivo, não linha de comando:**
  `--dart-define-from-file=env/dev.json`. `env/*.json` fica fora do git,
  `env/*.example.json` vai junto. O motivo não foi estética — saiu um APK
  apontando para a rede local em vez de produção, e só apareceu com `strings`.
- **Os `env/*.example.json` mostram o formato, não o endereço** (04/09). Eles
  traziam a porta da API e o domínio de produção em claro, e arquivo de exemplo
  versionado é lido por qualquer um que clone. Quem builda já sabe para onde
  aponta; **o valor real vive só no `env/*.json`, que não vai para o git.**
- **`AppConfig` importa `dart:io` e não compila para web.** Rodar no Chrome
  exigiria `kIsWeb` + import condicional.
- **Erro de sintaxe apontando para dentro do `.pub-cache` quase nunca é o seu
  código.** Um `a` solto em `multiple_result/result.dart` parou a suíte inteira
  de *carregar*. Apagar o pacote do cache e rodar `flutter pub get` resolve.

### Pacotes

- **`Watch` do signals está deprecado na 7.1.0** — use `SignalBuilder`.
- **`google_sign_in` 7.x reescreveu a API:** `GoogleSignIn.instance.initialize()`
  e depois `authenticate()`, e o `GoogleSignIn` é singleton de **construtor
  privado** — não dá para forjá-lo em teste, o que obriga um port no meio.
- **`Error` do `multiple_result` sombreia o `Error` do `dart:core`** — use
  prefixo no import.
- **Método abstrato com parâmetro nomeado precisa declarar o valor padrão.**
  `idToken({bool forceRefresh})` compila, mas chamar `idToken()` pelo tipo da
  interface **não passa** o argumento, e o duplo de teste vê uma invocação sem
  ele.
- **Reexecutar requisição de dentro do `onError` de um `QueuedInterceptor`
  trava** — a fila está ocupada por quem espera. E o `dio.fetch` passa pelo
  `onRequest` outra vez: sem uma marca na requisição, ele sobrescreve o token
  novo pelo antigo.
- **O dio não remove parâmetro de query nulo.** `{'month': null}` sai como
  `?month`, chave pelada, que o zod recusa como string vazia. A limpeza mora no
  `ApiClient`, porque a armadilha é do transporte.
- **`PrettyDioLogger` só imprime a URI quando o erro é `badResponse`.** Em
  timeout e `connectionError` — justamente "backend fora do ar" — o log não diz
  qual rota falhou.

### Flutter e Material

- **`AnimatedSwitcher` sem chave não anima nada**, nem entre tipos diferentes de
  widget, e a transição some **em silêncio**. Chavear pelo tipo também engana:
  `Loading` e `Failed` renderizam os dois um `Center`. Quem sabe que o estado
  mudou é o `ViewState` — por isso o `StateTransition` pede `stateKey`.
- **Elevação de card clareia a superfície no tema escuro** (é o `surfaceTint` do
  Material 3, não bug). Numa tela que empilha card sobre fundo vira degradê de
  cinzas: o `AppTheme` zera a elevação e usa borda.
- **No go_router, rota fixa vem antes de rota com parâmetro.** `form` declarado
  depois de `:id` vira um detalhe com id `"form"`.
- **Tag arquivada precisa entrar no seletor ao editar um gasto antigo.**
  `DropdownButtonFormField` com valor sem item correspondente é **assertion do
  Flutter**, não campo vazio.
- **Ícone repetido quebra `find.byIcon`** — use `find.descendant`.
- **`Month.label` capitaliza**, e no meio de uma frase lê como erro de digitação
  ("Janeiro 2026 a Outubro 2026"). Por isso existe `Month.periodLabel`.
- **Arredondar não conserta ponto flutuante.** `0.145` chega como `0.1449999…` e
  vira 14 centavos. Entrada de usuário usa `Money.tryParse`, que lê os dígitos do
  texto sem passar por `double`.
- **`amountCents`, `history` e `installments` são nulos conforme o tipo.** Ler o
  campo errado dá `null` silencioso, não erro. E `/summary` recebe o mês por
  **query string**: `/summary/2026-08` responde 404.

### Teste

- **Nunca conte com `Future.delayed` para dizer "ainda está carregando".** O
  `flutter test` roda os arquivos em paralelo, e sob carga o isolate fica sem CPU
  por mais que os 50 ms combinados — o future resolve antes da asserção. Use um
  `Completer` que ninguém completa: pendente é pendente. Isso já custou uma falha
  intermitente e foi migrado em **dezesseis** lugares.
- **Teste cujo nome descreve a intenção e a asserção não a verifica é pior que
  teste nenhum.** "Parâmetro nulo é removido" passou por dois dias procurando
  `month=&` numa URI que era `?month&`. Asserção sobre URL é sobre
  `uri.queryParameters`, não sobre pedaço de string.
- **Teste escrito depois do código confirma o bug em vez de achá-lo.** E fixture
  que depende do mês em que o teste roda é função (`singleMonthIncomeJson`), não
  constante.
- **Fake que só devolve resposta não testa ganhos.** Reajuste e correção produzem
  o mesmo `Success`; o que os distingue é **o que foi enviado** — daí o `verify`
  com os argumentos nomeados.
- **Dobrê de repositório que ignora filtro esconde bug.** O stub de `/tags` só
  passou a valer quando começou a respeitar `includeArchived`.
- **Detalhes do mocktail que custam tempo:** `verify` **consome** o histórico
  (chamar duas vezes devolve vazio na segunda); `clearInteractions` é o que zera
  antes de um `verifyNever`; e `any()` de tipo não nulo exige
  `registerFallbackValue` num `setUpAll`.
- **`BaseController` chama `onInit()` no construtor**, e o `onInit` do
  `HomeController` é `async`: construir já dispara `load()` e ninguém tem como
  aguardar essa primeira busca. Os testes dependem das microtasks drenarem entre
  o `setUp` e o corpo — com latência de verdade, essa garantia cai.
- **`ControlValueAccessor` avisa o campo por stream**, então testar que digitar
  não é reformatado exige `await Future.delayed(Duration.zero)`.
- **`dart format` reclama depois de rename por `sed`** — nome mais longo estoura
  as 80 colunas. Rode nos arquivos tocados para não misturar diff de formatação
  com diff de conteúdo.

---

## Decisões fechadas

| # | Decisão | Resolvida |
|---|---|---|
| 1 | **Autenticação e multiusuário: entra, e cedo.** Firebase Auth, só Google. Entra antes de notificações e offline porque obriga toda tabela a ganhar dono, e esse custo cresce com o número de tabelas | 21/08 · provedor em 25/08 · só Google em 27/08 |
| 2 | **Offline-first: entra, mas por último** (Fase 11) | 19/08 |
| 3 | **`intl`: não entra.** Moeda é `Money`, data é `IsoDate`, as duas por corte de string e sem `DateTime` no caminho — que é o que faz uma data andar um dia para trás. Reabrir só com localização de verdade | 19/08 |
| 4 | **Backend hospedado** em `https://secontroleai.com.br`, VPS do Google Cloud com Caddy e HTTPS automático. O Docker local segue sendo o ambiente de desenvolvimento | 21/08 |
| 5 | **A `API_KEY` sai dos dois lados.** O que decidiu não foi a redundância: num cliente distribuído a chave fica em texto no APK, e `strings -a` a encontra. Era uma string só, igual em todos os aparelhos, sem validade e sem dizer quem era | 31/08 |
| 6 | **O app é aberto.** Quem quiser entra com a conta Google — sem allowlist, convite ou aprovação. A defesa deixa de ser impedir e passa a ser observar e limitar: rate limit por IP e por `uid`, aviso de conta nova, e backup do Postgres muda de natureza | 31/08 |

**A Apple ficou fora** do login: exige anuidade paga e, sem build de iOS, não
alcançaria ninguém que o Google já não alcance. Volta quando houver App Store,
onde é requisito de aprovação.

**O GitHub saiu do corte** sem nunca ter tido código, e levou junto o deep link,
o esquema de URL e o **fluxo de vinculação de contas** (AUT-12) inteiro. Com um
provedor, um e-mail é um `uid`. **A única coisa a não fazer é desligar o "One
account per email address" no console do Firebase** — hoje ele não muda nada, e é
por isso mesmo que é fácil desligar sem pensar e só descobrir no dia do segundo
botão.
