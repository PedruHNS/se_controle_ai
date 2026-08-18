import 'package:flutter/material.dart';

import 'app.dart';
import 'core/di/injector.dart';

void main() {
  // Antes do runApp: a primeira tela já pode resolver dependência do get_it, e
  // registrar depois daria "Object/factory not registered" no primeiro build.
  setupInjector();

  runApp(const MyApp());
}
