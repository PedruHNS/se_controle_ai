import 'package:flutter/material.dart';

class const ActionCardWidget({
  super.key,
  required final IconData icon,
  required final String title,
  required final String subtitle,
  required final void Function()? onTap,
  final bool destructive = false,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = destructive ? theme.colorScheme.error : null;

    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: color),
      title: Text(title, style: TextStyle(color: color)),
      subtitle: Text(subtitle, style: theme.textTheme.bodySmall),
    );
  }
}
