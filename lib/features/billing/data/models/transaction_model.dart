import 'package:hive/hive.dart';

part 'transaction_model.g.dart';

@HiveType(typeId: 2)
class TransactionModel extends HiveObject {
  @HiveField(0)
  final String transactionId;

  @HiveField(1)
  final String productId;

  @HiveField(2)
  final String paymentStatus; // e.g. 'Success', 'Pending'

  @HiveField(3)
  final String purchasedBy; // e.g. user name or customer ID

  @HiveField(4)
  final DateTime purchasedAt;

  TransactionModel({
    required this.transactionId,
    required this.productId,
    required this.paymentStatus,
    required this.purchasedBy,
    required this.purchasedAt,
  });
}
