import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../bloc/product_bloc.dart';
import '../../domain/entities/product.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_validators.dart';
import '../../../../core/data/hive_database.dart';

class ProductListPage extends StatefulWidget {
  const ProductListPage({super.key});

  @override
  State<ProductListPage> createState() => _ProductListPageState();
}

class _ProductListPageState extends State<ProductListPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'All';
  String _selectedStockFilter = 'All'; // 'All', 'In Stock', 'Low Stock', 'Out of Stock'
  String _selectedStatusFilter = 'All'; // 'All', 'Available', 'Sold'
  bool _sortByRecentlyAdded = false;

  Widget _buildStockBadge(Product product) {
    final int minStock = HiveDatabase.settingsBox.get('min_stock_${product.id}', defaultValue: 5);
    final int stock = product.stock;

    Color color;
    String text;

    if (stock <= 0) {
      color = Colors.red;
      text = 'OUT OF STOCK';
    } else if (stock <= minStock) {
      color = Colors.orange;
      text = 'LOW STOCK ($stock)';
    } else {
      color = Colors.green;
      text = 'STOCK: $stock';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildStatusBadge(Product product) {
    final isSold = product.status == 'Sold';
    final color = isSold ? Colors.redAccent : Colors.teal;
    final text = isSold ? 'SOLD' : 'AVAILABLE';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _scanQR(List<Product> products) async {
    final barcode = await context.push<String>('/scanner');
    if (barcode != null && barcode.isNotEmpty) {
      final matchedProduct =
          products.where((p) => p.barcode == barcode).firstOrNull;
      if (matchedProduct != null) {
        _searchController.text = matchedProduct.name;
      } else {
        _searchController.text =
            barcode; // If not found, just put barcode in search
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = Colors.grey[100]!;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.chevron_left,
              size: 28, color: Theme.of(context).primaryColor),
          onPressed: () => context.pop(),
        ),
        title: const Text('Product Management',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.file_upload_outlined, color: AppTheme.primaryColor),
            tooltip: 'Import Bulk Products',
            onPressed: () => context.push('/products/import'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: BlocBuilder<ProductBloc, ProductState>(
                builder: (context, state) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _searchController,
                          textCapitalization: TextCapitalization.words,
                          decoration: InputDecoration(
                            hintText: 'Scan or enter barcode/name/category',
                            prefixIcon: Icon(
                              Icons.search,
                              color: Colors.grey[400],
                            ),
                          ),
                          validator:
                              AppValidators.required('Please enter a barcode'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.qr_code_scanner,
                              color: AppTheme.primaryColor),
                          onPressed: () => _scanQR(state.products),
                          padding: const EdgeInsets.all(15),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text('Tap the icon to open camera scanner',
                      style: TextStyle(fontSize: 12, color: Color(0xFF4C669A))),
                  const SizedBox(height: 12),
                  // Dropdown filters (Categories, Stock, Recently Added)
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      // Categories Filter
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[200]!),
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.white,
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedCategory,
                              isExpanded: true,
                              isDense: true,
                              style: const TextStyle(fontSize: 12, color: Colors.black, fontWeight: FontWeight.w500),
                              items: [
                                const DropdownMenuItem<String>(
                                  value: 'All',
                                  child: Text('Categories'),
                                ),
                                ...state.products.map((p) => p.category).toSet().map((cat) {
                                  return DropdownMenuItem<String>(
                                    value: cat,
                                    child: Text(cat, overflow: TextOverflow.ellipsis),
                                  );
                                }),
                              ],
                              onChanged: (val) {
                                setState(() {
                                  _selectedCategory = val ?? 'All';
                                });
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Stock Filter
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[200]!),
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.white,
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedStockFilter,
                              isExpanded: true,
                              isDense: true,
                              style: const TextStyle(fontSize: 12, color: Colors.black, fontWeight: FontWeight.w500),
                              items: const [
                                DropdownMenuItem<String>(
                                  value: 'All',
                                  child: Text('Stock'),
                                ),
                                DropdownMenuItem<String>(
                                  value: 'In Stock',
                                  child: Text('In Stock'),
                                ),
                                DropdownMenuItem<String>(
                                  value: 'Low Stock',
                                  child: Text('Low Stock'),
                                ),
                                DropdownMenuItem<String>(
                                  value: 'Out of Stock',
                                  child: Text('Out of Stock'),
                                ),
                              ],
                              onChanged: (val) {
                                setState(() {
                                  _selectedStockFilter = val ?? 'All';
                                });
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Recently Added chip
                      ChoiceChip(
                        selected: _sortByRecentlyAdded,
                        showCheckmark: false,
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        label: const Text('Recently Added', style: TextStyle(fontSize: 11)),
                        selectedColor: AppTheme.primaryColor,
                        backgroundColor: Colors.grey[100],
                        labelStyle: TextStyle(
                          color: _sortByRecentlyAdded ? Colors.white : Colors.black87,
                          fontWeight: _sortByRecentlyAdded ? FontWeight.bold : FontWeight.normal,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        onSelected: (val) {
                          setState(() {
                            _sortByRecentlyAdded = val;
                          });
                        },
                      ),
                    ],
                  ),
                ],
              );
            }),
          ),

          Expanded(
            child: BlocConsumer<ProductBloc, ProductState>(
              listener: (context, state) {
                if (state.status == ProductStatus.success &&
                    state.message != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(state.message!),
                        backgroundColor: Colors.green),
                  );
                } else if (state.status == ProductStatus.error &&
                    state.message != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(state.message!),
                        backgroundColor: Colors.red),
                  );
                }
              },
              builder: (context, state) {
                if (state.status == ProductStatus.loading &&
                    state.products.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (state.products.isEmpty) {
                  if (state.status == ProductStatus.error) {
                    return Center(child: Text('Error: ${state.message}'));
                  }
                  return const Center(
                      child: Text('No products found. Add some!'));
                }

                var filteredProducts = state.products
                    .where((product) =>
                        product.name.toLowerCase().contains(_searchQuery) ||
                        product.barcode.toLowerCase().contains(_searchQuery) ||
                        product.category.toLowerCase().contains(_searchQuery))
                    .toList();

                // Apply Category filter
                if (_selectedCategory != 'All') {
                  filteredProducts = filteredProducts.where((p) => p.category == _selectedCategory).toList();
                }

                // Apply Stock filter
                if (_selectedStockFilter != 'All') {
                  filteredProducts = filteredProducts.where((product) {
                    final int minStock = HiveDatabase.settingsBox.get('min_stock_${product.id}', defaultValue: 5);
                    if (_selectedStockFilter == 'Out of Stock') {
                      return product.stock <= 0;
                    } else if (_selectedStockFilter == 'Low Stock') {
                      return product.stock > 0 && product.stock <= minStock;
                    } else if (_selectedStockFilter == 'In Stock') {
                      return product.stock > minStock;
                    }
                    return true;
                  }).toList();
                }

                // Apply Status filter
                if (_selectedStatusFilter != 'All') {
                  filteredProducts = filteredProducts.where((p) {
                    if (_selectedStatusFilter == 'Sold') {
                      return p.status == 'Sold';
                    } else {
                      return p.status != 'Sold'; // i.e. Available
                    }
                  }).toList();
                }

                // Sort by recently added (reverses order since list index is insertion order)
                if (_sortByRecentlyAdded) {
                  filteredProducts = filteredProducts.reversed.toList();
                }

                if (filteredProducts.isEmpty) {
                  return const Center(
                      child: Text('No products match your search.'));
                }

                return ListView.separated(
                  padding: const EdgeInsets.only(
                      left: 16, right: 16, top: 8, bottom: 100),
                  itemCount: filteredProducts.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final product = filteredProducts[index];
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderColor),
                        boxShadow: const [
                          BoxShadow(
                              color: Colors.black12,
                              blurRadius: 4,
                              offset: Offset(0, 2))
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Row 1: Product Name
                          Text(
                            product.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Color(0xFF0F172A)),
                          ),
                          const SizedBox(height: 4),
                          // Row 2: Product Price
                          Row(
                            children: [
                              Icon(Icons.sell_outlined, size: 12, color: Colors.grey[600]),
                              const SizedBox(width: 4),
                              const Text('Price: ', style: TextStyle(fontSize: 12, color: Colors.grey)),
                              Text(
                                '₹${product.price.toStringAsFixed(2)}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: Color(0xFF0F172A)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          // Row 3: Product Cost
                          Row(
                            children: [
                              Icon(Icons.shopping_bag_outlined, size: 12, color: Colors.grey[600]),
                              const SizedBox(width: 4),
                              const Text('Cost: ', style: TextStyle(fontSize: 12, color: Colors.grey)),
                              Text(
                                '₹${product.purchasePrice.toStringAsFixed(2)}',
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          // Row 4: Stock Information
                          Row(
                            children: [
                              Icon(Icons.inventory_2_outlined, size: 12, color: Colors.grey[600]),
                              const SizedBox(width: 4),
                              const Text('Stock: ', style: TextStyle(fontSize: 12, color: Colors.grey)),
                              _buildStockBadge(product),
                            ],
                          ),
                          const SizedBox(height: 4),
                          // Row 5: Status Information
                          Row(
                            children: [
                              Icon(Icons.info_outline, size: 12, color: Colors.grey[600]),
                              const SizedBox(width: 4),
                              const Text('Status: ', style: TextStyle(fontSize: 12, color: Colors.grey)),
                              _buildStatusBadge(product),
                            ],
                          ),
                          const SizedBox(height: 6),
                          const Divider(height: 1, color: Color(0xFFF3F4F6)),
                          const SizedBox(height: 6),
                          // QR Code (Barcode text below the product info in a properly aligned section)
                          Row(
                            children: [
                              const Icon(Icons.qr_code, size: 14, color: Colors.grey),
                              const SizedBox(width: 6),
                              const Text('Barcode: ', style: TextStyle(fontSize: 11, color: Colors.grey)),
                              Text(
                                product.barcode,
                                style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    fontFamily: 'monospace',
                                    color: Colors.black87),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF3F4F6),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  product.category,
                                  style: const TextStyle(
                                      fontSize: 8,
                                      color: Colors.grey,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          // Invoice Information
                          if (product.status == 'Sold' && product.transactionId != null) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.receipt_long_outlined, size: 14, color: Colors.red[700]),
                                const SizedBox(width: 6),
                                Text(
                                  'Invoice: ${product.transactionId}',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.red[700],
                                      fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 6),
                          const Divider(height: 1, color: Color(0xFFF3F4F6)),
                          const SizedBox(height: 6),
                          // Action Buttons
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton.icon(
                                style: TextButton.styleFrom(
                                  foregroundColor: AppTheme.primaryColor,
                                  backgroundColor: AppTheme.primaryColor.withOpacity(0.06),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                icon: const Icon(Icons.edit_rounded, size: 13),
                                label: const Text('Edit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                                onPressed: () {
                                  context.push('/products/edit/${product.id}',
                                      extra: product);
                                },
                              ),
                              const SizedBox(width: 6),
                              TextButton.icon(
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.red,
                                  backgroundColor: Colors.red.withOpacity(0.06),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                icon: const Icon(Icons.delete_outline_rounded, size: 13),
                                label: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                                onPressed: () =>
                                    _confirmDelete(context, product),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/products/add'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, size: 32),
      ),
    );
  }

  void _confirmDelete(BuildContext context, Product product) {
    showDialog(
      context: context,
      builder: (innerContext) {
        return AlertDialog(
          title: const Text('Delete Product'),
          content: Text('Are you sure you want to delete ${product.name}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(innerContext),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                context.read<ProductBloc>().add(DeleteProduct(product.id));
                Navigator.pop(innerContext);
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }
}
