import 'package:signals/signals.dart';

import '../../core/shared/mixin/message_mixin.dart';
import '../../core/utils/month_utils.dart';

class SelectedMonthService with MessageMixin {
  static String initial() => MonthUtils.next(MonthUtils.current());
  static final _first = MonthUtils.of(MonthUtils.minYear, 1);
  static final _last = MonthUtils.of(MonthUtils.maxYear, 12);
  late final ReadonlySignal<String> label = computed(
    () => MonthUtils.label(_month.value),
  );
  late final ReadonlySignal<String> shortLabel = computed(
    () => MonthUtils.shortLabel(_month.value),
  );
  late final ReadonlySignal<bool> isCurrent = computed(
    () => MonthUtils.isCurrent(_month.value),
  );

  bool select(String month) {
    if (!MonthUtils.isValid(month) || month == _month.value) return false;
    _month.value = month;
    return true;
  }

  final _month = signal<String>(initial());
  ReadonlySignal<String> get month => _month;

  bool goToPrevious() {
    if (!MonthUtils.hasPrevious(_month.value)) {
      toastError('${MonthUtils.label(_first)} é o mês mais antigo do app.');
      return false;
    }
    return select(MonthUtils.previous(_month.value));
  }

  bool goToNext() {
    if (!MonthUtils.hasNext(_month.value)) {
      toastError('${MonthUtils.label(_last)} é o mês mais distante do app.');
      return false;
    }
    return select(MonthUtils.next(_month.value));
  }

  bool goToCurrent() => select(MonthUtils.current());

  void dispose() => _month.dispose();
}
