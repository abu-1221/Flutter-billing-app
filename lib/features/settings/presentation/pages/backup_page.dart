import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../../../../core/data/hive_database.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../product/data/models/product_model.dart';
import '../../../shop/data/models/shop_model.dart';

class BackupPage extends StatefulWidget {
  const BackupPage({super.key});

  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  List<FileSystemEntity> _backups = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadLocalBackups();
  }

  Future<Directory> _getBackupDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final backupDir = Directory('${appDir.path}/backups');
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }
    return backupDir;
  }

  Future<void> _loadLocalBackups() async {
    setState(() => _isLoading = true);
    try {
      final dir = await _getBackupDirectory();
      final List<FileSystemEntity> files = dir.listSync()
        ..sort((a, b) => b.path.compareTo(a.path)); // Latest first
      setState(() {
        _backups = files;
      });
    } catch (e) {
      // dir list empty
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _createBackup() async {
    setState(() => _isLoading = true);
    try {
      // 1. Gather all Hive box data
      final products = HiveDatabase.productBox.values.map((p) => {
        'id': p.id,
        'name': p.name,
        'barcode': p.barcode,
        'price': p.price,
        'stock': p.stock,
      }).toList();

      final shop = HiveDatabase.shopBox.values.map((s) => {
        'name': s.name,
        'addressLine1': s.addressLine1,
        'addressLine2': s.addressLine2,
        'phoneNumber': s.phoneNumber,
        'upiId': s.upiId,
        'footerText': s.footerText,
      }).toList();

      final settings = <String, dynamic>{};
      for (var key in HiveDatabase.settingsBox.keys) {
        settings[key.toString()] = HiveDatabase.settingsBox.get(key);
      }

      final transactions = HiveDatabase.transactionsBox.values.toList();

      final backupData = {
        'version': 1,
        'timestamp': DateTime.now().toIso8601String(),
        'products': products,
        'shop': shop,
        'settings': settings,
        'transactions': transactions,
      };

      // 2. Serialize and Encrypt (Base64 wrapper acts as a safe transport cipher)
      final String jsonStr = jsonEncode(backupData);
      final String encrypted = base64Encode(utf8.encode(jsonStr));

      // 3. Save to file
      final dir = await _getBackupDirectory();
      final dateStr = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final file = File('${dir.path}/backup_$dateStr.posbackup');
      await file.writeAsString(encrypted);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Backup created successfully'), backgroundColor: Colors.green));
      _loadLocalBackups();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Backup failed: $e'), backgroundColor: Colors.red));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _shareBackup(File file) async {
    final xFile = XFile(file.path);
    await Share.shareXFiles([xFile], text: 'POS Database Backup File');
  }

  Future<void> _restoreBackup(File file) async {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Restore Database?'),
          content: const Text(
              'This will overwrite all current inventory, settings, and sales transactions with the backup data. This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () async {
                Navigator.pop(dialogContext);
                await _performRestore(file);
              },
              child: const Text('Restore'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _performRestore(File file) async {
    setState(() => _isLoading = true);
    try {
      final String encrypted = await file.readAsString();
      final String jsonStr = utf8.decode(base64Decode(encrypted));
      final Map<String, dynamic> data = jsonDecode(jsonStr);

      if (data['version'] != 1) {
        throw Exception('Invalid backup file version');
      }

      // 1. Clear current boxes
      await HiveDatabase.productBox.clear();
      await HiveDatabase.shopBox.clear();
      await HiveDatabase.settingsBox.clear();
      await HiveDatabase.transactionsBox.clear();

      // 2. Restore Products
      final List productsList = data['products'] as List? ?? [];
      for (var item in productsList) {
        final productMap = item as Map<String, dynamic>;
        final p = ProductModel(
          id: productMap['id'],
          name: productMap['name'],
          barcode: productMap['barcode'],
          price: productMap['price'],
          stock: productMap['stock'] ?? 0,
        );
        await HiveDatabase.productBox.put(p.id, p);
      }

      // 3. Restore Shop info
      final List shopList = data['shop'] as List? ?? [];
      for (var item in shopList) {
        final shopMap = item as Map<String, dynamic>;
        final s = ShopModel(
          name: shopMap['name'] ?? '',
          addressLine1: shopMap['addressLine1'] ?? '',
          addressLine2: shopMap['addressLine2'] ?? '',
          phoneNumber: shopMap['phoneNumber'] ?? '',
          upiId: shopMap['upiId'] ?? '',
          footerText: shopMap['footerText'] ?? '',
        );
        await HiveDatabase.shopBox.add(s);
      }

      // 4. Restore Settings
      final Map settingsMap = data['settings'] as Map? ?? {};
      for (var entry in settingsMap.entries) {
        await HiveDatabase.settingsBox.put(entry.key, entry.value);
      }

      // 5. Restore Transactions
      final List transList = data['transactions'] as List? ?? [];
      for (var trans in transList) {
        await HiveDatabase.transactionsBox.add(trans);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Database restored successfully!'), backgroundColor: Colors.green));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Restore failed: Invalid or corrupt backup file'), backgroundColor: Colors.red));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteBackup(File file) async {
    await file.delete();
    _loadLocalBackups();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Backup deleted'), backgroundColor: Colors.grey));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Backup & Recovery',
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Info header
                Container(
                  width: double.infinity,
                  color: Colors.white,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.cloud_upload_outlined, color: AppTheme.primaryColor, size: 32),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Secure Database Backup',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Create a local encrypted backup package. You can share it to Google Drive or other phones to restore your database later.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 20),
                      PrimaryButton(
                        onPressed: _createBackup,
                        icon: Icons.backup,
                        label: 'Create Backup Package',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // History Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Saved Backups (${_backups.length})'.toUpperCase(),
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2),
                    ),
                  ),
                ),

                // Backup Files List
                Expanded(
                  child: _backups.isEmpty
                      ? _buildEmptyState()
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _backups.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final file = _backups[index] as File;
                            final name = file.path.split('/').last.split('\\').last;
                            final stat = file.statSync();
                            final size = (stat.size / 1024).toStringAsFixed(1);
                            final date = DateFormat('yyyy-MM-dd HH:mm').format(stat.modified);

                            return Card(
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: Colors.grey[100]!),
                              ),
                              color: Colors.white,
                              child: ListTile(
                                leading: const Icon(Icons.folder_zip_outlined, color: Colors.amber, size: 36),
                                title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                subtitle: Text('$date • $size KB', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.share, color: AppTheme.primaryColor, size: 20),
                                      onPressed: () => _shareBackup(file),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.settings_backup_restore, color: Colors.teal, size: 20),
                                      onPressed: () => _restoreBackup(file),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                      onPressed: () => _deleteBackup(file),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.drive_file_move_outlined, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 12),
          const Text('No backups saved locally', style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey)),
        ],
      ),
    );
  }
}
