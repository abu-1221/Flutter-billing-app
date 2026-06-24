import 'package:hive/hive.dart';

part 'sale_model.g.dart';

@HiveType(typeId: 3)
class SaleModel extends HiveObject {
  @HiveField(0)
  final String saleId;

  @HiveField(1)
  final String productId;

  @HiveField(2)
  final String barcode;

  @HiveField(3)
  final String transactionId;

  @HiveField(4)
  final DateTime soldAt;

  SaleModel({
    required this.saleId,
    required this.productId,
    required this.barcode,
    required this.transactionId,
    required this.soldAt,
  });
}
