import 'package:reactive_forms/reactive_forms.dart';
import 'package:se_controle_ai/core/shared/mixin/message_mixin.dart';
import 'package:se_controle_ai/data/services/navigation_service.dart';
import 'package:signals/signals.dart';

import '../../../core/shared/view_state.dart';
import '../../../core/utils/base_controller.dart';
import '../../../data/models/income_model.dart';
import '../../../data/repositories/income_repository.dart';
import '../../../data/services/selected_month_service.dart';

class IncomeController({
  required final IncomeRepository _repository,
  required final SelectedMonthService _selectedMonth,
  required final NavigationService _navigationService,
}) extends BaseController with MessageMixin {
  late final form = FormGroup({
    'description': FormControl<String>(validators: [Validators.required]),
    'amountCents': FormControl<int>(
      validators: [Validators.required, Validators.min(1)],
    ),

    'startMonth': FormControl<String>(
      value: _selectedMonth.month.value,
      validators: [Validators.required],
    ),
  });

  final _state = signal<ViewState<List<IncomeModel>>>(const Loading());
  ReadonlySignal<ViewState<List<IncomeModel>>> get state => _state;

  final _isRecurring = signal<bool>(false);
  ReadonlySignal<bool> get isRecurring => _isRecurring;
  set setIsRecurring(bool value) => _isRecurring.value = value;

  final _saving = signal<bool>(false);
  ReadonlySignal<bool> get saving => _saving;

  EffectCleanup? _watchingMonth;

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
    super.dispose();
    _watchingMonth?.call();
    _state.dispose();
    _isRecurring.dispose();
    _saving.dispose();
    form.dispose();
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

  void startForm() {
    form.reset(
      value: {
        'description': null,
        'amountCents': null,
        'startMonth': _selectedMonth.month.value,
      },
    );
    _isRecurring.value = false;
  }

  Future<void> submit() async {
    _saving.value = true;

    final result = await _repository.create(
      description: form.control('description').value!.trim(),
      amountCents: form.control('amountCents').value!,
      startMonth: form.control('startMonth').value!,
      recurring: _isRecurring.value,
    );

    result.when(
      (income) {
        final current = _state.value;
        if (current is! Loaded<List<IncomeModel>>) return;
        _state.value = Loaded(
          [income, ...current.data]
            ..sort((a, b) => a.description.compareTo(b.description)),
        );

        _navigationService.pop();
      },
      (failure) => Future.delayed(
        const Duration(milliseconds: 300),
        () => toastError(failure.message),
      ),
    );

    _saving.value = false;
  }

  Future<void> adjustValueIncome(
    String id, {
    required int amountCents,
    required String effectiveFromMonth,
  }) async {
    final current = _state.value;
    if (current is! Loaded<List<IncomeModel>>) return;

    _saving.value = true;

    final result = await _repository.adjust(
      id,
      amountCents: amountCents,
      effectiveFromMonth: effectiveFromMonth,
      month: _selectedMonth.month.value,
    );

    _saving.value = false;

    result.when((income) {
      _state.value = Loaded(
        current.data
            .map((item) => item.id == income.id ? income : item)
            .toList(),
      );

      _navigationService
        ..pop()
        ..pop();
    }, (err) => toastError(err.message));
  }

  Future<void> correctingValueIncome(
    String id, {
    required int amountCents,
  }) async {
    final current = _state.value;
    if (current is! Loaded<List<IncomeModel>>) return;

    _saving.value = true;

    final result = await _repository.correct(
      id,
      amountCents: amountCents,
      month: _selectedMonth.month.value,
    );

    _saving.value = false;

    result.when((income) {
      _state.value = Loaded(
        current.data
            .map((item) => item.id == income.id ? income : item)
            .toList(),
      );

      _navigationService
        ..pop()
        ..pop();
    }, (err) => toastError(err.message));
  }

  Future<void> terminateRecurringIncome(
    String id, {
    required String lastMonth,
  }) async {
    final current = _state.value;
    if (current is! Loaded<List<IncomeModel>>) return;

    _saving.value = true;

    final result = await _repository.close(
      id,
      lastMonth: lastMonth,
      month: _selectedMonth.month.value,
    );

    _saving.value = false;

    result.when((income) {
      _state.value = Loaded(
        current.data
            .map((item) => item.id == income.id ? income : item)
            .toList(),
      );

      _navigationService
        ..pop()
        ..pop();
    }, (err) => toastError(err.message));
  }

  Future<void> delete(String id) async {
    _saving.value = true;

    final result = await _repository.delete(id);

    _saving.value = false;

    result.when((_) {
      final current = _state.value;
      if (current is Loaded<List<IncomeModel>>) {
        _state.value = Loaded(
          current.data.where((income) => income.id != id).toList(),
        );
      }

      _navigationService
        ..pop()
        ..pop();
    }, (failure) => toastError(failure.message));
  }
}
