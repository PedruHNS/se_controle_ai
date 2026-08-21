import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:se_controle_ai/data/models/summary_line_item_model.dart';
import 'package:se_controle_ai/features/home/widgets/line_item_tile.dart';
import 'package:se_controle_ai/features/home/widgets/summary_section.dart';

/// Itens na ordem em que o backend entrega — do lançamento mais recente para o
/// mais antigo. A seção não reordena; se reordenasse, o teto de linhas
/// esconderia justamente o que acabou de ser cadastrado.
List<SummaryLineItemModel> _items(int count) => List.generate(
  count,
  (i) => SummaryLineItemModel(
    id: 'id-$i',
    description: 'Gasto $i',
    amountCents: 1000 * (i + 1),
    installmentLabel: null,
  ),
);

Future<void> _pump(
  WidgetTester tester, {
  required List<SummaryLineItemModel> items,
  int? maxItems,
}) => tester.pumpWidget(
  MaterialApp(
    home: Scaffold(
      body: SummarySection(
        title: 'Dinheiro e crédito',
        icon: Icons.payments_outlined,
        items: items,
        totalCents: 999900,
        maxItems: maxItems,
      ),
    ),
  ),
);

void main() {
  group('SummarySection com maxItems', () {
    testWidgets('mostra no máximo o teto de linhas', (tester) async {
      await _pump(tester, items: _items(6), maxItems: 4);

      expect(find.byType(LineItemTile), findsNWidgets(4));
    });

    testWidgets('preserva a ordem recebida, sem reordenar', (tester) async {
      await _pump(tester, items: _items(6), maxItems: 4);

      // Os quatro primeiros da lista, não os quatro de menor valor nem em
      // ordem alfabética.
      for (final i in [0, 1, 2, 3]) {
        expect(find.text('Gasto $i'), findsOneWidget);
      }
      for (final i in [4, 5]) {
        expect(find.text('Gasto $i'), findsNothing);
      }
    });

    testWidgets('avisa quantos lançamentos ficaram de fora', (tester) async {
      await _pump(tester, items: _items(6), maxItems: 4);

      expect(find.text('e mais 2 lançamentos'), findsOneWidget);
    });

    testWidgets('singular quando sobra um só', (tester) async {
      await _pump(tester, items: _items(5), maxItems: 4);

      expect(find.text('e mais 1 lançamento'), findsOneWidget);
    });

    testWidgets('sem rodapé quando tudo cabe', (tester) async {
      await _pump(tester, items: _items(3), maxItems: 4);

      expect(find.byType(LineItemTile), findsNWidgets(3));
      expect(find.textContaining('e mais'), findsNothing);
    });

    testWidgets('sem rodapé no limite exato', (tester) async {
      await _pump(tester, items: _items(4), maxItems: 4);

      expect(find.byType(LineItemTile), findsNWidgets(4));
      expect(find.textContaining('e mais'), findsNothing);
    });

    testWidgets('sem teto, mostra todos', (tester) async {
      await _pump(tester, items: _items(7));

      expect(find.byType(LineItemTile), findsNWidgets(7));
      expect(find.textContaining('e mais'), findsNothing);
    });

    // O total do cabeçalho é o do mês, não a soma do que aparece — é o que
    // mantém a seção coerente com o card de saldo acima dela.
    testWidgets('o total não é recalculado sobre a fatia visível', (
      tester,
    ) async {
      await _pump(tester, items: _items(6), maxItems: 4);

      expect(find.text(r'R$ 9.999,00'), findsOneWidget);
    });
  });
}
