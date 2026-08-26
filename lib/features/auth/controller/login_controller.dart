import 'dart:async';

import 'package:signals/signals.dart';

import '../../../core/errors/failure.dart';
import '../../../core/utils/base_controller.dart';
import '../../../data/models/auth_user_model.dart';
import '../../../data/repositories/auth_repository.dart';

/// Entrar e sair.
///
/// Sem `ViewState` aqui, ao contrário das listas: não há nada a carregar. O
/// estado desta tela é "trabalhando ou não" mais "quem está logado", e envolvê-
/// los num `Loading/Loaded/Failed` só acrescentaria um caso impossível — uma
/// tela de login que falha ao *abrir*.
class LoginController extends BaseController {
  LoginController(this._repository);

  final AuthRepository _repository;

  final _user = signal<AuthUserModel?>(null);
  final _working = signal<bool>(false);
  final _failure = signal<Failure?>(null);

  StreamSubscription<AuthUserModel?>? _subscription;

  /// Quem está logado, ou `null`.
  ReadonlySignal<AuthUserModel?> get user => _user;

  /// Login em andamento. A tela desabilita o botão — tocar duas vezes abriria
  /// duas folhas de escolha de conta, e a segunda cancela a primeira.
  ReadonlySignal<bool> get working => _working;

  /// A última falha, ou `null`. Fica na tela em vez de virar toast: quem não
  /// conseguiu entrar continua olhando para esta página, e o aviso precisa
  /// continuar visível junto do botão que se vai tocar de novo.
  ReadonlySignal<Failure?> get failure => _failure;

  @override
  void onInit() {
    super.onInit();

    _user.value = _repository.current;

    // Escutar em vez de só ler uma vez: o token pode ser revogado do lado do
    // Firebase, e aí a sessão cai sem ninguém ter tocado em nada.
    _subscription = _repository.changes.listen((user) => _user.value = user);
  }

  @override
  void dispose() {
    super.dispose();
    _subscription?.cancel();
    _user.dispose();
    _working.dispose();
    _failure.dispose();
  }

  Future<void> signInWithGoogle() async {
    _working.value = true;
    _failure.value = null;

    final result = await _repository.signInWithGoogle();

    _working.value = false;

    result.whenError((failure) {
      // Desistir não vira aviso. A pessoa fechou a folha de escolha de conta —
      // a tela só volta ao que era, sem nada vermelho para ela dispensar.
      if (failure is CancelledFailure) return;

      _failure.value = failure;
    });
  }

  Future<void> signOut() async {
    _working.value = true;
    _failure.value = null;

    final result = await _repository.signOut();

    _working.value = false;

    result.whenError((failure) => _failure.value = failure);
  }
}
