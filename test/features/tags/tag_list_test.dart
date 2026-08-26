import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:multiple_result/multiple_result.dart';
import 'package:se_controle_ai/core/errors/failure.dart';
import 'package:se_controle_ai/core/shared/patch.dart';
import 'package:se_controle_ai/features/tags/view/tag_list_page.dart';

import '../../fixtures/mocks.dart';
import '../../fixtures/tag_fixture.dart';
import '../../fixtures/test_injector.dart';

void main() {
  late MockTagRepository repository;

  setUp(() => repository = setupTagTestInjector());

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: TagListPage()));
    await tester.pumpAndSettle();
  }

  group('lista', () {
    testWidgets('mostra ativas e arquivadas em seções separadas', (
      tester,
    ) async {
      await pump(tester);

      expect(find.text('Moradia'), findsOneWidget);
      expect(find.text('Arquivadas'), findsOneWidget);
      expect(find.text('Assinaturas'), findsOneWidget);
    });

    // Arquivada é estado interno: some da circulação, inclusive desta tela.
    // Quem quiser uma de volta a recria pelo nome, e o backend ressuscita a
    // mesma linha com o histórico (TAG-17).
    testWidgets('busca só as ativas', (tester) async {
      await pump(tester);

      verify(() => repository.list(includeArchived: false)).called(1);
      verifyNever(() => repository.list(includeArchived: true));
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
    testWidgets('o FAB abre o diálogo e cria', (tester) async {
      await pump(tester);

      await tester.tap(find.text('Nova tag'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Mercado');
      await tester.tap(find.text('Criar'));
      await tester.pumpAndSettle();

      verify(() => repository.create(name: 'Mercado', color: null)).called(1);
    });

    // O `POST` devolve a tag inteira, e é ela que entra na lista. O `list` da
    // abertura é o único: recarregar seria pedir ao servidor o que ele acabou
    // de responder.
    testWidgets('a tag criada aparece na lista sem recarregar', (tester) async {
      await pump(tester);

      await tester.tap(find.text('Nova tag'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Mercado');
      await tester.tap(find.text('Criar'));
      await tester.pumpAndSettle();

      expect(find.text('Mercado'), findsOneWidget);
      verify(() => repository.list(includeArchived: false)).called(1);
    });
  });

  group('edição', () {
    testWidgets('tocar na tag abre o diálogo preenchido', (tester) async {
      await pump(tester);

      await tester.tap(find.text('Moradia'));
      await tester.pumpAndSettle();

      expect(find.text('Editar categoria'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Moradia'), findsOneWidget);
    });

    testWidgets('salvar manda só o que mudou', (tester) async {
      await pump(tester);

      await tester.tap(find.text('Moradia'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Casa');
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      verify(
        () => repository.update(
          moradiaTagId,
          name: 'Casa',
          // A cor não foi tocada, então nem entra no corpo.
          color: const Patch<String>.keep(),
        ),
      ).called(1);
    });

    // Sair sem mexer seria um PATCH de corpo vazio, que o backend recusa
    // com 400 — e prender quem só abriu e fechou seria absurdo.
    testWidgets('confirmar sem mexer em nada não chama o backend', (
      tester,
    ) async {
      await pump(tester);

      await tester.tap(find.text('Moradia'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      verifyNever(
        () => repository.update(
          any(),
          name: any(named: 'name'),
          color: any(named: 'color'),
        ),
      );
    });

    // TAG-03: renomear vale para trás, inclusive na arquivada.
    testWidgets('deixa editar tag arquivada', (tester) async {
      await pump(tester);

      await tester.tap(find.text('Assinaturas'));
      await tester.pumpAndSettle();

      expect(find.text('Editar categoria'), findsOneWidget);
    });
  });

  group('exclusão', () {
    testWidgets('tag sem uso é excluída, e o diálogo diz isso', (tester) async {
      await pump(tester);

      // "Outros" tem usageCount 0.
      await tester.tap(
        find.descendant(
          of: find.ancestor(
            of: find.text('Outros'),
            matching: find.byType(ListTile),
          ),
          matching: find.byIcon(Icons.delete_outline),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Excluir tag'), findsOneWidget);
      expect(find.textContaining('não é usada por nenhum'), findsOneWidget);
    });

    // O aviso vem ANTES, não depois: decidir sem saber o desfecho é decidir no
    // escuro.
    testWidgets('tag em uso avisa que será arquivada, não excluída', (
      tester,
    ) async {
      await pump(tester);

      await tester.tap(
        find.descendant(
          of: find.ancestor(
            of: find.text('Moradia'),
            matching: find.byType(ListTile),
          ),
          matching: find.byIcon(Icons.delete_outline),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Arquivar tag'), findsOneWidget);
      expect(find.textContaining('3 lançamentos usam'), findsOneWidget);
      expect(find.textContaining('continua neles'), findsOneWidget);
    });

    testWidgets('confirmar arquiva e avisa o que aconteceu', (tester) async {
      stubTagDelete(repository, archived: true);

      await pump(tester);

      await tester.tap(
        find.descendant(
          of: find.ancestor(
            of: find.text('Moradia'),
            matching: find.byType(ListTile),
          ),
          matching: find.byIcon(Icons.delete_outline),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Arquivar'));
      await tester.pumpAndSettle();

      verify(() => repository.delete(moradiaTagId)).called(1);
      expect(
        find.widgetWithText(
          SnackBar,
          'Moradia foi arquivada e continua nos '
          'lançamentos antigos.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('cancelar não chama o backend', (tester) async {
      await pump(tester);

      await tester.tap(
        find.descendant(
          of: find.ancestor(
            of: find.text('Moradia'),
            matching: find.byType(ListTile),
          ),
          matching: find.byIcon(Icons.delete_outline),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      verifyNever(() => repository.delete(any()));
    });
  });

  group('restaurar', () {
    testWidgets('só a arquivada tem o botão', (tester) async {
      await pump(tester);

      expect(find.byIcon(Icons.unarchive_outlined), findsOneWidget);
    });

    testWidgets('restaura a arquivada', (tester) async {
      await pump(tester);

      await tester.tap(find.byIcon(Icons.unarchive_outlined));
      await tester.pumpAndSettle();

      verify(() => repository.restore(arquivadaTagId)).called(1);
    });
  });
}
