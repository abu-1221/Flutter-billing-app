import 'package:hive/hive.dart';
import '../../domain/entities/product.dart';

part 'product_model.g.dart'; // Hive generator

@HiveType(typeId: 0)
class ProductModel extends Product {
  @override
  @HiveField(0)
  final String id;
  @override
  @HiveField(1)
  final String name;
  @override
  @HiveField(2)
  final String barcode;
  @override
  @HiveField(3)
  final double price;
  @override
  @HiveField(4)
  final int stock;
  @override
  @HiveField(5)
  final String category;
  @override
  @HiveField(6)
  final double purchasePrice;
  @override
  @HiveField(7)
  final String status;
  @override
  @HiveField(8)
  final DateTime? soldAt;
  @override
  @HiveField(9)
  final String? transactionId;

  const ProductModel({
    required this.id,
    required this.name,
    required this.barcode,
    required this.price,
    required this.stock,
    this.category = 'General',
    this.purchasePrice = 0.0,
    this.status = 'Available',
    this.soldAt,
    this.transactionId,
  }) : super(
          id: id,
          name: name,
          barcode: barcode,
          price: price,
          stock: stock,
          category: category,
          purchasePrice: purchasePrice,
          status: status,
          soldAt: soldAt,
          transactionId: transactionId,
        );

  factory ProductModel.fromEntity(Product product) {
    return ProductModel(
      id: product.id,
      name: product.name,
      barcode: product.barcode,
      price: product.price,
      stock: product.stock,
      category: product.category,
      purchasePrice: product.purchasePrice,
      status: product.status,
      soldAt: product.soldAt,
      transactionId: product.transactionId,
    );
  }

  Product toEntity() {
    return Product(
      id: id,
      name: name,
      barcode: barcode,
      price: price,
      stock: stock,
      category: category,
      purchasePrice: purchasePrice,
      status: status,
      soldAt: soldAt,
      transactionId: transactionId,
    );
  }
}
