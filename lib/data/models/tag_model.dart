import 'package:flutter/material.dart';

/// Rótulo do usuário — "Moradia", "Transporte". Substituiu a categoria em
/// texto livre: texto não agrupa, e agrupar é o motivo de a tag existir.
///
/// Obrigatória no gasto (TAG-06) e opcional no ganho (TAG-07).
class TagModel {
  final String id;
  final String name;
  final String? color;
  final bool archived;
  final int usageCount;

  const TagModel({
    required this.id,
    required this.name,
    required this.color,
    this.archived = false,
    this.usageCount = 0,
  });

  factory TagModel.fromJson(Map<String, dynamic> json) => TagModel(
    id: json['id'] as String,
    name: json['name'] as String,
    color: json['color'] as String?,
    // Ausentes na tag aninhada em gasto e ganho, presentes em `GET /tags`.
    archived: json['archived'] as bool? ?? false,
    usageCount: json['usageCount'] as int? ?? 0,
  );

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
      other.color == color &&
      other.archived == archived &&
      other.usageCount == usageCount;

  @override
  int get hashCode => Object.hash(id, name, color, archived, usageCount);
}
