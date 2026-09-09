import 'package:reactive_forms/reactive_forms.dart';
import 'package:se_controle_ai/core/shared/mixin/message_mixin.dart';
import 'package:signals/signals.dart';
import '../../../core/month/selected_month_service.dart';
import '../../../core/shared/view_state.dart';
import '../../../core/utils/base_controller.dart';
import '../../../data/models/credit_card_model.dart';
import '../../../data/repositories/credit_card_repository.dart';

class CreditCardController extends BaseController with MessageMixin {
  final CreditCardRepository _repository;
  final SelectedMonthService _selectedMonth;
  CreditCardController(this._repository, this._selectedMonth);

  EffectCleanup? _watchingMonth;

  final _state = signal<ViewState<List<CreditCardModel>>>(const Loading());

  ReadonlySignal<ViewState<List<CreditCardModel>>> get state => _state;

  final form = FormGroup({
    'name': FormControl<String>(validators: [Validators.required]),
    'lastDigits': FormControl<String>(
      validators: [Validators.pattern(r'^\d{4}$')],
    ),
    'closingDay': FormControl<int>(value: 1, validators: [Validators.required]),
    'dueDay': FormControl<int>(value: 10, validators: [Validators.required]),
    'limitCents': FormControl<int>(),
  });

  @override
  void onInit() {
    super.onInit();

    _watchingMonth = effect(() {
      _selectedMonth.month.value;
      untracked(_load);
    });
  }

  @override
  void dispose() {
    _watchingMonth?.call();
    _state.dispose();
    form.dispose();
    super.dispose();
  }

  void resetForm() {
    form.reset();
    form.patchValue({'closingDay': 1, 'dueDay': 10});
  }

  void loadCardCredit(final CreditCardModel creditCard) {
    form.control('name').value = creditCard.name;
    form.control('lastDigits').value = creditCard.lastDigits;
    form.control('closingDay').value = creditCard.closingDay;
    form.control('dueDay').value = creditCard.dueDay;
    form.control('limitCents').value = creditCard.limitCents;
  }

  Future<void> _load() async {
    _state.value = const Loading();
    final result = await _repository.list(month: _selectedMonth.month.value);
    result.when(
      (success) => _state.value = Loaded(success),
      (err) => _state.value = Failed(err),
    );
  }

  Future<void> refresh() async => await _load();

  Future<void> delete(String id) async {
    final current = _state.value;
    if (current is! Loaded<List<CreditCardModel>>) return;
    final result = await _repository.delete(id);

    return result.when(
      (_) async {
        _state.value = Loaded(current.data.where((e) => e.id != id).toList());

        Future.delayed(
          Duration(milliseconds: 300),
          () => toastSucess('Cartão deletado com sucesso'),
        );
      },
      (error) async => Future.delayed(
        Duration(milliseconds: 300),
        () => toastError(error.message),
      ),
    );
  }

  Future<void> create() async {
    final result = await _repository.create(
      name: form.control('name').value.trim(),
      closingDay: form.control('closingDay').value!,
      dueDay: form.control('dueDay').value!,
      lastDigits: form.control('lastDigits').value,
      limitCents: form.control('limitCents').value,
    );

    return result.when(
      (card) {
        final current = _state.value;
        if (current is! Loaded<List<CreditCardModel>>) return;
        _state.value = Loaded([card, ...current.data]);

        Future.delayed(
          Duration(milliseconds: 300),
          () => toastSucess('Cartão ${card.name} criado com sucesso!'),
        );
      },

      (err) {
        Future.delayed(
          Duration(milliseconds: 300),
          () => toastError(err.message),
        );
      },
    );
  }

  Future<void> update(String id) async {
    final current = _state.value;
    if (current is! Loaded<List<CreditCardModel>>) return;

    final result = await _repository.update(
      id,
      name: form.control('name').value.trim() as String,
      closingDay: form.control('closingDay').value!,
      dueDay: form.control('dueDay').value!,
      lastDigits: form.control('lastDigits').value,
      limitCents: form.control('limitCents').value,
      month: _selectedMonth.month.value,
    );

    return result.when(
      (card) {
        final index = current.data.indexWhere((item) => item.id == card.id);
        if (index == -1) return;

        final newList = [...current.data];
        newList[index] = card;
        _state.value = Loaded(newList);

        Future.delayed(
          Duration(milliseconds: 300),
          () => toastSucess('Cartão ${card.name} atualizado com sucesso!'),
        );
      },

      (err) {
        Future.delayed(
          Duration(milliseconds: 300),
          () => toastError(err.message),
        );
      },
    );
  }
}
