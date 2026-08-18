import 'package:se_controle_ai/data/models/summary_line_item_model.dart';

/// A fatura de um cartão no mês consultado.
class CreditCardInvoice {
  const CreditCardInvoice({
    required this.cardId,
    required this.name,
    required this.label,
    required this.dueDate,
    required this.limitCents,
    required this.totalCents,
    required this.items,
  });

  final String cardId;
  final String name;

  /// Pronto para exibir: `"Nubank ••••4321"`.
  final String label;

  /// Vencimento no mês, no formato `YYYY-MM-DD`.
  final String dueDate;

  final int? limitCents;
  final int totalCents;
  final List<SummaryLineItemModel> items;

  /// Quanto da fatura ocupa do limite, de 0 a 1. Null se o cartão não tem
  /// limite cadastrado. Pode passar de 1 — a fatura pode estourar o limite.
  double? get limitUsage {
    final limit = limitCents;
    if (limit == null || limit == 0) return null;
    return totalCents / limit;
  }

  factory CreditCardInvoice.fromJson(Map<String, dynamic> json) =>
      CreditCardInvoice(
        cardId: json['cardId'] as String,
        name: json['name'] as String,
        label: json['label'] as String,
        dueDate: json['dueDate'] as String,
        limitCents: json['limitCents'] as int?,
        totalCents: json['totalCents'] as int,
        items: (json['items'] as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .map(SummaryLineItemModel.fromJson)
            .toList(growable: false),
      );
}
