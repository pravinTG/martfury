import 'dart:async';
import 'package:flutter/material.dart';
import 'package:martfury/api_service.dart';
import 'package:martfury/screens/orders_screen.dart';
import 'package:martfury/theme/app_colors.dart';
import 'package:martfury/theme/app_text_styles.dart';
import 'package:martfury/razorpay_config.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

class OrderSummaryScreen extends StatefulWidget {
  const OrderSummaryScreen({
    super.key,
    required this.cartData,
    required this.selectedAddress,
  });

  final Map<String, dynamic> cartData;
  final Map<String, dynamic> selectedAddress;

  @override
  State<OrderSummaryScreen> createState() => _OrderSummaryScreenState();
}

class _OrderSummaryScreenState extends State<OrderSummaryScreen> {
  final ApiService _apiService = ApiService();
  bool _isPlacingOrder = false;
  late Razorpay _razorpay;
  Completer<String>? _paymentCompleter;
  final TextEditingController _noteController = TextEditingController();

  List<dynamic> get _cartItems {
    final cartItems = widget.cartData['cart_items'];
    if (cartItems is List) return cartItems;
    return <dynamic>[];
  }

  double get _cartTotal {
    final rawTotal = widget.cartData['cart_total'] ??
        widget.cartData['total'] ??
        widget.cartData['cart_totals']?['total'] ??
        '0';
    final value = rawTotal.toString().replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(value) ?? 0;
  }

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();

    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, (PaymentSuccessResponse response) {
      if (_paymentCompleter != null && !_paymentCompleter!.isCompleted) {
        _paymentCompleter!.complete(response.paymentId ?? '');
      }
    });

    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, (PaymentFailureResponse response) {
      if (_paymentCompleter != null && !_paymentCompleter!.isCompleted) {
        _paymentCompleter!
            .completeError(Exception(response.message ?? 'Payment failed'));
      }
    });

    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, (ExternalWalletResponse response) {
      if (_paymentCompleter != null && !_paymentCompleter!.isCompleted) {
        _paymentCompleter!
            .completeError(Exception(response.walletName ?? 'External wallet selected'));
      }
    });
  }

  double get _subTotal {
    return _cartItems.fold<double>(0, (sum, item) {
      final row = Map<String, dynamic>.from(item as Map);
      final quantity = int.tryParse(row['quantity'].toString()) ?? 1;
      final unitPrice = _effectiveUnitPrice(row);
      return sum + (unitPrice * quantity);
    });
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0;
    final sanitized = value.toString().replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(sanitized) ?? 0;
  }

  double _extractMetaPrice(Map<String, dynamic> row, String keyName) {
    final meta = row['meta_data'];
    if (meta is! List) return 0;
    for (final entry in meta) {
      if (entry is Map && (entry['key'] ?? '').toString() == keyName) {
        final value = _toDouble(entry['value']);
        if (value > 0) return value;
      }
    }
    return 0;
  }

  double _effectiveUnitPrice(Map<String, dynamic> row) {
    final mode = (row['price_mode'] ?? '').toString().toLowerCase();
    final directWallet = _toDouble(row['wallet_price']);
    final selectedPrice = _toDouble(row['selected_price']);
    final customPrice = _toDouble(row['custom_price']);
    final metaWalletA = _extractMetaPrice(row, '_wallet_price');
    final metaWalletB = _extractMetaPrice(row, 'wallet_price');

    final walletCandidate = [
      directWallet,
      selectedPrice,
      customPrice,
      metaWalletA,
      metaWalletB,
    ].firstWhere((v) => v > 0, orElse: () => 0);

    if (mode == 'wallet' && walletCandidate > 0) {
      return walletCandidate;
    }

    return _toDouble(
      row['price'] ?? row['line_total'] ?? row['subtotal'] ?? row['total'],
    );
  }

  String _extractImageUrl(Map<String, dynamic> item) {
    final image = item['image'];
    if (image is String) return image;
    if (image is Map && image['src'] != null) return image['src'].toString();
    if (item['images'] is List && (item['images'] as List).isNotEmpty) {
      final first = (item['images'] as List).first;
      if (first is Map && first['src'] != null) return first['src'].toString();
    }
    return '';
  }

  Future<void> _placeOrder() async {
    if (_cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cart is empty')),
      );
      return;
    }
    if (_isPlacingOrder) return;

    // Razorpay amount is in paise (1 INR = 100 paise).
    final amountPaise = (_cartTotal * 100).round();
    if (amountPaise <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid cart total for payment')),
      );
      return;
    }

    setState(() => _isPlacingOrder = true);
    try {
      final address = widget.selectedAddress;
      final customerName =
          '${address['first_name'] ?? ''} ${address['last_name'] ?? ''}'.trim();
      final customerEmail = address['email']?.toString() ?? '';
      final customerPhone = address['phone']?.toString() ?? '';

      _paymentCompleter = Completer<String>();

      _razorpay.open({
        'key': RazorpayConfig.keyId,
        'amount': amountPaise,
        'currency': 'INR',
        'name': 'Goodies World',
        'description': 'Order payment',
        'prefill': {
          'contact': customerPhone,
          'email': customerEmail,
          'name': customerName.isNotEmpty ? customerName : 'Customer',
        },
        'theme': {
          'color': '#4B1F78',
        },
      });

      final paymentId = await _paymentCompleter!.future;
      if (paymentId.isEmpty) {
        throw Exception('Payment id is empty');
      }

      final billing = <String, dynamic>{
        'first_name': address['first_name'] ?? '',
        'last_name': address['last_name'] ?? '',
        'company': '',
        'address_1': address['address_1'] ?? '',
        'address_2': address['address_2'] ?? '',
        'city': address['city'] ?? '',
        'postcode': address['postcode'] ?? '',
        'country': address['country'] ?? 'IN',
        'state': address['state'] ?? '',
        'email': address['email'] ?? '',
        'phone': address['phone'] ?? '',
      };

      final shipping = <String, dynamic>{
        'first_name': address['first_name'] ?? '',
        'last_name': address['last_name'] ?? '',
        'company': '',
        'address_1': address['address_1'] ?? '',
        'address_2': address['address_2'] ?? '',
        'city': address['city'] ?? '',
        'postcode': address['postcode'] ?? '',
        'country': address['country'] ?? 'IN',
        'state': address['state'] ?? '',
        'phone': address['phone'] ?? '',
      };

      final lineItems = _cartItems.map((item) {
        final row = Map<String, dynamic>.from(item as Map);
        final unitPrice = _effectiveUnitPrice(row);
        return <String, dynamic>{
          'product_id': int.tryParse(row['product_id'].toString()) ?? 0,
          'quantity': int.tryParse(row['quantity'].toString()) ?? 1,
          if (row['variation_id'] != null)
            'variation_id': int.tryParse(row['variation_id'].toString()) ?? 0,
          if (row['name'] != null) 'name': row['name'],
          if (unitPrice > 0) 'price': unitPrice,
        };
      }).toList();

      final result = await _apiService.createOrder(
        billing: billing,
        shipping: shipping,
        lineItems: lineItems,
        paymentMethod: 'razorpay',
        paymentMethodTitle: 'Razorpay',
        setPaid: true,
        transactionId: paymentId,
      );

      final orderId =
          (result['order_id'] ?? result['id'] ?? result['number'])?.toString() ??
              '';

      if (!mounted) return;

      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: false,
        backgroundColor: Colors.transparent,
        builder: (_) => _OrderSuccessSheet(orderId: orderId),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment/order failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isPlacingOrder = false);
      }
      _paymentCompleter = null;
    }
  }

  @override
  void dispose() {
    _razorpay.clear();
    _paymentCompleter = null;
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Order Summary', style: TextStyle(color: Colors.white)),
        backgroundColor: AppColors.yellow,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _checkoutStepper(),
              const SizedBox(height: 14),
              _sectionTitle('Delivery Address'),
              _addressCard(widget.selectedAddress),
              const SizedBox(height: 14),
              _sectionTitle('Items'),
              ..._cartItems.map(
                (item) => _itemTile(Map<String, dynamic>.from(item as Map)),
              ),
              const SizedBox(height: 8),
              _sectionTitle('Customer Note'),
              TextField(
                controller: _noteController,
                enabled: !_isPlacingOrder,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Any delivery instruction?',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              _totalCard(),
              const SizedBox(height: 8),
            ],
          ),
          if (_isPlacingOrder)
            Positioned.fill(
              child: IgnorePointer(
                ignoring: true,
                child: Container(
                  color: Colors.black.withOpacity(0.06),
                  child: const Center(
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: AppColors.yellow,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: ElevatedButton(
            onPressed: _isPlacingOrder ? null : _placeOrder,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.yellow,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: _isPlacingOrder
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Place Order Securely',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _checkoutStepper() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.purpleLight),
      ),
      child: Row(
        children: const [
          _StepDot(label: 'Address', done: true),
          Expanded(child: Divider(thickness: 1)),
          _StepDot(label: 'Summary', done: true, active: true),
          Expanded(child: Divider(thickness: 1)),
          _StepDot(label: 'Payment', done: false),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }

  Widget _addressCard(Map<String, dynamic> address) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.purpleLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.location_on_outlined, color: AppColors.yellow),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${address['first_name'] ?? ''} ${address['last_name'] ?? ''}\n'
                '${address['address_1'] ?? ''}, ${address['address_2'] ?? ''}\n'
                '${address['city'] ?? ''}, ${address['state'] ?? ''} - ${address['postcode'] ?? ''}\n'
                'Phone: ${address['phone'] ?? ''}',
                style: AppTextStyles.body2.copyWith(height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _itemTile(Map<String, dynamic> item) {
    final quantity = int.tryParse(item['quantity'].toString()) ?? 1;
    final price = _effectiveUnitPrice(item);
    final subtotal = quantity * price;
    final imageUrl = _extractImageUrl(item);
    final unitPrice = quantity > 0 ? subtotal / quantity : subtotal;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _placeholderImage(),
                    )
                  : _placeholderImage(),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (item['name'] ?? 'Item').toString(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body1.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '₹${unitPrice.toStringAsFixed(2)} x $quantity',
                    style: AppTextStyles.caption,
                  ),
                ],
              ),
            ),
            Text(
              '₹${subtotal.toStringAsFixed(2)}',
              style: AppTextStyles.body1.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.yellow,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _totalCard() {
    final shipping = 0.0;
    final grandTotal = _cartTotal > 0 ? _cartTotal : _subTotal + shipping;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            _amountRow('Subtotal', _subTotal),
            const SizedBox(height: 6),
            _amountRow('Shipping', shipping),
            const Divider(height: 18),
            _amountRow(
              'Grand Total',
              grandTotal,
              highlight: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _amountRow(String label, double amount, {bool highlight = false}) {
    final style = highlight
        ? AppTextStyles.body1.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.yellow,
          )
        : AppTextStyles.body2;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: style.copyWith(color: highlight ? AppColors.yellow : null)),
        Text('₹${amount.toStringAsFixed(2)}', style: style),
      ],
    );
  }

  Widget _placeholderImage() {
    return Container(
      width: 72,
      height: 72,
      color: AppColors.purpleLight,
      child: const Icon(Icons.fastfood_outlined, color: AppColors.yellow),
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({
    required this.label,
    required this.done,
    this.active = false,
  });

  final String label;
  final bool done;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final Color bgColor = done ? AppColors.yellow : AppColors.purpleLight;
    final Color fgColor = done ? Colors.white : AppColors.textSecondary;
    return Column(
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: bgColor,
          child: Icon(
            done ? Icons.check : Icons.circle,
            size: done ? 14 : 10,
            color: fgColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: active ? AppColors.yellow : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _OrderSuccessSheet extends StatelessWidget {
  const _OrderSuccessSheet({required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: AppColors.yellow, size: 54),
            const SizedBox(height: 10),
            Text(
              'Order confirmed!',
              style: AppTextStyles.heading2.copyWith(fontSize: 20),
            ),
            const SizedBox(height: 8),
            Text(
              orderId.isNotEmpty ? 'Order #$orderId placed successfully.' : 'Placed successfully.',
              textAlign: TextAlign.center,
              style: AppTextStyles.body2.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.yellow,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () {
                  final nav = Navigator.of(context);
                  nav.pop();
                  nav.push(
                    MaterialPageRoute(builder: (_) => const OrdersScreen()),
                  );
                },
                child: const Text(
                  'View My Orders',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}
