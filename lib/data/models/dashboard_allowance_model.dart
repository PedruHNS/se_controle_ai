import '../enums/dashboard_scope.dart';

/// O bloco `allowance` — o que o card 1 responde: quanto ainda cabe por dia.
///
/// O [scope] é o que dá sentido ao número: no mês corrente é "quanto ainda
/// cabe", num mês que já passou é a média diária realizada, e num futuro é o
/// orçamento diário (DSH-06).
class DashboardAllowanceModel {
  const DashboardAllowanceModel({
    required this.scope,
    required this.daysRemaining,
    required this.perDayCents,
    required this.overspentCents,
  });

  final DashboardScope scope;

  /// Dias que entram na divisão. No mês corrente, os que faltam **contando
  /// hoje** (DSH-05): dia 10 de um mês de 30 são 21, e no dia 30 é 1, nunca 0.
  final int daysRemaining;

  /// Já arredondado para baixo pelo backend (DSH-08): gastar esse valor todos
  /// os dias nunca estoura a sobra.
  ///
  /// **Null quando não há o que distribuir** (DSH-07) — o mês fechou no
  /// vermelho em `current` ou `future`. Dividir um negativo por dias é
  /// aritmética certa e conselho inútil, então a tela troca a frase, não o
  /// sinal. Em `past` continua vindo preenchido, porque lá é média realizada.
  final int? perDayCents;

  /// Quanto passou do que havia, **inteiro positivo**, sempre que o mês fecha
  /// no vermelho — inclusive em `past` (DSH-07). Null quando não passou.
  final int? overspentCents;

  factory DashboardAllowanceModel.fromJson(Map<String, dynamic> json) =>
      DashboardAllowanceModel(
        scope: DashboardScope.fromWire(json['scope'] as String),
        daysRemaining: json['daysRemaining'] as int,
        perDayCents: json['perDayCents'] as int?,
        overspentCents: json['overspentCents'] as int?,
      );

  @override
  String toString() =>
      'DashboardAllowanceModel(scope: $scope, daysRemaining: $daysRemaining, perDayCents: $perDayCents, overspentCents: $overspentCents)';
}
