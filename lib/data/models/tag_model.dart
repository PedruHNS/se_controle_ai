import 'package:flutter/material.dart';

/// Rótulo do usuário — "Moradia", "Transporte". Substituiu a categoria em
/// texto livre: texto não agrupa, e agrupar é o motivo de a tag existir.
///
/// Obrigatória no gasto (TAG-06) e opcional no ganho (TAG-07).
class TagModel {
  const TagModel({required this.id, required this.name, required this.color});

  final String id;
  final String name;

  /// `#RRGGBB` ou nulo. Puramente cosmética — nenhuma regra lê a cor (TAG-02).
  final String? color;

  factory TagModel.fromJson(Map<String, dynamic> json) => TagModel(
    id: json['id'] as String,
    name: json['name'] as String,
    color: json['color'] as String?,
  );

  /// A cor como [Color], ou nulo quando a tag não tem cor. O backend garante o
  /// formato `#RRGGBB` por CHECK, mas um valor estranho aqui viraria exceção em
  /// tempo de pintura — por isso o parse é tolerante.
  Color? get parsedColor {
    final value = color;
    if (value == null || !RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(value)) {
      return null;
    }
    return Color(int.parse('FF${value.substring(1)}', radix: 16));
  }

  @override
  bool operator ==(Object other) =>
      other is TagModel &&
      other.id == id &&
      other.name == name &&
      other.color == color;

  @override
  int get hashCode => Object.hash(id, name, color);
}
