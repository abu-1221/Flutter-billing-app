import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart' hide Border;
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

class _ImportProductsPageState extends State<ImportProductsPage> with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  String? _fileName;
  List<Product> _validProducts = [];
  List<Map<String, dynamic>> _invalidRecords = []; // Row number, product info, error message, suggested fix, invalid value
  bool _hasParsed = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _pickAndParseFile() async {
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'xlsx'],
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final path = file.path;
      if (path == null) return;

      setState(() {
        _isLoading = true;
        _fileName = file.name;
        _validProducts = [];
        _invalidRecords = [];
        _hasParsed = false;
      });

      final File systemFile = File(path);
      final String extension = file.extension?.toLowerCase() ?? '';

      List<List<dynamic>> rows = [];

      if (extension == 'csv') {
        final input = systemFile.openRead();
        final fields = await input
            .transform(utf8.decoder)
            .transform(const CsvToListConverter())
            .toList();
        rows = fields;
      } else if (extension == 'xlsx') {
        final bytes = systemFile.readAsBytesSync();
        final excel = Excel.decodeBytes(bytes);
        for (var table in excel.tables.keys) {
          final sheet = excel.tables[table];
          if (sheet != null) {
            for (var row in sheet.rows) {
              final listRow = row.map((cell) => cell?.value).toList();
              rows.add(listRow);
            }
          }
          break; // Parse first sheet only
        }
      }

      _validateAndPreview(rows);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error reading file: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _validateAndPreview(List<List<dynamic>> rows) {
    if (rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The selected file is empty!'), backgroundColor: Colors.red),
      );
      return;
    }

    int nameIdx = 0;
    int barcodeIdx = 1;
    int priceIdx = 2;
    int purPriceIdx = 3;
    int stockIdx = 4;
    int catIdx = 5;
    int minStockIdx = -1;

    final firstRow = rows.first.map((e) => e?.toString().toLowerCase().replaceAll('_', ' ').trim() ?? '').toList();
    bool hasHeader = firstRow.contains('name') || firstRow.contains('product name') || firstRow.contains('barcode');
    int startRow = 0;

    if (hasHeader) {
      startRow = 1;
      nameIdx = firstRow.indexOf('name') >= 0 
          ? firstRow.indexOf('name') 
          : (firstRow.indexOf('product name') >= 0 ? firstRow.indexOf('product name') : 0);
      barcodeIdx = firstRow.indexOf('barcode') >= 0 ? firstRow.indexOf('barcode') : 1;
      priceIdx = firstRow.indexOf('price') >= 0 
          ? firstRow.indexOf('price') 
          : (firstRow.indexOf('selling price') >= 0 ? firstRow.indexOf('selling price') : 2);
      purPriceIdx = firstRow.indexOf('purchase price') >= 0 ? firstRow.indexOf('purchase price') : 3;
      stockIdx = firstRow.indexOf('stock') >= 0 
          ? firstRow.indexOf('stock') 
          : (firstRow.indexOf('current stock') >= 0 ? firstRow.indexOf('current stock') : 4);
      catIdx = firstRow.indexOf('category') >= 0 ? firstRow.indexOf('category') : 5;
      minStockIdx = firstRow.indexOf('minimum stock') >= 0 ? firstRow.indexOf('minimum stock') : firstRow.indexOf('min stock');
    }

    final Set<String> fileBarcodes = {};
    final dbProducts = context.read<ProductBloc>().state.products;

    for (int i = startRow; i < rows.length; i++) {
      final row = rows[i];
      if (row.isEmpty || row.every((element) => element == null || element.toString().trim().isEmpty)) continue;
      final int rowNum = i + 1;

      final String name = _getVal(row, nameIdx, '').trim();
      final String barcode = _getVal(row, barcodeIdx, '').trim();
      final String priceStr = _getVal(row, priceIdx, '').trim();
      final String purPriceStr = _getVal(row, purPriceIdx, '').trim();
      final String stockStr = _getVal(row, stockIdx, '').trim();
      final String category = _getVal(row, catIdx, '').trim();
      final String minStockStr = minStockIdx >= 0 ? _getVal(row, minStockIdx, '5').trim() : '5';

      // Validation Checks row by row
      if (name.isEmpty) {
        _invalidRecords.add({
          'row': rowNum,
          'name': 'N/A',
          'barcode': barcode.isEmpty ? 'N/A' : barcode,
          'field': 'Product Name',
          'value': '',
          'error': 'Product Name cannot be empty',
          'fix': 'Enter a valid product name description'
        });
        continue;
      }

      if (barcode.isEmpty) {
        _invalidRecords.add({
          'row': rowNum,
          'name': name,
          'barcode': 'N/A',
          'field': 'Barcode',
          'value': '',
          'error': 'Barcode required',
          'fix': 'Enter a unique scanner barcode number'
        });
        continue;
      }

      if (category.isEmpty) {
        _invalidRecords.add({
          'row': rowNum,
          'name': name,
          'barcode': barcode,
          'field': 'Category',
          'value': '',
          'error': 'Category required',
          'fix': 'Enter a categorisation group like Grocery or Electronics'
        });
        continue;
      }

      if (priceStr.isEmpty) {
        _invalidRecords.add({
          'row': rowNum,
          'name': name,
          'barcode': barcode,
          'field': 'Selling Price',
          'value': '',
          'error': 'Selling Price required',
          'fix': 'Specify the sales price of this product'
        });
        continue;
      }

      if (purPriceStr.isEmpty) {
        _invalidRecords.add({
          'row': rowNum,
          'name': name,
          'barcode': barcode,
          'field': 'Purchase Price',
          'value': '',
          'error': 'Purchase Price required',
          'fix': 'Specify the cost price paid to acquire this item'
        });
        continue;
      }

      if (stockStr.isEmpty) {
        _invalidRecords.add({
          'row': rowNum,
          'name': name,
          'barcode': barcode,
          'field': 'Stock',
          'value': '',
          'error': 'Stock required',
          'fix': 'Enter an integer representing starting stock'
        });
        continue;
      }

      // Numeric validations
      final double? price = double.tryParse(priceStr);
      if (price == null || price < 0) {
        _invalidRecords.add({
          'row': rowNum,
          'name': name,
          'barcode': barcode,
          'field': 'Selling Price',
          'value': priceStr,
          'error': 'Selling price must be a positive numeric value',
          'fix': 'Enter a valid decimal number for price'
        });
        continue;
      }

      final double? purPrice = double.tryParse(purPriceStr);
      if (purPrice == null || purPrice < 0) {
        _invalidRecords.add({
          'row': rowNum,
          'name': name,
          'barcode': barcode,
          'field': 'Purchase Price',
          'value': purPriceStr,
          'error': 'Purchase price must be a positive numeric value',
          'fix': 'Enter a valid decimal number for purchase price'
        });
        continue;
      }

      if (purPrice > price) {
        _invalidRecords.add({
          'row': rowNum,
          'name': name,
          'barcode': barcode,
          'field': 'Purchase Price',
          'value': purPriceStr,
          'error': 'Purchase price cannot exceed selling price',
          'fix': 'Set purchase price lower than selling price ($price)'
        });
        continue;
      }

      final int? stock = int.tryParse(stockStr);
      if (stock == null || stock < 0) {
        _invalidRecords.add({
          'row': rowNum,
          'name': name,
          'barcode': barcode,
          'field': 'Stock',
          'value': stockStr,
          'error': 'Stock must be an integer count',
          'fix': 'Enter a positive non-decimal whole number'
        });
        continue;
      }

      final int? minStock = int.tryParse(minStockStr);
      if (minStock == null || minStock < 0) {
        _invalidRecords.add({
          'row': rowNum,
          'name': name,
          'barcode': barcode,
          'field': 'Minimum Stock',
          'value': minStockStr,
          'error': 'Minimum stock must be an integer',
          'fix': 'Specify a default low-stock threshold like 5'
        });
        continue;
      }

      // Barcode duplication validations
      if (fileBarcodes.contains(barcode)) {
        _invalidRecords.add({
          'row': rowNum,
          'name': name,
          'barcode': barcode,
          'field': 'Barcode',
          'value': barcode,
          'error': 'Duplicate barcode in import file',
          'fix': 'Ensure barcode is unique across the spreadsheet'
        });
        continue;
      }

      if (dbProducts.any((p) => p.barcode == barcode)) {
        _invalidRecords.add({
          'row': rowNum,
          'name': name,
          'barcode': barcode,
          'field': 'Barcode',
          'value': barcode,
          'error': 'Barcode already exists in database',
          'fix': 'Use a unique barcode that is not already in your product list'
        });
        continue;
      }

      // Passed all validations
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

      // Temporarily store the parsed min stock for insertion on save
      HiveDatabase.settingsBox.put('temp_min_stock_$barcode', minStock);
    }

    setState(() {
      _hasParsed = true;
      _tabController.index = _validProducts.isNotEmpty ? 0 : 1;
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully imported ${_validProducts.length} items!'),
          backgroundColor: Colors.green,
        ),
      );

      context.pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Import failed: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _downloadSampleFile(String extension) async {
    try {
      final List<List<dynamic>> sampleData = [
        ['name', 'barcode', 'price', 'purchase price', 'stock', 'category', 'minimum stock'],
        ['Oreo Biscuits 120g', '8901234567890', '30.00', '25.00', '100', 'Groceries', '10'],
        ['USB C Cable 1.5m', '6909876543210', '199.00', '90.00', '50', 'Electronics', '5'],
        ['Sprite Lemon Can 300ml', '8901234567899', '40.00', '32.00', '120', 'Beverages', '15']
      ];

      final directory = await getTemporaryDirectory();
      final String filePath = '${directory.path}/sample_inventory.$extension';
      final File file = File(filePath);

      if (extension == 'csv') {
        const converter = ListToCsvConverter();
        final String csvContent = converter.convert(sampleData);
        await file.writeAsString(csvContent);
      } else {
        final excel = Excel.createExcel();
        final sheet = excel['Sheet1'];
        for (var row in sampleData) {
          sheet.appendRow(row.map((cell) => TextCellValue(cell.toString())).toList());
        }
        final bytes = excel.encode();
        if (bytes != null) {
          await file.writeAsBytes(bytes);
        }
      }

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
        ['Row Number', 'Field Name', 'Invalid Value', 'Error Description', 'Suggested Fix'],
      ];

      for (var record in _invalidRecords) {
        reportData.add([
          record['row'],
          record['field'],
          record['value'],
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
          onPressed: () => context.pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Column(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.file_present, color: AppTheme.primaryColor, size: 24),
                      ),
                      const SizedBox(height: 8),
                      const Text('Upload Inventory Template', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      const Text(
                        'Upload a CSV or Excel (.xlsx) file. Columns must contain: Name, Barcode, Price, Purchase Price, Stock, and Category.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextButton.icon(
                            onPressed: () => _downloadSampleFile('csv'),
                            icon: const Icon(Icons.download, size: 16),
                            label: const Text('Sample CSV', style: TextStyle(fontSize: 12)),
                          ),
                          const SizedBox(width: 16),
                          TextButton.icon(
                            onPressed: () => _downloadSampleFile('xlsx'),
                            icon: const Icon(Icons.download, size: 16),
                            label: const Text('Sample Excel', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      PrimaryButton(
                        onPressed: _pickAndParseFile,
                        icon: Icons.upload_file,
                        label: _fileName ?? 'Select XLSX / CSV File',
                      ),
                    ],
                  ),
                ),

                if (_hasParsed) ...[
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Card(
                            elevation: 0,
                            color: Colors.green[50],
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: Colors.green[100]!),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Column(
                                children: [
                                  Text('${_validProducts.length}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green[700])),
                                  const SizedBox(height: 2),
                                  const Text('Valid Products', style: TextStyle(fontSize: 11, color: Colors.green)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Card(
                            elevation: 0,
                            color: _invalidRecords.isEmpty ? Colors.grey[50] : Colors.red[50],
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: _invalidRecords.isEmpty ? Colors.grey[200]! : Colors.red[100]!),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Column(
                                children: [
                                  Text('${_invalidRecords.length}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _invalidRecords.isEmpty ? Colors.grey : Colors.red[700])),
                                  const SizedBox(height: 2),
                                  const Text('Invalid Records', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  TabBar(
                    controller: _tabController,
                    labelColor: AppTheme.primaryColor,
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: AppTheme.primaryColor,
                    tabs: [
                      Tab(text: 'Ready to Import (${_validProducts.length})'),
                      Tab(text: 'Failed / Warnings (${_invalidRecords.length})'),
                    ],
                  ),

                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildValidTable(),
                        _buildInvalidReport(),
                      ],
                    ),
                  ),
                ],
              ],
            ),
      bottomNavigationBar: _hasParsed && _validProducts.isNotEmpty
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => context.pop(),
                        child: const Text('Cancel', style: TextStyle(color: Colors.red)),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: PrimaryButton(
                        onPressed: _confirmImport,
                        icon: Icons.check_circle,
                        label: 'Confirm Import (${_validProducts.length} Items)',
                      ),
                    ),
                  ],
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }

  Widget _buildValidTable() {
    if (_validProducts.isEmpty) {
      return const Center(child: Text('No valid products to preview', style: TextStyle(color: Colors.grey)));
    }

    return Scrollbar(
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Product Name')),
              DataColumn(label: Text('Barcode')),
              DataColumn(label: Text('Category')),
              DataColumn(label: Text('Selling Price')),
              DataColumn(label: Text('Purchase Price')),
              DataColumn(label: Text('Stock')),
            ],
            rows: _validProducts.map((product) {
              return DataRow(
                cells: [
                  DataCell(Text(product.name, style: const TextStyle(fontWeight: FontWeight.w600))),
                  DataCell(Text(product.barcode)),
                  DataCell(Text(product.category)),
                  DataCell(Text('₹${product.price.toStringAsFixed(2)}')),
                  DataCell(Text('₹${product.purchasePrice.toStringAsFixed(2)}')),
                  DataCell(Text('${product.stock}')),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildInvalidReport() {
    if (_invalidRecords.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline, size: 48, color: Colors.green[300]),
            const SizedBox(height: 8),
            const Text('All checks passed successfully.', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _exportErrorReport,
              icon: const Icon(Icons.share, size: 16),
              label: const Text('Export Error CSV', style: TextStyle(fontSize: 12)),
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _invalidRecords.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final record = _invalidRecords[index];
              return Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.red[50]!),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.red[50],
                        radius: 18,
                        child: Text('R${record['row']}', style: const TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              record['name'] == 'N/A' ? 'Missing Product Name' : record['name'],
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            const SizedBox(height: 4),
                            Text('Field: ${record['field']}', style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
                            if (record['value'].toString().isNotEmpty) ...[
                              Text('Invalid Value: "${record['value']}"', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            ],
                            const SizedBox(height: 4),
                            Text(record['error'], style: TextStyle(fontSize: 12, color: Colors.red[700], fontWeight: FontWeight.w500)),
                            const SizedBox(height: 2),
                            Text('Fix: ${record['fix']}', style: TextStyle(fontSize: 11, color: Colors.green[700], fontStyle: FontStyle.italic)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
