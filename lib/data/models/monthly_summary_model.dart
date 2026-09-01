import 'package:se_controle_ai/data/models/credit_card_invoice_model.dart';
import 'package:se_controle_ai/data/models/summary_section_model.dart';
import 'package:se_controle_ai/data/models/summary_line_item_model.dart';

/// Resposta de `GET /summary?month=YYYY-MM` — a tela inicial inteira em um
/// objeto.
///
/// **A home não usa mais.** Ela passou a buscar as quatro seções por rotas
/// próprias, para cada uma pintar quando chega. Isto continua aqui, junto com a
/// rota, enquanto existirem builds antigas do app instaladas: a API sobe no
/// push e o aparelho só atualiza quando alguém compila. Os dois saem juntos.
class MonthlySummaryModel {
  final String month;
  final int incomeCents;
  final int expenseCents;

  /// `incomeCents - expenseCents`. Negativo = mês no vermelho.
  final int balanceCents;

  /// Percentual do ganho já comprometido. Null quando não há ganho no mês
  /// (dividir por zero não teria sentido).
  final double? committedPercent;

  final List<SummaryLineItemModel> incomes;
  final SummarySectionModel debit;
  final List<CreditCardInvoiceModel> creditCards;

  bool get isNegative => balanceCents < 0;
  const MonthlySummaryModel({
    required this.month,
    required this.incomeCents,
    required this.expenseCents,
    required this.balanceCents,
    required this.committedPercent,
    required this.incomes,
    required this.debit,
    required this.creditCards,
  });

  factory MonthlySummaryModel.fromJson(Map<String, dynamic> json) =>
      MonthlySummaryModel(
        month: json['month'] as String,
        incomeCents: json['incomeCents'] as int,
        expenseCents: json['expenseCents'] as int,
        balanceCents: json['balanceCents'] as int,
        committedPercent: (json['committedPercent'] as num?)?.toDouble(),
        incomes: (json['incomes'] as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .map(SummaryLineItemModel.fromJson)
            .toList(growable: false),
        debit: SummarySectionModel.fromJson(
          json['debit'] as Map<String, dynamic>,
        ),
        creditCards: (json['creditCards'] as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .map(CreditCardInvoiceModel.fromJson)
            .toList(growable: false),
      );
}
