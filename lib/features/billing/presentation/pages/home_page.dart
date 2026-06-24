import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:vibration/vibration.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../billing/presentation/bloc/billing_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/cart_item.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  MobileScannerController? _scannerController;
  bool _isScannerReady = false;
  int _titleTapCount = 0;

  // Duplicate scan cooldown map
  final Map<String, DateTime> _scannedCooldowns = {};

  @override
  void dispose() {
    _scannerController?.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) async {
    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      if (barcode.rawValue != null) {
        final rawValue = barcode.rawValue!;

        final now = DateTime.now();
        final lastScanTime = _scannedCooldowns[rawValue];
        if (lastScanTime != null && now.difference(lastScanTime).inMilliseconds < 2000) {
          // Ignore duplicate scans within 2 seconds cooldown
          continue;
        }
        _scannedCooldowns[rawValue] = now;

        // Vibrate
        try {
          final hasVibrator = await Vibration.hasVibrator();
          if (hasVibrator == true) {
            Vibration.vibrate();
          }
        } catch (_) {}

        if (mounted) {
          context.read<BillingBloc>().add(ScanBarcodeEvent(rawValue));
        }
      }
    }
  }

  void _showRemoveConfirmation(BuildContext context, CartItem item) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Remove Item?'),
          content: Text('Are you sure you want to remove "${item.product.name}" from the cart?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () {
                context.read<BillingBloc>().add(RemoveProductFromCartEvent(item.product.id));
                Navigator.pop(context);
              },
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initScanner();
    });
  }

  void _initScanner() {
    if (!mounted) return;
    try {
      _scannerController = MobileScannerController(
        detectionSpeed: DetectionSpeed.normal,
        returnImage: false,
      );
      if (mounted) {
        setState(() {
          _isScannerReady = true;
        });
      }
    } catch (e) {
      debugPrint("Scanner init failed: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: BlocListener<BillingBloc, BillingState>(
          listenWhen: (previous, current) =>
              previous.error != current.error && current.error != null,
          listener: (context, state) {
            if (state.error != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.error!),
                  backgroundColor: Colors.red,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          },
          child: Column(
            children: [
              // 1. Scanner Square (viewfinder preview container)
              Container(
                height: 250,
                color: Colors.black,
                child: _buildScannerSection(),
              ),
              const SizedBox(height: 12),
              // 2. Scanner Terminal (Controls and Title)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      // Hidden Admin Entrance (Logo / Title)
                      GestureDetector(
                        onTap: () {
                          _titleTapCount++;
                          if (_titleTapCount >= 5) {
                            _titleTapCount = 0;
                            context.push('/admin');
                          }
                        },
                        child: const Row(
                          children: [
                            Icon(Icons.crop_free, color: Colors.greenAccent, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Scanner Terminal',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      // Torch control
                      if (_isScannerReady && _scannerController != null)
                        ValueListenableBuilder<MobileScannerState>(
                          valueListenable: _scannerController!,
                          builder: (context, scannerState, child) {
                            final isTorchOn = scannerState.torchState == TorchState.on;
                            return IconButton(
                              icon: Icon(isTorchOn ? Icons.flash_on : Icons.flash_off, color: isTorchOn ? Colors.yellowAccent : Colors.white, size: 20),
                              onPressed: () {
                                _scannerController?.toggleTorch();
                              },
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            );
                          },
                        ),
                      const SizedBox(width: 16),
                      // Billing / History control (Invoice Option)
                      IconButton(
                        icon: const Icon(Icons.receipt_long, color: Colors.white, size: 20),
                        onPressed: () {
                          context.push('/history');
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // 3. Scanned Items
              Expanded(
                child: BlocBuilder<BillingBloc, BillingState>(
                  builder: (context, state) {
                    if (state.cartItems.isEmpty) {
                      return _buildEmptyCart();
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: state.cartItems.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final item = state.cartItems[index];
                        return _buildCartItemCard(context, item);
                      },
                    );
                  },
                ),
              ),
              // 4. Add Product & 5. Total Price
              BlocBuilder<BillingBloc, BillingState>(
                builder: (context, state) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(top: BorderSide(color: Colors.grey[200]!)),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -4)),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${state.cartItems.fold<int>(0, (sum, i) => sum + i.quantity)} items total',
                              style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text('TOTAL PRICE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
                                Text(
                                  '₹${state.totalAmount.toStringAsFixed(2)}',
                                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppTheme.primaryColor),
                                ),
                              ],
                            ),
                          ],
                        ),
                        // 5. Confirm Order button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: state.cartItems.isEmpty
                                ? null
                                : () async {
                                    _scannerController?.stop();
                                    await context.push('/checkout');
                                    if (mounted) _scannerController?.start();
                                  },
                            icon: const Icon(Icons.payment),
                            label: const Text('Confirm Order', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScannerSection() {
    return Container(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Show scanner only when ready, otherwise show loading
          if (_isScannerReady && _scannerController != null)
            MobileScanner(
              controller: _scannerController!,
              onDetect: _onDetect,
              errorBuilder: (context, error, child) {
                String msg = 'Unable to start scanner. Please try again.';
                final errStr = error.toString().toLowerCase();
                if (errStr.contains('permission') || errStr.contains('denied')) {
                  msg = 'Camera permission is required to use the Barcode Scanner.';
                } else if (errStr.contains('no camera') || errStr.contains('available') || errStr.contains('notfound')) {
                  msg = 'Camera is not available on this device.';
                }
                return Container(
                  color: Colors.black87,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    msg,
                    style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                );
              },
            )
          else
            const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 16),
                  Text(
                    'Initializing camera...',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),

          // Central Overlay Bounding Box (Scanner Square viewfinder)
          if (_isScannerReady)
            Center(
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white24, width: 2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Stack(
                  children: [
                    // Corners
                    _buildCorner(Alignment.topLeft),
                    _buildCorner(Alignment.topRight),
                    _buildCorner(Alignment.bottomLeft),
                    _buildCorner(Alignment.bottomRight),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCorner(Alignment alignment) {
    return Align(
      alignment: alignment,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          border: Border(
            top: (alignment == Alignment.topLeft || alignment == Alignment.topRight)
                ? const BorderSide(color: Colors.greenAccent, width: 4)
                : BorderSide.none,
            bottom: (alignment == Alignment.bottomLeft || alignment == Alignment.bottomRight)
                ? const BorderSide(color: Colors.greenAccent, width: 4)
                : BorderSide.none,
            left: (alignment == Alignment.topLeft || alignment == Alignment.bottomLeft)
                ? const BorderSide(color: Colors.greenAccent, width: 4)
                : BorderSide.none,
            right: (alignment == Alignment.topRight || alignment == Alignment.bottomRight)
                ? const BorderSide(color: Colors.greenAccent, width: 4)
                : BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyCart() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(Icons.shopping_basket, size: 40, color: Colors.grey[300]),
          ),
          const SizedBox(height: 16),
          const Text('List is empty', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Scanned items will appear here as you scan them with the camera above.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItemCard(BuildContext context, CartItem item) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.product.name,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '₹${item.product.price.toStringAsFixed(2)}',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () => _showRemoveConfirmation(context, item),
            icon: const Icon(Icons.delete_outline, size: 16),
            label: const Text('Remove Product', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[50],
              foregroundColor: Colors.red,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: Size.zero,
            ),
          ),
        ],
      ),
    );
  }
}
