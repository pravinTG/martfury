import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/api_endpoints.dart';
import '../services/api_service.dart';
import '../services/session_manager.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/spacing.dart';

class OrderHistoryScreen extends StatefulWidget {
  static const String routeName = '/orders';

  /// initialTab: 'In Progress' | 'Delivered' | 'Returns'
  final String initialTab;

  const OrderHistoryScreen({super.key, this.initialTab = 'In Progress'});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  String selectedTab = 'In Progress';
  bool isLoading = false;
  String? errorMessage;

  List<Map<String, dynamic>> allOrders = [];
  final List<String> tabs = const ['In Progress', 'Delivered', 'Returns'];

  int currentPage = 1;
  int totalPages = 1;
  final int itemsPerPage = 10;
  bool _isFetchingMore = false;

  final ScrollController _inProgressScrollController = ScrollController();
  final ScrollController _deliveredScrollController = ScrollController();
  final ScrollController _returnsScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    selectedTab = tabs.contains(widget.initialTab) ? widget.initialTab : 'In Progress';
    fetchOrders();

    _inProgressScrollController.addListener(_scrollListener);
    _deliveredScrollController.addListener(_scrollListener);
    _returnsScrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _inProgressScrollController.removeListener(_scrollListener);
    _deliveredScrollController.removeListener(_scrollListener);
    _returnsScrollController.removeListener(_scrollListener);
    _inProgressScrollController.dispose();
    _deliveredScrollController.dispose();
    _returnsScrollController.dispose();
    super.dispose();
  }

  ScrollController get _activeController {
    if (selectedTab == 'Delivered') return _deliveredScrollController;
    if (selectedTab == 'Returns') return _returnsScrollController;
    return _inProgressScrollController;
  }

  void _scrollListener() {
    final currentController = _activeController;
    if (!currentController.hasClients) return;
    if (currentController.position.pixels >=
            currentController.position.maxScrollExtent - 20 &&
        !isLoading &&
        !_isFetchingMore &&
        currentPage < totalPages) {
      _loadMoreOrders();
    }
  }

  Future<void> _loadMoreOrders() async {
    if (_isFetchingMore) return;
    setState(() => _isFetchingMore = true);
    currentPage++;
    await fetchOrders(isInitialFetch: false);
    if (mounted) setState(() => _isFetchingMore = false);
  }

  Future<void> fetchOrders({bool isInitialFetch = true}) async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final customerId = await SessionManager.getBackendUserId();
      final loggedIn = await SessionManager.isLoggedIn();
      if (!loggedIn || customerId == null) {
        setState(() {
          isLoading = false;
          errorMessage = 'Please log in to view your orders';
        });
        return;
      }

      final response = await ApiService.gets(
        '${ApiEndpoints.orders}?customer=$customerId&page=$currentPage&per_page=$itemsPerPage',
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // total pages from WP headers
        final totalPagesHeader = response.headers['x-wp-totalpages'];
        if (totalPagesHeader != null) {
          totalPages = int.tryParse(totalPagesHeader) ?? 1;
        }

        if (data is List) {
          final newOrders = data.map<Map<String, dynamic>>((order) {
            final o = order is Map ? Map<String, dynamic>.from(order) : <String, dynamic>{};
            return {
              'orderId': o['id']?.toString() ?? '',
              'orderNumber': o['number']?.toString() ?? '',
              'status': o['status']?.toString() ?? '',
              'total': o['total']?.toString() ?? '0',
              'currency': o['currency']?.toString() ?? '',
              'dateCreated': o['date_created']?.toString() ?? '',
              'dateCompleted': o['date_completed']?.toString(),
              'paymentMethod': o['payment_method']?.toString() ?? '',
              'billing': o['billing'],
              'shipping': o['shipping'],
              'items': (o['line_items'] is List)
                  ? (o['line_items'] as List).map((item) {
                      final i = item is Map ? Map<String, dynamic>.from(item) : <String, dynamic>{};
                      return {
                        'name': i['name'],
                        'quantity': i['quantity'],
                        'price': i['price'],
                        'subtotal': i['subtotal'],
                        'total': i['total'],
                        'image': (i['image'] is Map) ? i['image']['src'] : '',
                        'meta': i['meta_data'],
                      };
                    }).toList()
                  : <Map<String, dynamic>>[],
            };
          }).toList();

          setState(() {
            if (isInitialFetch) {
              allOrders = newOrders;
            } else {
              allOrders.addAll(newOrders);
            }
            isLoading = false;
          });
        } else {
          setState(() {
            isLoading = false;
            errorMessage = 'Invalid orders response';
          });
        }
      } else {
        setState(() {
          isLoading = false;
          errorMessage = 'Failed: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = 'Error: $e';
      });
    }
  }

  void refreshOrders() {
    setState(() {
      currentPage = 1;
      totalPages = 1;
      allOrders.clear();
    });
    fetchOrders();
  }

  @override
  Widget build(BuildContext context) {
    final completedOrdersCount = allOrders
        .where((o) => (o['status']?.toString().toLowerCase() ?? '') == 'completed')
        .length;

    final totalOrderAmount = allOrders.fold<double>(0, (sum, o) {
      final amount = double.tryParse(o['total']?.toString() ?? '0') ?? 0;
      return sum + amount;
    });

    final filteredOrders = _filterOrdersForTab(selectedTab, allOrders);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.primary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Order History',
          style: TextStyle(
            color: Colors.black,
            fontSize: 22,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStats(allOrders.length.toString(), 'Total Orders', Colors.black),
                  _buildStats(completedOrdersCount.toString(), 'Delivered', Colors.green),
                  _buildStats('₹${totalOrderAmount.toStringAsFixed(0)}', 'Total Spent', Colors.deepOrange),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(30),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: tabs.map((tab) {
                  final isSelected = tab == selectedTab;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          selectedTab = tab;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(25),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : [],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          tab,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? Colors.black : Colors.grey,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => refreshOrders(),
              child: isLoading && allOrders.isEmpty
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : errorMessage != null && allOrders.isEmpty
                      ? _emptyGraphicState(selectedTab)
                      : filteredOrders.isEmpty && !isLoading
                          ? _emptyGraphicState(selectedTab)
                          : ListView.builder(
                              controller: _activeController,
                              itemCount: filteredOrders.length + (_isFetchingMore ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (index == filteredOrders.length) {
                                  return const Padding(
                                    padding: EdgeInsets.all(12.0),
                                    child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                                  );
                                }
                                return _buildOrderCard(filteredOrders[index], index);
                              },
                            ),
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _filterOrdersForTab(String tab, List<Map<String, dynamic>> orders) {
    if (tab == 'Delivered') {
      return orders.where((o) {
        final s = (o['status']?.toString().toLowerCase() ?? '');
        return s == 'completed' || s == 'delivered';
      }).toList();
    }
    if (tab == 'Returns') {
      return orders.where((o) {
        final s = (o['status']?.toString().toLowerCase() ?? '');
        return s == 'refunded' || s == 'returned';
      }).toList();
    }
    // In Progress
    return orders.where((o) {
      final s = (o['status']?.toString().toLowerCase() ?? '');
      return s != 'completed' && s != 'delivered' && s != 'refunded' && s != 'returned';
    }).toList();
  }

  Widget _buildStats(String value, String label, Color valueColor) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order, int index) {
    final status = (order['status']?.toString().toLowerCase() ?? 'unknown');
    final orderTotal = order['total']?.toString() ?? '0';
    final dateCreated = (order['dateCreated']?.toString() ?? '').isNotEmpty
        ? (order['dateCreated'] as String).substring(0, 10)
        : '';
    final dateCompleted = (order['dateCompleted']?.toString() ?? '');
    final numberOfItems = (order['items'] is List) ? (order['items'] as List).length : 0;

    final statusInfo = _statusColors(status);
    final showDelivery = dateCompleted.isNotEmpty;

    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 300 + index * 80),
      curve: Curves.easeOut,
      tween: Tween(begin: 0, end: 1),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 20),
            child: child,
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        elevation: 5,
        shadowColor: Colors.black.withOpacity(0.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Order #${order['orderNumber']} ($numberOfItems Items)',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          dateCreated.isNotEmpty ? 'Received on $dateCreated' : '',
                          style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusInfo.$2,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      status.isNotEmpty ? status[0].toUpperCase() + status.substring(1) : 'Unknown',
                      style: TextStyle(
                        color: statusInfo.$1,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '₹$orderTotal',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  if (showDelivery)
                    Text(
                      status == 'completed'
                          ? 'Delivered on ${dateCompleted.substring(0, 10)}'
                          : '',
                      style: TextStyle(fontSize: 12, color: Colors.green),
                    ),
                ],
              ),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  if (selectedTab == 'In Progress')
                    ElevatedButton.icon(
                      onPressed: () {
                        // TODO: Reorder flow
                      },
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.black,
                        backgroundColor: Colors.grey.shade200,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.repeat, size: 18),
                      label: const Text('Reorder'),
                    ),
                  ElevatedButton.icon(
                    onPressed: () {
                      // TODO: Order detail screen (add when needed)
                    },
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.black,
                      backgroundColor: Colors.grey.shade200,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.visibility, size: 18),
                    label: const Text('View'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  (Color, Color) _statusColors(String status) {
    switch (status) {
      case 'pending':
        return (Colors.blue, Colors.blue.shade100);
      case 'processing':
        return (Colors.orange, Colors.orange.shade100);
      case 'shipped':
        return (Colors.purple, Colors.purple.shade100);
      case 'completed':
      case 'delivered':
        return (Colors.green, Colors.green.shade100);
      case 'cancelled':
        return (Colors.red, Colors.red.shade100);
      case 'refunded':
      case 'returned':
        return (Colors.deepOrange, Colors.deepOrange.shade100);
      default:
        return (Colors.grey, Colors.grey.shade300);
    }
  }

  Widget _emptyGraphicState(String tab) {
    // Keep simple (assets not guaranteed in this repo)
    final msg = tab == 'Delivered'
        ? 'No delivered orders'
        : tab == 'Returns'
            ? 'No returns found'
            : 'No ongoing orders';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 72, color: Colors.grey.shade400),
            Spacing.sizedBoxH12,
            Text(
              msg,
              style: AppTextStyles.heading3.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            Spacing.sizedBoxH12,
            TextButton(
              onPressed: refreshOrders,
              child: const Text('Refresh'),
            ),
          ],
        ),
      ),
    );
  }
}


