import 'package:flutter/material.dart';

class CustomBoxShadowWidget extends StatelessWidget {
  final Widget child;
  const CustomBoxShadowWidget({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: .fromRGBO(57, 51, 96, 0.1),
            spreadRadius: 0,
            blurRadius: 40,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: child,
    );
  }
}
