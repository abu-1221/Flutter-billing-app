import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/entities/product.dart';
import '../../domain/usecases/product_usecases.dart';
import '../../../../core/usecase/usecase.dart';
import '../../data/models/product_model.dart';
import '../../../../core/data/hive_database.dart';

part 'product_event.dart';
part 'product_state.dart';

class ProductBloc extends Bloc<ProductEvent, ProductState> {
  final GetProductsUseCase getProductsUseCase;
  final AddProductUseCase addProductUseCase;
  final UpdateProductUseCase updateProductUseCase;
  final DeleteProductUseCase deleteProductUseCase;

  ProductBloc({
    required this.getProductsUseCase,
    required this.addProductUseCase,
    required this.updateProductUseCase,
    required this.deleteProductUseCase,
  }) : super(const ProductState()) {
    on<LoadProducts>(_onLoadProducts);
    on<AddProduct>(_onAddProduct);
    on<UpdateProduct>(_onUpdateProduct);
    on<DeleteProduct>(_onDeleteProduct);
    on<BulkAddProducts>(_onBulkAddProducts);
  }

  Future<void> _onLoadProducts(
      LoadProducts event, Emitter<ProductState> emit) async {
    emit(state.copyWith(status: ProductStatus.loading));
    final result = await getProductsUseCase(NoParams());
    result.fold(
      (failure) => emit(state.copyWith(
          status: ProductStatus.error, message: failure.message)),
      (products) => emit(
          state.copyWith(status: ProductStatus.loaded, products: products)),
    );
  }

  Future<void> _onAddProduct(
      AddProduct event, Emitter<ProductState> emit) async {
    emit(state.copyWith(status: ProductStatus.loading));
    final box = HiveDatabase.productBox;
    final exists = box.values.any((p) => p.barcode == event.product.barcode);
    if (exists) {
      final matchedProduct = box.values.firstWhere((p) => p.barcode == event.product.barcode);
      emit(state.copyWith(
        status: ProductStatus.error,
        message: 'This barcode already belongs to product:\n${matchedProduct.name}\n(Category: ${matchedProduct.category})',
      ));
      return;
    }
    final result = await addProductUseCase(event.product);
    result.fold(
      (failure) => emit(state.copyWith(
          status: ProductStatus.error, message: failure.message)),
      (_) {
        emit(state.copyWith(
            status: ProductStatus.success,
            message: 'Product added successfully'));
        add(LoadProducts());
      },
    );
  }

  Future<void> _onUpdateProduct(
      UpdateProduct event, Emitter<ProductState> emit) async {
    emit(state.copyWith(status: ProductStatus.loading));
    final box = HiveDatabase.productBox;
    final exists = box.values.any((p) => p.barcode == event.product.barcode && p.id != event.product.id);
    if (exists) {
      final matchedProduct = box.values.firstWhere((p) => p.barcode == event.product.barcode && p.id != event.product.id);
      emit(state.copyWith(
        status: ProductStatus.error,
        message: 'This barcode already belongs to product:\n${matchedProduct.name}\n(Category: ${matchedProduct.category})',
      ));
      return;
    }
    final result = await updateProductUseCase(event.product);
    result.fold(
      (failure) => emit(state.copyWith(
          status: ProductStatus.error, message: failure.message)),
      (_) {
        emit(state.copyWith(
            status: ProductStatus.success,
            message: 'Product updated successfully'));
        add(LoadProducts());
      },
    );
  }

  Future<void> _onDeleteProduct(
      DeleteProduct event, Emitter<ProductState> emit) async {
    emit(state.copyWith(status: ProductStatus.loading));
    final result = await deleteProductUseCase(event.id);
    result.fold(
      (failure) => emit(state.copyWith(
          status: ProductStatus.error, message: failure.message)),
      (_) {
        emit(state.copyWith(
            status: ProductStatus.success,
            message: 'Product deleted successfully'));
        add(LoadProducts());
      },
    );
  }

  Future<void> _onBulkAddProducts(
      BulkAddProducts event, Emitter<ProductState> emit) async {
    emit(state.copyWith(status: ProductStatus.loading));
    try {
      final box = HiveDatabase.productBox;
      int importedCount = 0;
      for (var product in event.products) {
        final exists = box.values.any((p) => p.barcode == product.barcode);
        if (exists) continue; // UNIQUE(barcode) database constraint: protect against duplicate insertion
        final model = ProductModel.fromEntity(product);
        await box.put(model.id, model);
        importedCount++;
      }
      emit(state.copyWith(
          status: ProductStatus.success,
          message: '$importedCount products imported successfully'));
      add(LoadProducts());
    } catch (e) {
      emit(state.copyWith(
          status: ProductStatus.error, message: 'Bulk import failed: $e'));
    }
  }
}
