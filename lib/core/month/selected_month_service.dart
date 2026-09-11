import 'package:signals/signals.dart';

import '../shared/mixin/message_mixin.dart';
import '../utils/month.dart';

/// A competência que o app inteiro está olhando.
///
/// **Existe porque "o mês" não é da home.** As setas ficam na AppBar dela, mas
/// quem responde por gasto, ganho, fatura e projeção é o mesmo mês: abrir
/// Gastos em setembro e ver o total de agosto não é uma tela errada, é duas
/// telas com fontes diferentes. Antes disto cada uma chamava `Month.current()`
/// por conta própria, e o relógio do aparelho vencia a escolha da pessoa.
///
/// Fica em `core` e não em `features/home` de propósito: gastos não deve
/// importar código de home para saber que mês mostrar.
///
/// **É um service, e não um controller.** Não tem `ViewState`, não busca nada,
/// não é liberado ao sair de página nenhuma e não pertence a tela alguma — é
/// `lazySingleton` no `getIt` e vive o app inteiro. Quem busca é quem depende
/// dele. Foi um `BaseController` até aqui, e herdava dele só o log de `onInit`:
/// o nome dizia "tela" para algo que sete telas compartilham.
///
/// A escolha não sobrevive a fechar o app, pelo mesmo motivo do tema: guardar
/// exige armazenamento local, que chega na Fase 10.
///
/// **Abrir cai no mês seguinte, não no corrente.** Quem abre o app está
/// lançando o que ainda vai acontecer — a fatura que fecha, o salário que
/// entra — e não conferindo o mês que já correu. O corrente continua a um
/// toque: é a seta de voltar, e é para onde [goToCurrent] leva, que segue
/// sendo o mês do relógio e não este de partida.
class SelectedMonthService with MessageMixin {
  static String initial() => Month.next(Month.current());

  final _month = signal<String>(initial());

  ReadonlySignal<String> get month => _month;

  late final ReadonlySignal<String> label = computed(
    () => Month.label(_month.value),
  );

  late final ReadonlySignal<String> shortLabel = computed(
    () => Month.shortLabel(_month.value),
  );

  late final ReadonlySignal<bool> isCurrent = computed(
    () => Month.isCurrent(_month.value),
  );

  bool select(String month) {
    if (!Month.isValid(month) || month == _month.value) return false;
    _month.value = month;
    return true;
  }

  static final _first = Month.of(Month.minYear, 1);
  static final _last = Month.of(Month.maxYear, 12);

  bool goToPrevious() {
    if (!Month.hasPrevious(_month.value)) {
      toastError('${Month.label(_first)} é o mês mais antigo do app.');
      return false;
    }
    return select(Month.previous(_month.value));
  }

  bool goToNext() {
    if (!Month.hasNext(_month.value)) {
      toastError('${Month.label(_last)} é o mês mais distante do app.');
      return false;
    }
    return select(Month.next(_month.value));
  }

  bool goToCurrent() => select(Month.current());

  void dispose() => _month.dispose();
}
