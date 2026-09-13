import 'package:flutter_test/flutter_test.dart';
import 'package:se_controle_ai/core/utils/text_order_utils.dart';

void main() {
  List<String> ordenado(List<String> itens) =>
      [...itens]..sort(TextOrderUtils.alfabetica);

  test('caixa não separa palavras iguais', () {
    // Com `compareTo` puro, toda maiúscula vem antes de toda minúscula: a lista
    // sairia [Aluguel, Zebra, aluguel], com os dois "aluguel" longe um do outro.
    // O que importa aqui é que eles fiquem **juntos**, antes de "Zebra"; qual
    // dos dois vem primeiro é o desempate pelo texto original, e a maiúscula
    // ganha porque 'A' é 65 e 'a' é 97.
    expect(ordenado(['Zebra', 'aluguel', 'Aluguel']), [
      'Aluguel',
      'aluguel',
      'Zebra',
    ]);
  });

  test('acento não joga a palavra para o fim', () {
    // `compareTo` põe tudo que tem acento depois do `z` — "Água" apareceria
    // embaixo de "Zebra", que é onde ninguém procura.
    expect(ordenado(['Zebra', 'Água', 'Banco']), ['Água', 'Banco', 'Zebra']);
  });

  test('ç ordena junto do c, e não no fim', () {
    expect(ordenado(['Dado', 'Ação', 'Casa']), ['Ação', 'Casa', 'Dado']);
  });

  test('mesma chave desempata pelo texto, e não pelo acaso', () {
    // "Água" e "agua" dobram para a mesma chave. Sem desempate explícito, a
    // ordem entre elas dependeria do algoritmo de ordenação e mudaria sozinha
    // ao inserir qualquer outro item na lista.
    final uma = ordenado(['Água', 'agua']);
    final outra = ordenado(['agua', 'Água']);

    expect(uma, outra);
  });

  test('letra fora do mapa não quebra, só cai na ordem antiga', () {
    expect(ordenado(['Ω', 'Alfa']), ['Alfa', 'Ω']);
  });

  test('lista vazia e de um item passam sem comparar nada', () {
    expect(ordenado([]), isEmpty);
    expect(ordenado(['Só eu']), ['Só eu']);
  });
}
