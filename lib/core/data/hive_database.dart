import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../features/product/data/models/product_model.dart';
import '../../features/shop/data/models/shop_model.dart';
import '../../features/billing/data/models/transaction_model.dart';
import '../../features/billing/data/models/sale_model.dart';

class HiveDatabase {
  static const String managerAccessBoxName = 'manager_access';
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
    await Hive.openBox(
        managerAccessBoxName); // Separate from exported/restored billing settings
    await Hive.openBox(settingsBoxName); // Generic box for simple key-value
    await Hive.openBox(transactionsBoxName); // Store history
    await Hive.openBox<TransactionModel>(transactionsTableBoxName);
    await Hive.openBox<SaleModel>(salesTableBoxName);
    await Hive.openBox(importHistoryBoxName);

    // Clear legacy placeholder defaults to let new ones load
    try {
      final shop = shopBox.get('shop_details');
      if (shop != null &&
          (shop.name == 'Abou' ||
              shop.upiId.endsWith('@oksbi') ||
              shop.name == 'Dinesh Shop')) {
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

/// Local, per-install manager access. Not an online identity or a defense against
/// someone who controls the device and can replace the app or read its data.
class ManagerAccess extends ChangeNotifier {
  ManagerAccess(this._box);

  static const boxName = 'manager_access';
  static const _iterations = 120000;
  static const _saltKey = 'salt';
  static const _hashKey = 'hash';
  static const _failuresKey = 'failures';
  static const _retryAtKey = 'retry_at';

  final Box _box;
  bool _unlocked = false;

  bool get isConfigured =>
      _box.get(_hashKey) is String && _box.get(_saltKey) is String;
  bool get isUnlocked => _unlocked;

  int get retrySeconds {
    final until = _box.get(_retryAtKey, defaultValue: 0) as int;
    final remaining = until - DateTime.now().millisecondsSinceEpoch;
    return remaining > 0 ? (remaining / 1000).ceil() : 0;
  }

  static bool validPasscode(String value) =>
      value.length >= 10 && value.length <= 128;

  Future<void> configure(String passcode) async {
    if (isConfigured) throw StateError('Manager passcode is already set');
    if (!validPasscode(passcode)) {
      throw ArgumentError('Use at least 10 characters');
    }
    final random = Random.secure();
    final salt = List<int>.generate(16, (_) => random.nextInt(256));
    final digest = await compute(_derive, _Input(passcode, salt));
    await _box
        .putAll({_saltKey: base64Encode(salt), _hashKey: base64Encode(digest)});
    _unlocked = true;
    notifyListeners();
  }

  Future<bool> unlock(String passcode) async {
    if (!isConfigured || retrySeconds > 0) return false;
    final salt = base64Decode(_box.get(_saltKey) as String);
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../features/product/data/models/product_model.dart';
import '../../features/shop/data/models/shop_model.dart';
import '../../features/billing/data/models/transaction_model.dart';
import '../../features/billing/data/models/sale_model.dart';

class HiveDatabase {
  static const String managerAccessBoxName = 'manager_access';
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
    await Hive.openBox(
        managerAccessBoxName); // Separate from exported/restored billing settings
    await Hive.openBox(settingsBoxName); // Generic box for simple key-value
    await Hive.openBox(transactionsBoxName); // Store history
    await Hive.openBox<TransactionModel>(transactionsTableBoxName);
    await Hive.openBox<SaleModel>(salesTableBoxName);
    await Hive.openBox(importHistoryBoxName);

    // Clear legacy placeholder defaults to let new ones load
    try {
      final shop = shopBox.get('shop_details');
      if (shop != null &&
          (shop.name == 'Abou' ||
              shop.upiId.endsWith('@oksbi') ||
              shop.name == 'Dinesh Shop')) {
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

/// Local, per-install manager access. Not an online identity or a defense against
/// someone who controls the device and can replace the app or read its data.
class ManagerAccess extends ChangeNotifier {
  ManagerAccess(this._box);

  static const boxName = 'manager_access';
  static const _iterations = 120000;
  static const _saltKey = 'salt';
  static const _hashKey = 'hash';
  static const _failuresKey = 'failures';
  static const _retryAtKey = 'retry_at';

  final Box _box;
  bool _unlocked = false;

  bool get isConfigured =>
      _box.get(_hashKey) is String && _box.get(_saltKey) is String;
  bool get isUnlocked => _unlocked;

  int get retrySeconds {
    final until = _box.get(_retryAtKey, defaultValue: 0) as int;
    final remaining = until - DateTime.now().millisecondsSinceEpoch;
    return remaining > 0 ? (remaining / 1000).ceil() : 0;
  }

  static bool validPasscode(String value) =>
      value.length >= 10 && value.length <= 128;

  Future<void> configure(String passcode) async {
    if (isConfigured) throw StateError('Manager passcode is already set');
    if (!validPasscode(passcode)) {
      throw ArgumentError('Use at least 10 characters');
    }
    final random = Random.secure();
    final salt = List<int>.generate(16, (_) => random.nextInt(256));
    final digest = await compute(_derive, _Input(passcode, salt));
    await _box
        .putAll({_saltKey: base64Encode(salt), _hashKey: base64Encode(digest)});
    _unlocked = true;
    notifyListeners();
  }

  Future<bool> unlock(String passcode) async {
    if (!isConfigured || retrySeconds > 0) return false;
    final salt = base64Decode(_box.get(_saltKey) as String);
    final expected = base64Decode(_box.get(_hashKey) as String);
    final actual = await compute(_derive, _Input(passcode, salt));
    var difference = actual.length ^ expected.length;
    for (var i = 0; i < actual.length && i < expected.length; i++) {
      difference |= actual[i] ^ expected[i];
    }
    if (difference == 0) {
      await _box.deleteAll([_failuresKey, _retryAtKey]);
      _unlocked = true;
      notifyListeners();
      return true;
    }
    final failures = (_box.get(_failuresKey, defaultValue: 0) as int) + 1;
    await _box.put(_failuresKey, failures);
    if (failures >= 5) {
      // Rate-limit repeated guesses; do not erase the manager credential or billing data.
      await _box.put(
          _retryAtKey,
          DateTime.now()
              .add(const Duration(minutes: 5))
              .millisecondsSinceEpoch);
      await _box.put(_failuresKey, 0);
    }
    return false;
  }

  void lock() {
    _unlocked = false;
    notifyListeners();
  }
}

class _Input {
  const _Input(this.passcode, this.salt);
  final String passcode;
  final List<int> salt;
}

Uint8List _derive(_Input input) {
  // PBKDF2-HMAC-SHA256, one 32-byte block, with a unique random salt.
  final hmac = Hmac(sha256, utf8.encode(input.passcode));
  var previous = hmac.convert([...input.salt, 0, 0, 0, 1]).bytes;
  final result = Uint8List.fromList(previous);
  for (var i = 1; i < ManagerAccess._iterations; i++) {
    previous = hmac.convert(previous).bytes;
    for (var j = 0; j < result.length; j++) {
      result[j] ^= previous[j];
    }
  }
  return result;
}
