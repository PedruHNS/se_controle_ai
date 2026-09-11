# se_controle_ai

App Flutter do controle de gastos. O backend é o `expense-tracker-api`, no
diretório irmão, e as specs dele (`docs/specs/`) são o contrato do que o app
consome.

## Regras do projeto

@.claude/rules/models.md

## Padrão de código

A referência viva é a **feature de tags** (`lib/features/tags/`): controller com
`signal` privado exposto como `ReadonlySignal`, `switch` exaustivo no
`ViewState`, esqueleto com `Skeletonizer`, `FailureCardWidget` no erro,
`EmptyStateWidget` na lista vazia, sub-widgets privados recebendo callbacks, e
arquivos de `widgets/` com sufixo `_widget.dart`.

## Antes de entregar

`flutter analyze` limpo e `flutter test` verde.
