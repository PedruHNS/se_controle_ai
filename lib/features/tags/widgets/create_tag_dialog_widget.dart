import 'package:flutter/material.dart';

import '../../../data/models/tag_model.dart';
import 'tag_form_dialog.dart';

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
const _palette = <String>[
  // Vermelhos e rosas
  '#EF5350',
  '#E53935',
  '#EC407A',
  '#D81B60',
  // Roxos
  '#AB47BC',
  '#8E24AA',
  '#7E57C2',
  '#5C6BC0',
  // Azuis
  '#42A5F5',
  '#1E88E5',
  '#29B6F6',
  '#00ACC1',
  // Verdes
  '#26A69A',
  '#00897B',
  '#66BB6A',
  '#43A047',
  '#9CCC65',
  '#C0CA33',
  // Amarelos e laranjas
  '#FFCA28',
  '#FFA726',
  '#FB8C00',
  '#FF7043',
  '#F4511E',
  // Neutros, para quem quer marcar sem gritar
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
  const CreateTagDialogWidget({super.key, this.tag});

  final TagModel? tag;

  @override
  State<CreateTagDialogWidget> createState() => _CreateTagDialogWidgetState();
}

class _CreateTagDialogWidgetState extends State<CreateTagDialogWidget> {
  late final _controller = TextEditingController(text: widget.tag?.name ?? '');
  late String? _color = widget.tag?.color;
  String? _error;

  bool get _editing => widget.tag != null;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _confirm() {
    final name = _controller.text.trim();

    // A mesma regra do backend (TAG-01), verificada aqui só para não gastar uma
    // ida ao servidor com o caso mais provável de erro.
    if (name.isEmpty) {
      setState(() => _error = 'Informe o nome.');
      return;
    }

    Navigator.of(context).pop(TagFormResult(name: name, color: _color));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_editing ? 'Editar categoria' : 'Nova categoria'),
      // Rolável porque a paleta cresceu: em tela baixa, ou com a fonte do
      // sistema aumentada, as quatro fileiras de cores não cabem junto com o
      // campo de nome.
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _controller,
              autofocus: !_editing,
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: (_) => _confirm(),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              decoration: InputDecoration(
                labelText: 'Nome',
                hintText: 'Mercado, saúde, pets',
                border: const OutlineInputBorder(),
                errorText: _error,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Cor (opcional)',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final hex in _palette)
                  _ColorDot(
                    // A chave é o próprio hex: é o que o teste usa para tocar
                    // numa cor específica sem depender da posição dela na
                    // paleta, que muda toda vez que uma cor nova entra.
                    key: ValueKey(hex),
                    hex: hex,
                    selected: _color == hex,
                    // Tocar na cor já escolhida desmarca: é como se tira a cor
                    // sem precisar de um botão "nenhuma".
                    onTap: () =>
                        setState(() => _color = _color == hex ? null : hex),
                  ),
              ],
            ),
          ],
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

    // O check acompanha a cor do círculo, e não é branco fixo: com a paleta
    // maior entraram tons claros — o amarelo, o lima —, e branco sobre eles
    // fica invisível justamente no momento em que precisa ser visto.
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
