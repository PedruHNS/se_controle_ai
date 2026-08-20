import 'package:flutter/material.dart';

import '../../../core/utils/money.dart';
import '../../../core/utils/month.dart';
import '../../../data/models/installment_model.dart';

/// O plano de parcelas — o que o histórico de vigências é para o gasto fixo.
///
/// Mostra todas, e não só as futuras: a pergunta de quem abre um parcelado é
/// "quanto falta e até quando", e isso só se responde vendo o que já passou
/// junto com o que vem.
class InstallmentsCard extends StatelessWidget {
  const InstallmentsCard({
    required this.installments,
    required this.currentMonth,
    super.key,
  });

  final List<InstallmentModel> installments;

  /// A competência de hoje, para destacar a parcela do mês.
  final String currentMonth;

  int get _totalCents =>
      installments.fold(0, (total, parcel) => total + parcel.amountCents);

  /// O que ainda vai ser cobrado, de hoje em diante — inclusive a deste mês,
  /// que ainda não venceu.
  int get _remainingCents => installments
      .where(
        (parcel) => Month.compare(parcel.referenceMonth, currentMonth) >= 0,
      )
      .fold(0, (total, parcel) => total + parcel.amountCents);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final remaining = _remainingCents;

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
                  Icons.view_week_outlined,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text('Parcelas', style: theme.textTheme.titleSmall),
                const Spacer(),
                Text(
                  Money.format(_totalCents),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (remaining > 0 && remaining != _totalCents)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                'Falta pagar ${Money.format(remaining)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          // Na ordem do backend, da primeira à última: é uma linha do tempo, e
          // ler de trás para a frente não ajuda a saber quando acaba.
          for (final parcel in installments)
            _InstallmentTile(
              parcel: parcel,
              isCurrent: parcel.referenceMonth == currentMonth,
              isPast: Month.isBefore(parcel.referenceMonth, currentMonth),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _InstallmentTile extends StatelessWidget {
  const _InstallmentTile({
    required this.parcel,
    required this.isCurrent,
    required this.isPast,
  });

  final InstallmentModel parcel;
  final bool isCurrent;
  final bool isPast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Passada, deste mês, futura. O sistema não sabe se foi paga — ele projeta
    // o que é devido, não concilia o que foi pago —, então o ícone fala de
    // tempo, não de pagamento.
    final (icon, color) = switch ((isCurrent, isPast)) {
      (true, _) => (Icons.play_arrow, theme.colorScheme.primary),
      (_, true) => (Icons.check, theme.colorScheme.onSurfaceVariant),
      _ => (Icons.schedule, theme.colorScheme.onSurfaceVariant),
    };

    return ListTile(
      dense: true,
      leading: Icon(icon, size: 16, color: color),
      title: Text(
        parcel.label,
        style: isCurrent
            ? theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)
            : null,
      ),
      subtitle: Text(Month.label(parcel.referenceMonth)),
      trailing: Text(
        Money.format(parcel.amountCents),
        style: theme.textTheme.bodyLarge,
      ),
    );
  }
}
