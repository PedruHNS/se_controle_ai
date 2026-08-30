import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:multiple_result/multiple_result.dart';
import 'package:se_controle_ai/core/errors/failure.dart';
import 'package:se_controle_ai/features/tags/view/tag_list_page.dart';
import 'package:se_controle_ai/features/tags/widgets/tag_tile_widget.dart';

import '../../fixtures/mocks.dart';
import '../../fixtures/test_injector.dart';

void main() {
  late MockTagRepository repository;

  setUp(() => repository = setupTagTestInjector());

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: TagListPage()));
    await tester.pumpAndSettle();
  }

  group('lista', () {
    testWidgets('mostra as tags ativas, em lista única', (tester) async {
      await pump(tester);

      expect(find.text('Moradia'), findsOneWidget);
      expect(find.text('Outros'), findsOneWidget);
      expect(find.text('Transporte'), findsOneWidget);
    });

    testWidgets('a arquivada não aparece', (tester) async {
      // A seção "Arquivadas" saiu da tela na refatoração de 27/08. `/tags`
      // devolve só as ativas, então a arquivada nem chega aqui — não é questão
      // de esconder, é de não vir.
      await pump(tester);

      expect(find.text('Assinaturas'), findsNothing);
    });

    // Arquivada é estado interno: some da circulação, inclusive desta tela.
    // Quem quiser uma de volta a recria pelo nome, e o backend ressuscita a
    // mesma linha com o histórico (TAG-17).
    testWidgets('busca a lista uma vez só', (tester) async {
      await pump(tester);

      verify(() => repository.list()).called(1);
    });

    testWidgets('diz quantos lançamentos usam cada tag', (tester) async {
      await pump(tester);

      expect(find.text('3 lançamentos'), findsOneWidget);
      expect(find.text('Sem uso'), findsOneWidget);
      expect(find.text('1 lançamento'), findsOneWidget);
    });

    testWidgets('falha mostra o card de erro', (tester) async {
      stubTagList(
        repository,
        result: const Error(NetworkFailure(message: 'Sem conexão.')),
      );

      await pump(tester);

      expect(find.text('Sem conexão.'), findsOneWidget);
    });
  });

  group('criação', () {
    /// Abre o diálogo pelo FAB e devolve o campo de nome.
    ///
    /// O FAB é procurado pelo ícone: ele não tem rótulo, e a `Key` que existia
    /// no botão "Nova tag" saiu com a refatoração.
    Future<void> abrirDialogo(WidgetTester tester) async {
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
    }

    testWidgets('o FAB abre o diálogo de nova tag', (tester) async {
      await pump(tester);
      await abrirDialogo(tester);

      expect(find.text('Nova categoria'), findsOneWidget);
      expect(find.text('Criar'), findsOneWidget);
      expect(find.text('Cancelar'), findsOneWidget);
    });

    testWidgets('confirmar manda nome e cor para o backend', (tester) async {
      await pump(tester);
      await abrirDialogo(tester);

      await tester.enterText(find.byType(TextField), 'Mercado');
      await tester.tap(find.text('Criar'));
      await tester.pumpAndSettle();

      verify(() => repository.create(name: 'Mercado', color: null)).called(1);
    });

    testWidgets('a cor escolhida vai junto', (tester) async {
      // Os círculos da paleta têm `ValueKey(hex)`, que é o único jeito de
      // apontar para um deles — são 25 widgets idênticos em forma.
      await pump(tester);
      await abrirDialogo(tester);

      await tester.enterText(find.byType(TextField), 'Mercado');
      await tester.tap(find.byKey(const ValueKey('#42A5F5')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Criar'));
      await tester.pumpAndSettle();

      verify(
        () => repository.create(name: 'Mercado', color: '#42A5F5'),
      ).called(1);
    });

    // O bug relatado em 27/08: o diálogo reabria com o círculo da tag anterior
    // ainda marcado. O nome limpava; a cor não, porque a linha que devia
    // apagá-la era `==` em vez de `=` — comparava e jogava o resultado fora.
    //
    // Fecha pelo "Cancelar" e não pelo "Criar" porque o `NavigationService`
    // daqui é dublê e o `pop()` do controller não fecha nada. Dá no mesmo: o
    // formulário é zerado na *abertura*, então o desfecho anterior não importa.
    testWidgets('reabrir traz o formulário em branco', (tester) async {
      await pump(tester);
      await abrirDialogo(tester);

      await tester.enterText(find.byType(TextField), 'Mercado');
      await tester.tap(find.byKey(const ValueKey('#42A5F5')));
      await tester.pumpAndSettle();
      // O visto só existe no círculo escolhido.
      expect(find.byIcon(Icons.check), findsOneWidget);

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      await abrirDialogo(tester);

      expect(find.widgetWithText(TextField, 'Mercado'), findsNothing);
      expect(find.byIcon(Icons.check), findsNothing);
    });

    // O `POST` devolve a tag inteira, e é ela que entra na lista. O `list` da
    // abertura é o único: recarregar seria pedir ao servidor o que ele acabou
    // de responder.
    testWidgets('a tag criada aparece na lista sem recarregar', (tester) async {
      await pump(tester);
      await abrirDialogo(tester);

      await tester.enterText(find.byType(TextField), 'Mercado');
      await tester.tap(find.text('Criar'));
      await tester.pumpAndSettle();

      // Procura dentro do [TagTile], e não a primeira ocorrência do texto: o
      // `NavigationService` daqui é dublê, então o `pop()` do controller não
      // fecha o diálogo e o nome digitado continua no campo. Quem fecha de
      // verdade é coberto no teste de controller, que verifica o `pop()`.
      expect(find.widgetWithText(TagTile, 'Mercado'), findsOneWidget);
      verify(() => repository.list()).called(1);
    });

    testWidgets('cancelar não chama o backend', (tester) async {
      await pump(tester);
      await abrirDialogo(tester);

      await tester.enterText(find.byType(TextField), 'Mercado');
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      verifyNever(
        () => repository.create(
          name: any(named: 'name'),
          color: any(named: 'color'),
        ),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Editar, excluir e restaurar saíram desta tela na refatoração de 27/08: a
  // `TagListPage` passa `onEdit: (tag) {}` e `onDelete: (tag) {}`, callbacks
  // vazios, e a lista não mostra arquivadas. Os 11 testes que cobriam esses
  // fluxos foram removidos aqui — mantê-los seria uma suíte vermelha
  // permanente, descrevendo uma tela que não existe.
  //
  // O que eles asseguravam, para quando os fluxos voltarem:
  //
  // - **Edição** — tocar na tag abria o diálogo já preenchido; salvar mandava
  //   **só o que mudou** (`Patch.keep` no campo intocado, CAR-08); confirmar
  //   sem alterar nada não chamava o backend; e tag arquivada também podia ser
  //   editada, porque renomear vale para trás (TAG-03).
  // - **Exclusão** — os dois desfechos da TAG-08 anunciados **antes** de
  //   confirmar: tag sem uso é apagada, tag em uso é arquivada. Cancelar não
  //   chamava o backend.
  // - **Restaurar** — só a arquivada tinha o botão, e ele devolvia a tag às
  //   escolhas de lançamento novo.
  //
  // Os métodos `update`, `delete` e `restore` do `TagListController` continuam
  // implementados e sem cobertura de tela. O histórico está em `git log` deste
  // arquivo, no commit anterior a esta remoção.
  // ---------------------------------------------------------------------------

  // A edição reaproveita o diálogo da criação, e é daí que vinham os dois bugs
  // que estes testes fecham: a tela abria o diálogo sem passar a tag, e o
  // diálogo não tinha ramo que carregasse a tag no formulário. O resultado era
  // "Editar" abrindo em branco e gravando uma tag nova.
  group('edição', () {
    /// Abre o menu da linha [indice] e escolhe Editar. Sem argumento, a
    /// primeira — "Moradia".
    Future<void> abrirEdicao(WidgetTester tester, {int indice = 0}) async {
      await tester.tap(find.byIcon(Icons.more_vert).at(indice));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Editar'));
      await tester.pumpAndSettle();
    }

    testWidgets('abre em modo de edição', (tester) async {
      await pump(tester);
      await abrirEdicao(tester);

      expect(find.text('Editar categoria'), findsOneWidget);
      expect(find.text('Salvar'), findsOneWidget);
      expect(find.text('Nova categoria'), findsNothing);
    });

    testWidgets('vem com o nome da tag preenchido', (tester) async {
      await pump(tester);
      await abrirEdicao(tester);

      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text,
        'Moradia',
      );
    });

    // "Transporte", e não "Moradia": a cor da Moradia na fixture é `#4CAF50`,
    // que não está em `Globals.pallete`, então não há círculo para marcar. O
    // `#42A5F5` do Transporte está.
    testWidgets('vem com a cor da tag marcada', (tester) async {
      await pump(tester);
      await abrirEdicao(tester, indice: 2);

      // O círculo marcado é o único que desenha o check.
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('#42A5F5')),
          matching: find.byIcon(Icons.check),
        ),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('salvar edita, e não cria', (tester) async {
      await pump(tester);
      await abrirEdicao(tester);

      await tester.enterText(find.byType(TextField), 'Casa');
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      verify(
        () => repository.update(any(), name: 'Casa', color: '#4CAF50'),
      ).called(1);
      verifyNever(
        () => repository.create(
          name: any(named: 'name'),
          color: any(named: 'color'),
        ),
      );
    });
  });
}
