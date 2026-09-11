import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:se_controle_ai/features/home/view/home_page.dart';
import 'package:se_controle_ai/features/home/widgets/home_fab.dart';

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

  /// As opções não têm rótulo: são o ícone e nada mais. Por isso o teste
  /// procura pelo ícone — e **escopado no [HomeFab]**, porque os mesmos dois
  /// ícones abrem as seções Ganhos e Dinheiro no corpo da tela.
  ///
  /// As opções continuam na árvore com o menu fechado — o `SizeTransition` as
  /// deixa com altura zero em vez de arrancá-las, que é o que permite a
  /// animação de saída. Então o que o teste pergunta é se dá para tocar nelas,
  /// não se elas existem.
  Finder acao(IconData icone) => find
      .descendant(of: find.byType(HomeFab), matching: find.byIcon(icone))
      .hitTestable();

  final ganho = Icons.trending_up;
  final gasto = Icons.payments_outlined;

  group('menu do botão de criar', () {
    testWidgets('começa fechado, mostrando só o botão de adicionar', (
      tester,
    ) async {
      await pumpHome(tester);

      expect(find.byIcon(Icons.add), findsOneWidget);
      expect(acao(ganho), findsNothing);
      expect(acao(gasto), findsNothing);
    });

    testWidgets('abre com as duas opções do mês', (tester) async {
      await pumpHome(tester);
      await tapFab(tester);

      expect(acao(ganho), findsOneWidget);
      expect(acao(gasto), findsOneWidget);
    });

    testWidgets('fecha ao tocar no botão de novo', (tester) async {
      await pumpHome(tester);
      await tapFab(tester);
      await tapFab(tester);

      expect(acao(ganho), findsNothing);
      expect(acao(gasto), findsNothing);
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
      final opcaoGasto = tester.getRect(
        find.widgetWithIcon(FloatingActionButton, gasto),
      );
      final opcaoGanho = tester.getRect(
        find.widgetWithIcon(FloatingActionButton, ganho),
      );

      // Gasto logo acima do botão, ganho acima do gasto.
      expect(opcaoGasto.bottom, lessThan(botao.top));
      expect(opcaoGanho.bottom, lessThan(opcaoGasto.top));

      // Todas terminam na mesma borda direita do botão principal.
      expect(opcaoGasto.right, closeTo(botao.right, 1));
      expect(opcaoGanho.right, closeTo(opcaoGasto.right, 1));

      // E nenhuma escapa da tela.
      expect(opcaoGanho.top, greaterThan(0));
      expect(opcaoGanho.left, greaterThan(0));
      expect(opcaoGasto.right, lessThan(tela.width));
    });
  });
}
