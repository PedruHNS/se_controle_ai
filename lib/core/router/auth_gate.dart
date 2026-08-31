import 'app_routes.dart';

/// A decisão do `redirect`, sem `BuildContext` e sem `GoRouter`.
///
/// Está fora do [appRouter] para poder ser testada como o que é: uma função de
/// quatro entradas para uma saída. Pelo router ela só é alcançável com um
/// `pumpWidget`, um injetor montado e um router global que guarda estado entre
/// testes — e aí o que falha não diz qual das quatro combinações quebrou.
///
/// Devolve `null` para "fica onde está", que é o contrato do go_router.
String? rotaParaEstado({
  required bool sessaoResolvida,
  required bool logado,
  required String indoPara,
  String? guardado,
}) {
  final noSplash = indoPara == AppRoutes.splashPath;
  final noLogin = indoPara == AppRoutes.loginPath;

  // Ainda não se sabe se há sessão. Qualquer decisão aqui tem chance de estar
  // errada, então a única saída honesta é esperar — e guardar onde a pessoa
  // queria chegar.
  if (!sessaoResolvida) {
    if (noSplash) return null;
    if (noLogin) return AppRoutes.splashPath;

    return '${AppRoutes.splashPath}'
        '?${AppRoutes.deParam}=${Uri.encodeComponent(indoPara)}';
  }

  if (!logado) return noLogin ? null : AppRoutes.loginPath;

  // Logado e saindo da espera: vai para onde queria ir. Se o destino guardado
  // for o próprio login ou o próprio splash, a home é o único lugar que sobra —
  // devolver um deles daria um ciclo.
  if (noSplash) {
    return guardado == null ||
            guardado == AppRoutes.loginPath ||
            guardado == AppRoutes.splashPath
        ? AppRoutes.homePath
        : guardado;
  }

  // Já logado, a tela de login não tem o que fazer — inclusive quando se chega
  // nela por link ou por `--route`, que é como ela era alcançada antes de este
  // redirect existir.
  return noLogin ? AppRoutes.homePath : null;
}
