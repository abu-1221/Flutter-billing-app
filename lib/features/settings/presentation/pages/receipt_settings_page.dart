import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/data/hive_database.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/primary_button.dart';

import '../../../../core/utils/printer_helper.dart';

class ReceiptSettingsPage extends StatefulWidget {
  const ReceiptSettingsPage({super.key});

  @override
  State<ReceiptSettingsPage> createState() => _ReceiptSettingsPageState();
}

class _ReceiptSettingsPageState extends State<ReceiptSettingsPage> {
  late int _selectedWidth;
  String? _logoPath;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _selectedWidth = HiveDatabase.settingsBox.get('printer_width', defaultValue: 58);
    _logoPath = HiveDatabase.settingsBox.get('store_logo_path');
  }

  Future<void> _pickLogo() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          _logoPath = image.path;
        });
        await HiveDatabase.settingsBox.put('store_logo_path', image.path);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Logo updated successfully'), backgroundColor: Colors.green));
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to pick logo: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _clearLogo() async {
    setState(() {
      _logoPath = null;
    });
    await HiveDatabase.settingsBox.delete('store_logo_path');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Logo removed'), backgroundColor: Colors.grey));
    }
  }

  Future<void> _saveWidth(int width) async {
    setState(() {
      _selectedWidth = width;
    });
    await HiveDatabase.settingsBox.put('printer_width', width);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Printer size configured to $width mm'), backgroundColor: Colors.green));
    }
  }

  Future<void> _runTestPrint() async {
    final printerHelper = PrinterHelper();
    if (!printerHelper.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Printer not connected! Please connect in Settings.'), backgroundColor: Colors.red));
      return;
    }

    try {
      final mockItems = [
        {'name': 'Test Item 1', 'qty': 1, 'price': 99.0, 'total': 99.0},
        {'name': 'Test Item 2', 'qty': 2, 'price': 49.5, 'total': 99.0},
      ];

      await printerHelper.printReceipt(
        shopName: 'Test Store',
        address1: '123 Test Street',
        address2: 'Test City, USA',
        phone: '1234567890',
        items: mockItems,
        total: 198.0,
        footer: 'THANK YOU FOR TESTING!',
        invoiceNumber: 'INV-TEST-001',
        receiptNumber: 'RCPT-TEST-001',
        subtotal: 167.8,
        tax: 30.2,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Test print completed'), backgroundColor: Colors.green));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Test print failed: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    const borderColor = Color(0xFFE5E5EA);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Receipt & Printer Customization',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.chevron_left,
              size: 28, color: Theme.of(context).primaryColor),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Logo Upload Section
            const Text('Store Logo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                children: [
                  if (_logoPath != null) ...[
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          File(_logoPath!),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.broken_image, size: 48, color: Colors.grey),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white),
                          onPressed: _pickLogo,
                          icon: const Icon(Icons.edit, size: 16),
                          label: const Text('Change Logo'),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                          onPressed: _clearLogo,
                          icon: const Icon(Icons.delete_outline, size: 16),
                          label: const Text('Remove'),
                        ),
                      ],
                    ),
                  ] else ...[
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[200]!, style: BorderStyle.solid),
                      ),
                      alignment: Alignment.center,
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.storefront, size: 48, color: Colors.grey),
                          SizedBox(height: 8),
                          Text('No Logo Configured', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white),
                      onPressed: _pickLogo,
                      icon: const Icon(Icons.upload, size: 16),
                      label: const Text('Upload Logo'),
                    ),
                  ]
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Printer Width Section
            const Text('Receipt Layout Format', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                children: [
                  RadioListTile<int>(
                    title: const Text('58mm Thermal Receipt Width', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: const Text('Standard portable hand-held printer format (32 characters/line).', style: TextStyle(fontSize: 11)),
                    value: 58,
                    groupValue: _selectedWidth,
                    activeColor: AppTheme.primaryColor,
                    onChanged: (val) {
                      if (val != null) _saveWidth(val);
                    },
                  ),
                  const Divider(),
                  RadioListTile<int>(
                    title: const Text('80mm Thermal Receipt Width', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: const Text('Countertop desktop POS printer format (48 characters/line).', style: TextStyle(fontSize: 11)),
                    value: 80,
                    groupValue: _selectedWidth,
                    activeColor: AppTheme.primaryColor,
                    onChanged: (val) {
                      if (val != null) _saveWidth(val);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            PrimaryButton(
              onPressed: _runTestPrint,
              icon: Icons.print,
              label: 'Print Test Receipt',
            ),
          ],
        ),
      ),
    );
  }
}
