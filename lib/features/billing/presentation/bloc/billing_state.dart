part of 'billing_bloc.dart';

class BillingState extends Equatable {
  final List<CartItem> cartItems;
  final String? error;
  final bool isPrinting;
  final bool printSuccess;
  final bool isPurchaseSuccess;
  final String? generatedInvoiceNumber;
  final String? generatedReceiptNumber;

  const BillingState({
    this.cartItems = const [],
    this.error,
    this.isPrinting = false,
    this.printSuccess = false,
    this.isPurchaseSuccess = false,
    this.generatedInvoiceNumber,
    this.generatedReceiptNumber,
  });

  double get subtotalAmount => cartItems.fold(0, (sum, item) => sum + item.total);
  
  double get taxAmount {
    final List? stored = HiveDatabase.settingsBox.get('taxes_config') as List?;
    if (stored == null) {
      return subtotalAmount * 0.18; // Fallback to 18% GST
    }
    double totalTax = 0.0;
    for (var t in stored) {
      if (t is Map && t['isActive'] == true) {
        final pct = double.tryParse(t['percentage'].toString()) ?? 0.0;
        totalTax += subtotalAmount * (pct / 100.0);
      }
    }
    return totalTax;
  }
  
  double get totalAmount => subtotalAmount + taxAmount;

  BillingState copyWith({
    List<CartItem>? cartItems,
    String? error,
    bool clearError = false,
    bool? isPrinting,
    bool? printSuccess,
    bool? isPurchaseSuccess,
    String? generatedInvoiceNumber,
    String? generatedReceiptNumber,
    bool clearPurchaseState = false,
  }) {
    return BillingState(
      cartItems: cartItems ?? this.cartItems,
      error: clearError ? null : (error ?? this.error),
      isPrinting: isPrinting ?? this.isPrinting,
      printSuccess: printSuccess ?? this.printSuccess,
      isPurchaseSuccess: clearPurchaseState ? false : (isPurchaseSuccess ?? this.isPurchaseSuccess),
      generatedInvoiceNumber: clearPurchaseState ? null : (generatedInvoiceNumber ?? this.generatedInvoiceNumber),
      generatedReceiptNumber: clearPurchaseState ? null : (generatedReceiptNumber ?? this.generatedReceiptNumber),
    );
  }

  @override
  List<Object?> get props => [
        cartItems,
        error,
        isPrinting,
        printSuccess,
        isPurchaseSuccess,
        generatedInvoiceNumber,
        generatedReceiptNumber,
      ];
}
