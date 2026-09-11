import 'package:flutter/material.dart';

abstract final class TagColor {
  static const fallback = Color(0xFF78909C);
  static final _formato = RegExp(r'^#[0-9A-Fa-f]{6}$');

  static Color? tryParse(String? hex) {
    if (hex == null || !_formato.hasMatch(hex)) return null;
    return Color(int.parse('FF${hex.substring(1)}', radix: 16));
  }

  static Color parse(String? hex) => tryParse(hex) ?? fallback;
}
