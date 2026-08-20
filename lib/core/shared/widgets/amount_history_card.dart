import 'package:flutter/material.dart';

import '../../../data/models/amount_version_model.dart';
import '../../utils/money.dart';
import '../../utils/month.dart';

/// A linha do tempo de vigências — é a prova visual de que um reajuste em
/// novembro não mexeu no que foi pago em setembro.
///
/// Serve ganho e gasto porque os dois leem o mesmo motor de vigência no backend
/// e recebem o histórico no mesmo formato. O que muda entre os dois é o texto
/// das ações, não o desenho de uma linha do tempo — por isso aqui só entra a
/// lista, e nenhum dos dois models.
class AmountHistoryCard extends StatelessWidget {
  const AmountHistoryCard({required this.history, super.key});

  /// Da mais antiga para a mais nova, como o backend devolve.
  final List<AmountVersionModel> history;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Icon(
                  Icons.history,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text('Histórico de valores', style: theme.textTheme.titleSmall),
              ],
            ),
          ),
          // Mais recente primeiro: é o que se consulta com mais frequência.
          for (final version in history.reversed)
            ListTile(
              dense: true,
              leading: Icon(
                version.isOpen ? Icons.play_arrow : Icons.check,
                size: 16,
                color: version.isOpen
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              title: Text(
                Month.periodLabel(version.validFrom, version.validTo),
              ),
              trailing: Text(
                Money.format(version.amountCents),
                style: theme.textTheme.bodyLarge,
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
