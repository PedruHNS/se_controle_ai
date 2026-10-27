import 'package:flutter/material.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:se_controle_ai/core/shared/widgets/custom_button_default_widget.dart';
import 'package:se_controle_ai/core/shared/widgets/text_field_custom_widget.dart';
import 'package:signals/signals_flutter.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../core/di/injector.dart';
import '../../../core/shared/view_state.dart';
import '../../../core/shared/widgets/date_field_widget.dart';
import '../../../core/shared/widgets/failure_card_widget.dart';
import '../../../core/shared/widgets/money_field_widget.dart';
import '../../../core/shared/widgets/month_field_widget.dart';
import '../../../core/utils/credit_card_months_utils.dart';
import '../../../core/utils/iso_date_utils.dart';
import '../../../core/utils/money_utils.dart';
import '../../../core/utils/month_utils.dart';
import '../../../core/utils/tag_color_utils.dart';
import '../../../data/enums/expense_type.dart';
import '../../../data/enums/payment_method.dart';
import '../../../data/models/expense_model.dart';
import '../../../data/models/tag_model.dart';
import '../../tags/controller/tag_list_controller.dart';
import '../../tags/widgets/create_tag_dialog_widget.dart';
import '../controller/expense_controller.dart';

class ExpenseFormPage extends StatefulWidget {
  final ExpenseModel? expense;
  const ExpenseFormPage({this.expense, super.key});

  @override
  State<ExpenseFormPage> createState() => _ExpenseFormPageState();
}

class _ExpenseFormPageState extends State<ExpenseFormPage> {
  final _controller = getIt<ExpenseController>();

  bool get _editing => widget.expense != null;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    getIt.resetLazySingleton<TagListController>();
    super.dispose();
  }

  Future<void> _createTag() async {
    final tag = await showDialog<TagModel>(
      context: context,
      builder: (context) => const CreateTagDialogWidget(),
    );
    if (tag != null) _controller.selectCreatedTag(tag);
  }

  Future<void> _start() {
    if (_editing) return _controller.loadExpense(widget.expense!);
    return _controller.resetForm();
  }

  Future<void> _submit() => _controller.onSubmit(expense: widget.expense);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Editar gasto' : 'Novo gasto'),
        centerTitle: true,
      ),
      body: SignalBuilder(
        builder: (context) {
          final state = _controller.formState.value;
          return switch (state) {
            Loading() => Skeletonizer(
              child: _ExpenseForm(
                controller: _controller,
                editing: _editing,
                onSubmit: _submit,
                onCreateTag: _createTag,
              ),
            ),
            Failed(:final failure) => Center(
              child: Padding(
                padding: const .all(16),
                child: FailureCardWidget(failure: failure, onRetry: _start),
              ),
            ),
            Loaded() => _ExpenseForm(
              controller: _controller,
              editing: _editing,
              onSubmit: _submit,
              onCreateTag: _createTag,
            ),
          };
        },
      ),
    );
  }
}

class const _ExpenseForm({
  required final ExpenseController controller,
  required final bool editing,
  required final VoidCallback onSubmit,
  required final VoidCallback onCreateTag,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ReactiveForm(
      formGroup: controller.form,
      child: ListView(
        padding: const .all(16),
        children: [
          TextFieldCustomWidget(
            formControlName: 'description',
            labelText: 'Descrição',
            hintText: 'Aluguel, streaming, ração',
            autofocus: true,
            validationMessages: {
              ValidationMessage.required: (_) => 'Informe a descrição.',
            },
          ),
          const SizedBox(height: 16),
          SignalBuilder(
            builder: (context) {
              final tags = controller.tags.value;

              return Row(
                crossAxisAlignment: .start,
                children: [
                  Expanded(
                    child: ReactiveDropdownField<String>(
                      formControlName: 'tagId',
                      isExpanded: true,
                      validationMessages: {
                        ValidationMessage.required: (_) =>
                            'Escolha a categoria.',
                      },
                      decoration: const InputDecoration(
                        labelText: 'Categoria',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (final tag in tags)
                          DropdownMenuItem(
                            value: tag.id,
                            child: _TagChipLabel(tag: tag),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const .only(top: 4),
                    child: IconButton.filledTonal(
                      onPressed: onCreateTag,
                      icon: const Icon(Icons.add),
                      tooltip: 'Nova categoria',
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          ReactiveTextField<String>(
            formControlName: 'notes',
            textCapitalization: .sentences,
            textInputAction: .newline,
            onTapOutside: (event) => FocusScope.of(context).unfocus(),
            keyboardType: .multiline,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Observação (opcional)',
              hintText: 'Detalhe que o rótulo não carrega',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 16),
          Text('Forma de pagamento', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          SignalBuilder(
            builder: (context) => SegmentedButton<PaymentMethod>(
              segments: const [
                ButtonSegment(
                  value: PaymentMethod.debit,
                  icon: Icon(Icons.payments_outlined),
                  label: Text('Débito'),
                ),
                ButtonSegment(
                  value: PaymentMethod.creditCard,
                  icon: Icon(Icons.credit_card),
                  label: Text('Cartão'),
                ),
              ],
              selected: {controller.getPaymentMethod.value},
              onSelectionChanged: (selection) =>
                  controller.setPaymentMethod = selection.first,
            ),
          ),
          SignalBuilder(
            builder: (context) {
              if (controller.getPaymentMethod.value !=
                  PaymentMethod.creditCard) {
                return const SizedBox.shrink();
              }

              if (controller.cards.isEmpty) {
                return Padding(
                  padding: const .only(top: 16),
                  child: Text(
                    'Nenhum cartão cadastrado. Cadastre um em Cartões antes de '
                    'lançar um gasto no cartão.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                );
              }

              return Padding(
                padding: const .only(top: 16),
                child: ReactiveDropdownField<String>(
                  formControlName: 'creditCardId',
                  validationMessages: {
                    ValidationMessage.required: (_) => 'Escolha o cartão.',
                  },
                  decoration: const InputDecoration(
                    labelText: 'Cartão',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final card in controller.cards)
                      DropdownMenuItem(value: card.id, child: Text(card.label)),
                  ],
                ),
              );
            },
          ),
          Visibility(
            visible: !editing,
            child: Column(
              crossAxisAlignment: .stretch,
              children: [
                const SizedBox(height: 16),
                Text('Tipo', style: theme.textTheme.labelLarge),
                const SizedBox(height: 8),
                SignalBuilder(
                  builder: (context) => SegmentedButton<ExpenseType>(
                    segments: const [
                      ButtonSegment(
                        value: ExpenseType.fixed,
                        icon: Icon(Icons.payments_outlined),
                        label: Text('À vista'),
                      ),
                      ButtonSegment(
                        value: ExpenseType.installment,
                        icon: Icon(Icons.view_week_outlined),
                        label: Text('Parcelado'),
                      ),
                    ],
                    selected: {controller.getType.value},
                    onSelectionChanged: (selection) =>
                        controller.setType = selection.first,
                  ),
                ),
                SignalBuilder(
                  builder: (context) =>
                      controller.getType.value == ExpenseType.installment
                      ? _InstallmentFields(controller: controller)
                      : _FixedFields(controller: controller),
                ),
              ],
            ),
          ),
          Visibility(
            visible: editing,
            child: Padding(
              padding: const .only(top: 16),
              child: Text(
                'Descrição, categoria e forma de pagamento valem para todos os '
                'meses, inclusive os que já passaram. Para mudar o valor, use '
                'as ações da tela do gasto.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          SignalBuilder(
            builder: (context) {
              final saving = controller.saving.value;

              return ReactiveFormConsumer(
                builder: (context, form, child) => CustomButtonDefaultWidget(
                  isLoading: saving,
                  enable: form.valid,
                  onPressed: onSubmit,
                  title: 'Salvar',
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _FixedFields extends StatelessWidget {
  final ExpenseController controller;

  const _FixedFields({required this.controller});

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(
      builder: (context) {
        final recurring = controller.isRecurring.value;

        return Column(
          crossAxisAlignment: .stretch,
          children: [
            const SizedBox(height: 16),
            MoneyFieldWidget(
              formControlName: 'amountCents',
              label: 'Valor por mês',
            ),
            const SizedBox(height: 16),
            _SpentAtField(controller: controller, recurring: recurring),
            const SizedBox(height: 8),
            SwitchListTile(
              value: recurring,
              onChanged: (value) => controller.setIsRecurring = value,
              contentPadding: .zero,
              title: const Text('Recorrente'),
              subtitle: Text(
                recurring ? 'Cobra todo mês até você encerrar.' : 'Sai só nesta competência — presente, conserto, consulta.',
              ),
            ),
          ],
        );
      },
    );
  }
}

class _InstallmentFields extends StatelessWidget {
  final ExpenseController controller;

  const _InstallmentFields({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: .stretch,
      children: [
        const SizedBox(height: 16),
        MoneyFieldWidget(
          formControlName: 'totalCents',
          label: 'Total da compra',
        ),
        const SizedBox(height: 16),
        TextFieldCustomWidget<int>(
          formControlName: 'installmentsCount',
          labelText: 'Em quantas vezes',
          keyboardType: TextInputType.number,
          validationMessages: {
            ValidationMessage.required: (_) => 'Informe em quantas vezes.',
            ValidationMessage.number: (_) => 'Só números.',
            ValidationMessage.min: (_) =>
                'Mínimo de 2 parcelas. '
                'Para 1x, cadastre como fixo não recorrente.',
            ValidationMessage.max: (_) => 'Máximo de 120 parcelas.',
          },
        ),
        const SizedBox(height: 16),
        _SpentAtField(controller: controller, recurring: false),
        const SizedBox(height: 8),
        const _InstallmentPreview(),
      ],
    );
  }
}

class _SpentAtField extends StatefulWidget {
  final ExpenseController controller;
  final bool recurring;

  const _SpentAtField({required this.controller, required this.recurring});

  @override
  State<_SpentAtField> createState() => _SpentAtFieldState();
}

class _SpentAtFieldState extends State<_SpentAtField> {
  bool _adjusting = false;

  String? get _helper {
    final controller = widget.controller;
    final month = controller.derivedMonth;
    if (month == null) return null;

    final card = controller.selectedCard;
    if (card == null) {
      return 'Entra na competência de ${MonthUtils.label(month).toLowerCase()}';
    }

    final vence = IsoDateUtils.label(_dueDate(card.dueDay, month));
    final purchase = CreditCardMonthsUtils.invoiceMonthFor(
      controller.form.control('spentAt').value,
      closingDay: card.closingDay,
      dueDay: card.dueDay,
    );

    if (purchase != month) {
      return 'A fatura de ${MonthUtils.label(purchase).toLowerCase()} já fechou '
          'dia ${card.closingDay} · entra na de '
          '${MonthUtils.label(month).toLowerCase()}, que vence $vence';
    }

    return 'Entra na fatura de ${MonthUtils.label(month).toLowerCase()} · '
        'vence $vence';
  }

  String _dueDate(int dueDay, String month) {
    final year = int.tryParse(month.substring(0, 4));
    final number = int.tryParse(month.substring(5, 7));
    if (year == null || number == null) return month;

    final lastDay = DateTime(year, number + 1, 0).day;
    final day = dueDay > lastDay ? lastDay : dueDay;

    return '$month-${day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) => ReactiveFormConsumer(
    builder: (context, form, child) => SignalBuilder(
      builder: (context) => Column(
        crossAxisAlignment: .stretch,
        children: [
          DateFieldWidget(
            formControlName: 'spentAt',
            label: widget.recurring ? 'Começou em' : 'Dia da compra',
            helperText: _helper,
            clearable: false,
          ),
          _adjusting
              ? Padding(
                  padding: const .only(top: 16),
                  child: MonthFieldWidget(
                    formControlName: widget.controller.monthField,
                    label: 'Competência',
                    helperText: 'Trocar o dia da compra refaz esta conta',
                  ),
                )
              : Align(
                  alignment: .centerRight,
                  child: TextButton(
                    onPressed: () => setState(() => _adjusting = true),
                    child: const Text('Ajustar competência'),
                  ),
                ),
        ],
      ),
    ),
  );
}

class const _InstallmentPreview() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ReactiveValueListenableBuilder<int>(
      formControlName: 'totalCents',
      builder: (context, totalControl, child) =>
          ReactiveValueListenableBuilder<int>(
            formControlName: 'installmentsCount',
            builder: (context, countControl, child) {
              final total = totalControl.value;
              final count = countControl.value;

              if (total == null ||
                  count == null ||
                  count < 1 ||
                  total < count) {
                return const SizedBox.shrink();
              }

              final each = total ~/ count;
              final remainder = total % count;

              return Text(
                remainder == 0
                    ? '${count}x de ${MoneyUtils.format(each)}'
                    : '${count}x de ${MoneyUtils.format(each)} — as $remainder '
                          'primeiras saem um centavo mais caras',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              );
            },
          ),
    );
  }
}

class const _TagChipLabel({required final TagModel tag})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: .min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: TagColorUtils.parse(tag.color),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Flexible(child: Text(tag.name, overflow: .ellipsis)),
      ],
    );
  }
}
