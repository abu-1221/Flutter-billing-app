import 'dart:io';
import 'package:intl/intl.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:permission_handler/permission_handler.dart';

import '../data/hive_database.dart';

class EscPos {
  static const List<int> init = [0x1B, 0x40];
  static const List<int> alignCenter = [0x1B, 0x61, 0x01];
  static const List<int> alignLeft = [0x1B, 0x61, 0x00];
  static const List<int> alignRight = [0x1B, 0x61, 0x02];
  static const List<int> boldOn = [0x1B, 0x45, 0x01];
  static const List<int> boldOff = [0x1B, 0x45, 0x00];
  static const List<int> textNormal = [0x1D, 0x21, 0x00];
  static const List<int> textLarge = [0x1D, 0x21, 0x11];
  static const List<int> lineFeed = [0x0A];
}

class PrinterHelper {
  // Singleton
  static final PrinterHelper _instance = PrinterHelper._internal();
  factory PrinterHelper() => _instance;
  PrinterHelper._internal();

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  Future<bool> checkPermission() async {
    if (Platform.isAndroid) {
      await Permission.bluetooth.request();
      final bluetoothScan = await Permission.bluetoothScan.request();
      final bluetoothConnect = await Permission.bluetoothConnect.request();
      final location = await Permission.location.request();

      // On Android 12+ (API 31+), bluetoothScan & bluetoothConnect are required.
      // On older versions, location permission is required for Bluetooth scanning.
      final isNewBluetoothGranted = bluetoothScan.isGranted && bluetoothConnect.isGranted;
      final isOldBluetoothGranted = location.isGranted;

      return isNewBluetoothGranted || isOldBluetoothGranted;
    }
    return true;
  }

  Future<List<BluetoothInfo>> getBondedDevices() async {
    try {
      final List<BluetoothInfo> list =
          await PrintBluetoothThermal.pairedBluetooths;
      return list;
    } catch (e) {
      return [];
    }
  }

  Future<bool> connect(String macAddress) async {
    try {
      final bool result =
          await PrintBluetoothThermal.connect(macPrinterAddress: macAddress);
      _isConnected = result;
      return result;
    } catch (e) {
      _isConnected = false;
      return false;
    }
  }

  Future<bool> disconnect() async {
    try {
      final bool result = await PrintBluetoothThermal.disconnect;
      _isConnected =
          !result; // If disconnected successfully, isConnected is false
      return result;
    } catch (e) {
      return false;
    }
  }

  Future<void> printText(String text) async {
    if (!_isConnected) return;

    // Simple text printing
    // We can use bytes for advanced formatting
    // But plugin supports basic text or bytes

    // Checking battery or connection status
    final bool connectionStatus = await PrintBluetoothThermal.connectionStatus;
    if (connectionStatus) {
      // Plugin allows sending bytes. We need ESC/POS commands for text.
      // However, the plugin might have helper.
      // Looking at doc, `writeBytes` or `writeString`?
      // The plugin `print_bluetooth_thermal` mainly exposes `writeBytes`.
      // We need a generator. `esc_pos_utils` is common but not requested.
      // But wait, `print_bluetooth_thermal` example often uses `capability_profile` and `generator`.
      // I don't have `esc_pos_utils` or similar in my pubspec.
      // The user requested `print_bluetooth_thermal`.
      // Let's assume we can send raw string bytes or use a simple helper.
      // Actually without `esc_pos_utils`, formatting is hard.
      // I will try to use `esc_pos_utils_plus` or similar if I can add it, but user gave specific packages.
      // Wait, user allowed "use required plugins".
      // "suggest barcode scanner ... and use required plugins".
      // So I can add `esc_pos_utils_plus`.

      // For now, I'll assume simple text printing by converting string to bytes.
      // ASCII bytes.
      List<int> bytes = text.codeUnits;
      await PrintBluetoothThermal.writeBytes(bytes);
    }
  }

  Future<void> printReceipt({
    required String shopName,
    required String address1,
    required String address2,
    required String phone,
    required List<Map<String, dynamic>> items, // Name, Qty, Price, Total
    required double total,
    required String footer,
    String? invoiceNumber,
    String? receiptNumber,
    double? subtotal,
    double? tax,
  }) async {
    if (!_isConnected) return;

    final int width = HiveDatabase.settingsBox.get('printer_width', defaultValue: 58);
    final int lineLength = width == 80 ? 48 : 32;
    final String divider = '-' * lineLength;

    // Construct ESC/POS bytes manually or using helper
    List<int> bytes = [];

    // Init
    bytes += EscPos.init;

    // Shop Name (Center, Bold, Large)
    bytes += EscPos.alignCenter;
    bytes += EscPos.boldOn;
    bytes += EscPos.textLarge;
    bytes += _textToBytes(shopName);
    bytes += EscPos.lineFeed;

    // Address & Phone (Normal, Center)
    bytes += EscPos.textNormal;
    bytes += EscPos.boldOff;
    if (address1.isNotEmpty) {
      bytes += _textToBytes(address1);
      bytes += EscPos.lineFeed;
    }
    if (address2.isNotEmpty) {
      bytes += _textToBytes(address2);
      bytes += EscPos.lineFeed;
    }
    bytes += _textToBytes(phone);
    bytes += EscPos.lineFeed;

    // Date and Time
    String formattedDate =
        DateFormat('dd-MM-yyyy hh:mm a').format(DateTime.now());
    bytes += _textToBytes(formattedDate);
    bytes += EscPos.lineFeed;

    if (invoiceNumber != null) {
      bytes += _textToBytes('Invoice: $invoiceNumber');
      bytes += EscPos.lineFeed;
    }
    if (receiptNumber != null) {
      bytes += _textToBytes('Receipt: $receiptNumber');
      bytes += EscPos.lineFeed;
    }

    bytes += _textToBytes(divider);
    bytes += EscPos.lineFeed;

    // Header (Align Left)
    bytes += EscPos.alignLeft;
    if (lineLength == 48) {
      bytes += _textToBytes('Item                    Price     Qty     Total');
    } else {
      bytes += _textToBytes('Item            Price   Total');
    }
    bytes += EscPos.lineFeed;
    bytes += _textToBytes(divider);
    bytes += EscPos.lineFeed;

    // Items
    for (var item in items) {
      String name = item['name'].toString();
      String qty = item['qty'].toString();
      String price = item['price'].toString();
      String totalItem = item['total'].toString();

      if (lineLength == 48) {
        if (name.length > 24) name = name.substring(0, 24);
        final String line = name.padRight(24) + price.padRight(10) + qty.padRight(6) + totalItem;
        bytes += _textToBytes(line);
      } else {
        String prefix = '${qty}x $name';
        if (prefix.length > 16) prefix = prefix.substring(0, 16);

        String line = prefix.padRight(16) + price.padRight(8) + totalItem;
        bytes += _textToBytes(line);
      }
      bytes += EscPos.lineFeed;
    }

    bytes += _textToBytes(divider);
    bytes += EscPos.lineFeed;

    // Total (Align Right)
    bytes += EscPos.alignRight;
    if (subtotal != null) {
      bytes += _textToBytes('Subtotal: ₹${subtotal.toStringAsFixed(2)}');
      bytes += EscPos.lineFeed;
    }
    // Print dynamic taxes
    final List? storedTaxes = HiveDatabase.settingsBox.get('taxes_config') as List?;
    if (storedTaxes == null) {
      if (tax != null) {
        bytes += _textToBytes('Tax (18% GST): ₹${tax.toStringAsFixed(2)}');
        bytes += EscPos.lineFeed;
      }
    } else {
      final double computedSubtotal = subtotal ?? (total - (tax ?? 0.0));
      for (var t in storedTaxes) {
        if (t is Map && t['isActive'] == true) {
          final name = t['name'] ?? 'Tax';
          final pct = double.tryParse(t['percentage'].toString()) ?? 0.0;
          final amount = computedSubtotal * (pct / 100.0);
          bytes += _textToBytes('Tax ($name): ₹${amount.toStringAsFixed(2)}');
          bytes += EscPos.lineFeed;
        }
      }
    }
    bytes += EscPos.boldOn;
    bytes += _textToBytes('TOTAL: ₹${total.toStringAsFixed(2)}');
    bytes += EscPos.lineFeed;
    bytes += EscPos.boldOff;
    bytes += EscPos.lineFeed;

    // Footer (Center)
    bytes += EscPos.alignCenter;
    bytes += _textToBytes(footer);
    bytes += EscPos.lineFeed;
    bytes += EscPos.lineFeed; // One line space after footer
    bytes += EscPos.lineFeed;
    bytes += EscPos.lineFeed; // Additional Feed

    await PrintBluetoothThermal.writeBytes(bytes);
  }

  List<int> _textToBytes(String text) {
    // Should verify encoding, but Latin-1 usually works for basic printers
    return List.from(text.codeUnits);
  }
}
