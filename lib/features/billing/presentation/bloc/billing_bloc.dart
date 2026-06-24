import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../domain/entities/cart_item.dart';
import 'package:billing_app/features/product/domain/entities/product.dart';
import 'package:billing_app/features/product/domain/usecases/product_usecases.dart';
import '../../../../core/utils/printer_helper.dart';
import '../../../../core/data/hive_database.dart';
import '../../data/models/transaction_model.dart';
import '../../data/models/sale_model.dart';
import '../../../product/data/models/product_model.dart';

part 'billing_event.dart';
part 'billing_state.dart';

class BillingBloc extends Bloc<BillingEvent, BillingState> {
  final GetProductByBarcodeUseCase getProductByBarcodeUseCase;

  BillingBloc({required this.getProductByBarcodeUseCase})
      : super(const BillingState()) {
    on<ScanBarcodeEvent>(_onScanBarcode);
    on<AddProductToCartEvent>(_onAddProductToCart);
    on<RemoveProductFromCartEvent>(_onRemoveProductFromCart);
    on<UpdateQuantityEvent>(_onUpdateQuantity);
    on<ClearCartEvent>(_onClearCart);
    on<PrintReceiptEvent>(_onPrintReceipt);
    on<ConfirmPurchaseEvent>(_onConfirmPurchase);
  }

  Future<void> _onScanBarcode(
      ScanBarcodeEvent event, Emitter<BillingState> emit) async {
    emit(state.copyWith(clearError: true));
    final result = await getProductByBarcodeUseCase(event.barcode);
    result.fold(
      (failure) =>
          emit(state.copyWith(error: 'Product not found: ${event.barcode}')),
      (product) {
        if (product.status == 'Sold') {
          emit(state.copyWith(error: 'This product has already been sold.'));
        } else {
          final isAlreadyInCart = state.cartItems.any((item) => item.product.id == product.id);
          if (isAlreadyInCart) {
            emit(state.copyWith(error: 'This product is already in your buying list.'));
          } else {
            add(AddProductToCartEvent(product));
          }
        }
      },
    );
  }

  void _onAddProductToCart(
      AddProductToCartEvent event, Emitter<BillingState> emit) {
    // Clear error when adding
    final cleanState = state.copyWith(error: null);

    final isAlreadyInCart = cleanState.cartItems
        .any((item) => item.product.id == event.product.id);
    if (isAlreadyInCart) {
      emit(cleanState.copyWith(error: 'This product is already in your buying list.'));
    } else {
      final newItem = CartItem(product: event.product, quantity: 1);
      emit(cleanState.copyWith(
          cartItems: [...cleanState.cartItems, newItem], error: null));
    }
  }

  void _onRemoveProductFromCart(
      RemoveProductFromCartEvent event, Emitter<BillingState> emit) {
    final updatedList = state.cartItems
        .where((item) => item.product.id != event.productId)
        .toList();
    emit(state.copyWith(cartItems: updatedList));
  }

  void _onUpdateQuantity(
      UpdateQuantityEvent event, Emitter<BillingState> emit) {
    if (event.quantity <= 0) {
      add(RemoveProductFromCartEvent(event.productId));
      return;
    }

    final index = state.cartItems
        .indexWhere((item) => item.product.id == event.productId);
    if (index >= 0) {
      final items = List<CartItem>.from(state.cartItems);
      items[index] = items[index].copyWith(quantity: event.quantity);
      emit(state.copyWith(cartItems: items));
    }
  }

  void _onClearCart(ClearCartEvent event, Emitter<BillingState> emit) {
    emit(state.copyWith(cartItems: const [], clearPurchaseState: true));
  }

  Future<void> _onConfirmPurchase(
      ConfirmPurchaseEvent event, Emitter<BillingState> emit) async {
    if (state.cartItems.isEmpty) return;

    emit(state.copyWith(isPrinting: false, clearError: true));

    final int nextInvoiceIndex =
        HiveDatabase.settingsBox.get('next_invoice_index', defaultValue: 1);
    final int nextReceiptIndex =
        HiveDatabase.settingsBox.get('next_receipt_index', defaultValue: 1);

    final String year = DateTime.now().year.toString();
    final String invoiceNumber =
        'INV-$year-${nextInvoiceIndex.toString().padLeft(6, '0')}';
    final String receiptNumber =
        'RCPT-$year-${nextReceiptIndex.toString().padLeft(6, '0')}';

    final now = DateTime.now();
    final String formattedDate = DateFormat('yyyy-MM-dd').format(now);
    final String formattedTime = DateFormat('hh:mm a').format(now);

    final subtotal = state.subtotalAmount;
    final tax = state.taxAmount;
    final grandTotal = state.totalAmount;

    final List<Map<String, dynamic>> itemsList = state.cartItems
        .map((item) => {
              'name': item.product.name,
              'qty': item.quantity,
              'price': item.product.price,
              'total': item.total,
            })
        .toList();

    final transaction = {
      'invoiceNumber': invoiceNumber,
      'receiptNumber': receiptNumber,
      'date': formattedDate,
      'time': formattedTime,
      'userId': event.userId,
      'userName': event.userName,
      'items': itemsList,
      'subtotal': subtotal,
      'tax': tax,
      'grandTotal': grandTotal,
    };

    // Save transaction to general transactions box
    await HiveDatabase.transactionsBox.add(transaction);

    // Maintain strict database requirements and relationships:
    // Update products table: status -> Sold, sold_at -> now, transaction_id -> invoiceNumber
    final productBox = HiveDatabase.productBox;
    for (var item in state.cartItems) {
      final dbProduct = productBox.get(item.product.id);
      if (dbProduct != null) {
        final updatedProduct = ProductModel(
          id: dbProduct.id,
          name: dbProduct.name,
          barcode: dbProduct.barcode,
          price: dbProduct.price,
          stock: dbProduct.stock,
          category: dbProduct.category,
          purchasePrice: dbProduct.purchasePrice,
          status: 'Sold',
          soldAt: now,
          transactionId: invoiceNumber,
        );
        await productBox.put(dbProduct.id, updatedProduct);
      }

      // Add to Transactions Table (Hive transactionsTableBox)
      final txModel = TransactionModel(
        transactionId: invoiceNumber,
        productId: item.product.id,
        paymentStatus: 'Success',
        purchasedBy: event.userName,
        purchasedAt: now,
      );
      await HiveDatabase.transactionsTableBox.add(txModel);

      // Add to Sales Table (Hive salesTableBox)
      final saleModel = SaleModel(
        saleId: const Uuid().v4(),
        productId: item.product.id,
        barcode: item.product.barcode,
        transactionId: invoiceNumber,
        soldAt: now,
      );
      await HiveDatabase.salesTableBox.add(saleModel);
    }

    await HiveDatabase.settingsBox.put('next_invoice_index', nextInvoiceIndex + 1);
    await HiveDatabase.settingsBox.put('next_receipt_index', nextReceiptIndex + 1);

    emit(state.copyWith(
      cartItems: const [],
      isPrinting: false,
      isPurchaseSuccess: true,
      generatedInvoiceNumber: invoiceNumber,
      generatedReceiptNumber: receiptNumber,
    ));
  }

  Future<void> _onPrintReceipt(
      PrintReceiptEvent event, Emitter<BillingState> emit) async {
    final printerHelper = PrinterHelper();

    if (!printerHelper.isConnected) {
      final savedMac = HiveDatabase.settingsBox.get('printer_mac');
      if (savedMac != null) {
        final connected = await printerHelper.connect(savedMac);
        if (!connected) {
          emit(state.copyWith(
              error: 'Failed to auto-connect to printer!', clearError: false));
          emit(state.copyWith(clearError: true));
          return;
        }
      } else {
        emit(state.copyWith(
            error: 'Printer not connected & no saved printer found!',
            clearError: false));
        emit(state.copyWith(clearError: true));
        return;
      }
    }

    emit(state.copyWith(
        isPrinting: true, printSuccess: false, clearError: true));

    try {
      List<Map<String, dynamic>> items = [];
      double subtotal = 0.0;
      double tax = 0.0;
      double grandTotal = 0.0;
      String? receiptNumber;
      String? invoiceNumber = event.invoiceNumber;

      if (invoiceNumber != null) {
        final tx = HiveDatabase.transactionsBox.values.firstWhere(
          (t) => t is Map && t['invoiceNumber'] == invoiceNumber,
          orElse: () => null,
        );
        if (tx != null) {
          items = List<Map<String, dynamic>>.from(
            (tx['items'] as List).map((i) => Map<String, dynamic>.from(i)),
          );
          subtotal = (tx['subtotal'] as num).toDouble();
          tax = (tx['tax'] as num).toDouble();
          grandTotal = (tx['grandTotal'] as num).toDouble();
          receiptNumber = tx['receiptNumber'] as String?;
        }
      }

      if (items.isEmpty) {
        items = state.cartItems
            .map((item) => {
                  'name': item.product.name,
                  'qty': item.quantity,
                  'price': item.product.price,
                  'total': item.total,
                })
            .toList();
        subtotal = state.subtotalAmount;
        tax = state.taxAmount;
        grandTotal = state.totalAmount;
      }

      await printerHelper.printReceipt(
          shopName: event.shopName,
          address1: event.address1,
          address2: event.address2,
          phone: event.phone,
          items: items,
          total: grandTotal,
          footer: event.footer,
          invoiceNumber: invoiceNumber,
          receiptNumber: receiptNumber,
          subtotal: subtotal,
          tax: tax);

      emit(state.copyWith(isPrinting: false, printSuccess: true));
    } catch (e) {
      emit(state.copyWith(
          isPrinting: false, error: 'Print failed: $e', clearError: false));
      emit(state.copyWith(clearError: true));
    }
  }
}
