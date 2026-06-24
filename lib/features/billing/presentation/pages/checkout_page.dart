import 'package:billing_app/core/widgets/primary_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/data/hive_database.dart';
import '../../../shop/presentation/bloc/shop_bloc.dart';
import '../bloc/billing_bloc.dart';

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  bool _isPaymentStep = false;

  @override
  Widget build(BuildContext context) {
    const borderColor = Color(0xFFE5E5EA);

    return PopScope(
        canPop: !_isPaymentStep,
        onPopInvoked: (didPop) {
          if (didPop) return;
          if (_isPaymentStep) {
            setState(() {
              _isPaymentStep = false;
            });
          }
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text(_isPaymentStep ? 'Scan & Pay' : 'Order Summary',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            centerTitle: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.chevron_left,
                  size: 28, color: Theme.of(context).primaryColor),
              onPressed: () {
                if (_isPaymentStep) {
                  setState(() {
                    _isPaymentStep = false;
                  });
                } else {
                  context.pop();
                }
              },
            ),
          ),
          body: BlocConsumer<BillingBloc, BillingState>(
            listener: (context, state) {
              if (state.isPurchaseSuccess) {
                final shopState = context.read<ShopBloc>().state;
                String shopName = 'Shop';
                String address1 = '';
                String address2 = '';
                String phone = '';
                String footer = '';
                if (shopState is ShopLoaded) {
                  shopName = shopState.shop.name;
                  address1 = shopState.shop.addressLine1;
                  address2 = shopState.shop.addressLine2;
                  phone = shopState.shop.phoneNumber;
                  footer = shopState.shop.footerText;
                }

                // Automatically print the receipt first
                context.read<BillingBloc>().add(
                      PrintReceiptEvent(
                        shopName: shopName,
                        address1: address1,
                        address2: address2,
                        phone: phone,
                        footer: footer,
                        invoiceNumber: state.generatedInvoiceNumber,
                      ),
                    );

                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) {
                    return BlocBuilder<BillingBloc, BillingState>(
                      builder: (context, billingState) {
                        return Dialog(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 72,
                                  height: 72,
                                  decoration: const BoxDecoration(
                                    color: Colors.greenAccent,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 40,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                const Text(
                                  'Transaction Completed Successfully.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Your payment has been completed.',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFFE5E5EA)),
                                  ),
                                  child: Column(
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text('Invoice:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                          Text(state.generatedInvoiceNumber ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text('Receipt:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                          Text(state.generatedReceiptNumber ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 24),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Theme.of(context).primaryColor,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    icon: billingState.isPrinting
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(Icons.print),
                                    label: Text(
                                      billingState.printSuccess ? 'Printed Successfully' : 'Reprint Receipt',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    onPressed: billingState.isPrinting
                                        ? null
                                        : () {
                                            context.read<BillingBloc>().add(
                                                  PrintReceiptEvent(
                                                    shopName: shopName,
                                                    address1: address1,
                                                    address2: address2,
                                                    phone: phone,
                                                    footer: footer,
                                                    invoiceNumber: state.generatedInvoiceNumber,
                                                  ),
                                                );
                                          },
                                  ),
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      side: BorderSide(color: Colors.grey[300]!),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    onPressed: () {
                                      Navigator.pop(context); // Close dialog
                                      context.read<BillingBloc>().add(ClearCartEvent());
                                      context.go('/');
                                    },
                                    child: const Text(
                                      'Done',
                                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              }
            },
            builder: (context, billingState) {
              return BlocBuilder<ShopBloc, ShopState>(
                  builder: (context, shopState) {
                String upiId = '';
                String shopName = 'Shop';

                if (shopState is ShopLoaded) {
                  upiId = shopState.shop.upiId;
                  shopName = shopState.shop.name;
                }

                return Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 16),
                        child: Column(
                          children: [
                            if (!_isPaymentStep) ...[
                              // Table
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: borderColor),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    )
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Table(
                                    border: const TableBorder(
                                      horizontalInside:
                                          BorderSide(color: borderColor),
                                      bottom: BorderSide(color: borderColor),
                                    ),
                                    children: [
                                      // Header row
                                      TableRow(
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFF8FAFC),
                                          border: Border(
                                              bottom:
                                                  BorderSide(color: borderColor)),
                                        ),
                                        children: [
                                          _buildHeaderCell(
                                              'Product Name', TextAlign.left),
                                          _buildHeaderCell(
                                              'Price', TextAlign.right),
                                          _buildHeaderCell(
                                              'Total', TextAlign.right),
                                        ],
                                      ),
                                      // Items rows
                                      ...billingState.cartItems.map((item) {
                                        return TableRow(
                                          children: [
                                            _buildDataCell(
                                              '${item.quantity} x ${item.product.name}',
                                              TextAlign.left,
                                            ),
                                            _buildDataCell(
                                                '₹${item.product.price.toStringAsFixed(2)}',
                                                TextAlign.right,
                                                isSubtitle: true),
                                            _buildDataCell(
                                                '₹${item.total.toStringAsFixed(2)}',
                                                TextAlign.right,
                                                isBold: true),
                                          ],
                                        );
                                      }),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    context.pop(); // Returns to homepage scanning terminal
                                  },
                                  icon: const Icon(Icons.qr_code_scanner),
                                  label: const Text('Add Product', style: TextStyle(fontWeight: FontWeight.bold)),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppTheme.primaryColor,
                                    side: BorderSide(color: AppTheme.primaryColor),
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                              ),
                            ] else ...[
                              // Payment Instructions / QR
                              const SizedBox(height: 24),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: borderColor),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    Icon(Icons.qr_code_scanner, size: 48, color: AppTheme.primaryColor),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'Unified Payments Interface (UPI)',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Scan the QR code below to complete the payment of ₹${billingState.totalAmount.toStringAsFixed(2)}',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                                    ),
                                    const SizedBox(height: 24),
                                    if (upiId.isNotEmpty)
                                      Center(
                                        child: Container(
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            border: Border.all(color: Colors.grey[200]!),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: SizedBox(
                                            width: 180,
                                            height: 180,
                                            child: PrettyQrView.data(
                                              data:
                                                  'upi://pay?pa=$upiId&pn=$shopName&am=${billingState.totalAmount.toStringAsFixed(2)}&cu=INR',
                                            ),
                                          ),
                                        ),
                                      )
                                    else
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: Colors.orange[50],
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: Colors.orange[100]!),
                                        ),
                                        child: const Text(
                                          'UPI Payment is currently unavailable. Please contact the administrator.',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(color: Colors.orange, fontSize: 13, fontWeight: FontWeight.w500),
                                        ),
                                      ),
                                    const SizedBox(height: 16),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ),

                    // Bottom Bar
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: const BorderRadius.horizontal(
                            left: Radius.circular(24),
                            right: Radius.circular(24)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, -4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                            ),
                            child: Column(
                              children: [
                                const SizedBox(height: 15),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'SUBTOTAL',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                    Text(
                                      '₹${billingState.subtotalAmount.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                  ],
                                ),
                                // Dynamic active taxes display
                                ...(() {
                                  final List? stored = HiveDatabase.settingsBox.get('taxes_config') as List?;
                                  final subtotal = billingState.subtotalAmount;
                                  if (stored == null) {
                                    // Fallback to default 18% GST
                                    return [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text('TAX (18% GST)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[500])),
                                          Text('₹${(subtotal * 0.18).toStringAsFixed(2)}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                        ],
                                      )
                                    ];
                                  }
                                  final widgets = <Widget>[];
                                  for (var t in stored) {
                                    if (t is Map && t['isActive'] == true) {
                                      final name = t['name'] ?? 'Tax';
                                      final pct = double.tryParse(t['percentage'].toString()) ?? 0.0;
                                      final amount = subtotal * (pct / 100.0);
                                      widgets.add(
                                        Padding(
                                          padding: const EdgeInsets.only(bottom: 6),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text('TAX ($name)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[500])),
                                              Text('₹${amount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                            ],
                                          ),
                                        ),
                                      );
                                    }
                                  }
                                  if (widgets.isEmpty) {
                                    widgets.add(
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text('TAX (0%)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[500])),
                                          const Text('₹0.00', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                        ],
                                      ),
                                    );
                                  }
                                  return widgets;
                                })(),
                                const Divider(height: 16),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'GRAND TOTAL',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey[400],
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                    Text(
                                      '₹${billingState.totalAmount.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: -0.5,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          PrimaryButton(
                            onPressed: () {
                              if (!_isPaymentStep) {
                                setState(() {
                                  _isPaymentStep = true;
                                });
                              } else {
                                if (shopState is ShopLoaded) {
                                  context.read<BillingBloc>().add(
                                      ConfirmPurchaseEvent(
                                          shopName: shopState.shop.name,
                                          address1: shopState.shop.addressLine1,
                                          address2: shopState.shop.addressLine2,
                                          phone: shopState.shop.phoneNumber,
                                          footer: shopState.shop.footerText,
                                          userId: 'USR-2026-CUSTOMER',
                                          userName: 'Customer Term'));
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content:
                                              Text('Shop details not loaded'),
                                          backgroundColor: Colors.red));
                                }
                              }
                            },
                            label: _isPaymentStep ? 'Confirm Payment' : 'Proceed to Payment',
                            icon: _isPaymentStep ? Icons.check_circle : Icons.payment,
                            isLoading: billingState.isPrinting,
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              });
            },
          ),
        ));
  }

  Widget _buildHeaderCell(String text, TextAlign align) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Text(
        text.toUpperCase(),
        textAlign: align,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _buildDataCell(String text, TextAlign align,
      {bool isBold = false, bool isSubtitle = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: Text(
        text,
        textAlign: align,
        style: TextStyle(
          fontSize: isSubtitle ? 12 : 14,
          fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
          color: isSubtitle ? Colors.grey[500] : Colors.black87,
        ),
      ),
    );
  }
}
