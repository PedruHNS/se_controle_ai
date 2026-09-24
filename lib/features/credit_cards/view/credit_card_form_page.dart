import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:se_controle_ai/core/shared/widgets/text_field_custom_widget.dart';
import 'package:se_controle_ai/data/models/credit_card_model.dart';
import 'package:se_controle_ai/features/credit_cards/controller/credit_card_controller.dart';
import 'package:signals/signals_flutter.dart';
import '../../../core/utils/credit_card_months_utils.dart';
import '../../../core/di/injector.dart';
import '../../../core/shared/widgets/day_field_widget.dart';
import '../../../core/shared/widgets/money_field_widget.dart';

class CreditCardFormPage extends StatefulWidget {
  final CreditCardModel? card;
  const CreditCardFormPage({this.card, super.key});

  @override
  State<CreditCardFormPage> createState() => _CreditCardFormPageState();
}

class _CreditCardFormPageState extends State<CreditCardFormPage> {
  final _controller = getIt<CreditCardController>();

  bool get _editing => widget.card != null;

  @override
  void initState() {
    super.initState();
    if (_editing) {
      _controller.loadCardCredit(widget.card!);
      return;
    }
    _controller.resetForm();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Editar cartão' : 'Novo cartão'),
        centerTitle: true,
      ),
      body: SignalBuilder(
        builder: (context) {
          return _CreditCardForm(controller: _controller, id: widget.card?.id);
        },
      ),
    );
  }
}

class _CreditCardForm extends StatelessWidget {
  final CreditCardController controller;
  final String? id;
  const _CreditCardForm({required this.controller, this.id});

  String _dueHelper(int closingDay, int dueDay) {
    return CreditCardMonthsUtils.closesInPreviousMonth(
          closingDay: closingDay,
          dueDay: dueDay,
        )
        ? 'Fecha dia $closingDay e vence dia $dueDay: a fatura de um mês cobra '
              'as compras do mês anterior, até o dia $closingDay.'
        : 'Fecha dia $closingDay e vence dia $dueDay: a fatura de um mês cobra '
              'as compras desse mesmo mês.';
  }

  @override
  Widget build(BuildContext context) {
    return ReactiveForm(
      formGroup: controller.form,
      child: ListView(
        padding: const .all(16),
        children: [
          TextFieldCustomWidget(
            formControlName: 'name',
            autofocus: true,
            validationMessages: {
              ValidationMessage.required: (_) => 'Informe o nome do cartão.',
            },
            labelText: 'Nome',
            hintText: 'Nubank, Itaú, Inter',
          ),
          const SizedBox(height: 16),
          TextFieldCustomWidget(
            formControlName: 'lastDigits',
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(4),
            ],
            validationMessages: {
              ValidationMessage.pattern: (_) =>
                  'Informe os quatro últimos dígitos, ou deixe em branco.',
            },
            labelText: 'Últimos dígitos (opcional)',
            hintText: '1234',
            // helperText: 'Aparece no nome do cartão nas telas de gasto.',
          ),
          const SizedBox(height: 16),
          SignalBuilder(
            builder: (context) => DayFieldWidget(
              day: controller.getClosingDay.value,
              onChanged: (day) => controller.setClosingDay = day,
              label: 'Fechamento',
            ),
          ),
          const SizedBox(height: 16),
          SignalBuilder(
            builder: (context) => DayFieldWidget(
              day: controller.getDueDay.value,
              onChanged: (day) => controller.setDueDay = day,
              label: 'Vencimento',
              helperText: _dueHelper(
                controller.getClosingDay.value,
                controller.getDueDay.value,
              ),
            ),
          ),
          const SizedBox(height: 16),

          MoneyFieldWidget(
            formControlName: 'limitCents',
            label: 'Limite (opcional)',
          ),
          const SizedBox(height: 24),
          ReactiveFormConsumer(
            builder: (context, form, child) => FilledButton(
              onPressed: form.valid
                  ? () => controller.onSubmit(cardId: id)
                  : null,
              child: const Text('Salvar'),
            ),
          ),
        ],
      ),
    );
  }
}
