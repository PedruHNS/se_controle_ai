import 'dart:async';

import 'package:multiple_result/multiple_result.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:se_controle_ai/core/shared/mixin/message_mixin.dart';
import 'package:se_controle_ai/data/services/navigation_service.dart';
import 'package:signals/signals.dart';

import '../../../core/errors/failure.dart';
import '../../../core/shared/view_state.dart';
import '../../../core/utils/base_controller.dart';
import '../../../core/utils/credit_card_months_utils.dart';
import '../../../core/utils/month_utils.dart';
import '../../../data/enums/expense_type.dart';
import '../../../data/enums/payment_method.dart';
import '../../../data/models/credit_card_model.dart';
import '../../../data/models/expense_model.dart';
import '../../../data/models/tag_model.dart';
import '../../../data/repositories/credit_card_repository.dart';
import '../../../data/repositories/expense_repository.dart';
import '../../../data/repositories/tag_repository.dart';
import '../../../data/services/selected_month_service.dart';

class ExpenseController extends BaseController with MessageMixin {
  final ExpenseRepository _repository;
  final CreditCardRepository _cardRepository;
  final TagRepository _tagRepository;
  final SelectedMonthService _selectedMonth;
  final NavigationService _nav;
  ExpenseController({
    required this._repository,
    required this._cardRepository,
    required this._tagRepository,
    required this._selectedMonth,
    required this._nav,
  });

  static String today() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  late final form = FormGroup({
    'description': FormControl<String>(validators: [Validators.required]),
    'tagId': FormControl<String>(validators: [Validators.required]),
    'notes': FormControl<String>(),
    'creditCardId': FormControl<String>(validators: [Validators.required]),
    'amountCents': FormControl<int>(
      validators: [Validators.required, Validators.min(1)],
    ),
    'startMonth': FormControl<String>(
      value: _selectedMonth.month.value,
      validators: [Validators.required],
    ),
    'totalCents': FormControl<int>(
      validators: [Validators.required, Validators.min(1)],
    ),
    'installmentsCount': FormControl<int>(
      value: 2,
      validators: [Validators.required, Validators.min(2), Validators.max(120)],
    ),
    'firstMonth': FormControl<String>(
      value: _selectedMonth.month.value,
      validators: [Validators.required],
    ),
    'spentAt': FormControl<String>(
      value: today(),
      validators: [Validators.required],
    ),
  });

  final _state = signal<ViewState<List<ExpenseModel>>>(const Loading());
  ReadonlySignal<ViewState<List<ExpenseModel>>> get state => _state;

  final _formState = signal<ViewState<void>>(const Loading());
  ReadonlySignal<ViewState<void>> get formState => _formState;

  final _tags = signal<List<TagModel>>(const []);
  ReadonlySignal<List<TagModel>> get tags => _tags;

  final _cardLabel = signal<String?>(null);
  ReadonlySignal<String?> get cardLabel => _cardLabel;

  final _saving = signal<bool>(false);
  ReadonlySignal<bool> get saving => _saving;

  final _type = signal<ExpenseType>(ExpenseType.fixed);
  ReadonlySignal<ExpenseType> get getType => _type;
  set setType(ExpenseType type) {
    _type.value = type;
    _syncTypeFields();
    _applyDerivedMonth();
  }

  final _paymentMethod = signal<PaymentMethod>(PaymentMethod.debit);
  ReadonlySignal<PaymentMethod> get getPaymentMethod => _paymentMethod;
  set setPaymentMethod(PaymentMethod method) {
    _paymentMethod.value = method;
    _syncCardField();
    _applyDerivedMonth();
  }

  final _isRecurring = signal<bool>(false);
  ReadonlySignal<bool> get isRecurring => _isRecurring;
  set setIsRecurring(bool value) {
    _isRecurring.value = value;
    _applyDerivedMonth();
  }

  PaymentMethod? _methodFilter;

  List<CreditCardModel> _cards = const [];
  List<CreditCardModel> get cards => _cards;

  EffectCleanup? _watchingMonth;

  final _invoiceWatchers = <StreamSubscription<dynamic>>[];

  @override
  void onInit() {
    super.onInit();
    for (final field in ['spentAt', 'creditCardId']) {
      _invoiceWatchers.add(
        form.control(field).valueChanges.listen((_) => _applyDerivedMonth()),
      );
    }
  }

  @override
  void dispose() {
    _watchingMonth?.call();
    super.dispose();
    for (final watcher in _invoiceWatchers) {
      watcher.cancel();
    }
    _state.dispose();
    _formState.dispose();
    _tags.dispose();
    _cardLabel.dispose();
    _saving.dispose();
    _type.dispose();
    _paymentMethod.dispose();
    _isRecurring.dispose();
    form.dispose();
  }

  void start(PaymentMethod? paymentMethod) {
    _methodFilter = paymentMethod;
    _watchingMonth = effect(() {
      _selectedMonth.month.value;
      untracked(_load);
    });
  }

  Future<void> _load() async {
    _state.value = const Loading();
    final result = await _repository.list(
      activeFrom: _selectedMonth.month.value,
      paymentMethod: _methodFilter,
    );

    result.when(
      (success) => _state.value = Loaded(success),
      (err) => _state.value = Failed(err),
    );
  }

  Future<void> refresh() => _load();

  Future<void> loadCardLabel(String? cardId) async {
    _cardLabel.value = null;
    if (cardId == null) return;

    final result = await _cardRepository.getById(cardId);
    result.when(
      (card) => _cardLabel.value = card.label,
      (_) => _cardLabel.value = null,
    );
  }

  Future<void> resetForm() {
    _type.value = ExpenseType.fixed;
    _paymentMethod.value = PaymentMethod.debit;
    _isRecurring.value = false;

    form.reset(
      value: {
        'startMonth': _selectedMonth.month.value,
        'installmentsCount': 2,
        'firstMonth': _selectedMonth.month.value,
        'spentAt': today(),
      },
    );
    _syncTypeFields();
    _syncCardField();
    _applyDerivedMonth();

    return _loadOptions();
  }

  Future<void> loadExpense(ExpenseModel expense) {
    _type.value = expense.type;
    _paymentMethod.value = expense.paymentMethod;
    _isRecurring.value = false;

    form.reset(
      value: {
        'description': expense.description,
        'tagId': expense.tag.id,
        'notes': expense.notes,
        'creditCardId': expense.creditCardId,
      },
    );
    _toggle([
      'amountCents',
      'startMonth',
      'totalCents',
      'installmentsCount',
      'firstMonth',
      'spentAt',
    ], enabled: false);
    _syncCardField();

    return _loadOptions(keep: expense.tag);
  }

  Future<void> _loadOptions({TagModel? keep}) async {
    _formState.value = const Loading();

    final (cardList, tagList) = await (
      _cardRepository.list(),
      _tagRepository.list(),
    ).wait;

    final cardsLoaded = cardList.when(
      (success) {
        _cards = success;
        return true;
      },
      (err) {
        _formState.value = Failed(err);
        return false;
      },
    );
    if (!cardsLoaded) return;

    final tagsLoaded = tagList.when(
      (success) {
        _tags.value = success;
        return true;
      },
      (err) {
        _formState.value = Failed(err);
        return false;
      },
    );
    if (!tagsLoaded) return;

    if (keep != null && !_tags.value.any((tag) => tag.id == keep.id)) {
      _tags.value = [..._tags.value, keep]
        ..sort((a, b) => a.name.compareTo(b.name));
    }

    _formState.value = const Loaded(null);
  }

  void selectCreatedTag(TagModel tag) {
    _tags.value = [..._tags.value.where((item) => item.id != tag.id), tag]
      ..sort((a, b) => a.name.compareTo(b.name));
    form.control('tagId').updateValue(tag.id);
  }

  void _syncTypeFields() {
    final fixed = _type.value == ExpenseType.fixed;
    _toggle(['amountCents', 'startMonth'], enabled: fixed);
    _toggle(['totalCents', 'installmentsCount', 'firstMonth'], enabled: !fixed);
  }

  void _syncCardField() {
    final card = form.control('creditCardId');

    if (_paymentMethod.value == PaymentMethod.debit) {
      card.reset(disabled: true);
      return;
    }

    card.markAsEnabled();
  }

  void _toggle(List<String> fields, {required bool enabled}) {
    for (final field in fields) {
      final control = form.control(field);
      enabled ? control.markAsEnabled() : control.markAsDisabled();
    }
  }

  CreditCardModel? get selectedCard {
    if (_paymentMethod.value != PaymentMethod.creditCard) return null;

    final id = form.control('creditCardId').value;
    if (id == null) return null;

    for (final card in _cards) {
      if (card.id == id) return card;
    }
    return null;
  }

  String get monthField =>
      _type.value == ExpenseType.fixed ? 'startMonth' : 'firstMonth';

  String? get derivedMonth {
    final String? chosen = form.control('spentAt').value;
    if (chosen == null || chosen.length != 10) return null;

    final card = selectedCard;
    if (card == null) return chosen.substring(0, 7);

    final recurring = _type.value == ExpenseType.fixed && _isRecurring.value;

    return recurring
        ? CreditCardMonthsUtils.invoiceMonthFor(
            chosen,
            closingDay: card.closingDay,
            dueDay: card.dueDay,
          )
        : CreditCardMonthsUtils.chargeMonthFor(
            chosen,
            closingDay: card.closingDay,
            dueDay: card.dueDay,
          );
  }

  void _applyDerivedMonth() {
    final month = derivedMonth;
    if (month == null) return;

    final field = form.control(monthField);
    if (field.value != month) field.updateValue(month);
  }

  Future<void> onSubmit({required ExpenseModel? expense}) async {
    _saving.value = true;

    if (expense != null) {
      await update(expense);
    } else {
      await create();
    }

    _saving.value = false;
  }

  Future<void> create() async {
    final String? competence = form.control(monthField).value;
    final result = _type.value == ExpenseType.installment
        ? await _createInstallment()
        : await _createFixed();

    result.when((expense) {
      if (competence != null && competence != _selectedMonth.month.value) {
        _nav.pop();
        _selectedMonth.select(competence);
        Future.delayed(
          const Duration(milliseconds: 300),
          () => toastSucess('Lançado em ${MonthUtils.label(competence)}'),
        );
        return;
      }

      _putInList(expense);
      _nav.pop();
    }, (err) => toastError(err.message));
  }

  Future<void> update(ExpenseModel expense) async {
    final String tagId = form.control('tagId').value;

    final result = await _repository.updateDetails(
      expense.id,
      description: form.control('description').value.trim(),
      paymentMethod: _paymentMethod.value,
      tagId: tagId == expense.tag.id ? null : tagId,
      notes: _notes,
      creditCardId: _cardId,
    );

    result.when((updated) {
      _putInList(updated);
      _nav
        ..pop()
        ..pop();
    }, (err) => toastError(err.message));
  }

  Future<Result<ExpenseModel, Failure>> _createFixed() =>
      _repository.createFixed(
        description: form.control('description').value.trim(),
        tagId: form.control('tagId').value,
        notes: _notes,
        paymentMethod: _paymentMethod.value,
        creditCardId: _cardId,
        amountCents: form.control('amountCents').value,
        startMonth: form.control('startMonth').value,
        recurring: _isRecurring.value,
        spentAt: form.control('spentAt').value,
      );

  Future<Result<ExpenseModel, Failure>> _createInstallment() =>
      _repository.createInstallment(
        description: form.control('description').value.trim(),
        tagId: form.control('tagId').value,
        notes: _notes,
        paymentMethod: _paymentMethod.value,
        creditCardId: _cardId,
        totalCents: form.control('totalCents').value,
        installmentsCount: form.control('installmentsCount').value,
        firstMonth: form.control('firstMonth').value,
        spentAt: form.control('spentAt').value,
      );

  String? get _notes {
    final String value = form.control('notes').value?.trim() ?? '';
    return value.isEmpty ? null : value;
  }

  String? get _cardId => _paymentMethod.value == PaymentMethod.debit
      ? null
      : form.control('creditCardId').value;

  void _putInList(ExpenseModel expense) {
    final current = _state.value;
    if (current is! Loaded<List<ExpenseModel>>) return;

    final belongs =
        _methodFilter == null || expense.paymentMethod == _methodFilter;

    _state.value = Loaded(
      [
        ...current.data.where((item) => item.id != expense.id),
        if (belongs) expense,
      ]..sort((a, b) => a.description.compareTo(b.description)),
    );
  }

  Future<void> adjust(
    String id, {
    required int amountCents,
    required String effectiveFrom,
  }) async {
    _saving.value = true;

    final result = await _repository.adjust(
      id,
      amountCents: amountCents,
      effectiveFrom: effectiveFrom,
    );

    _saving.value = false;

    result.when((expense) {
      _putInList(expense);
      _nav
        ..pop()
        ..pop();
    }, (err) => toastError(err.message));
  }

  Future<void> correct(String id, {required int amountCents}) async {
    _saving.value = true;

    final result = await _repository.correct(id, amountCents: amountCents);

    _saving.value = false;

    result.when((expense) {
      _putInList(expense);
      _nav
        ..pop()
        ..pop();
    }, (err) => toastError(err.message));
  }

  Future<void> close(String id, {required String lastMonth}) async {
    _saving.value = true;

    final result = await _repository.close(id, lastMonth: lastMonth);

    _saving.value = false;

    result.when((expense) {
      _putInList(expense);
      _nav
        ..pop()
        ..pop();
    }, (err) => toastError(err.message));
  }

  Future<void> reschedule(
    String id, {
    required int newTotalCents,
    required int newInstallmentsCount,
    required String fromMonth,
  }) async {
    _saving.value = true;

    final result = await _repository.reschedule(
      id,
      newTotalCents: newTotalCents,
      newInstallmentsCount: newInstallmentsCount,
      fromMonth: fromMonth,
    );

    _saving.value = false;

    result.when((expense) {
      _putInList(expense);
      _nav
        ..pop()
        ..pop();
    }, (err) => toastError(err.message));
  }

  Future<void> settle(String id, {required String fromMonth}) async {
    _saving.value = true;

    final result = await _repository.settle(id, fromMonth: fromMonth);

    _saving.value = false;

    result.when((expense) {
      _putInList(expense);
      _nav
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
      if (current is Loaded<List<ExpenseModel>>) {
        _state.value = Loaded(
          current.data.where((expense) => expense.id != id).toList(),
        );
      }

      _nav
        ..pop()
        ..pop();
    }, (failure) => toastError(failure.message));
  }
}
