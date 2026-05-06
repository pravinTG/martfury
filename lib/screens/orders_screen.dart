import 'package:flutter/material.dart';
import 'package:martfury/api_service.dart';
import 'package:martfury/screens/order_detail_screen.dart';
import 'package:martfury/theme/app_colors.dart';
import 'package:martfury/widgets/async_state_view.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final ApiService _apiService = ApiService();
  late Future<List<dynamic>> _ordersFuture;

  @override
  void initState() {
    super.initState();
    _ordersFuture = _apiService.getOrders();
  }

  Future<void> _refresh() async {
    final next = _apiService.getOrders();
    setState(() {
      _ordersFuture = next;
    });
    await next;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.yellow,
        title: const Text('My Orders', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _ordersFuture,
        builder: (context, snapshot) {
          final orders = snapshot.data ?? [];
          return AsyncStateView(
            isLoading: snapshot.connectionState == ConnectionState.waiting,
            errorMessage:
                snapshot.hasError ? 'Failed to load orders: ${snapshot.error}' : null,
            onRetry: () => setState(() => _ordersFuture = _apiService.getOrders()),
            isEmpty: !snapshot.hasError && snapshot.connectionState != ConnectionState.waiting && orders.isEmpty,
            emptyMessage: 'No orders found.',
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: ListView.separated(
                itemCount: orders.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final order = orders[index] as Map<String, dynamic>;
                  final orderId = order['id'];
                  final status = (order['status'] ?? '').toString();
                  final total = (order['total'] ?? '').toString();
                  final createdAt = (order['date_created'] ?? '').toString();

                  return ListTile(
                    title: Text('Order #$orderId'),
                    subtitle: Text('Status: $status\nDate: $createdAt'),
                    isThreeLine: true,
                    trailing: Text('Rs $total'),
                    onTap: () {
                      if (orderId is int) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => OrderDetailScreen(orderId: orderId),
                          ),
                        );
                      }
                    },
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
