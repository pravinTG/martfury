import 'package:flutter/material.dart';
import 'package:martfury/api_service.dart';
import 'package:martfury/theme/app_colors.dart';
import 'package:martfury/theme/app_text_styles.dart';
import 'package:martfury/widgets/async_state_view.dart';

class OrderDetailScreen extends StatelessWidget {
  const OrderDetailScreen({super.key, required this.orderId});

  final int orderId;

  @override
  Widget build(BuildContext context) {
    final apiService = ApiService();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.yellow,
        title: Text('Order #$orderId', style: const TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: apiService.getOrderById(orderId),
        builder: (context, snapshot) {
          final order = snapshot.data ?? {};
          final lineItems = (order['line_items'] as List?) ?? [];
          return AsyncStateView(
            isLoading: snapshot.connectionState == ConnectionState.waiting,
            errorMessage: snapshot.hasError
                ? 'Failed to load order detail: ${snapshot.error}'
                : null,
            onRetry: () {},
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _orderHeader(order),
                const SizedBox(height: 16),
                Text('Items', style: AppTextStyles.heading2),
                const SizedBox(height: 8),
                ...lineItems.map((item) {
                  final row = item as Map<String, dynamic>;
                  return _itemCard(row);
                }),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _orderHeader(Map<String, dynamic> order) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          _detailTile('Status', '${order['status'] ?? '-'}'),
          _detailTile('Total', '₹${order['total'] ?? '-'}', highlight: true),
          _detailTile('Payment', '${order['payment_method_title'] ?? '-'}'),
          _detailTile('Date', '${order['date_created'] ?? '-'}'),
        ],
      ),
    );
  }

  Widget _detailTile(String label, String value, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(label, style: AppTextStyles.body2),
          ),
          Expanded(
            flex: 4,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: AppTextStyles.body1.copyWith(
                fontWeight: highlight ? FontWeight.w700 : FontWeight.w500,
                color: highlight ? AppColors.yellow : AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _itemCard(Map<String, dynamic> item) {
    final imageUrl = _extractImageUrl(item);
    final quantity = int.tryParse(item['quantity'].toString()) ?? 1;
    final total = _toDouble(item['total'] ?? item['subtotal'] ?? item['price']);
    final unitPrice = quantity > 0 ? total / quantity : total;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: imageUrl.isNotEmpty
                ? Image.network(
                    imageUrl,
                    width: 74,
                    height: 74,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _placeholder(),
                  )
                : _placeholder(),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${item['name'] ?? ''}',
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
            '₹${total.toStringAsFixed(2)}',
            style: AppTextStyles.body1.copyWith(
              color: AppColors.yellow,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  String _extractImageUrl(Map<String, dynamic> item) {
    final image = item['image'];
    if (image is Map && image['src'] != null) return image['src'].toString();
    if (image is String) return image;
    final images = item['images'];
    if (images is List && images.isNotEmpty) {
      final first = images.first;
      if (first is Map && first['src'] != null) return first['src'].toString();
    }
    return '';
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0;
    final sanitized = value.toString().replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(sanitized) ?? 0;
  }

  Widget _placeholder() {
    return Container(
      width: 74,
      height: 74,
      color: AppColors.purpleLight,
      child: const Icon(Icons.fastfood_outlined, color: AppColors.yellow),
    );
  }
}
