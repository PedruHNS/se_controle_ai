import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:se_controle_ai/core/shared/widgets/state_transition.dart';

void main() {
  Future<void> pump(WidgetTester tester, Object stateKey, Widget child) =>
      tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StateTransition(stateKey: stateKey, child: child),
          ),
        ),
      );

  testWidgets('a troca de estado atravessa uma transição', (tester) async {
    await pump(tester, 'Loading', const CircularProgressIndicator());
    await pump(tester, 'Loaded', const Text('carregou'));

    // No meio da animação os dois convivem — é o que prova que houve fade em
    // vez de troca seca no mesmo frame.
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('carregou'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('carregou'), findsOneWidget);
  });

  // Sem isto, o pull-to-refresh piscaria a cada puxada: os dados mudam, mas o
  // estado continua Loaded, e não é troca de estado.
  testWidgets('recarga silenciosa no mesmo estado não anima', (tester) async {
    await pump(tester, 'Loaded', const Text('antes'));
    await pump(tester, 'Loaded', const Text('depois'));

    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('antes'), findsNothing);
    expect(find.text('depois'), findsOneWidget);
  });

  // Loading e Failed renderizam os dois um `Center`. Chavear pelo tipo do
  // widget deixaria essa troca sem animação, em silêncio — foi o motivo de o
  // `stateKey` existir em vez de ser derivado da árvore.
  testWidgets('anima entre dois estados que renderizam o mesmo widget', (
    tester,
  ) async {
    await pump(tester, 'Loading', const Center(child: Text('carregando')));
    await pump(tester, 'Failed', const Center(child: Text('falhou')));

    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('carregando'), findsOneWidget);
    expect(find.text('falhou'), findsOneWidget);
  });
}
