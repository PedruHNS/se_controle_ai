import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:se_controle_ai/core/shared/widgets/empty_state_widget.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    Future<void> Function()? onRefresh,
  }) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: EmptyStateWidget(
          icon: Icons.sell_outlined,
          title: 'Nenhuma tag cadastrada',
          message: 'Todo gasto precisa de uma.',
          onRefresh: onRefresh,
        ),
      ),
    ),
  );

  testWidgets('mostra ícone, título e o próximo passo', (tester) async {
    await pump(tester);

    expect(find.byIcon(Icons.sell_outlined), findsOneWidget);
    expect(find.text('Nenhuma tag cadastrada'), findsOneWidget);
    expect(find.text('Todo gasto precisa de uma.'), findsOneWidget);
  });

  // O motivo de o widget embrulhar o scroll em vez de só o miolo: sem conteúdo
  // não há o que rolar, e o gesto sumiria.
  testWidgets('mantém o pull-to-refresh mesmo sem conteúdo', (tester) async {
    var recarregou = false;
    await pump(tester, onRefresh: () async => recarregou = true);

    await tester.fling(find.byType(ListView), const Offset(0, 300), 1000);
    await tester.pumpAndSettle();

    expect(recarregou, isTrue);
  });

  testWidgets('sem onRefresh, não há indicador', (tester) async {
    await pump(tester);

    expect(find.byType(RefreshIndicator), findsNothing);
  });
}
