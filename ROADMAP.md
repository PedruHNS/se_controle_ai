# Roadmap — se_controle_ai

App Flutter do controle de gastos, cliente da API `expense-tracker-api`
(Node + Express + Postgres, rodando em Docker na mesma máquina).

## Onde estamos

*Atualizado em 17/08/2026.*

Flutter 3.44.9 · Dart 3.12.2 · **Fases 0 e 1 concluídas** · a home mostra o
resumo do mês com dados reais do backend.

`flutter analyze` sem issue · **92 testes passando** · fatia vertical validada
contra o backend real rodando em Docker.

As cinco libs estão em uso:

| Lib | Versão | Papel no app |
|---|---|---|
| `dio` | ^5.11.0 | Cliente HTTP: baseUrl, timeouts, interceptors |
| `multiple_result` | ^5.3.0 | `Result<Sucesso, Falha>` — erro como retorno, não exceção |
| `get_it` | ^9.2.1 | Service locator: Dio, ApiClient, repositórios, controllers |
| `go_router` | ^17.5.0 | Navegação declarativa por rota nomeada + deep link |
| `signals` | ^7.1.0 | Estado reativo: `signal` no controller, `SignalBuilder` na view |

### O que já existe em `lib/`

| Arquivo | O que faz |
|---|---|
| `core/config/app_config.dart` | baseUrl por plataforma + `--dart-define=API_BASE_URL`, timeouts |
| `core/network/dio_factory.dart` | Monta o Dio: BaseOptions, `validateStatus < 400`, log em debug |
| `core/errors/app_exception.dart` | O que a infra **lança** — técnico: status, código, causa, stack |
| `core/network/exception_mapper.dart` | Único lugar que conhece `DioException` → `AppException` |
| `core/errors/failure.dart` | O que a UI **recebe** — `Failure.fromException` traduz para o usuário |
| `core/network/api_client.dart` | Fala HTTP: devolve JSON cru (`dynamic`) e **lança** `AppException` |
| `core/di/injector.dart` | Registro no get_it: Dio, ApiClient, repositório, controller |
| `core/router/app_routes.dart` | Nomes e caminhos de rota centralizados |
| `core/router/app_router.dart` | Instância do GoRouter + tela de 404 |
| `core/shared/view_state.dart` | `Loading` / `Loaded` / `Failed` para a view dar switch exaustivo |
| `core/shared/widgets/failure_card_widget.dart` | Card de erro reutilizável, com ícone e título por tipo de `Failure` |
| `core/utils/money.dart` | Centavos ↔ real: `format`, `formatSigned`, `formatCompact`, `tryParse` |
| `core/utils/month.dart` | Competência `YYYY-MM`: label, aritmética, limites do backend |
| `data/models/monthly_summary.dart` | `MonthlySummary`, `SummaryLineItem`, `DebitGroup`, `CreditCardInvoice`, `MonthProjection` |
| `data/repositories/summary_repository.dart` | Interface + impl de `/summary` e `/summary/projection` |
| `features/home/controller/home_controller.dart` | Estado do resumo com signals — **é o molde a copiar** |
| `features/home/view/home_page.dart` | A tela: navegação de mês, `switch` no `ViewState`, pull-to-refresh |
| `features/home/widgets/` | `BalanceCard`, `SummarySection`, `CreditCardInvoiceCard`, `LineItemTile` |

### Onde erro deixa de ser exceção e passa a ser valor

```
Dio  --DioException-->  exception_mapper  --AppException-->  ApiClient (lança)
                                                                  |
                              repositório: try/catch + decode  <--+
                                                                  |
                                            Result<T, Failure>  <-+  --> controller/UI
```

`ApiClient` devolve `dynamic` e **lança**; `Result` nasce no repositório. O molde
de um método de repositório:

```dart
@override
Future<Result<MonthlySummary, Failure>> getMonthly({String? month}) async {
  try {
    final json = await _api.get('/summary', query: {'month': month});
    return Success(MonthlySummary.fromJson(json as Map<String, dynamic>));
  } on AppException catch (exception) {
    return Error(Failure.fromException(exception));
  }
}
```

Três consequências para quem escreve código:

- **Repositório é o único lugar com decode e com `try/catch`.** Nunca escreva
  `try/catch` em controller ou widget.
- **`AppException` só circula entre `ApiClient` e repositório**; `Failure` só
  circula dali para cima. Se um `AppException` chegou a um widget, algo furou a
  camada.
- **O decode fica dentro do `try`.** Se o `fromJson` ficar fora, um contrato
  quebrado no backend vira crash em vez de `Failure` — `on AppException` não pega
  o `TypeError` de um cast. Se quiser cobrir isso, acrescente um `catch` genérico
  devolvendo `SerializationException`.

Cada nível tem função distinta: o mapper **classifica** (qual falha técnica foi),
o `Failure` **traduz** (o que o usuário lê). É por isso que um 500 com
`TypeError: x is not a function` mostra "O servidor falhou ao processar" na tela
e guarda o stack do Node em `failure.exception`, para log.

---

## O contrato do backend

Toda a superfície que o app tem para consumir. Dinheiro **sempre em centavos
(int)**; competência **sempre string `YYYY-MM`**.

### Resumo — a tela inicial em uma chamada
| Método | Rota | Observação |
|---|---|---|
| GET | `/summary?month=YYYY-MM` | Sem `month`, usa o mês corrente |
| GET | `/summary/projection?from=YYYY-MM&months=N` | `N` de 1 a 60, default 12 |

`/summary` devolve `incomeCents`, `expenseCents`, `balanceCents`,
`committedPercent`, a lista de ganhos, o grupo `debit` e um `creditCards[]` com
a fatura de cada cartão (com `label`, `dueDate`, `limitCents`, itens).

### Ganhos
| Método | Rota | Semântica |
|---|---|---|
| POST | `/incomes` | `{description, amountCents, startMonth}` |
| GET | `/incomes?month=` · `/incomes/:id?month=` | `amountCents` = valor vigente no mês |
| POST | `/incomes/:id/adjustments` | Aumento: preserva os meses anteriores |
| PATCH | `/incomes/:id/amount` | Correção: o valor estava errado desde o início |
| POST | `/incomes/:id/closure` | `{lastMonth}` — parei de receber |
| DELETE | `/incomes/:id` | |

**Reajuste e correção são operações diferentes** e a UI precisa deixar isso
explícito — não são dois caminhos para "editar valor".

### Cartões
| Método | Rota |
|---|---|
| POST · GET · GET/:id · PATCH/:id · DELETE/:id | `/credit-cards` (`?month=` resolve `dueDate`) |

### Gastos
| Método | Rota | Semântica |
|---|---|---|
| POST | `/expenses` | Discriminado por `type`: `FIXED` ou `INSTALLMENT` |
| GET | `/expenses?month=&type=&paymentMethod=&creditCardId=` | Filtros combináveis |
| GET | `/expenses/:id?month=` | |
| PATCH | `/expenses/:id` | Só descrição/categoria/forma de pagamento |
| POST | `/expenses/:id/adjustments` · PATCH `/amount` · POST `/closure` | Só `FIXED` |
| POST | `/expenses/:id/reschedule` · POST `/settlement` | Só `INSTALLMENT` |
| DELETE | `/expenses/:id` | |

**Os dois tipos não compartilham operação de dinheiro.** `FIXED` tem vigências
(`history`), `INSTALLMENT` tem parcelas (`installments`), e o campo do outro tipo
vem `null`. Isso precisa virar duas telas de edição distintas, não uma com ifs.

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

| | |
|---|---|
| ▓▓▓▓▓▓▓▓▓▓ | Fase 0 — Fundação: **concluída** |
| ▓▓▓▓▓▓▓▓▓▓ | Fase 1 — Resumo mensal: **concluída** |
| ░░░░░░░░░░ | Fases 2 a 8 — não iniciadas |

Próximo passo: Fase 2 (Ganhos), o primeiro CRUD. O padrão a copiar está na
Fase 1 — model, repositório com `try/catch`, controller com signals, view com
`SignalBuilder` e `switch` no `ViewState`.

### Fase 0 — Fundação · ▓▓▓▓▓▓▓▓▓▓ concluída
Nenhuma tela. Só o encanamento que todas as fases seguintes usam.

- [x] `core/config` — baseUrl por plataforma e `--dart-define`
- [x] `core/network` — Dio configurado + tradução de `DioException` para `Failure`
- [x] `core/errors` — `sealed AppException` (lançada) e `sealed Failure` (retornada),
      espelhando a tabela de status do backend
- [x] `core/di` — get_it com `Dio` e `ApiClient`
- [x] `core/router` — go_router com rotas nomeadas, `errorBuilder` e gancho de `redirect`
- [x] `core/shared/view_state.dart` — `Loading` / `Loaded` / `Failed`
- [x] `core/utils/money.dart` — formatação e parse de dinheiro
- [x] `core/utils/month.dart` — competência `YYYY-MM`: label em português,
      aritmética com virada de ano, limites 2000–2100 do backend
- [x] **Padrão de controller com signals + `Result`** — `HomeController` é o molde

**Pronto quando:** um `main.dart` sobe, resolve dependências do get_it, navega
por go_router e uma chamada de teste ao `/health` do backend volta `Success`.
→ **Esse critério já passa.** Verificado ao vivo contra o Docker: `/health` devolveu
`Success('ok')`, `/summary?month=2026-08` decodificou e formatou
(`R$ 5.000,00` / `R$ 2.455,90` / `+R$ 2.544,10`), 404 real virou `NotFoundFailure`
e 400 real virou `ValidationFailure` com as issues do zod.

**Testes que já cobrem a fase** (36 no total):
`test/core/utils/money_test.dart` (formatação, parse, round-trip),
`test/core/network/api_client_test.dart` (200/204, remoção de query nula,
400 com issues, 404, 409, 422, 500, corpo HTML de proxy, timeout, cancelamento,
decode quebrado), `test/core/router/app_router_test.dart` (rota inicial,
`goNamed`, 404, botão de voltar).

### Fase 1 — Resumo mensal (home) · ▓▓▓▓▓▓▓▓▓▓ concluída
Só leitura. É a fase que prova a stack de ponta a ponta com o menor risco.

- [x] `GET /summary?month=` + navegação mês anterior / próximo, com atalho de
      voltar ao mês atual e setas desabilitadas nos limites do backend
- [x] Cartão de saldo com "Entra"/"Sai" e barra de `committedPercent`
      (laranja acima de 80%, vermelha acima de 100%)
- [x] Lista de débito e fatura por cartão, com uso do limite e aviso de estouro
- [x] Estados de carregando, vazio e erro; "tentar de novo" só em falha que vale
      repetir (`Failure.isRetryable`)
- [x] Pull-to-refresh que não pisca a tela — `load(silent: true)` mantém o
      conteúdo enquanto busca

**Pronto quando:** a home mostra o mês corrente com dados reais do Docker e
trocar de mês refaz a busca sem travar a UI. → **Atendido.**

**Testes da fase:** `month_test.dart` (30 casos), `monthly_summary_test.dart`
(parse do JSON real capturado do backend, incluindo mês vazio e mês no
vermelho), `home_controller_test.dart` (navegação, limites, corrida entre
respostas), `home_page_test.dart` (16 casos de widget).

### Fase 2 — Ganhos · ░░░░░░░░░░ não iniciada
Primeiro CRUD, e o mais simples — é onde o padrão de formulário nasce.

- Listar, criar, encerrar, excluir
- **Reajuste** e **correção** como ações distintas
- Histórico de vigências visível
- `issues[].path` do 400 ligado aos campos

**Pronto quando:** dá para cadastrar um salário, aplicar um aumento a partir de
um mês, e o resumo dos meses anteriores continua com o valor antigo.

### Fase 3 — Cartões · ░░░░░░░░░░ não iniciada
Vem antes de gastos porque gasto no cartão exige `creditCardId`.

- CRUD completo; `closingDay`/`dueDay` com seletor de dia
- Limite opcional

**Pronto quando:** o cartão criado aparece como opção no formulário de gasto.

### Fase 4 — Gastos fixos · ░░░░░░░░░░ não iniciada
- Criar `FIXED` (débito ou cartão), editar detalhes
- Reajuste com vigência, correção, encerramento
- Recorrente vs. mês único (`recurring`)

**Pronto quando:** um aluguel reajustado em julho aparece com valor antigo em
junho e novo em julho, no resumo.

### Fase 5 — Gastos parcelados · ░░░░░░░░░░ não iniciada
A fase com mais regra de negócio — vale deixar para depois de o padrão estar firme.

- Criar `INSTALLMENT`, ver as parcelas geradas
- Reparcelamento (corta no mês corrente, numeração continua)
- Quitação antecipada (`settlement`)

**Pronto quando:** R$ 100 em 3x mostra 33,34 + 33,33 + 33,33, e reparcelar em
outra quantidade não mexe nas parcelas passadas.

### Fase 6 — Projeção · ░░░░░░░░░░ não iniciada
- `GET /summary/projection` como gráfico ou lista de saldo acumulado
- Horizonte configurável

### Fase 7 — Acabamento · ░░░░░░░░░░ não iniciada
Tema claro/escuro, máscara de moeda no input, estados vazios com ilustração,
pull-to-refresh, animações de transição, tratamento de "backend offline".

### Fase 8 — Qualidade · ░░░░░░░░░░ não iniciada
Testes de model (parse do JSON real), de repositório (Dio mockado), de
controller (repositório fake) e de widget nas telas principais. `flutter analyze`
sem issue como porta de entrada.

---

## Armadilhas já mapeadas

Coisas que descobri conferindo os pacotes e o backend, e que custam tempo se
forem encontradas no meio da implementação:

- **`Watch` do signals está deprecado na 7.1.0.** O recomendado agora é
  `SignalBuilder`. Muito tutorial na internet ainda ensina `Watch`.
- **`Error` do `multiple_result` sombreia o `Error` do `dart:core`.** Ao importar
  o pacote num arquivo que também mexe com erros nativos, use prefixo no import.
- **No emulador Android, `localhost` é o emulador, não a sua máquina.** O backend
  em Docker fica em `http://10.0.2.2:3333`. Em device físico, nem um nem outro —
  precisa do IP da máquina na rede local.
- **`/summary` recebe o mês por query string, não por path.** `/summary/2026-08`
  responde 404.
- **`amountCents`, `history` e `installments` são nulos conforme o tipo.** Ler o
  campo errado dá `null` silencioso, não erro.
- **O package Android é `app.b4a.mangatrix.se_controle_ai`** — sobra do template
  que gerou o projeto. Trocar agora é barato; depois de publicar, não.
- **O backend não tem autenticação nem noção de usuário.** Hoje é single-user na
  máquina local. Qualquer plano de publicar o app exige resolver isso primeiro.

Descobertas já na pele, implementando a Fase 0:

- **`DioExceptionType.transformTimeout` chegou no dio 5.11.** Um `switch`
  exaustivo sobre esse enum escrito com base em exemplo antigo não compila.
- **`logPrint` do `LogInterceptor` recebe `Object`, e `debugPrint` recebe
  `String?`.** Passar `logPrint: debugPrint` não compila; use
  `logPrint: (line) => debugPrint('$line')`.
- **`AppConfig` importa `dart:io` para decidir o baseUrl por plataforma, e isso
  não compila para web.** O único device disponível na máquina hoje é o Chrome,
  então rodar no navegador exige trocar por `kIsWeb` + import condicional.
- **Arredondar não conserta ponto flutuante, só reduz o dano.** `0.145` chega
  como `0.1449999...` e `fromReais` devolve 14 centavos, não 15. Entrada de
  usuário deve usar `Money.tryParse`, que lê os dígitos do texto e nunca passa
  por `double`.

## Decisões abertas

1. **Autenticação e multi-usuário** — precisa existir? Muda o backend, não só o app.
2. **Offline** — cache local (drift/sqflite) ou o app só funciona conectado?
3. **`intl`** — entra para formatar moeda/data, ou formatador próprio para não
   adicionar dependência?
4. **Onde o backend vai rodar** — só local em Docker, ou hospedado?
