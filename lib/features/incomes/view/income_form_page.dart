import 'package:flutter/material.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:se_controle_ai/core/shared/widgets/text_field_custom_widget.dart';
import 'package:signals/signals_flutter.dart';

import '../../../core/di/injector.dart';
import '../../../core/shared/widgets/money_field_widget.dart';
import '../../../core/shared/widgets/month_field_widget.dart';
import '../controller/income_controller.dart';

/// Cadastro de ganho: descrição, valor, competência inicial e recorrência.
class IncomeFormPage extends StatefulWidget {
  const IncomeFormPage({super.key});

  @override
  State<IncomeFormPage> createState() => _IncomeFormPageState();
}

class _IncomeFormPageState extends State<IncomeFormPage> {
  final _controller = getIt<IncomeController>();

  @override
  void initState() {
    super.initState();
    _controller.startForm();
  }

  Future<void> _submit() async {
    await _controller.submit();

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Novo ganho'), centerTitle: true),
      body: ReactiveForm(
        formGroup: _controller.form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFieldCustomWidget(
              formControlName: 'description',
              labelText: 'Título',
              hintText: 'Ex:. salário',
              autofocus: true,
              validationMessages: {
                ValidationMessage.required: (_) => 'Informe a descrição.',
                'backend': (error) => '$error',
              },
            ),

            const SizedBox(height: 16),
            MoneyFieldWidget(formControlName: 'amountCents'),
            const SizedBox(height: 16),
            MonthFieldWidget(
              formControlName: 'startMonth',
              label: 'A partir de',
            ),
            const SizedBox(height: 8),

            SignalBuilder(
              builder: (context) => Row(
                mainAxisAlignment: .spaceBetween,
                children: [
                  Padding(
                    padding: const .only(left: 8),
                    child: Text(
                      'Recorrente',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Switch(
                    value: _controller.isRecurring.value,
                    onChanged: (value) => _controller.setIsRecurring = value,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SignalBuilder(
              builder: (context) {
                final saving = _controller.saving.value;

                return ReactiveFormConsumer(
                  builder: (context, form, child) {
                    return FilledButton(
                      onPressed: form.valid && !saving ? _submit : null,
                      child: saving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Salvar'),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
