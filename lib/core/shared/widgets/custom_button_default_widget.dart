import 'package:flutter/material.dart';

class const CustomButtonDefaultWidget({
  super.key,
  final bool isLoading = false,
  final bool enable = true,
  required final String title,
  final double width = 120,
  required final void Function()? onPressed,
}) extends StatelessWidget {
  static const _height = 40.0;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      style: FilledButton.styleFrom(
        fixedSize: Size(isLoading ? _height : width, _height),
        shape: isLoading ? const CircleBorder() : null,
      ),
      onPressed: isLoading || !enable ? null : onPressed,
      child: isLoading
          ? const CircularProgressIndicator(strokeWidth: 2)
          : Text(title),
    );
  }
}
