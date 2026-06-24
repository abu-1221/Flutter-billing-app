import 'package:billing_app/core/widgets/input_label.dart';
import 'package:billing_app/core/widgets/primary_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../bloc/product_bloc.dart';
import '../../domain/entities/product.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_validators.dart';
import '../../../../core/data/hive_database.dart';

class AddProductPage extends StatefulWidget {
  const AddProductPage({super.key});

  @override
  State<AddProductPage> createState() => _AddProductPageState();
}

class _AddProductPageState extends State<AddProductPage> {
  final _formKey = GlobalKey<FormState>();
  String _name = '';
  String _barcode = '';
  double _price = 0.0;
  double _purchasePrice = 0.0;
  String _category = 'General';
  int _stock = 50;
  int _minStock = 5;

  void _scanBarcode() async {
    final result = await context.push<String>('/scanner');
    if (result != null && result.isNotEmpty) {
      setState(() {
        _barcode = result;
      });
    }
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      if (_purchasePrice > _price) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Purchase price cannot exceed selling price!'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final productState = context.read<ProductBloc>().state;
      final existingProduct =
          productState.products.where((p) => p.barcode == _barcode).firstOrNull;

      if (existingProduct != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('This barcode already belongs to product:\n${existingProduct.name}\n(Category: ${existingProduct.category})'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final product = Product(
        id: const Uuid().v4(),
        name: _name,
        barcode: _barcode,
        price: _price,
        stock: _stock,
        category: _category,
        purchasePrice: _purchasePrice,
      );

      // Save threshold setting in settings box
      HiveDatabase.settingsBox.put('min_stock_${product.id}', _minStock);

      context.read<ProductBloc>().add(AddProduct(product));
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.chevron_left,
                size: 28, color: Theme.of(context).primaryColor),
            onPressed: () => context.pop(),
          ),
          title: const Text('Add Product',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          centerTitle: true,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const InputLabel(text: 'Barcode'),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          key: ValueKey(_barcode),
                          initialValue: _barcode,
                          decoration: const InputDecoration(
                            hintText: 'Scan or enter barcode',
                          ),
                          validator:
                              AppValidators.required('Please enter a barcode'),
                          onSaved: (value) => _barcode = value!,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.qr_code_scanner,
                              color: AppTheme.primaryColor),
                          onPressed: _scanBarcode,
                          padding: const EdgeInsets.all(14),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text('Tap the icon to open camera scanner',
                      style: TextStyle(fontSize: 12, color: Color(0xFF4C669A))),
                  const SizedBox(height: 24),
                  const InputLabel(text: 'Product Name'),
                  TextFormField(
                    decoration: const InputDecoration(
                      hintText: 'e.g. Basmati Rice',
                    ),
                    textCapitalization: TextCapitalization.words,
                    validator: AppValidators.required('Please enter a name'),
                    onSaved: (value) => _name = value!,
                  ),
                  const SizedBox(height: 24),
                  const InputLabel(text: 'Category'),
                  TextFormField(
                    initialValue: 'General',
                    decoration: const InputDecoration(
                      hintText: 'e.g. Beverages, Groceries',
                    ),
                    textCapitalization: TextCapitalization.words,
                    validator: AppValidators.required('Please enter a category'),
                    onSaved: (value) => _category = value!,
                  ),
                  const SizedBox(height: 24),
                  const InputLabel(text: 'Selling Price'),
                  TextFormField(
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      hintText: '0.00',
                      prefixText: '₹ ',
                      prefixStyle: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.black),
                    ),
                    validator: AppValidators.price,
                    onSaved: (value) => _price = double.parse(value!),
                  ),
                  const SizedBox(height: 24),
                  const InputLabel(text: 'Purchase Price'),
                  TextFormField(
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      hintText: '0.00',
                      prefixText: '₹ ',
                      prefixStyle: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.black),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a purchase price';
                      }
                      if (double.tryParse(value) == null || double.parse(value) < 0) {
                        return 'Please enter a valid price';
                      }
                      return null;
                    },
                    onSaved: (value) => _purchasePrice = double.parse(value!),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const InputLabel(text: 'Current Stock'),
                            TextFormField(
                              keyboardType: TextInputType.number,
                              initialValue: '50',
                              validator: AppValidators.required('Required'),
                              onSaved: (value) => _stock = int.parse(value!),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const InputLabel(text: 'Min Stock Warning'),
                            TextFormField(
                              keyboardType: TextInputType.number,
                              initialValue: '5',
                              validator: AppValidators.required('Required'),
                              onSaved: (value) => _minStock = int.parse(value!),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        bottomNavigationBar: PrimaryButton(
          onPressed: _submit,
          icon: Icons.add_circle,
          label: 'Add Product',
        ));
  }
}
