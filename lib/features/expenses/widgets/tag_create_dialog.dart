import 'package:flutter/material.dart';

/// O que o diálogo devolve quando a pessoa confirma.
class NewTag {
  const NewTag({required this.name, required this.color});

  final String name;

  /// `#RRGGBB` ou nulo. A cor é opcional e puramente cosmética (TAG-02).
  final String? color;
}

/// Paleta fixa em vez de seletor livre de cor.
///
/// O backend aceita qualquer `#RRGGBB`, mas cor escolhida à mão vira rótulo
/// ilegível — cinza-claro sobre branco — e não há contraste garantido. Estas
/// oito são do Material e funcionam nos dois temas.
const _palette = <String>[
  '#EF5350',
  '#EC407A',
  '#AB47BC',
  '#5C6BC0',
  '#42A5F5',
  '#26A69A',
  '#66BB6A',
  '#FFA726',
];

/// Cria uma tag sem sair do formulário de gasto.
///
/// Devolve o [NewTag] confirmado, ou null se a pessoa cancelou. Quem chama é
/// que fala com o repositório — o diálogo não conhece rede, só coleta.
Future<NewTag?> showTagCreateDialog(BuildContext context) => showDialog<NewTag>(
  context: context,
  builder: (context) => const _TagCreateDialog(),
);

class _TagCreateDialog extends StatefulWidget {
  const _TagCreateDialog();

  @override
  State<_TagCreateDialog> createState() => _TagCreateDialogState();
}

class _TagCreateDialogState extends State<_TagCreateDialog> {
  final _controller = TextEditingController();
  String? _color;
  String? _error;

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

    Navigator.of(context).pop(NewTag(name: name, color: _color));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nova categoria'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
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
          Text('Cor (opcional)', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final hex in _palette)
                _ColorDot(
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
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _confirm, child: const Text('Criar')),
      ],
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({
    required this.hex,
    required this.selected,
    required this.onTap,
  });

  final String hex;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = Color(int.parse('FF${hex.substring(1)}', radix: 16));

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
        child: selected
            ? const Icon(Icons.check, size: 16, color: Colors.white)
            : null,
      ),
    );
  }
}
