import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:se_controle_ai/features/home/view/home_page.dart';

import '../../fixtures/test_injector.dart';

void main() {
  setUp(setupTestInjector);

  Future<void> pumpHome(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomePage()));
    await tester.pumpAndSettle();
  }

  Future<void> tapFab(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
  }

  /// As opções continuam na árvore com o menu fechado — o `SizeTransition` as
  /// deixa com altura zero em vez de arrancá-las, que é o que permite a
  /// animação de saída. Então o que o teste pergunta é se dá para tocar nelas,
  /// não se elas existem.
  Finder acao(String label) => find.text(label).hitTestable();

  group('menu do botão de criar', () {
    testWidgets('começa fechado, mostrando só o botão de adicionar', (
      tester,
    ) async {
      await pumpHome(tester);

      expect(find.byIcon(Icons.add), findsOneWidget);
      expect(acao('Novo ganho'), findsNothing);
      expect(acao('Novo gasto'), findsNothing);
    });

    testWidgets('abre com as duas opções do mês', (tester) async {
      await pumpHome(tester);
      await tapFab(tester);

      expect(acao('Novo ganho'), findsOneWidget);
      expect(acao('Novo gasto'), findsOneWidget);
    });

    testWidgets('fecha ao tocar no botão de novo', (tester) async {
      await pumpHome(tester);
      await tapFab(tester);
      await tapFab(tester);

      expect(acao('Novo ganho'), findsNothing);
      expect(acao('Novo gasto'), findsNothing);
    });

    // Fechar tocando fora é o que se espera de qualquer menu, e sem isto a
    // única saída seria acertar de novo o botão que abriu.
    testWidgets('fecha ao tocar fora, na cortina', (tester) async {
      await pumpHome(tester);
      await tapFab(tester);

      await tester.tapAt(const Offset(20, 300));
      await tester.pumpAndSettle();

      expect(acao('Novo gasto'), findsNothing);
    });

    // O teste de layout que a olho nu se faria abrindo o app: as duas opções
    // empilhadas em cima do botão, alinhadas com ele e inteiras dentro da tela.
    // Um `SizeTransition` mal ancorado ou um alinhamento trocado põe a opção
    // fora do canto sem quebrar nenhum dos testes acima.
    testWidgets('as opções sobem do botão, alinhadas e dentro da tela', (
      tester,
    ) async {
      await pumpHome(tester);
      await tapFab(tester);

      final tela = tester.view.physicalSize / tester.view.devicePixelRatio;
      // O botão em si, e não o ícone dentro dele: o `+` é centralizado nos
      // 56px do FAB, e comparar borda com borda usando o ícone mediria a
      // margem errada.
      final botao = tester.getRect(
        find.ancestor(
          of: find.byIcon(Icons.add),
          matching: find.byType(FloatingActionButton),
        ),
      );
      final gasto = tester.getRect(
        find.widgetWithText(FloatingActionButton, 'Novo gasto'),
      );
      final ganho = tester.getRect(
        find.widgetWithText(FloatingActionButton, 'Novo ganho'),
      );

      // Gasto logo acima do botão, ganho acima do gasto.
      expect(gasto.bottom, lessThan(botao.top));
      expect(ganho.bottom, lessThan(gasto.top));

      // Todas terminam na mesma borda direita do botão principal.
      expect(gasto.right, closeTo(botao.right, 1));
      expect(ganho.right, closeTo(gasto.right, 1));

      // E nenhuma escapa da tela.
      expect(ganho.top, greaterThan(0));
      expect(ganho.left, greaterThan(0));
      expect(gasto.right, lessThan(tela.width));
    });

    // A cortina cobre o resumo enquanto o menu está aberto — é o que faz o
    // toque fora fechar em vez de abrir uma seção por engano. Fechada, ela não
    // pode roubar o toque de nada: nem do pull-to-refresh, nem das seções.
    testWidgets('a cortina só engole o toque do resumo com o menu aberto', (
      tester,
    ) async {
      await pumpHome(tester);

      expect(find.text('Ganhos').hitTestable(), findsOneWidget);

      await tapFab(tester);

      expect(find.text('Ganhos').hitTestable(), findsNothing);
    });
  });
}
