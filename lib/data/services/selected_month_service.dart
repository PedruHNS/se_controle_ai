import 'package:signals/signals.dart';

import '../../core/shared/mixin/message_mixin.dart';
import '../../core/utils/month.dart';

class SelectedMonthService with MessageMixin {
  static String initial() => Month.next(Month.current());
  static final _first = Month.of(Month.minYear, 1);
  static final _last = Month.of(Month.maxYear, 12);
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

  final _month = signal<String>(initial());
  ReadonlySignal<String> get month => _month;

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
