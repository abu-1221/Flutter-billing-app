import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive/hive.dart';
import 'config/routes/app_routes.dart';
import 'core/data/hive_database.dart';
import 'core/service_locator.dart' as di;
import 'core/theme/app_theme.dart';
import 'features/billing/presentation/bloc/billing_bloc.dart';
import 'features/product/presentation/bloc/product_bloc.dart';
import 'features/shop/presentation/bloc/shop_bloc.dart';
import 'features/settings/presentation/bloc/printer_bloc.dart';
import 'features/settings/presentation/bloc/printer_event.dart';

void main() {
  // Wrap everything in a zone to catch ALL uncaught errors
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // CRITICAL: Disable Google Fonts network fetching BEFORE building any theme.
    // This was causing the app to hang on splash screen when no internet.
    AppTheme.init();

    // Catch Flutter framework errors (widget build errors, etc.)
    FlutterError.onError = (details) {
      debugPrint("FlutterError: ${details.exceptionAsString()}");
    };

    // Robust Hive initialization with fallback
    bool hiveReady = false;
    try {
      await HiveDatabase.init();
      hiveReady = true;
    } catch (e) {
      debugPrint("Hive init failed: $e");
      try {
        await Hive.deleteFromDisk();
        await HiveDatabase.init();
        hiveReady = true;
      } catch (e2) {
        debugPrint("Hive fallback also failed: $e2");
      }
    }

    if (!hiveReady) {
      runApp(const _ErrorApp(message: 'Database failed to initialize.\nPlease uninstall and reinstall the app.'));
      return;
    }

    // Initialize dependency injection
    try {
      await di.init();
    } catch (e) {
      debugPrint("DI init failed: $e");
      runApp(_ErrorApp(message: 'App setup failed: $e'));
      return;
    }

    runApp(const MyApp());
  }, (error, stackTrace) {
    // This catches any async errors that weren't caught anywhere else
    debugPrint("Uncaught error: $error");
    debugPrint("Stack: $stackTrace");
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<ProductBloc>(
            create: (context) => di.sl<ProductBloc>()..add(LoadProducts())),
        BlocProvider<ShopBloc>(
            create: (context) => di.sl<ShopBloc>()..add(LoadShopEvent())),
        BlocProvider<BillingBloc>(
            create: (context) =>
                BillingBloc(getProductByBarcodeUseCase: di.sl())),
        BlocProvider<PrinterBloc>(
            create: (context) => di.sl<PrinterBloc>()..add(InitPrinterEvent())),
      ],
      child: MaterialApp.router(
        title: 'Billing App',
        theme: AppTheme.lightTheme,
        routerConfig: router,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

/// Fallback error screen shown if initialization fails
class _ErrorApp extends StatelessWidget {
  final String message;
  const _ErrorApp({required this.message});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                const Text(
                  'Startup Error',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
