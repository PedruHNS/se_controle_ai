import 'package:flutter/material.dart';
import 'package:signals/signals_flutter.dart';

import '../../di/injector.dart';
import '../../../data/services/selected_month_service.dart';

class MonthSelectorWidget extends StatelessWidget {
  final bool short;
  const MonthSelectorWidget({this.short = false, super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedMonth = getIt<SelectedMonthService>();

    // Sem cor própria: quem define o fundo é quem o coloca na tela — dentro de
    // um card ele é transparente, e num cabeçalho fixo quem precisa ser opaco é
    // o cabeçalho, não o seletor.
    return Material(
      type: MaterialType.transparency,
      child: Padding(
        padding: .symmetric(horizontal: 12, vertical: 4),
        child: Row(
          mainAxisAlignment: .center,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              tooltip: 'Mês anterior',
              onPressed: selectedMonth.goToPrevious,
            ),

            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: SignalBuilder(
                  builder: (context) => Text(
                    short
                        ? selectedMonth.shortLabel.value
                        : selectedMonth.label.value,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              tooltip: 'Próximo mês',
              onPressed: selectedMonth.goToNext,
            ),
          ],
        ),
      ),
    );
  }
}
