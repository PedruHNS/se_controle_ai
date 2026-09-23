import 'package:flutter/material.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:signals/signals_flutter.dart';

import '../../../core/di/injector.dart';
import '../../../core/shared/widgets/money_field_widget.dart';
import '../../../core/shared/widgets/month_field_widget.dart';
import '../controller/income_form_controller.dart';

/// Cadastro de ganho: descrição, valor, competência inicial e recorrência.
class IncomeFormPage extends StatefulWidget {
  const IncomeFormPage({super.key});

  @override
  State<IncomeFormPage> createState() => _IncomeFormPageState();
}

class _IncomeFormPageState extends State<IncomeFormPage> {
  final _controller = getIt<IncomeFormController>();

  @override
  void initState() {
    super.initState();
    // Sem await e sem estado de carregamento: a tag é opcional (TAG-07), então
    // o formulário já é utilizável enquanto a lista não chega — o seletor
    // aparece vazio e se preenche sozinho.
    _controller.loadTags();
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
    return Scaffold(
      appBar: AppBar(title: const Text('Novo ganho'), centerTitle: true),
      body: ReactiveForm(
        formGroup: _controller.form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ReactiveTextField<String>(
              formControlName: IncomeFormController.description,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              validationMessages: {
                ValidationMessage.required: (_) => 'Informe a descrição.',
                IncomeFormController.backendError: (error) => '$error',
              },
              decoration: const InputDecoration(
                labelText: 'Descrição',
                hintText: 'Salário, freela, aluguel recebido',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            SignalBuilder(
              builder: (context) => ReactiveDropdownField<String>(
                formControlName: IncomeFormController.tagId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Categoria (opcional)',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final tag in _controller.tags.value)
                    DropdownMenuItem(value: tag.id, child: Text(tag.name)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            MoneyFieldWidget(formControlName: IncomeFormController.amountCents),
            const SizedBox(height: 16),
            MonthFieldWidget(
              formControlName: IncomeFormController.startMonth,
              label: 'A partir de',
            ),
            const SizedBox(height: 8),
            ReactiveSwitchListTile(
              formControlName: IncomeFormController.recurring,
              contentPadding: EdgeInsets.zero,
              title: const Text('Recorrente'),
              subtitle: ReactiveValueListenableBuilder<bool>(
                formControlName: IncomeFormController.recurring,
                builder: (context, control, child) => Text(
                  control.value ?? true
                      ? 'Segue todo mês até você encerrar.'
                      : 'Entra só nesta competência — 13º, freela, bônus.',
                ),
              ),
            ),
            const SizedBox(height: 24),
            SignalBuilder(
              builder: (context) {
                final saving = _controller.saving.value;

                return FilledButton(
                  onPressed: saving ? null : _submit,
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
      ),
    );
  }
}
