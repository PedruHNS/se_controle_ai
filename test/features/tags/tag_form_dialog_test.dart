// import 'package:flutter/material.dart';
// import 'package:flutter_test/flutter_test.dart';
// import 'package:se_controle_ai/data/models/tag_model.dart';
// import 'package:se_controle_ai/features/tags/widgets/tag_form_dialog.dart';

// void main() {
//   /// O que o diálogo devolveu, preenchido quando ele fecha. É lido **depois**
//   /// de confirmar: enquanto o diálogo está aberto, o `await` do `showDialog`
//   /// ainda não voltou.
//   // TagFormResult? captured;

//   // setUp(() => captured = null);

//   /// Abre o diálogo — o mesmo caminho que a tela de tags e o formulário de
//   /// gasto usam.
//   Future<void> open(WidgetTester tester, {TagModel? tag}) async {
//     var opened = false;

//     await tester.pumpWidget(
//       MaterialApp(
//         home: Scaffold(
//           body: Builder(
//             builder: (context) => TextButton(
//               onPressed: () async {
//                 opened = true;
//                 // captured = await showTagFormDialog(context, tag: tag);
//               },
//               child: const Text('abrir'),
//             ),
//           ),
//         ),
//       ),
//     );

//     await tester.tap(find.text('abrir'));
//     await tester.pumpAndSettle();
//     expect(opened, isTrue);
//   }

//   /// Toca no círculo daquela cor. A chave é o hex, então o teste não depende da
//   /// ordem da paleta.
//   Future<void> tapColor(WidgetTester tester, String hex) async {
//     await tester.tap(find.byKey(ValueKey(hex)));
//     await tester.pumpAndSettle();
//   }

//   testWidgets('oferece as cores da paleta', (tester) async {
//     await open(tester);

//     // Uma de cada família, para o teste falhar se um bloco inteiro sumir.
//     for (final hex in [
//       '#EF5350', // vermelho
//       '#AB47BC', // roxo
//       '#42A5F5', // azul
//       '#66BB6A', // verde
//       '#FFA726', // laranja
//       '#78909C', // neutro
//     ]) {
//       expect(
//         find.byKey(ValueKey(hex)),
//         findsOneWidget,
//         reason: '$hex sumiu da paleta',
//       );
//     }
//   });

//   // As oito cores originais continuam na paleta com o mesmo código: tag antiga
//   // precisa seguir casando com um círculo, senão a edição abre sem seleção e a
//   // pessoa acha que perdeu a cor.
//   testWidgets('mantém as cores do arranjo anterior', (tester) async {
//     await open(tester);

//     for (final hex in [
//       '#EF5350',
//       '#EC407A',
//       '#AB47BC',
//       '#5C6BC0',
//       '#42A5F5',
//       '#26A69A',
//       '#66BB6A',
//       '#FFA726',
//     ]) {
//       expect(find.byKey(ValueKey(hex)), findsOneWidget, reason: '$hex sumiu');
//     }
//   });

//   testWidgets('cria com nome e a cor escolhida', (tester) async {
//     await open(tester);

//     await tester.enterText(find.byType(TextField), 'Mercado');
//     await tapColor(tester, '#43A047');
//     await tester.tap(find.widgetWithText(FilledButton, 'Criar'));
//     await tester.pumpAndSettle();

//     expect(captured?.name, 'Mercado');
//     expect(captured?.color, '#43A047');
//   });

//   // Cor é opcional (TAG-02), e sair sem escolher nenhuma tem que devolver null
//   // — não uma cor padrão escolhida pela tela.
//   testWidgets('cria sem cor quando nenhuma é tocada', (tester) async {
//     await open(tester);

//     await tester.enterText(find.byType(TextField), 'Pets');
//     await tester.tap(find.widgetWithText(FilledButton, 'Criar'));
//     await tester.pumpAndSettle();

//     expect(captured?.name, 'Pets');
//     expect(captured?.color, isNull);
//   });

//   testWidgets('tocar na cor escolhida desmarca', (tester) async {
//     await open(tester);

//     await tester.enterText(find.byType(TextField), 'Mercado');
//     await tapColor(tester, '#FFCA28');
//     await tapColor(tester, '#FFCA28');

//     // Sem cor selecionada, nenhum check aparece.
//     expect(find.byIcon(Icons.check), findsNothing);

//     await tester.tap(find.widgetWithText(FilledButton, 'Criar'));
//     await tester.pumpAndSettle();

//     expect(captured?.color, isNull, reason: 'desmarcar tem que limpar a cor');
//   });

//   testWidgets('uma cor por vez', (tester) async {
//     await open(tester);

//     await tapColor(tester, '#E53935');
//     expect(find.byIcon(Icons.check), findsOneWidget);

//     await tapColor(tester, '#00ACC1');
//     expect(
//       find.byIcon(Icons.check),
//       findsOneWidget,
//       reason: 'escolher outra cor troca a seleção, não soma',
//     );
//   });

//   testWidgets('editar abre com a cor da tag já marcada', (tester) async {
//     await open(
//       tester,
//       tag: const TagModel(
//         id: 'tag-1',
//         name: 'Mercado',
//         color: '#8D6E63',
//         archived: false,
//         usageCount: 3,
//       ),
//     );

//     expect(find.text('Editar categoria'), findsOneWidget);
//     expect(find.byIcon(Icons.check), findsOneWidget);
//   });
// }
