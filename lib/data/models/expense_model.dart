import '../../core/utils/iso_date.dart';
import '../../core/utils/month.dart';
import 'amount_version_model.dart';
import 'installment_model.dart';
import 'tag_model.dart';

/// Como o gasto é pago. O backend só aceita estes dois (GFX-01).
enum PaymentMethod {
  creditCard('CREDIT_CARD'),
  debit('DEBIT');

  const PaymentMethod(this.wire);

  /// O valor como o backend o escreve. Não é o `name` do enum: lá é
  /// `SCREAMING_SNAKE`, aqui é `lowerCamel`, e traduzir por `toUpperCase()`
  /// funcionaria por acaso hoje e quebraria no primeiro valor com duas
  /// palavras.
  final String wire;

  static PaymentMethod fromWire(String value) =>
      values.firstWhere((method) => method.wire == value);

  /// Como [fromWire], mas devolve nulo em vez de estourar no valor
  /// desconhecido. É para ler o que vem de fora do app — hoje a query da rota
  /// da lista de gastos, que qualquer um pode digitar errado.
  static PaymentMethod? tryFromWire(String? value) =>
      value == null ? null : values.where((m) => m.wire == value).firstOrNull;
}

/// Fixo (valor versionado por vigência) ou parcelado (parcelas materializadas).
///
/// Cada tipo tem exatamente uma fonte da verdade para o dinheiro (GFX-09): um
/// `FIXED` nunca tem parcelas, um `INSTALLMENT` nunca tem vigências.
enum ExpenseType {
  fixed('FIXED'),
  installment('INSTALLMENT');

  const ExpenseType(this.wire);

  final String wire;

  static ExpenseType fromWire(String value) =>
      values.firstWhere((type) => type.wire == value);
}

/// Um gasto: aluguel, streaming, ração dos gatos, o presente de agosto.
///
/// **[amountCents] é nulo quando a busca não leva `?month`** — diferente do
/// ganho, onde o backend cai para a vigência mais recente (GAN-10). É a razão
/// de existirem [amountCentsIn] e [latestAmountCents]: a lista busca sem
/// competência, para não esconder o que já foi encerrado, e tira o valor do
/// [history].
class ExpenseModel {
  const ExpenseModel({
    required this.id,
    required this.description,
    required this.tag,
    required this.notes,
    required this.type,
    required this.paymentMethod,
    required this.creditCardId,
    required this.recurring,
    required this.spentAt,
    required this.startMonth,
    required this.endMonth,
    required this.amountCents,
    required this.totalCents,
    required this.installmentsCount,
    required this.installmentLabel,
    required this.history,
    required this.installments,
  });

  final String id;
  final String description;

  /// TAG-06: obrigatória no gasto. Substituiu a categoria em texto livre.
  final TagModel tag;

  /// Texto livre, opcional. Nada consulta este campo — nem filtra, nem agrupa,
  /// nem entra no resumo. Só aparece no detalhe.
  final String? notes;

  final ExpenseType type;
  final PaymentMethod paymentMethod;

  /// Obrigatório quando [paymentMethod] é cartão, proibido quando é débito
  /// (GFX-01). O backend recusa a combinação errada com 422.
  final String? creditCardId;

  /// Segue até ser encerrado. Falso no gasto avulso — que não é um tipo à
  /// parte, é um fixo não recorrente (GFX-03).
  final bool recurring;

  /// O dia em que a compra foi feita (GFX-12), em `YYYY-MM-DD` e já no fuso do
  /// aparelho. Quem não informou o dia no cadastro recebe do backend o dia em
  /// que cadastrou.
  ///
  /// Não confundir com [startMonth], que é a competência de onde o valor sai:
  /// a compra do dia 30 pode ser cobrada na competência seguinte.
  ///
  /// Nulo só quando o backend é anterior à GFX-12 — a tela omite a linha em
  /// vez de estourar.
  final String? spentAt;

  final String startMonth;

  /// Última competência cobrada. Null enquanto o gasto está em aberto.
  final String? endMonth;

  /// O valor **da competência consultada**, ou null quando a busca veio sem
  /// `?month`.
  final int? amountCents;

  /// Os três só valem para parcelado (Fase 5). Em gasto fixo chegam nulos.
  final int? totalCents;
  final int? installmentsCount;
  final String? installmentLabel;

  /// Da vigência mais antiga para a mais nova, como o backend devolve. Vazio em
  /// gasto parcelado, onde o dinheiro mora nas parcelas (GFX-09).
  final List<AmountVersionModel> history;

  /// Da primeira à última, como o backend devolve. Vazio em gasto fixo — é a
  /// outra metade do GFX-09.
  final List<InstallmentModel> installments;

  bool get isFixed => type == ExpenseType.fixed;
  bool get isInstallment => type == ExpenseType.installment;
  bool get onCreditCard => paymentMethod == PaymentMethod.creditCard;

  /// Tem data de fim. É o que decide se as operações de dinheiro ainda são
  /// possíveis: gasto encerrado não aceita reajuste, correção nem novo
  /// encerramento.
  ///
  /// **Não** é o mesmo que "não é mais cobrado": um gasto avulso nasce com
  /// `endMonth` preenchido e ainda assim é cobrado no mês dele. Para essa
  /// pergunta use [endedBefore].
  bool get isClosed => endMonth != null;

  /// Começa e termina na mesma competência: o presente, a consulta avulsa.
  bool get isSingleMonth => endMonth != null && endMonth == startMonth;

  /// Já acabou **antes** de [month] — aí sim "não é mais cobrado".
  bool endedBefore(String month) {
    final end = endMonth;
    return end != null && Month.isBefore(end, month);
  }

  /// O valor cobrado em [month]. Null quando o gasto não é cobrado naquela
  /// competência.
  ///
  /// Procura nos dois lugares porque cada tipo guarda o dinheiro no seu: fixo
  /// na vigência, parcelado na parcela. Como nenhum gasto tem as duas listas
  /// preenchidas (GFX-09), não há ambiguidade — e quem chama não precisa saber
  /// de que tipo é o gasto.
  int? amountCentsIn(String month) {
    for (final version in history) {
      final started = Month.compare(month, version.validFrom) >= 0;
      final to = version.validTo;
      final notFinished = to == null || Month.compare(month, to) <= 0;
      if (started && notFinished) return version.amountCents;
    }
    return installmentIn(month)?.amountCents;
  }

  /// A parcela cobrada em [month], se houver.
  InstallmentModel? installmentIn(String month) {
    for (final installment in installments) {
      if (installment.referenceMonth == month) return installment;
    }
    return null;
  }

  /// `'3/10'` para a competência corrente, ou null em gasto fixo e nos meses
  /// sem parcela. O `installmentLabel` do backend só vem quando a busca leva
  /// `?month`, e a listagem da tela não leva.
  String? installmentLabelIn(String month) => installmentIn(month)?.label;

  /// É cobrado em [month]?
  bool isActiveIn(String month) => amountCentsIn(month) != null;

  /// O último valor que o gasto teve. É o que a lista mostra quando ele não é
  /// cobrado no mês corrente — encerrado, ou ainda por começar —, onde
  /// [amountCentsIn] não teria resposta.
  int? get latestAmountCents {
    if (history.isNotEmpty) return history.last.amountCents;
    if (installments.isNotEmpty) return installments.last.amountCents;
    return amountCents;
  }

  /// A vigência que ainda está aberta, se houver. É dela que saem os limites
  /// dos diálogos de reajuste e de encerramento.
  AmountVersionModel? get currentVersion {
    for (final version in history.reversed) {
      if (version.isOpen) return version;
    }
    return null;
  }

  /// Houve pelo menos um reajuste — a tela só mostra a linha do tempo quando
  /// existe mais de uma vigência para comparar.
  bool get hasAdjustments => history.length > 1;

  factory ExpenseModel.fromJson(Map<String, dynamic> json) => ExpenseModel(
    id: json['id'] as String,
    description: json['description'] as String,
    tag: TagModel.fromJson(json['tag'] as Map<String, dynamic>),
    notes: json['notes'] as String?,
    type: ExpenseType.fromWire(json['type'] as String),
    paymentMethod: PaymentMethod.fromWire(json['paymentMethod'] as String),
    creditCardId: json['creditCardId'] as String?,
    recurring: json['recurring'] as bool,
    spentAt: IsoDate.fromInstant(json['spentAt'] as String?),
    startMonth: json['startMonth'] as String,
    endMonth: json['endMonth'] as String?,
    amountCents: json['amountCents'] as int?,
    totalCents: json['totalCents'] as int?,
    installmentsCount: json['installmentsCount'] as int?,
    installmentLabel: json['installmentLabel'] as String?,
    // Um dos dois vem null, conforme o tipo, e o null vira lista vazia: quem lê
    // não precisa de `?` em cima de cada acesso para saber que gasto fixo não
    // tem parcela.
    history: (json['history'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>()
        .map(AmountVersionModel.fromJson)
        .toList(growable: false),
    installments: (json['installments'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>()
        .map(InstallmentModel.fromJson)
        .toList(growable: false),
  );
}
