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
  double get taxAmount => subtotalAmount * 0.18; // 18% GST standard
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
