import 'package:flutter/material.dart';
import 'package:signals/signals.dart';

import '../utils/base_controller.dart';

/// Qual tema o app usa: o do sistema, o claro ou o escuro.
///
/// **A escolha vive só nesta sessão.** Guardá-la exige armazenamento local, que
/// o app ainda não tem — é o que chega na Fase 10 (offline-first). Enquanto
/// isso, fechar e abrir volta para [ThemeMode.system], que é a preferência que
/// a pessoa já configurou uma vez no aparelho.
///
/// Por isso o padrão continua sendo o sistema, e não o claro: quem nunca abriu
/// o seletor não deve perceber que ele existe.
class ThemeController extends BaseController {
  final _mode = signal<ThemeMode>(ThemeMode.system);

  ReadonlySignal<ThemeMode> get mode => _mode;

  void select(ThemeMode value) => _mode.value = value;

  @override
  void dispose() {
    _mode.dispose();
    super.dispose();
  }
}
