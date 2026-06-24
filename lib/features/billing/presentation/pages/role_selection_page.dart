import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/data/hive_database.dart';
import '../../../../core/theme/app_theme.dart';

class RoleSelectionPage extends StatefulWidget {
  const RoleSelectionPage({super.key});

  @override
  State<RoleSelectionPage> createState() => _RoleSelectionPageState();
}

class _RoleSelectionPageState extends State<RoleSelectionPage> {
  final _passcodeController = TextEditingController();
  bool _obscureText = true;

  @override
  void dispose() {
    _passcodeController.dispose();
    super.dispose();
  }

  void _showPasscodeDialog() {
    _passcodeController.clear();
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.lock, color: AppTheme.primaryColor),
                  SizedBox(width: 8),
                  Text('Admin Authorization', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Please enter the manager passcode to access admin privileges.',
                    style: TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passcodeController,
                    obscureText: _obscureText,
                    keyboardType: TextInputType.text,
                    decoration: InputDecoration(
                      hintText: 'Enter passcode',
                      prefixIcon: const Icon(Icons.password, color: Colors.grey),
                      suffixIcon: IconButton(
                        icon: Icon(_obscureText ? Icons.visibility : Icons.visibility_off, color: Colors.grey),
                        onPressed: () {
                          setState(() {
                            _obscureText = !_obscureText;
                          });
                        },
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (_passcodeController.text == 'admin') {
                      Navigator.pop(context);
                      HiveDatabase.settingsBox.put('admin_mode_active', true);
                      context.go('/settings'); // Go to Admin Settings/Dashboard directly
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Incorrect Passcode'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  child: const Text('Confirm'),
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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF3F4F6),
              Color(0xFFE5E7EB),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                // Icon Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet,
                    size: 64,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Billing Platform',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Select your interface to get started',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const Spacer(),
                // Customer Terminal Mode Card
                Card(
                  elevation: 2,
                  child: InkWell(
                    onTap: () {
                      HiveDatabase.settingsBox.put('admin_mode_active', false);
                      context.go('/');
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.teal.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.qr_code_scanner_outlined, color: Colors.teal, size: 32),
                          ),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Customer Terminal',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Scan products & complete order payment',
                                  style: TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Admin Mode Card
                Card(
                  elevation: 2,
                  child: InkWell(
                    onTap: _showPasscodeDialog,
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.admin_panel_settings_outlined, color: AppTheme.primaryColor, size: 32),
                          ),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Admin & Store Manager',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Inventory, Analytics, configuration & settings',
                                  style: TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
                        ],
                      ),
                    ),
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
