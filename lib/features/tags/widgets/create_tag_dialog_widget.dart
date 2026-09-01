import 'package:flutter/material.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:se_controle_ai/core/config/globals.dart';
import 'package:se_controle_ai/core/di/injector.dart';
import 'package:se_controle_ai/data/services/navigation_service.dart';
import 'package:se_controle_ai/features/tags/controller/tag_list_controller.dart';
import 'package:signals/signals_hooks.dart';

import '../../../data/models/tag_model.dart';

class CreateTagDialogWidget extends StatefulWidget {
  final TagModel? tag;
  const CreateTagDialogWidget({super.key, this.tag});

  @override
  State<CreateTagDialogWidget> createState() => _CreateTagDialogWidgetState();
}

class _CreateTagDialogWidgetState extends State<CreateTagDialogWidget> {
  final controller = getIt<TagListController>();
  final nav = getIt<NavigationService>();
  bool get _editing => widget.tag != null;

  @override
  void initState() {
    super.initState();

    if (_editing) {
      controller.loadTag(widget.tag!);
    } else {
      controller.clearText();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ReactiveForm(
      formGroup: controller.form,
      child: AlertDialog(
        title: Text(_editing ? 'Editar categoria' : 'Nova categoria'),

        content: SingleChildScrollView(
          padding: .all(8),
          child: Column(
            mainAxisSize: .min,
            crossAxisAlignment: .start,
            children: [
              ReactiveTextField(
                formControlName: 'title',
                onTapOutside: (_) => FocusScope.of(context).unfocus(),
                decoration: InputDecoration(
                  labelText: 'Nome',
                  hintText: 'Mercado, saúde, pets',

                  border: const OutlineInputBorder(),
                ),
                validationMessages: {
                  ValidationMessage.required: (_) =>
                      'Esse campo é obrigatório.',
                },
              ),

              const SizedBox(height: 16),
              Text('Cor', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              SignalBuilder(
                builder: (context) {
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final hex in Globals.pallete)
                        _ColorDot(
                          key: ValueKey(hex), // usado no test de widget
                          hex: hex,
                          selected: controller.getColorSelected.value == hex,
                          onTap: () => controller.setColorSelected = hex,
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),

        actions: [
          TextButton(onPressed: () => nav.pop(), child: const Text('Cancelar')),
          ReactiveFormConsumer(
            builder: (context, form, child) => SignalBuilder(
              builder: (context) {
                final pronto =
                    form.valid && controller.getColorSelected.value != null;

                return FilledButton(
                  onPressed: pronto
                      ? () async {
                          if (_editing) {
                            await controller.update(widget.tag!.id);
                          } else {
                            await controller.create();
                          }
                        }
                      : null,
                  child: Text(_editing ? 'Salvar' : 'Criar'),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({
    required this.hex,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String hex;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = Color(int.parse('FF${hex.substring(1)}', radix: 16));
    final checkColor =
        ThemeData.estimateBrightnessForColor(color) == Brightness.dark
        ? Colors.white
        : Colors.black87;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.onSurface
                : Colors.transparent,
            width: 3,
          ),
        ),
        child: selected ? Icon(Icons.check, size: 16, color: checkColor) : null,
      ),
    );
  }
}
