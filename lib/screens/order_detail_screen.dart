import 'package:flutter/material.dart';
import 'package:martfury/api_service.dart';
import 'package:martfury/theme/app_colors.dart';
import 'package:martfury/widgets/async_state_view.dart';

class OrderDetailScreen extends StatelessWidget {
  const OrderDetailScreen({super.key, required this.orderId});

  final int orderId;

  @override
  Widget build(BuildContext context) {
    final apiService = ApiService();
    return Scaffold(
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
                _detailTile('Status', '${order['status'] ?? '-'}'),
                _detailTile('Total', 'Rs ${order['total'] ?? '-'}'),
                _detailTile('Payment Method', '${order['payment_method_title'] ?? '-'}'),
                _detailTile('Date', '${order['date_created'] ?? '-'}'),
                const SizedBox(height: 16),
                const Text('Items', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                ...lineItems.map((item) {
                  final row = item as Map<String, dynamic>;
                  return Card(
                    child: ListTile(
                      title: Text('${row['name'] ?? ''}'),
                      subtitle: Text('Qty: ${row['quantity'] ?? 0}'),
                      trailing: Text('Rs ${row['total'] ?? 0}'),
                    ),
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _detailTile(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Expanded(flex: 4, child: Text(value)),
        ],
      ),
    );
  }
}
