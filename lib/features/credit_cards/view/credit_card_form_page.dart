import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:se_controle_ai/data/models/credit_card_model.dart';
import 'package:se_controle_ai/data/services/navigation_service.dart';
import 'package:se_controle_ai/features/credit_cards/controller/credit_card_controller.dart';
import 'package:signals/signals_flutter.dart';

import '../../../core/di/injector.dart';
import '../../../core/shared/widgets/day_field_widget.dart';
import '../../../core/shared/widgets/money_field_widget.dart';

class CreditCardFormPage extends StatefulWidget {
  const CreditCardFormPage({this.card, super.key});

  final CreditCardModel? card;

  @override
  State<CreditCardFormPage> createState() => _CreditCardFormPageState();
}

class _CreditCardFormPageState extends State<CreditCardFormPage> {
  final _controller = getIt<CreditCardController>();
  final _nav = getIt<NavigationService>();

  bool get _editing => widget.card != null;

  @override
  void initState() {
    super.initState();
    if (_editing) {
      _controller.loadCardCredit(widget.card!);
    } else {
      _controller.resetForm();
    }
  }

  Future<void> _submit() async {
    if (_editing) {
      await _controller.update(widget.card!.id);
    } else {
      await _controller.create();
    }
    _nav.pop();
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
          return _CreditCardForm(controller: _controller, onSubmit: _submit);
        },
      ),
    );
  }
}

class _CreditCardForm extends StatelessWidget {
  const _CreditCardForm({required this.controller, required this.onSubmit});

  final CreditCardController controller;
  final void Function() onSubmit;

  @override
  Widget build(BuildContext context) {
    return ReactiveForm(
      formGroup: controller.form,
      child: ListView(
        padding: const .all(16),
        children: [
          ReactiveTextField(
            formControlName: 'name',
            autofocus: true,
            onTapUpOutside: (event) => FocusScope.of(context).unfocus(),
            textCapitalization: .sentences,
            textInputAction: .next,
            validationMessages: {
              ValidationMessage.required: (_) => 'Informe o nome do cartão.',
            },
            decoration: const InputDecoration(
              labelText: 'Nome',
              hintText: 'Nubank, Itaú, Inter',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          ReactiveTextField(
            formControlName: 'lastDigits',
            keyboardType: .number,
            onTapOutside: (event) => FocusScope.of(context).unfocus(),
            textInputAction: .next,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(4),
            ],
            validationMessages: {
              ValidationMessage.pattern: (_) =>
                  'Informe os quatro últimos dígitos, ou deixe em branco.',
            },
            decoration: const InputDecoration(
              labelText: 'Últimos dígitos (opcional)',
              hintText: '1234',
              helperText: 'Aparece no nome do cartão nas telas de gasto.',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          DayFieldWidget(formControlName: 'closingDay', label: 'Fechamento'),
          const SizedBox(height: 16),

          ReactiveValueListenableBuilder<int>(
            formControlName: 'closingDay',
            builder: (context, closing, child) =>
                ReactiveValueListenableBuilder<int>(
                  formControlName: 'dueDay',
                  builder: (context, due, child) => DayFieldWidget(
                    formControlName: 'dueDay',
                    label: 'Vencimento',
                    helperText: _dueHelper(closing.value, due.value),
                  ),
                ),
          ),
          const SizedBox(height: 16),
          MoneyFieldWidget(
            formControlName: 'limitCents',
            label: 'Limite (opcional)',
            onSubmitted: (_) => onSubmit(),
          ),
          const SizedBox(height: 24),
          ReactiveFormConsumer(
            builder: (context, form, child) => FilledButton(
              onPressed: form.valid ? onSubmit : null,
              child: const Text('Salvar'),
            ),
          ),
        ],
      ),
    );
  }

  String _dueHelper(int? closingDay, int? dueDay) {
    if (closingDay == null || dueDay == null) return '';

    // A fatura leva o nome do mês em que é paga (CAR-03). Quando vence antes de
    // fechar, ela cobra o que foi comprado no mês anterior — e é esse
    // deslocamento que a pessoa precisa entender antes de lançar um gasto.
    return dueDay > closingDay
        ? 'Fecha dia $closingDay e vence dia $dueDay: a fatura de um mês cobra '
              'as compras desse mesmo mês.'
        : 'Fecha dia $closingDay e vence dia $dueDay: a fatura de um mês cobra '
              'as compras do mês anterior, até o dia $closingDay.';
  }
}
