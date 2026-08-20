import 'package:flutter/material.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:signals/signals_flutter.dart';

import '../../../core/di/injector.dart';
import '../../../core/shared/widgets/failure_card_widget.dart';
import '../../../core/shared/widgets/money_field_widget.dart';
import '../../../core/shared/widgets/month_field_widget.dart';
import '../../../data/models/expense_model.dart';
import '../controller/expense_form_controller.dart';

/// Cadastro e edição de gasto fixo.
///
/// Uma tela para os dois: o [id] null é cadastro, preenchido é edição. Em
/// edição só os dados cadastrais aparecem — valor, competência e recorrência
/// somem, porque mexer em dinheiro é reajuste, correção ou encerramento, e cada
/// um faz uma coisa diferente com o passado.
class ExpenseFormPage extends StatefulWidget {
  const ExpenseFormPage({this.id, super.key});

  final String? id;

  @override
  State<ExpenseFormPage> createState() => _ExpenseFormPageState();
}

class _ExpenseFormPageState extends State<ExpenseFormPage> {
  final _controller = getIt<ExpenseFormController>();

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

    // Formulário inválido ou erro de campo: a mensagem já está embaixo do
    // campo, e a tela continua aberta para a correção.
    if (id == null) return;

    Navigator.of(context).pop(id);
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.id != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'Editar gasto' : 'Novo gasto'),
        centerTitle: true,
      ),
      body: SignalBuilder(
        builder: (context) {
          // Enquanto os `GET` não voltam não há formulário: preencher depois em
          // cima do que a pessoa digitou seria pior que esperar.
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

          return _ExpenseForm(controller: _controller, onSubmit: _submit);
        },
      ),
    );
  }
}

class _ExpenseForm extends StatelessWidget {
  const _ExpenseForm({required this.controller, required this.onSubmit});

  final ExpenseFormController controller;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final editing = controller.isEditing;

    return ReactiveForm(
      formGroup: controller.form,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ReactiveTextField<String>(
            formControlName: ExpenseFormController.description,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.next,
            validationMessages: {
              ValidationMessage.required: (_) => 'Informe a descrição.',
              ExpenseFormController.backendError: (error) => '$error',
            },
            decoration: const InputDecoration(
              labelText: 'Descrição',
              hintText: 'Aluguel, streaming, ração',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          ReactiveTextField<String>(
            formControlName: ExpenseFormController.category,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.next,
            validationMessages: {
              ExpenseFormController.backendError: (error) => '$error',
            },
            decoration: const InputDecoration(
              labelText: 'Categoria (opcional)',
              hintText: 'Moradia, lazer, saúde',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          Text('Forma de pagamento', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          ReactiveValueListenableBuilder<PaymentMethod>(
            formControlName: ExpenseFormController.paymentMethod,
            builder: (context, control, child) {
              final method = control.value ?? PaymentMethod.debit;

              return SegmentedButton<PaymentMethod>(
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
                selected: {method},
                onSelectionChanged: (selection) =>
                    controller.selectPaymentMethod(selection.first),
              );
            },
          ),

          // O seletor de cartão só existe quando a forma é cartão: no débito
          // ele não teria o que fazer, e o backend recusa cartão junto com
          // débito (GFX-01).
          ReactiveValueListenableBuilder<PaymentMethod>(
            formControlName: ExpenseFormController.paymentMethod,
            builder: (context, control, child) {
              if (control.value != PaymentMethod.creditCard) {
                return const SizedBox.shrink();
              }

              if (controller.cards.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.only(top: 16),
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
                padding: const EdgeInsets.only(top: 16),
                child: ReactiveDropdownField<String>(
                  formControlName: ExpenseFormController.creditCardId,
                  validationMessages: {
                    ValidationMessage.required: (_) => 'Escolha o cartão.',
                    ExpenseFormController.backendError: (error) => '$error',
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

          // Dinheiro só no cadastro (GFX-06): depois de existir, o valor muda
          // por reajuste ou correção, na tela do gasto.
          if (!editing) ...[
            const SizedBox(height: 16),
            MoneyFieldWidget(
              formControlName: ExpenseFormController.amountCents,
              label: 'Valor por mês',
              onSubmitted: (_) => onSubmit(),
            ),
            const SizedBox(height: 16),
            MonthFieldWidget(
              formControlName: ExpenseFormController.startMonth,
              label: 'A partir de',
            ),
            const SizedBox(height: 8),
            ReactiveSwitchListTile(
              formControlName: ExpenseFormController.recurring,
              contentPadding: EdgeInsets.zero,
              title: const Text('Recorrente'),
              subtitle: ReactiveValueListenableBuilder<bool>(
                formControlName: ExpenseFormController.recurring,
                builder: (context, control, child) => Text(
                  control.value ?? true
                      ? 'Cobra todo mês até você encerrar.'
                      : 'Sai só nesta competência — presente, conserto, '
                            'consulta.',
                ),
              ),
            ),
          ],

          if (editing) ...[
            const SizedBox(height: 16),
            Text(
              'Descrição, categoria e forma de pagamento valem para todos os '
              'meses, inclusive os que já passaram. Para mudar o valor, use '
              'Reajustar ou Corrigir na tela do gasto.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],

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
}
