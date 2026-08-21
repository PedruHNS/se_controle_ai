import 'package:flutter/material.dart';

/// Cores que o `ColorScheme` do Material não tem, mas o app precisa.
///
/// Hoje é só o alerta. Ele existe porque o app tem **três** estados de
/// gravidade — normal, atenção, estourado — e o `ColorScheme` só oferece dois
/// (`primary` e `error`). Antes disso, os dois pontos que precisavam do
/// intermediário usavam `Colors.orange` fixo, que no tema escuro fica saturado
/// demais contra o fundo.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({required this.warning, required this.onWarning});

  /// Comprometimento acima de 80%, fatura acima de 80% do limite. Ainda não é
  /// erro — é o aviso de que está chegando perto.
  final Color warning;
  final Color onWarning;

  static const _light = AppColors(
    warning: Color(0xFFB26A00),
    onWarning: Color(0xFFFFFFFF),
  );

  /// Mais claro e menos saturado que o do tema claro: laranja forte sobre fundo
  /// escuro vibra e cansa, além de competir com o vermelho do erro.
  static const _dark = AppColors(
    warning: Color(0xFFFFB74D),
    onWarning: Color(0xFF3E2600),
  );

  @override
  AppColors copyWith({Color? warning, Color? onWarning}) => AppColors(
    warning: warning ?? this.warning,
    onWarning: onWarning ?? this.onWarning,
  );

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other == null) return this;
    return AppColors(
      warning: Color.lerp(warning, other.warning, t)!,
      onWarning: Color.lerp(onWarning, other.onWarning, t)!,
    );
  }
}

/// Os dois temas do app, do mesmo seed.
///
/// `fromSeed` e não cores escritas à mão: o Material 3 deriva o esquema inteiro
/// — inclusive os pares `on*`, que são o que garante contraste — e derivar duas
/// vezes a partir do mesmo seed é o que faz claro e escuro serem o mesmo app,
/// não dois parecidos.
abstract final class AppTheme {
  static const seed = Colors.deepPurple;

  static final light = _build(Brightness.light, AppColors._light);
  static final dark = _build(Brightness.dark, AppColors._dark);

  static ThemeData _build(Brightness brightness, AppColors colors) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );

    return ThemeData(
      colorScheme: scheme,
      extensions: [colors],
      // Sem elevação nos cards: o app empilha card sobre fundo o tempo todo, e
      // no escuro a elevação do Material 3 clareia a superfície — o que
      // transformaria a home num degradê de cinzas. A borda separa melhor.
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1),
    );
  }
}

/// Atalho para as cores fora do `ColorScheme`.
///
/// Nunca é nulo em widget do app — os dois temas registram a extensão —, mas o
/// `?` do Flutter obriga a tratar. O fallback é o do tema claro, e não uma cor
/// inventada, porque um widget montado sem `AppTheme` é teste, não tela.
extension AppColorsX on ThemeData {
  AppColors get appColors => extension<AppColors>() ?? AppColors._light;
}
