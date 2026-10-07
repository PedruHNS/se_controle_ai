import '../../core/utils/iso_date_utils.dart';
import '../enums/expense_type.dart';
import '../enums/payment_method.dart';
import 'amount_version_model.dart';
import 'installment_model.dart';
import 'tag_model.dart';

class ExpenseModel {
  final String id;
  final String description;
  final TagModel tag;
  final String? notes;
  final ExpenseType type;
  final PaymentMethod paymentMethod;
  final String? creditCardId;
  final bool recurring;
  final String? spentAt;
  final String startMonth;
  final String? endMonth;
  final int? amountCents;
  final int? totalCents;
  final int? installmentsCount;
  final String? installmentLabel;
  final List<AmountVersionModel> history;
  final List<InstallmentModel> installments;

  const ExpenseModel({
    required this.id,
    required this.description,
    required this.tag,
    required this.notes,
    required this.type,
    required this.paymentMethod,
    required this.creditCardId,
    required this.recurring,
    required this.spentAt,
    required this.startMonth,
    required this.endMonth,
    required this.amountCents,
    required this.totalCents,
    required this.installmentsCount,
    required this.installmentLabel,
    required this.history,
    required this.installments,
  });

  factory ExpenseModel.fromJson(Map<String, dynamic> json) => ExpenseModel(
    id: json['id'] as String,
    description: json['description'] as String,
    tag: TagModel.fromJson(json['tag'] as Map<String, dynamic>),
    notes: json['notes'] as String?,
    type: ExpenseType.fromWire(json['type'] as String),
    paymentMethod: PaymentMethod.fromWire(json['paymentMethod'] as String),
    creditCardId: json['creditCardId'] as String?,
    recurring: json['recurring'] as bool,
    spentAt: IsoDateUtils.fromInstant(json['spentAt'] as String?),
    startMonth: json['startMonth'] as String,
    endMonth: json['endMonth'] as String?,
    amountCents: json['amountCents'] as int?,
    totalCents: json['totalCents'] as int?,
    installmentsCount: json['installmentsCount'] as int?,
    installmentLabel: json['installmentLabel'] as String?,
    history: (json['history'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>()
        .map(AmountVersionModel.fromJson)
        .toList(growable: false),
    installments: (json['installments'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>()
        .map(InstallmentModel.fromJson)
        .toList(growable: false),
  );

  @override
  String toString() =>
      'ExpenseModel(id: $id, description: $description, tag: $tag, '
      'notes: $notes, type: $type, paymentMethod: $paymentMethod, '
      'creditCardId: $creditCardId, recurring: $recurring, spentAt: $spentAt, '
      'startMonth: $startMonth, endMonth: $endMonth, '
      'amountCents: $amountCents, totalCents: $totalCents, '
      'installmentsCount: $installmentsCount, '
      'installmentLabel: $installmentLabel, history: $history, '
      'installments: $installments)';
}
