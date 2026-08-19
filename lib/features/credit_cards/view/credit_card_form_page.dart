import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:signals/signals_flutter.dart';

import '../../../core/di/injector.dart';
import '../../../core/shared/widgets/day_field_widget.dart';
import '../../../core/shared/widgets/failure_card_widget.dart';
import '../../../core/shared/widgets/money_field_widget.dart';
import '../controller/credit_card_form_controller.dart';

/// Cadastro e edição de cartão.
///
/// Uma tela para os dois: o [id] null é cadastro, preenchido é edição. Quem
/// entrega o id é a view, no `initState` — o controller não o recebe pelo
/// construtor.
class CreditCardFormPage extends StatefulWidget {
  const CreditCardFormPage({this.id, super.key});

  final String? id;

  @override
  State<CreditCardFormPage> createState() => _CreditCardFormPageState();
}

class _CreditCardFormPageState extends State<CreditCardFormPage> {
  final _controller = getIt<CreditCardFormController>();

  @override
  void initState() {
    super.initState();
    _controller.start(id: widget.id);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final id = await _controller.submit();

    if (!mounted) return;

    final failure = _controller.generalFailure.value;
    if (failure != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure.message)));
      return;
    }

    // Formulário inválido ou erro de campo: a mensagem já está embaixo do campo,
    // e a tela continua aberta para a correção.
    if (id == null) return;

    Navigator.of(context).pop(id);
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.id != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'Editar cartão' : 'Novo cartão'),
        centerTitle: true,
      ),
      body: SignalBuilder(
        builder: (context) {
          // Em edição, enquanto o `GET` não volta não há formulário: preencher
          // depois em cima do que a pessoa digitou seria pior que esperar.
          if (!_controller.ready.value) {
            final failure = _controller.generalFailure.value;

            if (failure != null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: FailureCardWidget(
                    failure: failure,
                    onRetry: _controller.retry,
                  ),
                ),
              );
            }

            return const Center(child: CircularProgressIndicator());
          }

          return _CreditCardForm(controller: _controller, onSubmit: _submit);
        },
      ),
    );
  }
}

class _CreditCardForm extends StatelessWidget {
  const _CreditCardForm({required this.controller, required this.onSubmit});

  final CreditCardFormController controller;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return ReactiveForm(
      formGroup: controller.form,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ReactiveTextField<String>(
            formControlName: CreditCardFormController.name,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.next,
            validationMessages: {
              ValidationMessage.required: (_) => 'Informe o nome do cartão.',
              CreditCardFormController.backendError: (error) => '$error',
            },
            decoration: const InputDecoration(
              labelText: 'Nome',
              hintText: 'Nubank, Itaú, Inter',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          ReactiveTextField<String>(
            formControlName: CreditCardFormController.lastDigits,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            // Quatro dígitos e nada mais: o limite de tamanho no campo evita a
            // recusa depois.
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(4),
            ],
            validationMessages: {
              CreditCardFormController.fourDigitsError: (_) =>
                  'Informe os quatro últimos dígitos, ou deixe em branco.',
              CreditCardFormController.backendError: (error) => '$error',
            },
            decoration: const InputDecoration(
              labelText: 'Últimos dígitos (opcional)',
              hintText: '1234',
              helperText: 'Aparece no nome do cartão nas telas de gasto.',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          DayFieldWidget(
            formControlName: CreditCardFormController.closingDay,
            label: 'Fechamento',
          ),
          const SizedBox(height: 16),
          // O helper é reativo porque a explicação depende dos dois dias: é aqui
          // que o CAR-03 fica visível para quem está preenchendo, em vez de
          // virar surpresa quando a fatura aparecer no mês seguinte.
          ReactiveValueListenableBuilder<int>(
            formControlName: CreditCardFormController.closingDay,
            builder: (context, closing, child) =>
                ReactiveValueListenableBuilder<int>(
                  formControlName: CreditCardFormController.dueDay,
                  builder: (context, due, child) => DayFieldWidget(
                    formControlName: CreditCardFormController.dueDay,
                    label: 'Vencimento',
                    helperText: _dueHelper(closing.value, due.value),
                  ),
                ),
          ),
          const SizedBox(height: 16),
          MoneyFieldWidget(
            formControlName: CreditCardFormController.limitCents,
            label: 'Limite (opcional)',
            onSubmitted: (_) => onSubmit(),
          ),
          const SizedBox(height: 24),
          SignalBuilder(
            builder: (context) {
              final saving = controller.saving.value;

              return FilledButton(
                onPressed: saving ? null : onSubmit,
                child: saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Salvar'),
              );
            },
          ),
        ],
      ),
    );
  }

  /// Diz em que mês a fatura da competência vence, que é o CAR-03 em português.
  String _dueHelper(int? closingDay, int? dueDay) {
    if (closingDay == null || dueDay == null) return '';

    return dueDay > closingDay
        ? 'Fecha dia $closingDay e vence dia $dueDay: a fatura de um mês vence '
              'no próprio mês.'
        : 'Fecha dia $closingDay e vence dia $dueDay: a fatura de um mês vence '
              'no mês seguinte.';
  }
}
