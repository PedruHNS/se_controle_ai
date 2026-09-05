import 'package:flutter/material.dart';

/// Cores que o `ColorScheme` do Material não tem, mas o app precisa.
///
/// O **alerta** existe porque o app tem três estados de gravidade — normal,
/// atenção, estourado — e o `ColorScheme` só oferece dois (`primary` e
/// `error`). Antes disso, os dois pontos que precisavam do intermediário
/// usavam `Colors.orange` fixo, que no tema escuro fica saturado demais contra
/// o fundo.
///
/// O **card** existe porque o branco do tema claro é uma decisão de design que
/// o esquema não tem como derivar. Ele estava escrito como `Colors.white`
/// dentro dos widgets, e por isso o card continuava branco no tema escuro —
/// com o texto do tema escuro por cima, claro sobre claro, ilegível.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.warning,
    required this.onWarning,
    required this.card,
    required this.cardShadow,
  });

  /// Comprometimento acima de 80%, fatura acima de 80% do limite. Ainda não é
  /// erro — é o aviso de que está chegando perto.
  final Color warning;
  final Color onWarning;

  /// O fundo dos cards de lista — cartão e tag.
  ///
  /// No claro é branco puro e não `surfaceContainerLow`: o do esquema claro é
  /// `#F6F2FF`, um lilás pálido que quase encosta no fundo `#FCF8FF` e apaga o
  /// card. No escuro a lógica se inverte — o que separa card de fundo lá é
  /// clarear, e o degrau do esquema serve exatamente para isso.
  final Color card;

  /// A sombra do card.
  ///
  /// No claro é o índigo do app a 10%, que dá profundidade sem sujar de cinza.
  /// No escuro sombra colorida não aparece contra um fundo quase preto: só
  /// preto, e mais opaco, ainda separa alguma coisa.
  final Color cardShadow;

  static const _light = AppColors(
    warning: Color(0xFFB26A00),
    onWarning: Color(0xFFFFFFFF),
    card: Color(0xFFFFFFFF),
    cardShadow: Color(0x1A393360),
  );

  /// Mais claro e menos saturado que o do tema claro: laranja forte sobre fundo
  /// escuro vibra e cansa, além de competir com o vermelho do erro.
  static const _dark = AppColors(
    warning: Color(0xFFFFB74D),
    onWarning: Color(0xFF3E2600),
    // `card` é sobrescrito em `_build` pelo `surfaceContainerLow` do esquema.
    // O valor aqui é o que ele resolve hoje, para a constante não mentir para
    // quem a ler solta.
    card: Color(0xFF1B1A25),
    cardShadow: Color(0x66000000),
  );

  @override
  AppColors copyWith({
    Color? warning,
    Color? onWarning,
    Color? card,
    Color? cardShadow,
  }) => AppColors(
    warning: warning ?? this.warning,
    onWarning: onWarning ?? this.onWarning,
    card: card ?? this.card,
    cardShadow: cardShadow ?? this.cardShadow,
  );

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other == null) return this;
    return AppColors(
      warning: Color.lerp(warning, other.warning, t)!,
      onWarning: Color.lerp(onWarning, other.onWarning, t)!,
      card: Color.lerp(card, other.card, t)!,
      cardShadow: Color.lerp(cardShadow, other.cardShadow, t)!,
    );
  }
}

/// Os raios de canto do app, em um lugar só.
///
/// Três degraus, e não um valor por widget: o que muda entre eles é o tamanho
/// da superfície, não o gosto. Campo e botão usam [_small], cartão e caixa
/// usam [_medium], o que cobre a tela — diálogo, folha de baixo — usa
/// [_large]. Misturar raios parecidos (12 aqui, 14 ali) é o tipo de detalhe
/// que ninguém aponta e todo mundo sente.
const _small = 12.0;
const _medium = 16.0;
const _large = 24.0;

/// Os dois temas do app, do mesmo seed.
///
/// `fromSeed` e não cores escritas à mão: o Material 3 deriva o esquema inteiro
/// — inclusive os pares `on*`, que são o que garante contraste — e derivar duas
/// vezes a partir do mesmo seed é o que faz claro e escuro serem o mesmo app,
/// não dois parecidos.
///
/// A variante é [DynamicSchemeVariant.vibrant] e não a padrão `tonalSpot`
/// porque essa lava a cor: o mesmo seed sai como `#5B5891`, um cinza-arroxeado
/// que parece protótipo. A `vibrant` mantém a chroma do índigo (`#4C34FF` no
/// claro, `#C4C0FF` no escuro) e ainda deriva os pares `on*` com o mesmo rigor
/// — nenhum par usado aqui fica abaixo de 4.5:1.
abstract final class AppTheme {
  /// Índigo, e não o roxo padrão do Material: é a família que o app já usava
  /// nas sombras dos cartões, e ela lê como "dinheiro sério" sem ser mais um
  /// app azul-banco.
  static const seed = Color(0xFF5B4FE9);

  static final light = _build(Brightness.light, AppColors._light);
  static final dark = _build(Brightness.dark, AppColors._dark);

  static ThemeData _build(Brightness brightness, AppColors colors) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
      dynamicSchemeVariant: DynamicSchemeVariant.vibrant,
    );

    final base = ThemeData(colorScheme: scheme);
    final text = _typography(base.textTheme);

    // O card escuro sai do esquema em vez de uma constante escrita à mão: é o
    // mesmo `surfaceContainerLow` do `cardTheme` logo abaixo, então card custom
    // e `Card` do Material não divergem se o seed mudar.
    final appColors = brightness == Brightness.dark
        ? colors.copyWith(card: scheme.surfaceContainerLow)
        : colors;

    return base.copyWith(
      extensions: [appColors],
      textTheme: text,
      scaffoldBackgroundColor: scheme.surface,
      // O respingo do Android 12 em vez do circular antigo. Não muda nada de
      // layout, mas é a diferença entre um toque que responde e um que só
      // acontece.
      splashFactory: InkSparkle.splashFactory,
      // Sem elevação nos cards: o app empilha card sobre fundo o tempo todo, e
      // no escuro a elevação do Material 3 clareia a superfície — o que
      // transformaria a home num degradê de cinzas. A borda separa melhor.
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_medium),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
        titleTextStyle: text.titleLarge,
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1),
      // O FAB em `primary`, e não no `primaryContainer` do padrão: no claro o
      // container é um lilás pálido que some contra o fundo quase branco, e o
      // botão de criar é justamente o que precisa ser achado sem procurar.
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 2,
        highlightElevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_medium),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(style: _button(text)),
      elevatedButtonTheme: ElevatedButtonThemeData(style: _button(text)),
      outlinedButtonTheme: OutlinedButtonThemeData(style: _button(text)),
      textButtonTheme: TextButtonThemeData(style: _button(text)),
      // Campo preenchido em vez de só contornado: o preenchimento é o que
      // mostra onde se escreve antes de tocar, e num formulário de gasto —
      // valor, data, cartão, tag — são muitos alvos na mesma tela.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_small),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_small),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_small),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_small),
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_small),
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_large),
        ),
        titleTextStyle: text.headlineSmall,
        contentTextStyle: text.bodyMedium,
      ),
      // Flutuante e arredondada: encostada no rodapé ela cobre justamente o
      // FAB, que é onde a mão está depois de criar ou excluir alguma coisa.
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: text.bodyMedium?.copyWith(
          color: scheme.onInverseSurface,
        ),
        actionTextColor: scheme.inversePrimary,
        elevation: 3,
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_small),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surfaceContainerHigh,
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_small),
        ),
        textStyle: text.bodyMedium,
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(scheme.surfaceContainerHigh),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(_small)),
          ),
        ),
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        elevation: 1,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.horizontal(right: Radius.circular(_large)),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_small),
        ),
        selectedColor: scheme.onSecondaryContainer,
        selectedTileColor: scheme.secondaryContainer,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        selectedColor: scheme.secondaryContainer,
        side: BorderSide(color: scheme.outlineVariant),
        labelStyle: text.labelLarge,
        shape: const StadiumBorder(),
        showCheckmark: false,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        elevation: 0,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHighest,
        circularTrackColor: Colors.transparent,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: scheme.inverseSurface,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: text.bodySmall?.copyWith(color: scheme.onInverseSurface),
      ),
    );
  }

  /// O mesmo botão em todas as variantes: 48 de altura, canto do degrau
  /// pequeno e rótulo semibold.
  ///
  /// 48 é o alvo mínimo de toque do Material, e o padrão do Flutter entrega 40
  /// — três pixels a menos de cada lado num "Salvar" no fim de um formulário
  /// longo é onde o toque erra.
  static ButtonStyle _button(TextTheme text) => ButtonStyle(
    minimumSize: const WidgetStatePropertyAll(Size(64, 48)),
    padding: const WidgetStatePropertyAll(
      EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    ),
    textStyle: WidgetStatePropertyAll(text.labelLarge),
    shape: WidgetStatePropertyAll(
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(_small)),
    ),
  );

  /// Ajuste de tipografia sobre a escala do Material, sem trocar a fonte.
  ///
  /// Só duas coisas mudam, e nenhuma delas é tamanho: **peso** nos títulos e
  /// rótulos, que o padrão deixa em `w400` e some no meio do texto corrido, e
  /// **espaçamento negativo** nos números grandes. Saldo e total são o que a
  /// pessoa abre o app para ver, e o Roboto solta as letras o bastante para um
  /// `R$ 1.234,56` parecer largo demais para caber onde cabe.
  ///
  /// Trocar a fonte exigiria dependência nova ou arquivo em `assets`, e o app
  /// não tem nenhum dos dois.
  static TextTheme _typography(TextTheme base) => base.copyWith(
    displayLarge: base.displayLarge?.copyWith(
      fontWeight: FontWeight.w600,
      letterSpacing: -1.5,
    ),
    displayMedium: base.displayMedium?.copyWith(
      fontWeight: FontWeight.w600,
      letterSpacing: -1,
    ),
    displaySmall: base.displaySmall?.copyWith(
      fontWeight: FontWeight.w600,
      letterSpacing: -0.5,
    ),
    headlineLarge: base.headlineLarge?.copyWith(
      fontWeight: FontWeight.w600,
      letterSpacing: -0.5,
    ),
    headlineMedium: base.headlineMedium?.copyWith(
      fontWeight: FontWeight.w600,
      letterSpacing: -0.4,
    ),
    headlineSmall: base.headlineSmall?.copyWith(
      fontWeight: FontWeight.w600,
      letterSpacing: -0.3,
    ),
    titleLarge: base.titleLarge?.copyWith(
      fontWeight: FontWeight.w600,
      letterSpacing: -0.2,
    ),
    titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w600),
    titleSmall: base.titleSmall?.copyWith(fontWeight: FontWeight.w600),
    labelLarge: base.labelLarge?.copyWith(fontWeight: FontWeight.w600),
  );
}

/// Atalho para as cores fora do `ColorScheme`.
///
/// Nunca é nulo em widget do app — os dois temas registram a extensão —, mas o
/// `?` do Flutter obriga a tratar. O fallback é o do tema claro, e não uma cor
/// inventada, porque um widget montado sem `AppTheme` é teste, não tela.
extension AppColorsX on ThemeData {
  AppColors get appColors => extension<AppColors>() ?? AppColors._light;
}
