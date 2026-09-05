import 'package:signals/signals.dart';

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
class SelectedMonthService {
  /// O mês em que o app abre — ver a explicação na classe.
  ///
  /// É `static` e público porque teste e código precisam do mesmo valor. Sem
  /// ele, "o mês em que o app abre" e "o mês do relógio" seriam a mesma
  /// expressão escrita nos dois casos, e a próxima mudança de padrão teria de
  /// separar um do outro a olho, teste por teste.
  static String initial() => Month.next(Month.current());

  final _month = signal<String>(initial());

  /// Para ler dentro de `build`/`SignalBuilder`, onde a leitura precisa ser
  /// rastreada — trocar o mês repinta quem depende dele.
  ReadonlySignal<String> get month => _month;

  /// `'Setembro 2026'`. Derivado: trocar o mês reformata sozinho.
  late final ReadonlySignal<String> label = computed(
    () => Month.label(_month.value),
  );

  /// `'set/2026'`. É o que cabe na AppBar, que divide espaço com o botão do
  /// menu, as duas setas e o sino.
  late final ReadonlySignal<String> shortLabel = computed(
    () => Month.shortLabel(_month.value),
  );

  /// A competência exibida é a de hoje? A UI usa para destacar o "hoje" e
  /// habilitar o atalho de voltar ao mês corrente.
  late final ReadonlySignal<bool> isCurrent = computed(
    () => Month.isCurrent(_month.value),
  );

  /// Falsos nos limites que o backend aceita (2000–2100), para a seta ficar
  /// desabilitada em vez de disparar uma requisição que voltaria 400.
  late final ReadonlySignal<bool> canGoPrevious = computed(
    () => Month.hasPrevious(_month.value),
  );

  late final ReadonlySignal<bool> canGoNext = computed(
    () => Month.hasNext(_month.value),
  );

  /// Troca a competência. Devolve se ela de fato mudou, para quem chamou saber
  /// se precisa buscar de novo — pedir o mês que já está selecionado não é
  /// erro, é toque repetido.
  ///
  /// Mês inválido é ignorado em silêncio: a única origem possível é dado de
  /// rota ou de fora, e derrubar a tela por causa disso seria pior que
  /// continuar no mês que já estava.
  bool select(String month) {
    if (!Month.isValid(month) || month == _month.value) return false;
    _month.value = month;
    return true;
  }

  bool goToPrevious() =>
      canGoPrevious.value && select(Month.previous(_month.value));

  bool goToNext() => canGoNext.value && select(Month.next(_month.value));

  bool goToCurrent() => select(Month.current());

  /// Na prática não roda: nada em produção chama `getIt.reset()` — o
  /// `resetInjector` está comentado — e o registro de teste é feito sem
  /// `dispose:` de propósito. Existe para o dia em que o reset voltar, e para
  /// o registro não prometer uma limpeza que não sabe fazer.
  void dispose() => _month.dispose();
}
