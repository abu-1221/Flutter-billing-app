import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../domain/entities/product.dart';
import '../bloc/product_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/data/hive_database.dart';

class ImportProductsPage extends StatefulWidget {
  const ImportProductsPage({super.key});

  @override
  State<ImportProductsPage> createState() => _ImportProductsPageState();
}

class _ImportProductsPageState extends State<ImportProductsPage> {
  bool _isLoading = false;
  String? _fileName;
  String? _filePath;
  List<Product> _validProducts = [];
  List<Map<String, dynamic>> _invalidRecords = [];
  bool _hasParsed = false;

  final Map<String, List<String>> variations = {
    'Product Name': ['name', 'product_name', 'product', 'item_name'],
    'Barcode': ['barcode', 'bar_code', 'barcode_number', 'code'],
    'Price': ['price', 'selling_price', 'sale_price'],
    'Purchase Price': ['purchase_price', 'cost', 'cost_price'],
    'Stock': ['stock', 'quantity', 'qty'],
    'Category': ['category', 'product_category'],
    'Minimum Stock': ['minimum_stock', 'min_stock', 'minimum_quantity'],
  };

  int _getMappedIndex(List<String> normalizedHeaders, String fieldName) {
    final aliases = variations[fieldName]!;
    for (var alias in aliases) {
      final idx = normalizedHeaders.indexOf(alias);
      if (idx >= 0) return idx;
    }
    return -1;
  }

  void _pickFile() async {
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final path = file.path;
      if (path == null) return;

      setState(() {
        _fileName = file.name;
        _filePath = path;
        _validProducts = [];
        _invalidRecords = [];
        _hasParsed = false;
      });

      // Automatically validate immediately
      _validateImport();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error selecting file: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _validateImport() async {
    final path = _filePath;
    if (path == null) return;

    setState(() => _isLoading = true);

    try {
      final File systemFile = File(path);
      String csvString;
      try {
        csvString = await systemFile.readAsString(encoding: utf8);
      } catch (_) {
        csvString = await systemFile.readAsString(encoding: latin1);
      }

      if (csvString.startsWith('\uFEFF')) {
        csvString = csvString.substring(1);
      }

      String separator = ',';
      if (csvString.contains(';') && !csvString.contains(',')) {
        separator = ';';
      }

      final fields = CsvToListConverter(
        fieldDelimiter: separator,
        shouldParseNumbers: false,
      ).convert(csvString);

      if (fields.isEmpty) {
        throw Exception('The selected file is empty!');
      }

      _validateAndPreview(fields);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error parsing file: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _validateAndPreview(List<List<dynamic>> rows) {
    final cleanRows = rows.where((row) => row.isNotEmpty && row.any((cell) => cell != null && cell.toString().trim().isNotEmpty)).toList();
    if (cleanRows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('CSV structure does not match the template.'), backgroundColor: Colors.red),
      );
      return;
    }

    final firstRow = cleanRows.first.map((e) {
      if (e == null) return '';
      String s = e.toString().toLowerCase().trim();
      s = s.replaceAll('\uFEFF', '');
      s = s.replaceAll('_', ' ');
      s = s.replaceAll('\r', '');
      s = s.replaceAll('\n', '');
      return s.trim();
    }).toList();

    int nameIdx = _getMappedIndex(firstRow, 'Product Name');
    int barcodeIdx = _getMappedIndex(firstRow, 'Barcode');
    int priceIdx = _getMappedIndex(firstRow, 'Price');
    int purPriceIdx = _getMappedIndex(firstRow, 'Purchase Price');
    int stockIdx = _getMappedIndex(firstRow, 'Stock');
    int catIdx = _getMappedIndex(firstRow, 'Category');
    int minStockIdx = _getMappedIndex(firstRow, 'Minimum Stock');

    final Set<String> fileBarcodes = {};
    final dbProducts = context.read<ProductBloc>().state.products;

    for (int i = 1; i < cleanRows.length; i++) {
      final row = cleanRows[i];
      final int rowNum = i + 1;

      final String name = nameIdx >= 0 ? _getVal(row, nameIdx, '').trim() : '';
      final String barcode = barcodeIdx >= 0 ? _getVal(row, barcodeIdx, '').trim() : '';
      final String priceStr = priceIdx >= 0 ? _getVal(row, priceIdx, '').trim() : '';
      final String purPriceStr = purPriceIdx >= 0 ? _getVal(row, purPriceIdx, '').trim() : '';
      final String stockStr = stockIdx >= 0 ? _getVal(row, stockIdx, '').trim() : '';
      final String category = catIdx >= 0 ? _getVal(row, catIdx, '').trim() : '';
      final String minStockStr = minStockIdx >= 0 ? _getVal(row, minStockIdx, '').trim() : '';

      final List<String> missingFields = [];
      if (name.isEmpty) missingFields.add('Product Name');
      if (barcode.isEmpty) missingFields.add('Barcode');
      if (priceStr.isEmpty) missingFields.add('Price');
      if (purPriceStr.isEmpty) missingFields.add('Purchase Price');
      if (stockStr.isEmpty) missingFields.add('Stock');
      if (category.isEmpty) missingFields.add('Category');
      if (minStockStr.isEmpty) missingFields.add('Minimum Stock');

      Map<String, dynamic> recordBase = {
        'row': rowNum,
        'name': name.isEmpty ? 'N/A' : name,
        'barcode': barcode.isEmpty ? 'N/A' : barcode,
        'category': category.isEmpty ? 'N/A' : category,
        'price': priceStr.isEmpty ? '—' : priceStr,
        'purchasePrice': purPriceStr.isEmpty ? '—' : purPriceStr,
        'stock': stockStr.isEmpty ? '—' : stockStr,
        'minStock': minStockStr.isEmpty ? '—' : minStockStr,
        'missingFields': missingFields,
      };

      if (missingFields.isNotEmpty) {
        _invalidRecords.add({
          ...recordBase,
          'error': 'Missing ${missingFields.join(', ')}',
          'warning': '${missingFields.join(', ')} is missing.',
          'fix': 'Ensure all required fields are filled.'
        });
        continue;
      }

      final double? price = double.tryParse(priceStr);
      if (price == null || price < 0) {
        _invalidRecords.add({
          ...recordBase,
          'error': 'Invalid Price',
          'warning': 'Price must be a positive numeric value.',
          'fix': 'Enter a valid decimal number'
        });
        continue;
      }

      final double? purPrice = double.tryParse(purPriceStr);
      if (purPrice == null || purPrice < 0) {
        _invalidRecords.add({
          ...recordBase,
          'error': 'Invalid Purchase Price',
          'warning': 'Purchase Price must be a positive numeric value.',
          'fix': 'Enter a valid decimal number'
        });
        continue;
      }

      if (purPrice > price) {
        _invalidRecords.add({
          ...recordBase,
          'error': 'Cost exceeds Price',
          'warning': 'Cost ($purPrice) exceeds Selling Price ($price).',
          'fix': 'Ensure Cost is lower than Selling Price'
        });
        continue;
      }

      final int? stock = int.tryParse(stockStr);
      if (stock == null || stock < 0) {
        _invalidRecords.add({
          ...recordBase,
          'error': 'Invalid Stock',
          'warning': 'Stock must be a positive integer.',
          'fix': 'Enter a whole number'
        });
        continue;
      }

      final int? minStock = int.tryParse(minStockStr);
      if (minStock == null || minStock < 0) {
        _invalidRecords.add({
          ...recordBase,
          'error': 'Invalid Minimum Stock',
          'warning': 'Minimum Stock must be a positive integer.',
          'fix': 'Enter a whole number'
        });
        continue;
      }

      if (fileBarcodes.contains(barcode)) {
        _invalidRecords.add({
          ...recordBase,
          'error': 'Duplicate barcode inside CSV.',
          'warning': 'Duplicate barcode inside CSV.',
          'fix': 'Ensure barcode is unique across CSV'
        });
        continue;
      }

      if (dbProducts.any((p) => p.barcode == barcode)) {
        _invalidRecords.add({
          ...recordBase,
          'error': 'Barcode already exists:\n$barcode',
          'warning': 'Barcode already exists:\n$barcode',
          'fix': 'Use a unique barcode'
        });
        continue;
      }

      fileBarcodes.add(barcode);
      _validProducts.add(Product(
        id: const Uuid().v4(),
        name: name,
        barcode: barcode,
        price: price,
        purchasePrice: purPrice,
        stock: stock,
        category: category,
      ));

      HiveDatabase.settingsBox.put('temp_min_stock_$barcode', minStock);
    }

    setState(() {
      _hasParsed = true;
    });
  }

  String _getVal(List<dynamic> row, int index, String fallback) {
    if (index < 0 || index >= row.length) return fallback;
    return row[index]?.toString() ?? fallback;
  }

  void _confirmImport() async {
    if (_validProducts.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      context.read<ProductBloc>().add(BulkAddProducts(_validProducts));

      for (var product in _validProducts) {
        final savedMinStock = HiveDatabase.settingsBox.get('temp_min_stock_${product.barcode}', defaultValue: 5);
        HiveDatabase.settingsBox.put('min_stock_${product.id}', savedMinStock);
        HiveDatabase.settingsBox.delete('temp_min_stock_${product.barcode}');
      }

      // Store Import History
      final total = _validProducts.length + _invalidRecords.length;
      final historyEntry = {
        'id': const Uuid().v4(),
        'admin_id': 'admin',
        'file_name': _fileName ?? 'Unknown file',
        'total_products': total,
        'valid_products': _validProducts.length,
        'invalid_products': _invalidRecords.length,
        'imported_products': _validProducts.length,
        'failed_products': _invalidRecords.length,
        'created_at': DateTime.now().toIso8601String(),
      };
      await HiveDatabase.importHistoryBox.add(historyEntry);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_validProducts.length} Products Imported Successfully.\n${_invalidRecords.length} Products Failed Validation.'),
          backgroundColor: Colors.green,
        ),
      );

      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Import failed: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _downloadSampleFile() async {
    try {
      final List<List<dynamic>> sampleData = [
        ['name', 'barcode', 'price', 'purchase_price', 'stock', 'category', 'minimum_stock'],
        ['Rice 5Kg', '8901000000001', '320', '280', '50', 'Grocery', '5'],
        ['Oil 1L', '8901000000002', '180', '160', '30', 'Grocery', '5'],
        ['USB Cable', '8901000000003', '250', '180', '20', 'Electronics', '3'],
        ['Sprite 750ml', '8901000000004', '45', '30', '100', 'Beverages', '10']
      ];

      final directory = await getTemporaryDirectory();
      final String filePath = '${directory.path}/sample_inventory.csv';
      final File file = File(filePath);

      const converter = ListToCsvConverter();
      final String csvContent = converter.convert(sampleData);
      await file.writeAsString(csvContent);

      await Share.shareXFiles([XFile(filePath)], text: 'Download Sample Inventory Spreadsheet');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate template: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _exportErrorReport() async {
    if (_invalidRecords.isEmpty) return;

    try {
      final List<List<dynamic>> reportData = [
        ['Row Number', 'Error Description', 'Suggested Fix'],
      ];

      for (var record in _invalidRecords) {
        reportData.add([
          record['row'],
          record['error'],
          record['fix']
        ]);
      }

      final directory = await getTemporaryDirectory();
      final String filePath = '${directory.path}/import_error_report.csv';
      final File file = File(filePath);

      const converter = ListToCsvConverter();
      final String csvContent = converter.convert(reportData);
      await file.writeAsString(csvContent);

      await Share.shareXFiles([XFile(filePath)], text: 'Exported Bulk Import Errors');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to export error report: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bulk Import Products', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.chevron_left, size: 28, color: Theme.of(context).primaryColor),
          onPressed: () {
            if (_hasParsed) {
              setState(() {
                _hasParsed = false;
                _validProducts = [];
                _invalidRecords = [];
              });
            } else {
              context.pop();
            }
          },
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _hasParsed
              ? _buildFullPagePreview()
              : _buildUploadSection(),
    );
  }

  Widget _buildUploadSection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.file_present, color: AppTheme.primaryColor, size: 28),
                ),
                const SizedBox(height: 12),
                const Text('Upload Inventory Template', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text(
                  'Upload a CSV file. Columns must contain: Name, Barcode, Price, Purchase Price, Stock, Category, and Minimum Stock.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey, height: 1.4),
                ),
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: _downloadSampleFile,
                  icon: const Icon(Icons.download, size: 16),
                  label: const Text('Download Sample CSV Template', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 16),
                PrimaryButton(
                  onPressed: _pickFile,
                  icon: Icons.upload_file,
                  label: _fileName ?? 'Select CSV File',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFullPagePreview() {
    final totalProducts = _validProducts.length + _invalidRecords.length;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Summary Cards (Validation Summary Dashboard)
          Row(
            children: [
              Expanded(child: _buildSummaryCard('Total Products', '$totalProducts', Colors.blue)),
              const SizedBox(width: 8),
              Expanded(child: _buildSummaryCard('Valid Products', '${_validProducts.length}', Colors.green)),
              const SizedBox(width: 8),
              Expanded(child: _buildSummaryCard('Invalid Products', '${_invalidRecords.length}', Colors.red)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildSummaryCard('Ready To Import', '${_validProducts.length}', Colors.teal)),
              const SizedBox(width: 8),
              Expanded(child: _buildSummaryCard('Failed Products', '${_invalidRecords.length}', Colors.orange)),
            ],
          ),
          const SizedBox(height: 20),

          // 2. Ready To Import Table
          const Text('Ready To Import Table', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.teal)),
          const SizedBox(height: 8),
          _buildReadyTable(),
          const SizedBox(height: 20),

          // 3. Invalid Products Table
          const Text('Invalid Products Table', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.red)),
          const SizedBox(height: 8),
          _buildInvalidTable(),
          const SizedBox(height: 20),

          // 4. Warning Section
          if (_invalidRecords.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Warning Section', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.orange)),
                TextButton.icon(
                  onPressed: _exportErrorReport,
                  icon: const Icon(Icons.share, size: 16),
                  label: const Text('Export Error CSV', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildWarningsSection(),
            const SizedBox(height: 20),
          ],

          // 5. Import Products Button
          SizedBox(
            width: double.infinity,
            child: PrimaryButton(
              onPressed: _validProducts.isNotEmpty ? _confirmImport : null,
              icon: Icons.check_circle,
              label: 'Import Products',
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, Color color) {
    return Card(
      elevation: 0,
      color: color.withOpacity(0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withOpacity(0.15)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Text(title, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildReadyTable() {
    if (_validProducts.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: const Text(
          'No valid products to import',
          style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic, fontSize: 13),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(Colors.teal[50]),
          columns: const [
            DataColumn(label: Text('Product', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Barcode', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Price', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Stock', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Category', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
          rows: _validProducts.map<DataRow>((product) {
            return DataRow(cells: [
              DataCell(Text(product.name)),
              DataCell(Text(product.barcode)),
              DataCell(Text('₹${product.price.toStringAsFixed(2)}')),
              DataCell(Text('${product.stock}')),
              DataCell(Text(product.category)),
            ]);
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildInvalidTable() {
    if (_invalidRecords.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: const Text(
          'No failed products',
          style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic, fontSize: 13),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(Colors.red[50]),
          columns: const [
            DataColumn(label: Text('Row', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Product', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Error', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
          rows: _invalidRecords.map<DataRow>((record) {
            return DataRow(cells: [
              DataCell(Text('${record['row']}')),
              DataCell(Text(record['name'] == 'N/A' ? 'Unknown' : record['name'])),
              DataCell(Text(record['error']?.toString() ?? 'Validation failed', style: const TextStyle(color: Colors.red))),
            ]);
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildWarningsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _invalidRecords.map((record) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(
            'Row ${record['row']}:\n${record['warning'] ?? record['error']}\n',
            style: const TextStyle(fontSize: 13, color: Colors.orange, fontWeight: FontWeight.bold),
          ),
        );
      }).toList(),
    );
  }
}
