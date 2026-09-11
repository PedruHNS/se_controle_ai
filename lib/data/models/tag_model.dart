class TagModel {
  final String id;
  final String name;
  final String color;
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
    color: json['color'] as String,
    archived: json['archived'] as bool? ?? false,
    usageCount: json['usageCount'] as int? ?? 0,
  );

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

  @override
  String toString() =>
      'TagModel(id: $id, name: $name, color: $color, '
      'archived: $archived, usageCount: $usageCount)';
}
