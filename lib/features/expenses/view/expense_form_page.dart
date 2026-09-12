import 'package:flutter/material.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:signals/signals_flutter.dart';

import '../../../core/di/injector.dart';
import '../../../core/utils/month.dart';
import '../../../core/month/selected_month_service.dart';
import '../../../core/shared/widgets/failure_card_widget.dart';
import '../../../core/shared/widgets/date_field_widget.dart';
import '../../../core/shared/widgets/money_field_widget.dart';
import '../../../core/shared/widgets/month_field_widget.dart';
import '../../../core/utils/money.dart';
import '../../../data/models/tag_model.dart';
import '../controller/expense_form_controller.dart';
import 'package:se_controle_ai/data/enums/payment_method.dart';
import 'package:se_controle_ai/data/enums/expense_type.dart';
import 'package:se_controle_ai/core/utils/tag_color.dart';

/// Cadastro e edição de gasto.
///
/// Uma tela para os dois: o [id] null é cadastro, preenchido é edição. Em
/// edição só os dados cadastrais aparecem — dinheiro e competência somem,
/// porque mexer neles é reajuste, correção, encerramento, reparcelamento ou
/// quitação, e cada um faz uma coisa diferente com o passado.
///
/// No cadastro, o seletor de tipo troca a metade de baixo do formulário: fixo
/// pede valor por mês, parcelado pede o total da compra e em quantas vezes.
class ExpenseFormPage extends StatefulWidget {
  const ExpenseFormPage({this.id, super.key});

  final String? id;

  @override
  State<ExpenseFormPage> createState() => _ExpenseFormPageState();
}

class _ExpenseFormPageState extends State<ExpenseFormPage> {
  final _controller = getIt<ExpenseFormController>();

  @override
  void initState() {
    super.initState();
    _controller.start(id: widget.id);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final id = await _controller.submit();

    if (!mounted) return;

    final failure = _controller.generalFailure.value;
    if (failure != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure.message)));
      return;
    }

    // Formulário inválido ou erro de campo: a mensagem já está embaixo do
    // campo, e a tela continua aberta para a correção.
    if (id == null) return;

    // A competência sai do dia, não do mês que a home está mostrando — então
    // o gasto pode ter caído fora da tela de onde veio. Sem este aviso, um
    // almoço de hoje lançado enquanto se olha outubro simplesmente sumiria, e
    // a leitura natural seria "não salvou".
    final month = _controller.competenceMonth;
    final selected = getIt<SelectedMonthService>();

    if (month != null && month != selected.month.value) {
      selected.select(month);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lançado em ${Month.label(month)}')),
      );
    }

    Navigator.of(context).pop(id);
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.id != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'Editar gasto' : 'Novo gasto'),
        centerTitle: true,
      ),
      body: SignalBuilder(
        builder: (context) {
          // Enquanto os `GET` não voltam não há formulário: preencher depois em
          // cima do que a pessoa digitou seria pior que esperar.
          if (!_controller.ready.value) {
            final failure = _controller.generalFailure.value;

            if (failure != null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: FailureCardWidget(
                    failure: failure,
                    onRetry: _controller.retry,
                  ),
                ),
              );
            }

            return const Center(child: CircularProgressIndicator());
          }

          return _ExpenseForm(controller: _controller, onSubmit: _submit);
        },
      ),
    );
  }
}

class _ExpenseForm extends StatelessWidget {
  const _ExpenseForm({required this.controller, required this.onSubmit});

  final ExpenseFormController controller;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final editing = controller.isEditing;

    return ReactiveForm(
      formGroup: controller.form,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ReactiveTextField<String>(
            formControlName: ExpenseFormController.description,
            autofocus: true,
            onTapOutside: (event) => FocusScope.of(context).unfocus(),
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.next,
            validationMessages: {
              ValidationMessage.required: (_) => 'Informe a descrição.',
              ExpenseFormController.backendError: (error) => '$error',
            },
            decoration: const InputDecoration(
              labelText: 'Descrição',
              hintText: 'Aluguel, streaming, ração',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          // A categoria virou tag, e é obrigatória (TAG-06). O botão ao lado
          // cria uma na hora: sem ele, precisar de um rótulo novo obrigaria a
          // abandonar o cadastro pela metade — pior do que o texto livre que
          // havia antes.
          SignalBuilder(
            builder: (context) {
              final tags = controller.tags.value;

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: ReactiveDropdownField<String>(
                      formControlName: ExpenseFormController.tagId,
                      isExpanded: true,
                      validationMessages: {
                        ValidationMessage.required: (_) =>
                            'Escolha a categoria.',
                        ExpenseFormController.backendError: (error) =>
                            '\$error',
                      },
                      decoration: const InputDecoration(
                        labelText: 'Categoria',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (final tag in tags)
                          DropdownMenuItem(
                            value: tag.id,
                            child: _TagChipLabel(tag: tag),
                          ),
                      ],
                    ),
                  ),
                  // const SizedBox(width: 8),
                  // Padding(
                  //   padding: const EdgeInsets.only(top: 4),
                  //   child: IconButton.filledTonal(
                  //     onPressed: () => _createTag(context, controller),
                  //     icon: const Icon(Icons.add),
                  //     tooltip: 'Nova categoria',
                  //   ),
                  // ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          ReactiveTextField<String>(
            formControlName: ExpenseFormController.notes,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.newline,
            onTapOutside: (event) => FocusScope.of(context).unfocus(),
            keyboardType: TextInputType.multiline,
            minLines: 2,
            maxLines: 4,
            validationMessages: {
              ExpenseFormController.backendError: (error) => '\$error',
            },
            decoration: const InputDecoration(
              labelText: 'Observação (opcional)',
              hintText: 'Detalhe que o rótulo não carrega',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 16),

          Text('Forma de pagamento', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          ReactiveValueListenableBuilder<PaymentMethod>(
            formControlName: ExpenseFormController.paymentMethod,
            builder: (context, control, child) {
              final method = control.value ?? PaymentMethod.debit;

              return SegmentedButton<PaymentMethod>(
                segments: const [
                  ButtonSegment(
                    value: PaymentMethod.debit,
                    icon: Icon(Icons.payments_outlined),
                    label: Text('Débito'),
                  ),
                  ButtonSegment(
                    value: PaymentMethod.creditCard,
                    icon: Icon(Icons.credit_card),
                    label: Text('Cartão'),
                  ),
                ],
                selected: {method},
                onSelectionChanged: (selection) =>
                    controller.selectPaymentMethod(selection.first),
              );
            },
          ),

          // O seletor de cartão só existe quando a forma é cartão: no débito
          // ele não teria o que fazer, e o backend recusa cartão junto com
          // débito (GFX-01).
          ReactiveValueListenableBuilder<PaymentMethod>(
            formControlName: ExpenseFormController.paymentMethod,

            builder: (context, control, child) {
              if (control.value != PaymentMethod.creditCard) {
                return const SizedBox.shrink();
              }

              if (controller.cards.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    'Nenhum cartão cadastrado. Cadastre um em Cartões antes de '
                    'lançar um gasto no cartão.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                );
              }

              return Padding(
                padding: const EdgeInsets.only(top: 16),
                child: ReactiveDropdownField<String>(
                  formControlName: ExpenseFormController.creditCardId,
                  validationMessages: {
                    ValidationMessage.required: (_) => 'Escolha o cartão.',
                    ExpenseFormController.backendError: (error) => '$error',
                  },
                  decoration: const InputDecoration(
                    labelText: 'Cartão',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final card in controller.cards)
                      DropdownMenuItem(value: card.id, child: Text(card.label)),
                  ],
                ),
              );
            },
          ),

          // Dinheiro só no cadastro (GFX-06): depois de existir, o valor muda
          // pelas operações da tela do gasto.
          //
          // O tipo também só aparece aqui: à vista e parcelado guardam dinheiro
          // em lugares diferentes (GFX-09), e trocar o tipo de um gasto
          // existente seria jogar fora a fonte da verdade dele. O backend nem
          // oferece.
          if (!editing) ...[
            const SizedBox(height: 16),
            Text('Tipo', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            ReactiveValueListenableBuilder<ExpenseType>(
              formControlName: ExpenseFormController.type,
              builder: (context, control, child) =>
                  SegmentedButton<ExpenseType>(
                    segments: const [
                      // "À vista" e não "Fixo": o par de "Parcelado" é a forma
                      // de pagar, e desde que a recorrência virou switch à
                      // parte — desligado por padrão — chamar isto de fixo
                      // contradizia o controle logo abaixo. O tipo no backend
                      // continua `FIXED`; o que mudou é como se lê na tela.
                      ButtonSegment(
                        value: ExpenseType.fixed,
                        icon: Icon(Icons.payments_outlined),
                        label: Text('À vista'),
                      ),
                      ButtonSegment(
                        value: ExpenseType.installment,
                        icon: Icon(Icons.view_week_outlined),
                        label: Text('Parcelado'),
                      ),
                    ],
                    selected: {control.value ?? ExpenseType.fixed},
                    onSelectionChanged: (selection) =>
                        controller.selectType(selection.first),
                  ),
            ),

            ReactiveValueListenableBuilder<ExpenseType>(
              formControlName: ExpenseFormController.type,
              builder: (context, control, child) =>
                  control.value == ExpenseType.installment
                  ? _InstallmentFields(
                      controller: controller,
                      onSubmit: onSubmit,
                    )
                  : _FixedFields(controller: controller, onSubmit: onSubmit),
            ),
          ],

          if (editing) ...[
            const SizedBox(height: 16),
            Text(
              'Descrição, categoria e forma de pagamento valem para todos os '
              'meses, inclusive os que já passaram. Para mudar o valor, use as '
              'ações da tela do gasto.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],

          const SizedBox(height: 24),
          SignalBuilder(
            builder: (context) {
              final saving = controller.saving.value;

              return FilledButton(
                onPressed: saving ? null : onSubmit,
                child: saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Salvar'),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Os campos do gasto à vista (`FIXED` no backend): um valor, a partir de uma
/// competência, repetindo ou não.
class _FixedFields extends StatelessWidget {
  const _FixedFields({required this.controller, required this.onSubmit});

  final ExpenseFormController controller;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        MoneyFieldWidget(
          formControlName: ExpenseFormController.amountCents,
          label: 'Valor por mês',
          onSubmitted: (_) => onSubmit(),
        ),
        const SizedBox(height: 16),
        _SpentAtField(controller: controller),
        const SizedBox(height: 8),
        ReactiveSwitchListTile(
          formControlName: ExpenseFormController.recurring,
          contentPadding: EdgeInsets.zero,
          title: const Text('Recorrente'),
          subtitle: ReactiveValueListenableBuilder<bool>(
            formControlName: ExpenseFormController.recurring,
            builder: (context, control, child) => Text(
              control.value ?? false
                  ? 'Cobra todo mês até você encerrar.'
                  : 'Sai só nesta competência — presente, conserto, consulta.',
            ),
          ),
        ),
      ],
    );
  }
}

/// Os campos que só o parcelado tem. O valor pedido é o **total da compra**
/// (GPR-02) — quem digita 3.000 em 10x está comprando uma geladeira de três
/// mil, não pagando trinta mil.
class _InstallmentFields extends StatelessWidget {
  const _InstallmentFields({required this.controller, required this.onSubmit});

  final ExpenseFormController controller;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        MoneyFieldWidget(
          formControlName: ExpenseFormController.totalCents,
          label: 'Total da compra',
          onSubmitted: (_) => onSubmit(),
        ),
        const SizedBox(height: 16),
        ReactiveTextField<int>(
          formControlName: ExpenseFormController.installmentsCount,
          keyboardType: TextInputType.number,
          validationMessages: {
            ValidationMessage.required: (_) => 'Informe em quantas vezes.',
            ValidationMessage.number: (_) => 'Só números.',
            ValidationMessage.min: (_) =>
                'Mínimo de ${ExpenseFormController.minInstallments} parcelas. '
                'Para 1x, cadastre como fixo não recorrente.',
            ValidationMessage.max: (_) =>
                'Máximo de ${ExpenseFormController.maxInstallments} parcelas.',
            ExpenseFormController.backendError: (error) => '$error',
          },
          decoration: const InputDecoration(
            labelText: 'Em quantas vezes',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        _SpentAtField(controller: controller),
        const SizedBox(height: 8),
        // O rateio é do backend, e a sobra vai nas primeiras parcelas (GPR-03).
        // Dizer isso aqui evita a pergunta "por que a primeira é um centavo
        // maior" depois de salvar.
        _InstallmentPreview(style: theme.textTheme.bodySmall),
      ],
    );
  }
}

/// O dia do gasto e, quando alguém discorda da conta, a competência.
///
/// O mês normalmente não é uma segunda pergunta: ele sai do dia, pela regra de
/// fechamento do cartão ou pelo próprio mês do dia no débito, e o texto de
/// apoio diz em qual fatura o gasto caiu e quando ela vence.
///
/// **O "Ajustar" existe porque a conta já errou duas vezes.** Ele foi desenhado
/// em 10/09/2026 e descartado por falta de caso de uso — dois dias depois
/// apareceu o caso: num cartão que fecha 31 e vence 5 a competência ficava um
/// mês antes do mês em que o dinheiro sai, e não havia nada na tela para
/// discordar. A regra que adivinha continua sendo o padrão; o que muda é que
/// agora dá para vencê-la sem apagar e refazer o gasto.
///
/// Fica escondido até ser pedido: quem concorda com o padrão — quase sempre —
/// continua vendo um campo de tempo só.
///
/// `ReactiveFormConsumer` porque a frase e o rótulo dependem de quatro campos
/// ao mesmo tempo — dia, cartão, forma de pagamento e recorrência. Aninhar
/// quatro `ReactiveValueListenable` custaria mais linhas do que reconstruir um
/// `InputDecorator`.
class _SpentAtField extends StatefulWidget {
  const _SpentAtField({required this.controller});

  final ExpenseFormController controller;

  @override
  State<_SpentAtField> createState() => _SpentAtFieldState();
}

class _SpentAtFieldState extends State<_SpentAtField> {
  /// Estado de tela, e por isso não está no controller: é só "este seletor
  /// está aparecendo", e não sobrevive a nada nem é lido por mais ninguém.
  bool _adjusting = false;

  @override
  Widget build(BuildContext context) => ReactiveFormConsumer(
    builder: (context, form, child) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DateFieldWidget(
          formControlName: ExpenseFormController.spentAt,
          label: widget.controller.spentAtLabel,
          helperText: widget.controller.spentAtHelper,
          // Obrigatório: limpar só deixaria o formulário inválido de propósito.
          clearable: false,
        ),
        // Em edição a competência nem é enviada — oferecer o ajuste ali seria
        // um campo que não muda nada.
        if (!widget.controller.isEditing)
          if (_adjusting) ...[
            const SizedBox(height: 16),
            MonthFieldWidget(
              formControlName: widget.controller.monthField,
              label: 'Competência',
              helperText: 'Trocar o dia da compra refaz esta conta',
            ),
          ] else
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => setState(() => _adjusting = true),
                child: const Text('Ajustar competência'),
              ),
            ),
      ],
    ),
  );
}

/// "10x de R$ 300,00" enquanto a pessoa digita — a conta que ela faria de
/// cabeça, feita na tela.
class _InstallmentPreview extends StatelessWidget {
  const _InstallmentPreview({this.style});

  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;

    return ReactiveValueListenableBuilder<int>(
      formControlName: ExpenseFormController.totalCents,
      builder: (context, totalControl, child) =>
          ReactiveValueListenableBuilder<int>(
            formControlName: ExpenseFormController.installmentsCount,
            builder: (context, countControl, child) {
              final total = totalControl.value;
              final count = countControl.value;

              if (total == null ||
                  count == null ||
                  count < 1 ||
                  total < count) {
                return const SizedBox.shrink();
              }

              // Divisão inteira, como o backend faz. A sobra vai um centavo em
              // cada uma das primeiras, então o texto fala em "a partir de".
              final each = total ~/ count;
              final remainder = total % count;

              return Text(
                remainder == 0
                    ? '${count}x de ${Money.format(each)}'
                    : '${count}x de ${Money.format(each)} — as $remainder '
                          'primeiras saem um centavo mais caras',
                style: style?.copyWith(color: color),
              );
            },
          ),
    );
  }
}

/// Abre o diálogo, cria a tag e a seleciona. O erro do backend — nome repetido
/// é 409 (TAG-01) — aparece em snackbar, e não como falha da tela: o formulário
/// continua utilizável, só a criação não foi.
Future<void> _createTag(
  BuildContext context,
  ExpenseFormController controller,
) async {
  // final novo = await showTagFormDialog(context);
  // if (novo == null) return;

  // final erro = await controller.createTag(name: novo.name, color: novo.color);
  // if (erro == null || !context.mounted) return;

  // ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(erro)));
}

/// O nome da tag com um ponto da cor dela na frente. Tag sem cor mostra só o
/// nome — um ponto cinza sugeriria que a cor é cinza.
class _TagChipLabel extends StatelessWidget {
  const _TagChipLabel({required this.tag});

  final TagModel tag;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: TagColor.parse(tag.color),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Flexible(child: Text(tag.name, overflow: TextOverflow.ellipsis)),
      ],
    );
  }
}
