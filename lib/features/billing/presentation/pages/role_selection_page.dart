import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../config/routes/app_routes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/data/manager_access.dart';

class RoleSelectionPage extends StatefulWidget {
  const RoleSelectionPage({super.key});

  @override
  State<RoleSelectionPage> createState() => _RoleSelectionPageState();
}

class _RoleSelectionPageState extends State<RoleSelectionPage> {
  final _passcodeController = TextEditingController();
  bool _obscureText = true;
  bool _busy = false;
  final _confirmationController = TextEditingController();

  @override
  void dispose() {
    _passcodeController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  void _showPasscodeDialog() {
    _passcodeController.clear();
    _confirmationController.clear();
    final setup = !managerAccess.isConfigured;
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, updateDialog) => AlertDialog(
          title: Text(setup ? 'Set Manager Passcode' : 'Manager Access'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(setup
                  ? 'Store owner: set a unique passcode (10 or more characters) before giving this device to staff. Keep it safe: there is no recovery without app-data reset.'
                  : 'Enter your manager passcode.'),
              const SizedBox(height: 12),
              TextField(
                controller: _passcodeController,
                obscureText: _obscureText,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText: 'Passcode',
                  suffixIcon: IconButton(
                    icon: Icon(
                        _obscureText ? Icons.visibility : Icons.visibility_off),
                    onPressed: () =>
                        updateDialog(() => _obscureText = !_obscureText),
                  ),
                ),
              ),
              if (setup)
                TextField(
                  controller: _confirmationController,
                  obscureText: _obscureText,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration:
                      const InputDecoration(labelText: 'Confirm passcode'),
                ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: _busy ? null : () => Navigator.pop(dialogContext),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: _busy
                  ? null
                  : () async {
                      final passcode = _passcodeController.text;
                      if (setup &&
                          (!ManagerAccess.validPasscode(passcode) ||
                              passcode != _confirmationController.text)) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text(
                                'Use 10-128 characters and enter the same passcode twice.')));
                        return;
                      }
                      updateDialog(() => _busy = true);
                      try {
                        if (setup) {
                          await managerAccess.configure(passcode);
                        } else if (!await managerAccess.unlock(passcode)) {
                          if (mounted) {
                            final wait = managerAccess.retrySeconds;
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text(wait > 0
                                    ? 'Too many attempts. Try again in $wait seconds.'
                                    : 'Incorrect passcode.')));
                          }
                          return;
                        }
                        if (mounted && dialogContext.mounted) {
                          Navigator.pop(dialogContext);
                          context.go('/settings');
                        }
                      } catch (_) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                              content: Text(
                                  'Could not save manager access. Try again.')));
                        }
                      } finally {
                        _passcodeController.clear();
                        _confirmationController.clear();
                        _busy = false;
                        if (dialogContext.mounted) {
                          updateDialog(() {});
                        }
                      }
                    },
              child: Text(setup ? 'Set passcode' : 'Unlock'),
            ),
          ],
        ),
      ),
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
                      managerAccess.lock();
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
                            child: const Icon(Icons.qr_code_scanner_outlined,
                                color: Colors.teal, size: 32),
                          ),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Customer Terminal',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Scan products & complete order payment',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios,
                              color: Colors.grey, size: 16),
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
                            child: const Icon(
                                Icons.admin_panel_settings_outlined,
                                color: AppTheme.primaryColor,
                                size: 32),
                          ),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Admin & Store Manager',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Inventory, Analytics, configuration & settings',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios,
                              color: Colors.grey, size: 16),
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
