import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/spacing.dart';
import 'delivery_address_screen.dart';

class CheckoutScreen extends StatefulWidget {
  static const String routeName = '/checkout';

  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  late Razorpay _razorpay;

  // Shipping and payment selections
  String _selectedShippingMethod = 'standard';
  String _selectedPaymentMethod = 'razorpay';

  // Selected address (matches design in screenshots)
  Map<String, String> _selectedAddress = {
    'name': 'John Smith',
    'phone': '020-7946-0000',
    'addressLine1': '10 Downing Street, London, SW1A 2AA',
  };

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Payment successful')),
    );
    // You can navigate to an order confirmation screen here
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Payment failed: ${response.message}')),
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('External wallet selected: ${response.walletName}')),
    );
  }

  Future<void> _changeAddress() async {
    final result = await Navigator.of(context).push<Map<String, String>>(
      MaterialPageRoute(
        builder: (_) => const DeliveryAddressScreen(),
      ),
    );

    if (result != null) {
      setState(() {
        _selectedAddress = result;
      });
    }
  }

  void _openRazorpay(double amount) {
    final int amountInPaise = (amount * 100).round();

    final options = {
      'key': 'YOUR_RAZORPAY_KEY_ID', // TODO: Replace with your Razorpay key
      'amount': amountInPaise,
      'name': 'Goodies World',
      'description': 'Order payment',
      'prefill': {
        'contact': _selectedAddress['phone'] ?? '',
        'email': 'customer@example.com',
      },
      'theme': {'color': '#FFC107'},
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      debugPrint('Error opening Razorpay: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    final double totalAmount = (args?['totalAmount'] as double?) ?? 0.0;
    final int totalItems = (args?['totalItems'] as int?) ?? 0;

    final double deliveryFee =
        _selectedShippingMethod == 'standard' ? 10.0 : 19.0;
    const double couponDiscount = 25.0;
    final double subtotal = totalAmount;
    final double totalPayable =
        (subtotal + deliveryFee - couponDiscount).clamp(0, double.infinity);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Checkout',
          style: AppTextStyles.heading3.copyWith(color: Colors.black),
        ),
        centerTitle: false,
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Icon(
              Icons.headset_mic_outlined,
              color: Colors.black,
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Shipping address section
            Container(
              color: AppColors.primary,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Shipping Address',
                    style: AppTextStyles.heading3.copyWith(
                      color: Colors.black,
                    ),
                  ),
                  Spacing.sizedBoxH12,
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          color: Colors.orange,
                        ),
                        Spacing.sizedBoxW12,
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    _selectedAddress['name'] ?? '',
                                    style: AppTextStyles.body1.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Spacing.sizedBoxW8,
                                  Text(
                                    '│',
                                    style: AppTextStyles.caption.copyWith(
                                      color: Colors.grey,
                                    ),
                                  ),
                                  Spacing.sizedBoxW8,
                                  Text(
                                    _selectedAddress['phone'] ?? '',
                                    style: AppTextStyles.caption.copyWith(
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                              Spacing.sizedBoxH4,
                              Text(
                                _selectedAddress['addressLine1'] ?? '',
                                style: AppTextStyles.body2.copyWith(
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Spacing.sizedBoxW12,
                        TextButton(
                          onPressed: _changeAddress,
                          child: const Text('Change'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Decorative separator
            Container(
              height: 4,
              color: Colors.white,
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      height: 4,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        gradient: const LinearGradient(
                          colors: [
                            Colors.red,
                            Colors.blue,
                            Colors.red,
                            Colors.blue,
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Shipping method
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Shipping Method',
                    style: AppTextStyles.heading3,
                  ),
                  Spacing.sizedBoxH8,
                  _buildShippingOption(
                    title: 'Standard Shipping',
                    subtitle:
                        'Estimated delivery time: Jan 03 - Jan 05, 2025',
                    price: 10.0,
                    value: 'standard',
                    groupValue: _selectedShippingMethod,
                    onChanged: (value) {
                      setState(() {
                        _selectedShippingMethod = value;
                      });
                    },
                  ),
                  Spacing.sizedBoxH8,
                  _buildShippingOption(
                    title: 'Express Shipping',
                    subtitle:
                        'Estimated delivery time: Jan 01 - Jan 03, 2025',
                    price: 19.0,
                    value: 'express',
                    groupValue: _selectedShippingMethod,
                    onChanged: (value) {
                      setState(() {
                        _selectedShippingMethod = value;
                      });
                    },
                  ),
                ],
              ),
            ),
            // Payment method
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Payment Method',
                    style: AppTextStyles.heading3,
                  ),
                  Spacing.sizedBoxH8,
                  _buildPaymentOption(
                    title: 'Cash on Delivery',
                    value: 'cod',
                  ),
                  _buildPaymentOption(
                    title: 'Razorpay (Cards / UPI / Wallets)',
                    value: 'razorpay',
                  ),
                  _buildPaymentOption(
                    title: 'Paypal',
                    value: 'paypal',
                  ),
                ],
              ),
            ),
            Spacing.sizedBoxH16,
            // Promo code
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Promo Code',
                    style: AppTextStyles.heading3,
                  ),
                  Spacing.sizedBoxH8,
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Enter your code',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                          ),
                        ),
                      ),
                      Spacing.sizedBoxW8,
                      ElevatedButton(
                        onPressed: () {
                          // TODO: Apply coupon logic
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[200],
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                        ),
                        child: const Text('Apply'),
                      ),
                    ],
                  ),
                  Spacing.sizedBoxH8,
                  Row(
                    children: [
                      const Icon(
                        Icons.local_offer_outlined,
                        size: 18,
                        color: Colors.red,
                      ),
                      Spacing.sizedBoxW4,
                      Text(
                        'Coupons',
                        style: AppTextStyles.body2,
                      ),
                      const Spacer(),
                      Text(
                        '- \$${couponDiscount.toStringAsFixed(2)}',
                        style: AppTextStyles.body2.copyWith(
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Spacing.sizedBoxH16,
            // Order summary
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Order Summary',
                    style: AppTextStyles.heading3,
                  ),
                  Spacing.sizedBoxH8,
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        _buildSummaryRow(
                          'Subtotal ($totalItems items)',
                          subtotal,
                          isBold: false,
                          oldPrice: subtotal == 0 ? null : subtotal + 64.0,
                        ),
                        Spacing.sizedBoxH8,
                        _buildSummaryRow(
                          'Delivery Fee',
                          deliveryFee,
                          isBold: false,
                        ),
                        Spacing.sizedBoxH8,
                        _buildSummaryRow(
                          'Coupon',
                          -couponDiscount,
                          isBold: false,
                          isNegative: true,
                        ),
                        const Divider(height: 24),
                        _buildSummaryRow(
                          'Total',
                          totalPayable,
                          isBold: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Spacing.sizedBoxH16,
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (_selectedPaymentMethod == 'razorpay') {
                      _openRazorpay(totalPayable);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Only Razorpay flow is wired in this demo.',
                          ),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Place Order',
                    style: AppTextStyles.body1.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
              Spacing.sizedBoxH8,
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.lock_outline,
                    size: 16,
                    color: Colors.grey,
                  ),
                  Spacing.sizedBoxW4,
                  Text(
                    'All data will be encrypted',
                    style: AppTextStyles.caption.copyWith(
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShippingOption({
    required String title,
    required String subtitle,
    required double price,
    required String value,
    required String groupValue,
    required ValueChanged<String> onChanged,
  }) {
    final bool isSelected = value == groupValue;

    return GestureDetector(
      onTap: () => onChanged(value),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            Radio<String>(
              value: value,
              groupValue: groupValue,
              activeColor: AppColors.primary,
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.body1.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Spacing.sizedBoxH4,
                  Text(
                    subtitle,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Spacing.sizedBoxW8,
            Text(
              '\$${price.toStringAsFixed(2)}',
              style: AppTextStyles.body1.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentOption({
    required String title,
    required String value,
  }) {
    return RadioListTile<String>(
      value: value,
      groupValue: _selectedPaymentMethod,
      activeColor: AppColors.primary,
      onChanged: (val) {
        if (val != null) {
          setState(() {
            _selectedPaymentMethod = val;
          });
        }
      },
      title: Text(
        title,
        style: AppTextStyles.body1,
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    double amount, {
    bool isBold = false,
    bool isNegative = false,
    double? oldPrice,
  }) {
    final TextStyle valueStyle = (isBold
            ? AppTextStyles.heading3
            : AppTextStyles.body1)
        .copyWith(
      color: isNegative ? Colors.red : Colors.black,
      fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTextStyles.body2,
        ),
        Row(
          children: [
            if (oldPrice != null)
              Text(
                '\$${oldPrice.toStringAsFixed(2)}',
                style: AppTextStyles.caption.copyWith(
                  color: Colors.grey,
                  decoration: TextDecoration.lineThrough,
                ),
              ),
            if (oldPrice != null) Spacing.sizedBoxW4,
            Text(
              (isNegative ? '- ' : '') +
                  '\$${amount.abs().toStringAsFixed(2)}',
              style: valueStyle,
            ),
          ],
        ),
      ],
    );
  }
}
