import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/data/hive_database.dart';

class TaxConfigurationPage extends StatefulWidget {
  const TaxConfigurationPage({super.key});

  @override
  State<TaxConfigurationPage> createState() => _TaxConfigurationPageState();
}

class _TaxConfigurationPageState extends State<TaxConfigurationPage> {
  List<Map<String, dynamic>> _taxes = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadTaxes();
  }

  void _loadTaxes() {
    setState(() => _isLoading = true);
    final List? stored = HiveDatabase.settingsBox.get('taxes_config') as List?;
    if (stored != null) {
      _taxes = stored.map((t) => Map<String, dynamic>.from(t as Map)).toList();
    } else {
      // Default fallback
      _taxes = [
        {
          'id': 'gst_18',
          'name': 'GST 18%',
          'percentage': 18.0,
          'type': 'GST',
          'isActive': true,
        }
      ];
      HiveDatabase.settingsBox.put('taxes_config', _taxes);
    }
    setState(() => _isLoading = false);
  }

  void _saveTaxes() {
    HiveDatabase.settingsBox.put('taxes_config', _taxes);
    _loadTaxes();
  }

  void _toggleTaxActive(int index, bool value) {
    setState(() {
      _taxes[index]['isActive'] = value;
    });
    _saveTaxes();
  }

  void _deleteTax(int index) {
    final taxName = _taxes[index]['name'];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Tax?'),
        content: Text('Are you sure you want to delete the tax "$taxName"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              setState(() {
                _taxes.removeAt(index);
              });
              _saveTaxes();
              Navigator.pop(ctx);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showTaxFormDialog({Map<String, dynamic>? existingTax, int? index}) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: existingTax?['name'] ?? '');
    final percentageController = TextEditingController(text: existingTax?['percentage']?.toString() ?? '');
    String selectedType = existingTax?['type'] ?? 'GST';
    bool isActive = existingTax?['isActive'] ?? true;

    final taxTypes = [
      'GST',
      'CGST',
      'SGST',
      'IGST',
      'VAT',
      'Service Tax',
      'Additional Charges',
      'Custom'
    ];

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(existingTax == null ? 'Add New Tax' : 'Edit Tax Rule'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(labelText: 'Tax Name', hintText: 'e.g. VAT 5%'),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) return 'Name is required';
                          // Check duplicate name
                          final exists = _taxes.any((t) => t['name'].toString().toLowerCase() == value.trim().toLowerCase() && t['id'] != existingTax?['id']);
                          if (exists) return 'Tax name already exists';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: percentageController,
                        decoration: const InputDecoration(labelText: 'Percentage (%)', hintText: 'e.g. 5.0'),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) return 'Percentage is required';
                          final parsed = double.tryParse(value);
                          if (parsed == null || parsed < 0) return 'Enter a non-negative number';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: selectedType,
                        decoration: const InputDecoration(labelText: 'Tax Type'),
                        items: taxTypes.map((type) => DropdownMenuItem(value: type, child: Text(type))).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() => selectedType = val);
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Active status', style: TextStyle(fontWeight: FontWeight.w500)),
                          Switch(
                            value: isActive,
                            activeColor: AppTheme.primaryColor,
                            onChanged: (val) {
                              setDialogState(() => isActive = val);
                            },
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                TextButton(
                  onPressed: () {
                    if (formKey.currentState!.validate()) {
                      final name = nameController.text.trim();
                      final pct = double.parse(percentageController.text.trim());
                      final id = existingTax?['id'] ?? const Uuid().v4();

                      final newTax = {
                        'id': id,
                        'name': name,
                        'percentage': pct,
                        'type': selectedType,
                        'isActive': isActive,
                      };

                      setState(() {
                        if (index != null) {
                          _taxes[index] = newTax;
                        } else {
                          _taxes.add(newTax);
                        }
                      });
                      _saveTaxes();
                      Navigator.pop(ctx);
                    }
                  },
                  child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tax Configuration', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.percent, color: AppTheme.primaryColor, size: 28),
                      ),
                      const SizedBox(height: 12),
                      const Text('Dynamic Tax Configuration', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      const Text(
                        'Set up active tax rates. Taxes marked as active will be calculated automatically during billing checkout and printed on receipts.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Configured Taxes (${_taxes.length})'.toUpperCase(),
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2),
                    ),
                  ),
                ),
                Expanded(
                  child: _taxes.isEmpty
                      ? const Center(child: Text('No tax rules configured', style: TextStyle(color: Colors.grey)))
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _taxes.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final tax = _taxes[index];
                            final isActive = tax['isActive'] ?? true;
                            final name = tax['name'] ?? 'N/A';
                            final type = tax['type'] ?? 'GST';
                            final pct = tax['percentage']?.toString() ?? '0';

                            return Card(
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: Colors.grey[100]!),
                              ),
                              color: Colors.white,
                              child: ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isActive ? AppTheme.primaryColor.withOpacity(0.08) : Colors.grey[100],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '$pct%',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isActive ? AppTheme.primaryColor : Colors.grey,
                                    ),
                                  ),
                                ),
                                title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                subtitle: Text('Type: $type', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Switch(
                                      value: isActive,
                                      activeColor: AppTheme.primaryColor,
                                      onChanged: (val) => _toggleTaxActive(index, val),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, color: Colors.blue, size: 20),
                                      onPressed: () => _showTaxFormDialog(existingTax: tax, index: index),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                      onPressed: () => _deleteTax(index),
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
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: PrimaryButton(
            onPressed: () => _showTaxFormDialog(),
            icon: Icons.add,
            label: 'Add New Tax Rule',
          ),
        ),
      ),
    );
  }
}
