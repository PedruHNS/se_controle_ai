import 'dart:developer';

import 'package:flutter/widgets.dart';

abstract class BaseController {
  BaseController({bool onReady = false}) {
    _onReady = onReady;
    onInit();
  }

  late final bool _onReady;

  @mustCallSuper
  void onInit() {
    log('[onInit] => $runtimeType');

    if (_onReady) {
      WidgetsBinding.instance.addPostFrameCallback((_) => onReady());
    }
  }

  @mustCallSuper
  void dispose() {
    log('[dispose] => $runtimeType');
  }

  @mustCallSuper
  void onReady() {
    log('[onReady] => $runtimeType');
  }
}
