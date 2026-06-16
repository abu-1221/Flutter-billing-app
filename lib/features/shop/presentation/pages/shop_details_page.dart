import 'dart:io';
import 'package:billing_app/core/widgets/input_label.dart';
import 'package:billing_app/core/widgets/primary_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../domain/entities/shop.dart';
import '../bloc/shop_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_validators.dart';
import '../../../../core/data/hive_database.dart';

class ShopDetailsPage extends StatefulWidget {
  const ShopDetailsPage({super.key});

  @override
  State<ShopDetailsPage> createState() => _ShopDetailsPageState();
}

class _ShopDetailsPageState extends State<ShopDetailsPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _address1Controller;
  late TextEditingController _address2Controller;
  late TextEditingController _phoneController;
  late TextEditingController _upiController;
  late TextEditingController _footerController;
  
  late TextEditingController _emailController;
  late TextEditingController _gstinController;
  late TextEditingController _regNoController;
  String? _logoPath;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _address1Controller = TextEditingController();
    _address2Controller = TextEditingController();
    _phoneController = TextEditingController();
    _upiController = TextEditingController();
    _footerController = TextEditingController();
    
    _emailController = TextEditingController(text: HiveDatabase.settingsBox.get('shop_email', defaultValue: 'siddique2k6@gmail.com'));
    _gstinController = TextEditingController(text: HiveDatabase.settingsBox.get('shop_gstin', defaultValue: ''));
    _regNoController = TextEditingController(text: HiveDatabase.settingsBox.get('shop_reg_no', defaultValue: ''));
    _logoPath = HiveDatabase.settingsBox.get('shop_logo_path');

    // Load shop data
    context.read<ShopBloc>().add(LoadShopEvent());
  }

  void _updateControllers(Shop shop) {
    if (_nameController.text.isEmpty && shop.name.isNotEmpty) {
      _nameController.text = shop.name;
      _address1Controller.text = shop.addressLine1;
      _address2Controller.text = shop.addressLine2;
      _phoneController.text = shop.phoneNumber;
      _upiController.text = shop.upiId;
      _footerController.text = shop.footerText;
    }
  }

  void _pickLogo(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: source);
      if (image != null) {
        setState(() {
          _logoPath = image.path;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error picking logo: $e')));
    }
  }

  void _showLogoPickerOptions() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _pickLogo(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take a Photo'),
              onTap: () {
                Navigator.pop(ctx);
                _pickLogo(ImageSource.camera);
              },
            ),
            if (_logoPath != null)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Remove Logo', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _logoPath = null;
                  });
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _address1Controller.dispose();
    _address2Controller.dispose();
    _phoneController.dispose();
    _upiController.dispose();
    _footerController.dispose();
    _emailController.dispose();
    _gstinController.dispose();
    _regNoController.dispose();
    super.dispose();
  }

  void _saveShop() {
    if (_formKey.currentState!.validate()) {
      final shop = Shop(
        name: _nameController.text,
        addressLine1: _address1Controller.text,
        addressLine2: _address2Controller.text,
        phoneNumber: _phoneController.text,
        upiId: _upiController.text,
        footerText: _footerController.text,
      );

      HiveDatabase.settingsBox.put('shop_email', _emailController.text.trim());
      HiveDatabase.settingsBox.put('shop_gstin', _gstinController.text.trim());
      HiveDatabase.settingsBox.put('shop_reg_no', _regNoController.text.trim());
      if (_logoPath != null) {
        HiveDatabase.settingsBox.put('shop_logo_path', _logoPath);
      } else {
        HiveDatabase.settingsBox.delete('shop_logo_path');
      }

      context.read<ShopBloc>().add(UpdateShopEvent(shop));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Shop Details'),
        ),
        body: BlocConsumer<ShopBloc, ShopState>(
          listener: (context, state) {
            if (state is ShopLoaded) {
              _updateControllers(state.shop);
            } else if (state is ShopOperationSuccess) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Shop details saved!'),
                  backgroundColor: Colors.green));
              context.pop();
            } else if (state is ShopError) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(state.message), backgroundColor: Colors.red));
            }
          },
          buildWhen: (previous, current) =>
              current is ShopLoading || current is ShopLoaded,
          builder: (context, state) {
            if (state is ShopLoading) {
              return const Center(child: CircularProgressIndicator());
            }            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Store Logo Display & Edit
                    Center(
                      child: GestureDetector(
                        onTap: _showLogoPickerOptions,
                        child: Stack(
                          children: [
                            Container(
                              width: 90,
                              height: 90,
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.grey[200]!),
                                image: _logoPath != null && File(_logoPath!).existsSync()
                                    ? DecorationImage(
                                        image: FileImage(File(_logoPath!)),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                              ),
                              child: _logoPath == null || !File(_logoPath!).existsSync()
                                  ? const Icon(Icons.store, size: 40, color: Colors.grey)
                                  : null,
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: AppTheme.primaryColor,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.camera_alt, color: Colors.white, size: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        _logoPath != null ? 'Tap to change store logo' : 'Tap to upload store logo',
                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text('General Information',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                          color: AppTheme.primaryColor.withOpacity(0.8),
                        )),
                    const SizedBox(
                      height: 5,
                    ),
                    Text(
                      'These details will appear on your digital and printed receipts.',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                    const SizedBox(height: 24),
                    const InputLabel(text: 'Business Name'),
                    _buildTextField(
                      controller: _nameController,
                      hint: 'Enter Business Name',
                      validator: AppValidators.required('Required'),
                    ),
                    const SizedBox(height: 15),
                    const InputLabel(text: 'Address Line 1'),
                    _buildTextField(
                      controller: _address1Controller,
                      hint: 'e.g. No. 26, Gandhi Street',
                      validator: AppValidators.required('Required'),
                    ),
                    const SizedBox(height: 15),
                    const InputLabel(text: 'Address Line 2 (Optional)'),
                    _buildTextField(
                      controller: _address2Controller,
                      hint: 'e.g. Subramaniyapuram',
                    ),
                    const SizedBox(height: 15),
                    const InputLabel(text: 'Phone Number'),
                    _buildTextField(
                      controller: _phoneController,
                      hint: 'e.g. 8925483671',
                      keyboardType: TextInputType.phone,
                      validator: AppValidators.required('Required'),
                    ),
                    const SizedBox(height: 15),
                    const InputLabel(text: 'Email Address'),
                    _buildTextField(
                      controller: _emailController,
                      hint: 'business@example.com',
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 15),
                    const InputLabel(text: 'GSTIN / Tax Identification'),
                    _buildTextField(
                      controller: _gstinController,
                      hint: 'e.g. 22AAAAA0000A1Z5',
                    ),
                    const SizedBox(height: 15),
                    const InputLabel(text: 'Business Registration Number'),
                    _buildTextField(
                      controller: _regNoController,
                      hint: 'e.g. REG-109283-99',
                    ),
                    const SizedBox(height: 15),
                    const InputLabel(text: 'UPI ID'),
                    _buildTextField(
                      controller: _upiController,
                      hint: 'example@okicici',
                    ),
                    const SizedBox(height: 15),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const InputLabel(text: 'Receipt Footer Text'),
                        Text('Max 150 chars',
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey[400])),
                      ],
                    ),
                    _buildTextField(
                      controller: _footerController,
                      hint: 'Thank you, Visit again!!!',
                      maxLines: 2,
                      maxLength: 60,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        bottomNavigationBar: PrimaryButton(
          onPressed: _saveShop,
          icon: Icons.save,
          label: 'Save Details',
        ));
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
    int maxLines = 1,
    int? maxLength,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      maxLength: maxLength,
      textCapitalization: TextCapitalization.words,
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
      ),
    );
  }
}
