import 'package:flutter/material.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:se_controle_ai/core/di/injector.dart';
import 'package:se_controle_ai/features/tags/controller/tag_list_controller.dart';
import 'package:signals/signals_hooks.dart';

import '../../../data/models/tag_model.dart';

/// Paleta fixa em vez de seletor livre de cor.
///
/// O backend aceita qualquer `#RRGGBB`, mas cor escolhida à mão vira rótulo
/// ilegível — cinza-claro sobre branco — e não há contraste garantido. Estas
/// são todas do Material, nos tons **400 e 600**, que é a faixa que se enxerga
/// tanto no tema claro quanto no escuro. Fora dela, os tons 100–300 somem no
/// branco e os 800–900 somem no preto.
///
/// **Na ordem do círculo cromático**, e não por gosto: quem procura "um verde"
/// acha os verdes juntos. As oito primeiras do arranjo antigo continuam aqui,
/// com os mesmos códigos — tag já cadastrada segue casando com um círculo da
/// paleta em vez de aparecer sem seleção ao abrir a edição.
const _palette = [
  '#EF5350',
  '#E53935',
  '#EC407A',
  '#D81B60',
  '#AB47BC',
  '#8E24AA',
  '#7E57C2',
  '#5C6BC0',
  '#42A5F5',
  '#1E88E5',
  '#29B6F6',
  '#00ACC1',
  '#26A69A',
  '#00897B',
  '#66BB6A',
  '#43A047',
  '#9CCC65',
  '#C0CA33',
  '#FFCA28',
  '#FFA726',
  '#FB8C00',
  '#FF7043',
  '#F4511E',
  '#8D6E63',
  '#78909C',
];

/// O formulário de tag em si — nome e cor, sem rede.
///
/// Público porque mora fora do arquivo de quem o abre, mas o caminho normal
/// continua sendo [showTagFormDialog]: é ele que devolve o [TagFormResult] e
/// resolve o `showDialog`. Construir esta classe direto só faz sentido para
/// montá-la fora de um diálogo.
///
/// Passe [tag] para editar; sem ele, é criação.
class CreateTagDialogWidget extends StatefulWidget {
  final TagModel? tag;
  const CreateTagDialogWidget({super.key, this.tag});

  @override
  State<CreateTagDialogWidget> createState() => _CreateTagDialogWidgetState();
}

class _CreateTagDialogWidgetState extends State<CreateTagDialogWidget> {
  final controller = getIt<TagListController>();

  String? _error;

  bool get _editing => widget.tag != null;

  @override
  void dispose() {
    super.dispose();
  }

  void _confirm() async {
    // A mesma regra do backend (TAG-01), verificada aqui só para não gastar uma
    // ida ao servidor com o caso mais provável de erro.
    await controller.create();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_editing ? 'Editar categoria' : 'Nova categoria'),

      content: SingleChildScrollView(
        padding: .all(8),
        child: ReactiveForm(
          formGroup: controller.form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ReactiveTextField(
                formControlName: 'title',
                decoration: InputDecoration(
                  labelText: 'Nome',
                  hintText: 'Mercado, saúde, pets',
                  border: const OutlineInputBorder(),
                  errorText: _error,
                ),
                validationMessages: {
                  ValidationMessage.required: (_) =>
                      'Esse campo é obrigatório.',
                },
              ),

              const SizedBox(height: 16),
              Text(
                'Cor (opcional)',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              SignalBuilder(
                builder: (context) {
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final hex in _palette)
                        _ColorDot(
                          key: ValueKey(hex), // usado no test de widget
                          hex: hex,
                          selected: controller.getColorSelected.value == hex,
                          // Tocar na cor já escolhida desmarca: é como se tira a cor
                          // sem precisar de um botão "nenhuma".
                          onTap: () => controller.setColorSelected = hex,
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _confirm,
          child: Text(_editing ? 'Salvar' : 'Criar'),
        ),
      ],
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
