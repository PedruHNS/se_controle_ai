import 'package:flutter/material.dart';

import '../../../data/models/tag_model.dart';
import 'create_tag_dialog_widget.dart';

/// O que o diálogo devolve quando a pessoa confirma.
class TagFormResult {
  const TagFormResult({required this.name, required this.color});

  final String name;

  /// `#RRGGBB` ou nulo. A cor é opcional e puramente cosmética (TAG-02).
  ///
  /// Nulo é um valor, não "não informado": na edição ele significa **limpar a
  /// cor**, e é por isso que quem chama traduz para `Patch.clear()`.
  final String? color;
}

/// Cria ou edita uma tag em diálogo.
///
/// Serve os dois lugares que precisam disso: a tela de tags e o formulário de
/// gasto, onde criar sem sair da tela evita abandonar o cadastro pela metade.
/// Passe [tag] para editar; sem ele, é criação.
///
/// Devolve o [TagFormResult] confirmado, ou null se a pessoa cancelou. Quem
/// chama é que fala com o repositório — o diálogo não conhece rede, só coleta.
/// O formulário mora em [CreateTagDialogWidget].
Future<TagFormResult?> showTagFormDialog(
  BuildContext context, {
  TagModel? tag,
}) => showDialog<TagFormResult>(
  context: context,
  builder: (context) => CreateTagDialogWidget(tag: tag),
);
