# Regra dos repositórios

Vale para tudo em `lib/data/repositories/`. Escrita em 11/09/2026, a partir do
que o `CreditCardRepository` e o `DashboardRepository` já fazem.

## A forma

Um arquivo por recurso do backend, com **a interface e a implementação juntas**:

```dart
abstract interface class DashboardRepository {
  Future<Result<DashboardModel, Failure>> getDashboard({required String month});
}

class DashboardRepositoryImpl implements DashboardRepository {
  DashboardRepositoryImpl(this._api);

  final ApiClient _api;
  ...
}
```

- **`abstract interface class`**, e não classe abstrata comum: ninguém herda de
  repositório, só implementa — o duplo de teste inclusive.
- O nome da implementação é **`XRepositoryImpl`**. As duas exceções existentes
  (`HttpTagRepository`, `FirebaseAuthRepository`) nomeiam a tecnologia porque
  poderia haver outra; sem esse motivo, `Impl`.
- **Depende do `ApiClient`, nunca do `Dio`.** Quem cuida de token, baseUrl e
  erro de transporte é o client.

## O que todo método faz

1. Devolve **`Future<Result<T, Failure>>`** — nunca lança, nunca devolve nulo
   para dizer "deu errado".
2. Chama `_api.get/post/delete` e decodifica com **`Decode.object`** ou
   **`Decode.listOf`**.
3. Fecha com os dois `catch`, **escritos em cada método**:

```dart
} on AppException catch (exception) {
  return Error(Failure.fromException(exception));
} catch (error, stackTrace) {
  return Error(serializationFailure(error, stackTrace));
}
```

O `try/catch` repetido é **de propósito**: um helper com closure (`_guard`)
existiu e foi removido em 20/08 — ele escondia o caminho de erro e não pagava o
custo de ler. O que **não** se repete é o corpo do segundo `catch`: ele é a
função `serializationFailure(error, stackTrace)`, em
`lib/core/errors/serialization_failure.dart`. Era um método privado copiado em
seis repositórios.

O segundo `catch` é o que transforma payload fora do contrato em erro tratado,
em vez de exceção no meio de um `build`.

## O que um repositório não faz

- **Não calcula e não formata.** Soma, média, ordenação e rótulo são de quem
  usa. Se o backend manda `amountCents`, o repositório entrega `amountCents`.
- **Não guarda estado.** Por isso é `lazySingleton` **sem `dispose:`** no
  `injector_repositories.dart`: não há o que liberar.
- **Não conhece `BuildContext`, tema, `Color` nem widget.**
- **Não decide o mês.** A competência chega por parâmetro; quem a escolhe é o
  `SelectedMonthService`.

## Parâmetro de competência

`{required String month}` quando a resposta **só faz sentido dentro de um mês**
— é o caso do `/dashboard` e do `getBill`. A rota até aceita a ausência, mas aí
o backend responde a competência do relógio **dele**, e a tela mostraria um mês
diferente do selecionado: erro que não aparece em teste, só na virada do mês.

`{String? month}` quando a ausência é uma consulta legítima — a lista de gastos
sem `?month` traz também o que já foi encerrado, e é disso que a tela precisa.

## Duplo de teste

Em `test/fixtures/mocks.dart`, sempre os três:

```dart
class MockDashboardRepository extends Mock implements DashboardRepository {}

void stubDashboard(MockDashboardRepository mock, {Result<...>? result, Future<void>? pendenteAte}) { ... }

MockDashboardRepository dashboardRepositoryMock({...}) { ... }
```

- O stub responde a **fixture padrão** quando `result` é nulo, para o teste que
  não se importa com o conteúdo não precisar montar nada.
- **`pendenteAte`** segura a resposta até um `Completer`, e é o que permite
  testar `Loading` e resposta fora de ordem.

Teste do próprio repositório é opcional e vale quando há o que provar além do
mapeamento — rota, query e tradução de erro. O
`dashboard_repository_test.dart` é o modelo: `ApiClient` real com o
`HttpClientAdapter` do Dio mockado, nada de rede.
