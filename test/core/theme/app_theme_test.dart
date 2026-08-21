import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:se_controle_ai/core/theme/app_theme.dart';

void main() {
  group('AppTheme', () {
    test('claro e escuro saem do mesmo seed, com brilhos opostos', () {
      expect(AppTheme.light.colorScheme.brightness, Brightness.light);
      expect(AppTheme.dark.colorScheme.brightness, Brightness.dark);
    });

    test('os dois registram a extensão de cores', () {
      expect(AppTheme.light.appColors.warning, isNot(Colors.transparent));
      expect(AppTheme.dark.appColors.warning, isNot(Colors.transparent));
    });

    test('o alerta é diferente nos dois temas', () {
      expect(
        AppTheme.dark.appColors.warning,
        isNot(AppTheme.light.appColors.warning),
        reason: 'laranja de tema claro sobre fundo escuro vibra e cansa',
      );
    });

    // Não é preciosismo: no escuro, a elevação do Material 3 clareia a
    // superfície, e a home empilha card sobre card.
    test('card não tem elevação, para o escuro não virar degradê', () {
      expect(AppTheme.dark.cardTheme.elevation, 0);
      expect(AppTheme.light.cardTheme.elevation, 0);
    });

    test('o fallback da extensão é o tema claro, não uma cor inventada', () {
      final semExtensao = ThemeData.light();

      expect(semExtensao.appColors.warning, AppTheme.light.appColors.warning);
    });
  });
}
