/// Um campo de `PATCH`, com os três estados que o backend distingue.
///
/// O `PATCH` de cartão (CAR-08) trata **campo ausente** e **campo `null`** como
/// coisas diferentes: ausente não muda nada, `null` limpa. Um `String?` no
/// parâmetro do repositório não consegue dizer isso — `null` teria que
/// significar as duas coisas ao mesmo tempo, e uma delas ficaria impossível de
/// pedir.
///
/// ```dart
/// repository.update(
///   id,
///   name: 'Nubank roxo',            // troca
///   lastDigits: const Patch.keep(), // não mexe
///   limitCents: const Patch.clear() // apaga
/// );
/// ```
///
/// Só existe para os campos que o backend aceita limpar. `name`, `closingDay` e
/// `dueDay` não são anuláveis (CAR-01/CAR-02), então neles um `null` só pode
/// querer dizer "não mexi" e o tipo simples basta.
sealed class Patch<T extends Object> {
  const Patch();

  /// O campo não entra no corpo. Estado inicial de tudo que a pessoa não tocou.
  const factory Patch.keep() = _Keep<T>;

  /// O campo entra como `null`, e o backend apaga o que estava lá.
  const factory Patch.clear() = _Clear<T>;

  /// O campo entra com o valor novo.
  const factory Patch.to(T value) = _To<T>;

  /// Compara o que está no formulário agora com o que o cartão tinha quando a
  /// tela abriu — a única forma de saber se a pessoa mexeu no campo.
  ///
  /// É aqui que "esvaziei o campo" (limpar) se separa de "nunca cheguei nele"
  /// (não mexer): os dois chegam como `null` do formulário, e o que os distingue
  /// é o valor anterior.
  factory Patch.diff(T? current, T? previous) {
    if (current == previous) return Patch<T>.keep();
    if (current == null) return Patch<T>.clear();
    return Patch<T>.to(current);
  }

  /// Escreve no corpo do `PATCH` — ou não escreve nada, que é o ponto de
  /// [Patch.keep].
  void writeTo(Map<String, dynamic> body, String field) {
    switch (this) {
      case _Keep<T>():
        return;
      case _Clear<T>():
        body[field] = null;
      case _To<T>(value: final value):
        body[field] = value;
    }
  }

  /// Há algo a enviar? O `PATCH` de corpo vazio volta 400, então o formulário
  /// usa isto para não mandar requisição quando nada mudou.
  bool get changesSomething => this is! _Keep<T>;
}

final class _Keep<T extends Object> extends Patch<T> {
  const _Keep();

  @override
  bool operator ==(Object other) => other is _Keep<T>;

  @override
  int get hashCode => Object.hash(_Keep<T>, T);

  @override
  String toString() => 'Patch<$T>.keep()';
}

final class _Clear<T extends Object> extends Patch<T> {
  const _Clear();

  @override
  bool operator ==(Object other) => other is _Clear<T>;

  @override
  int get hashCode => Object.hash(_Clear<T>, T);

  @override
  String toString() => 'Patch<$T>.clear()';
}

final class _To<T extends Object> extends Patch<T> {
  const _To(this.value);

  final T value;

  /// Igualdade por valor, e não por identidade, para o teste poder afirmar
  /// `verify(() => mock.update(id, limitCents: const Patch.to(150000)))`.
  @override
  bool operator ==(Object other) => other is _To<T> && other.value == value;

  @override
  int get hashCode => Object.hash(_To<T>, value);

  @override
  String toString() => 'Patch<$T>.to($value)';
}
