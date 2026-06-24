import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../features/product/data/models/product_model.dart';
import '../../features/shop/data/models/shop_model.dart';
import '../../features/billing/data/models/transaction_model.dart';
import '../../features/billing/data/models/sale_model.dart';

class HiveDatabase {
  static const String productBoxName = 'products';
  static const String shopBoxName = 'shop';
  static const String settingsBoxName = 'settings';
  static const String transactionsBoxName = 'transactions';
  static const String transactionsTableBoxName = 'transactions_table';
  static const String salesTableBoxName = 'sales_table';
  static const String importHistoryBoxName = 'import_history';

  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;

    await Hive.initFlutter();

    // Register Adapters safely — skip if already registered
    _safeRegisterAdapter(ProductModelAdapter());
    _safeRegisterAdapter(ShopModelAdapter());
    _safeRegisterAdapter(TransactionModelAdapter());
    _safeRegisterAdapter(SaleModelAdapter());

    // Open Boxes
    await Hive.openBox<ProductModel>(productBoxName);
    final shopBox = await Hive.openBox<ShopModel>(shopBoxName);
    await Hive.openBox(settingsBoxName); // Generic box for simple key-value
    await Hive.openBox(transactionsBoxName); // Store history
    await Hive.openBox<TransactionModel>(transactionsTableBoxName);
    await Hive.openBox<SaleModel>(salesTableBoxName);
    await Hive.openBox(importHistoryBoxName);

    // Clear legacy placeholder defaults to let new ones load
    try {
      final shop = shopBox.get('shop_details');
      if (shop != null && (shop.name == 'Abou' || shop.upiId.endsWith('@oksbi') || shop.name == 'Dinesh Shop')) {
        await shopBox.delete('shop_details');
      }
    } catch (e) {
      debugPrint("Shop cleanup warning: $e");
    }

    _initialized = true;
  }

  /// Safely register an adapter — catches the error if it's already registered.
  static void _safeRegisterAdapter<T>(TypeAdapter<T> adapter) {
    try {
      Hive.registerAdapter(adapter);
    } catch (e) {
      debugPrint("Adapter already registered: ${adapter.runtimeType}");
    }
  }

  static Box<ProductModel> get productBox =>
      Hive.box<ProductModel>(productBoxName);
  static Box<ShopModel> get shopBox => Hive.box<ShopModel>(shopBoxName);
  static Box get settingsBox => Hive.box(settingsBoxName);
  static Box get transactionsBox => Hive.box(transactionsBoxName);
  static Box<TransactionModel> get transactionsTableBox =>
      Hive.box<TransactionModel>(transactionsTableBoxName);
  static Box<SaleModel> get salesTableBox =>
      Hive.box<SaleModel>(salesTableBoxName);
  static Box get importHistoryBox => Hive.box(importHistoryBoxName);
}
