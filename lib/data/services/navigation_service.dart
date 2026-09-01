import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:se_controle_ai/core/router/app_routes.dart';

class NavigationService {
  final GoRouter _router;

  NavigationService(this._router);

  void go(String route, {Object? arguments}) {
    _router.go(route, extra: arguments);
  }

  void goNamed(
    String route, {
    Map<String, String> pathParameters = const <String, String>{},
    Map<String, dynamic> queryParameters = const <String, dynamic>{},
    Object? extra,
    String? fragment,
  }) {
    _router.goNamed(
      route,
      pathParameters: pathParameters,
      queryParameters: queryParameters,
      extra: extra,
      fragment: fragment,
    );
  }

  /// Empilha por **caminho**: `/credit-cards/abc-123`.
  ///
  /// Para rota com parâmetro, use [pushNamed]. Passar um nome aqui não
  /// funciona — o go_router procura a location literal, não acha, e cai na
  /// tela de erro; e o `arguments` vira `extra`, que não preenche `:id`.
  Future<T?> push<T>(String route, {Object? arguments}) {
    return _router.push<T>(route, extra: arguments);
  }

  /// Empilha por **nome**, montando o caminho a partir dos parâmetros — o par
  /// de [goNamed], que já existia sozinho aqui.
  Future<T?> pushNamed<T>(
    String route, {
    Map<String, String> pathParameters = const <String, String>{},
    Map<String, dynamic> queryParameters = const <String, dynamic>{},
    Object? extra,
  }) {
    return _router.pushNamed<T>(
      route,
      pathParameters: pathParameters,
      queryParameters: queryParameters,
      extra: extra,
    );
  }

  Future<T?> pushReplacement<T>(String route, {Object? arguments}) {
    return _router.pushReplacement<T>(route, extra: arguments);
  }

  Future<T?> replace<T>(String route, {Object? arguments}) {
    return _router.replace<T>(route, extra: arguments);
  }

  void pop<T>([T? result]) {
    if (_router.canPop()) {
      _router.pop<T>(result);
    } else {
      if (kDebugMode) {
        debugPrint(
          '[NavigationService] pop called but cannot pop. Current route: ${_router.routeInformationProvider.value.uri.path}',
        );
      }
      _router.go(AppRoutes.home);
    }
  }
}
