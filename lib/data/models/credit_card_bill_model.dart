import 'credit_card_model.dart';
import 'expense_model.dart';

/// A tela de um cartão inteira, como `GET /credit-cards/:id/invoice` a devolve:
/// o cartão, o que cai na fatura do mês, e o total.
///
/// **Não confundir com `CreditCardInvoiceModel`.** Aquele é a fatura resumida
/// que vem dentro de `/summary`, para o carrossel da home — tem o total e os
/// primeiros itens, e não tem fechamento nem vencimento. Este é o corpo da tela
/// do cartão, com o cadastro completo e todos os gastos da competência.
///
/// Existe para a tela abrir com **uma** requisição. Antes dela o app pedia o
/// cartão e os gastos em duas rotas e somava o total no cliente.
class CreditCardBillModel {
  const CreditCardBillModel({
    required this.card,
    required this.expenses,
    required this.month,
    required this.totalCents,
  });

  final CreditCardModel card;
  final List<ExpenseModel> expenses;

  /// A competência da fatura, `YYYY-MM`. Ecoada pelo backend.
  final String month;

  /// A soma do que está em [expenses], calculada pelo backend.
  ///
  /// Vem pronta e não é somada aqui: num gasto parcelado o valor do mês não
  /// está no `history`, está nas parcelas (GFX-09), e refazer essa conta no app
  /// seria a mesma regra escrita em dois lugares que podem discordar.
  final int totalCents;

  factory CreditCardBillModel.fromJson(Map<String, dynamic> json) =>
      CreditCardBillModel(
        card: CreditCardModel.fromJson(json['card'] as Map<String, dynamic>),
        expenses: (json['expenses'] as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .map(ExpenseModel.fromJson)
            .toList(growable: false),
        month: json['month'] as String,
        totalCents: json['totalCents'] as int,
      );
}
