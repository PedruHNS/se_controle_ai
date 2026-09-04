import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:se_controle_ai/data/models/credit_card_invoice_model.dart';
import 'package:se_controle_ai/data/models/summary_line_item_model.dart';
import 'package:se_controle_ai/features/home/widgets/credit_card_invoice_card.dart';
import 'package:se_controle_ai/features/home/widgets/invoice_carousel.dart';

void main() {
  /// Uma fatura com o que o backend manda: até três itens por cartão.
  CreditCardInvoiceModel fatura(
    String nome, {
    int itens = 2,
    int? limitCents = 800000,
    int totalCents = 65590,
    String descricao = 'Gasto',
    String? parcela,
  }) => CreditCardInvoiceModel(
    cardId: 'id-$nome',
    name: nome,
    label: '$nome ••••4321',
    dueDate: '2026-08-17',
    limitCents: limitCents,
    totalCents: totalCents,
    items: [
      for (var i = 0; i < itens; i++)
        SummaryLineItemModel(
          id: '$nome-$i',
          description: '$descricao $i',
          amountCents: 5590,
          installmentLabel: parcela,
          tag: null,
        ),
    ],
  );

  const larguraTela = 400.0;

  /// Monta o carrossel do jeito que a home o monta: numa coluna que rola na
  /// vertical, com 16 de respiro de cada lado.
  Future<List<CreditCardInvoiceModel>> pumpCarrossel(
    WidgetTester tester,
    List<CreditCardInvoiceModel> faturas, {
    void Function(CreditCardInvoiceModel)? onOpen,
  }) async {
    tester.view.physicalSize = const Size(larguraTela, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              InvoiceCarousel(invoices: faturas, onOpen: onOpen ?? (_) {}),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return faturas;
  }

  Finder cardDe(String nome) => find.ancestor(
    of: find.text('$nome ••••4321'),
    matching: find.byType(CreditCardInvoiceCard),
  );

  testWidgets('mostra um card por fatura', (tester) async {
    await pumpCarrossel(tester, [
      fatura('Nubank'),
      fatura('Inter'),
      fatura('Itaú'),
    ]);

    expect(find.byType(CreditCardInvoiceCard), findsNWidgets(3));
  });

  // O que faz disto um carrossel, e não uma pilha: os cards ficam um ao lado do
  // outro. Achar os três na árvore não provaria nada — o `Row` constrói todos
  // de qualquer jeito, estejam eles visíveis ou não.
  testWidgets('os cards ficam lado a lado, e não empilhados', (tester) async {
    await pumpCarrossel(tester, [fatura('Nubank'), fatura('Inter')]);

    final primeiro = tester.getRect(cardDe('Nubank'));
    final segundo = tester.getRect(cardDe('Inter'));

    expect(segundo.left, greaterThan(primeiro.right));
    expect(segundo.top, primeiro.top);
  });

  // O pedaço do próximo card à mostra é o que conta que dá para deslizar. Sem
  // ele o carrossel se passa por lista de um item só.
  testWidgets('o próximo card fica espiando na borda', (tester) async {
    await pumpCarrossel(tester, [fatura('Nubank'), fatura('Inter')]);

    final segundo = tester.getRect(cardDe('Inter'));

    // Começou dentro da tela...
    expect(segundo.left, lessThan(larguraTela));
    // ...mas só a pontinha: o grosso dele está para fora.
    expect(segundo.right, greaterThan(larguraTela));
  });

  // Um cartão só não tem próximo para espiar, e estreitar o card deixaria uma
  // sobra à direita que parece defeito de alinhamento.
  testWidgets('com um cartão só, o card ocupa a largura toda', (tester) async {
    await pumpCarrossel(tester, [fatura('Nubank')]);

    // A largura da tela menos os 16 de padding de cada lado.
    expect(tester.getSize(cardDe('Nubank')).width, larguraTela - 32);
  });

  testWidgets('deslizar para o lado traz o próximo card', (tester) async {
    await pumpCarrossel(tester, [fatura('Nubank'), fatura('Inter')]);

    final antes = tester.getRect(cardDe('Inter'));

    // De sobra, e não medido: o `drag` come uns 18px no *touch slop* antes de
    // rolar, e o próprio scroll trava no fim da lista.
    await tester.drag(find.byType(InvoiceCarousel), const Offset(-400, 0));
    await tester.pumpAndSettle();

    final depois = tester.getRect(cardDe('Inter'));

    expect(depois.left, lessThan(antes.left));
    // E agora ele cabe inteiro na tela, que é o ponto de ter deslizado.
    expect(depois.right, lessThanOrEqualTo(larguraTela));
  });

  testWidgets('tocar num card abre o cartão daquela fatura', (tester) async {
    CreditCardInvoiceModel? aberta;
    await pumpCarrossel(tester, [
      fatura('Nubank'),
      fatura('Inter'),
    ], onOpen: (invoice) => aberta = invoice);

    await tester.tap(find.text('Nubank ••••4321'));
    await tester.pumpAndSettle();

    expect(aberta?.cardId, 'id-Nubank');
  });

  // Este é o teste que sustenta a `alturaBase`. Ela é fixa, então uma altura
  // curta demais não aparece como erro de layout: aparece como listra amarela
  // na tela de quem tem a fatura mais cheia. Aqui está o pior caso que o
  // backend consegue mandar — limite estourado, os três itens que ele manda,
  // todos parcelados e com descrição longa — e overflow vira exceção no teste.
  //
  // Se um dia o card ganhar mais uma linha, é este teste que avisa que a
  // constante precisa subir junto.
  testWidgets('a altura fixa aguenta o pior caso que o backend manda', (
    tester,
  ) async {
    await pumpCarrossel(tester, [
      fatura(
        'Cartão de nome bastante comprido para forçar reticências',
        itens: 3,
        totalCents: 450000,
        limitCents: 400000,
        descricao: 'Descrição bem longa que não caberia numa linha só',
        parcela: '3/10',
      ),
      fatura('Inter', itens: 3, parcela: '2/12'),
    ]);

    expect(tester.takeException(), isNull);
  });

  // O que a altura fixa compra: a borda de baixo não serrilha ao deslizar.
  testWidgets('todos os cards têm a mesma altura', (tester) async {
    await pumpCarrossel(tester, [
      fatura('Nubank', itens: 0, limitCents: null, totalCents: 0),
      fatura('Inter', itens: 1),
      fatura('Itaú', itens: 3, parcela: '3/10'),
    ]);

    final alturas = [
      'Nubank',
      'Inter',
      'Itaú',
    ].map((nome) => tester.getSize(cardDe(nome)).height).toSet();

    expect(alturas, hasLength(1));
  });

  // Cartão sem gasto no mês continua aparecendo, com fatura zerada. Com altura
  // fixa ele sobraria vazio por baixo do divisor, e vazio sem explicação passa
  // por card que não terminou de carregar.
  testWidgets('cartão sem gasto no mês diz que não há gasto', (tester) async {
    await pumpCarrossel(tester, [
      fatura('Nubank', itens: 0, limitCents: null, totalCents: 0),
      fatura('Inter', itens: 2),
    ]);

    expect(find.text('Nenhum gasto registrado'), findsOneWidget);
  });

  // Fonte grande é a armadilha clássica da altura fixa: o texto cresce, a caixa
  // não, e o card estoura em quem mais precisa enxergar.
  testWidgets('a altura acompanha a fonte do sistema', (tester) async {
    tester.view.physicalSize = const Size(larguraTela, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
          child: Scaffold(
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                InvoiceCarousel(
                  invoices: [
                    fatura('Nubank', itens: 3, parcela: '3/10'),
                    fatura('Inter', itens: 3, parcela: '1/2'),
                  ],
                  onOpen: (_) {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(cardDe('Nubank')).height,
      greaterThan(CreditCardInvoiceCard.alturaBase),
    );
  });
}
