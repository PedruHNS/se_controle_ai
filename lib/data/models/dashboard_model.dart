import 'dashboard_allowance_model.dart';
import 'dashboard_card_model.dart';
import 'dashboard_daily_model.dart';
import 'dashboard_history_entry_model.dart';
import 'dashboard_nature_model.dart';
import 'dashboard_tag_amount_model.dart';
import 'dashboard_top_expense_model.dart';
import 'dashboard_totals_model.dart';

/// A resposta inteira de `GET /dashboard?month=YYYY-MM`: os sete cards da tela
/// e o `totals` do topo, numa requisição só.
///
/// **Todos os blocos vêm sempre**, mesmo num mês sem nenhum lançamento —
/// listas vazias e zeros, nunca chave ausente (DSH-02). É o que permite a tela
/// montar os sete cards sem checar existência de campo.
///
/// Agregado no backend de propósito: `byTag` é um `GROUP BY` de uma linha em
/// SQL e dezenas de linhas de agrupamento aqui; `history` sem rota seriam seis
/// requisições; e `byNature` nem era computável no app, porque os itens do
/// resumo não carregam o tipo do gasto.
class DashboardModel {
  const DashboardModel({
    required this.month,
    required this.totals,
    required this.allowance,
    required this.byTag,
    required this.daily,
    required this.cards,
    required this.byNature,
    required this.history,
    required this.topExpenses,
  });

  /// A competência que a resposta descreve, `YYYY-MM`. Ecoada pelo backend —
  /// sem `?month` ele responde a competência do relógio dele (DSH-01).
  final String month;

  final DashboardTotalsModel totals;
  final DashboardAllowanceModel allowance;

  /// Do maior para o menor, com o nome da tag como desempate (DSH-09).
  final List<DashboardTagAmountModel> byTag;

  final DashboardDailyModel daily;

  /// Da maior fatura para a menor, com o nome como desempate (DSH-16).
  final List<DashboardCardModel> cards;

  final DashboardNatureModel byNature;

  /// Seis competências terminando na pedida, inclusive (DSH-20).
  final List<DashboardHistoryEntryModel> history;

  /// Os cinco maiores, do maior para o menor (DSH-23).
  final List<DashboardTopExpenseModel> topExpenses;

  factory DashboardModel.fromJson(Map<String, dynamic> json) => DashboardModel(
    month: json['month'] as String,
    totals: DashboardTotalsModel.fromJson(
      json['totals'] as Map<String, dynamic>,
    ),
    allowance: DashboardAllowanceModel.fromJson(
      json['allowance'] as Map<String, dynamic>,
    ),
    byTag: _lista(json['byTag'], DashboardTagAmountModel.fromJson),
    daily: DashboardDailyModel.fromJson(json['daily'] as Map<String, dynamic>),
    cards: _lista(json['cards'], DashboardCardModel.fromJson),
    byNature: DashboardNatureModel.fromJson(
      json['byNature'] as Map<String, dynamic>,
    ),
    history: _lista(json['history'], DashboardHistoryEntryModel.fromJson),
    topExpenses: _lista(json['topExpenses'], DashboardTopExpenseModel.fromJson),
  );

  static List<T> _lista<T>(
    dynamic value,
    T Function(Map<String, dynamic>) fromJson,
  ) => (value as List<dynamic>)
      .cast<Map<String, dynamic>>()
      .map(fromJson)
      .toList(growable: false);

  // Listas viram contagem: um dashboard inteiro num `log` ou numa falha de
  // teste seriam trinta linhas de série diária, e o que ajuda a achar o erro é
  // o mês e o tamanho de cada bloco.
  @override
  String toString() =>
      'DashboardModel(month: $month, totals: $totals, allowance: $allowance, '
      'byTag: ${byTag.length}, daily: $daily, cards: ${cards.length}, '
      'byNature: $byNature, history: ${history.length}, '
      'topExpenses: ${topExpenses.length})';
}
