import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/models/auth_user_model.dart';

/// Avisa o `GoRouter` de que o estado de autenticação mudou.
///
/// O `redirect` do go_router não é reativo: ele roda em cada navegação, e não
/// quando um dado muda. Sem este `Listenable`, sair da conta deixaria a pessoa
/// parada na tela em que estava — a decisão de mandá-la ao login só valeria na
/// próxima vez que ela tocasse em alguma coisa.
///
/// É um `ChangeNotifier` de uma linha porque não guarda estado: quem sabe quem
/// está logado é o repositório, e o `redirect` o consulta na hora. Guardar uma
/// cópia aqui criaria uma segunda verdade para divergir da primeira.
class AuthRefresh extends ChangeNotifier {
  AuthRefresh(Stream<AuthUserModel?> changes) {
    _subscription = changes.listen((_) => notifyListeners());
  }

  late final StreamSubscription<AuthUserModel?> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
