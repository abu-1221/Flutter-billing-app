import 'package:hive_flutter/hive_flutter.dart';
import '../../features/product/data/models/product_model.dart';
import '../../features/shop/data/models/shop_model.dart';

class HiveDatabase {
  static const String productBoxName = 'products';
  static const String shopBoxName = 'shop';
  static const String settingsBoxName = 'settings';
  static const String transactionsBoxName = 'transactions';

  static Future<void> init() async {
    await Hive.initFlutter();

    // Register Adapters
    Hive.registerAdapter(ProductModelAdapter());
    Hive.registerAdapter(ShopModelAdapter());

    // Open Boxes
    await Hive.openBox<ProductModel>(productBoxName);
    final shopBox = await Hive.openBox<ShopModel>(shopBoxName);
    await Hive.openBox(settingsBoxName); // Generic box for simple key-value
    await Hive.openBox(transactionsBoxName); // Store history

    // Clear legacy placeholder defaults to let new ones load
    final shop = shopBox.get('shop_details');
    if (shop != null && (shop.name == 'Abou' || shop.upiId.endsWith('@oksbi') || shop.name == 'Dinesh Shop')) {
      await shopBox.delete('shop_details');
    }
  }

  static Box<ProductModel> get productBox =>
      Hive.box<ProductModel>(productBoxName);
  static Box<ShopModel> get shopBox => Hive.box<ShopModel>(shopBoxName);
  static Box get settingsBox => Hive.box(settingsBoxName);
  static Box get transactionsBox => Hive.box(transactionsBoxName);
}
