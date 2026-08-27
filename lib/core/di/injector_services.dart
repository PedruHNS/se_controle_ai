part of 'injector.dart';

void _registerServices() {
  if (!getIt.isRegistered<NavigationService>()) {
    final router = appRouter;
    getIt.registerSingleton<NavigationService>(NavigationService(router));
  }
}
