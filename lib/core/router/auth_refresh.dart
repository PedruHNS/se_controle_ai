import 'dart:async';

import 'package:signals/signals_flutter.dart';

import '../../data/models/auth_user_model.dart';

/// Avisa o `GoRouter` de que o estado de autenticação mudou — e diz se já se
/// **sabe** qual é esse estado.
///
/// O `redirect` do go_router não é reativo: ele roda em cada navegação, e não
/// quando um dado muda. Sem este aviso, sair da conta deixaria a pessoa parada
/// na tela em que estava — a decisão de mandá-la ao login só valeria na próxima
/// vez que ela tocasse em alguma coisa.
///
/// **É um signal, como o resto do app.** O `refreshListenable` do go_router pede
/// um `Listenable`, e o `signal()` do `signals_flutter` já é um: `FlutterSignal`
/// implementa `ValueNotifier`. Não é preciso um `ChangeNotifier` no meio só para
/// atender a assinatura — seria um segundo jeito de guardar estado nesta base,
/// convivendo com o único que ela usa.
///
/// **O que ele guarda é um contador, e não o usuário.** Quem sabe quem está
/// logado é o repositório, e o `redirect` o consulta na hora; guardar uma cópia
/// aqui criaria uma segunda verdade para divergir da primeira — e a que decide
/// navegação é a pior das duas para estar errada. O contador existe porque um
/// signal só notifica quando o valor **muda**: com o usuário dentro, o primeiro
/// evento de quem não está logado seria `null` → `null`, mudança nenhuma, e o
/// router ficaria esperando para sempre na tela de espera.
class AuthRefresh {
  AuthRefresh(Stream<AuthUserModel?> changes) {
    _subscription = changes.listen(
      // Incrementar antes de qualquer coisa: o `redirect` roda dentro da
      // notificação do signal, e ele lê [resolvido] daqui. Notificar primeiro e
      // marcar depois deixaria o app na espera, sem nenhum evento novo para
      // tirá-lo de lá.
      (_) => _eventos.value++,
      // Stream que fecha sem emitir nada também é uma resposta: não vem mais
      // evento, então esperar por um é esperar para sempre.
      onDone: () => _eventos.value++,
    );
  }

  late final StreamSubscription<AuthUserModel?> _subscription;

  final _eventos = signal(0);

  /// O que o `GoRouter` escuta.
  ///
  /// Somente leitura para ninguém de fora empurrar um refresh: o único fato que
  /// move este contador é um evento do Firebase. O tipo é o do `signals_flutter`
  /// — e não o `ReadonlySignal` do core — porque é ele que implementa
  /// `ValueListenable`, que é o que o `refreshListenable` do go_router pede.
  FlutterReadonlySignal<int> get mudancas => _eventos;

  /// Já se sabe se há alguém logado?
  ///
  /// Falso apenas nos primeiros quadros do app, entre o `runApp` e o primeiro
  /// evento do `authStateChanges()`. Nesse intervalo `currentUser` é nulo em
  /// quem **está** logado — o SDK ainda está lendo a sessão do disco —, e
  /// decidir navegação com isso manda ao login quem acabou de abrir o app.
  ///
  /// É pergunta diferente de "está logado": aqui a resposta possível é
  /// "ainda não sei".
  bool get resolvido => _eventos.value > 0;

  void dispose() {
    _subscription.cancel();
    _eventos.dispose();
  }
}
