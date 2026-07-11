import 'package:flutter/material.dart';
import 'package:martfury/screens/address_selection_screen.dart';
import '../api_service.dart';
import '../widgets/shimmer_loading.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key, this.onCartChanged});

  final VoidCallback? onCartChanged;

  @override
  State<CartScreen> createState() => CartScreenState();
}

class CartScreenState extends State<CartScreen> {
  final ApiService _apiService = ApiService();
  Map<String, dynamic>? _cartData;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCart();
  }

  Future<void> refresh() async {
    await _loadCart();
  }

  Future<void> _loadCart() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await _apiService.getCart();
      if (!mounted) return;
      setState(() {
        _cartData = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _removeFromCart(String productId) async {
    try {
      setState(() => _isLoading = true);
      await _apiService.removeFromCart(productId: productId);
      await _loadCart();
      widget.onCartChanged?.call();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Item removed from cart'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove item: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updateQuantity(String productId, int newQuantity, String? variationId) async {
    if (newQuantity < 1) return;
    try {
      setState(() => _isLoading = true);
      await _apiService.updateCartItem(productId: productId, quantity: newQuantity, variationId: variationId);
      await _loadCart();
      widget.onCartChanged?.call();
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update quantity: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ── Parse cart_items from API response ────────────────────────────────────
  List<dynamic> _getCartItems() {
    if (_cartData == null) return [];
    if (_cartData!.containsKey('cart_items')) {
      return _cartData!['cart_items'] ?? [];
    }
    if (_cartData!.containsKey('items')) return _cartData!['items'] ?? [];
    if (_cartData!.containsKey('data')) {
      final data = _cartData!['data'];
      if (data is List) return data;
    }
    return [];
  }

  // ── Parse cart_totals.total from API response ─────────────────────────────
  double _getCartTotal() {
    if (_cartData == null) return 0.0;
    final totals = _cartData!['cart_totals'];
    if (totals != null && totals['total'] != null) {
      return double.tryParse(totals['total'].toString()) ?? 0.0;
    }
    final total = _cartData!['total'] ?? _cartData!['cart_total'] ?? '0';
    return double.tryParse(total.toString()) ?? 0.0;
  }

  int _getTotalItems() {
    if (_cartData == null) return 0;
    final totals = _cartData!['cart_totals'];
    if (totals != null && totals['total_items'] != null) {
      return int.tryParse(totals['total_items'].toString()) ?? 0;
    }
    return _getCartItems().length;
  }

  bool _hasOutOfStockItems(List<dynamic> items) {
    return items.any((item) {
      final row = Map<String, dynamic>.from(item as Map);
      return (row['stock_status'] ?? '').toString().toLowerCase() == 'outofstock';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: AppColors.headerRed,
        elevation: 0,
        title: const Text(
          'My Cart',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        actions: [
          // if (!_isLoading)
          //   IconButton(
          //     icon: const Icon(Icons.refresh, color: Colors.white),
          //     onPressed: _loadCart,
          //   ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: _buildCheckoutBar(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 4,
        itemBuilder: (context, index) => const ShimmerCartItem(),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Failed to load cart',
                style: AppTextStyles.body1.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: AppTextStyles.body2.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadCart,
                icon: const Icon(Icons.refresh, color: Colors.white),
                label: const Text(
                  'Retry',
                  style: TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.headerRed,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final items = _getCartItems();

    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: 100,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'Your cart is empty',
              style: AppTextStyles.body1.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add items to get started!',
              style: AppTextStyles.body2.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadCart,
      color: AppColors.yellow,
      child: Column(
        children: [
          // ── Cart item count banner ────────────────────────────────────────
          Container(
            width: double.infinity,
            color: AppColors.yellow.withOpacity(0.1),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Text(
              '${_getTotalItems()} item(s) in your cart',
              style: AppTextStyles.body2.copyWith(
                color: AppColors.yellow,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          // ── Cart items list ───────────────────────────────────────────────
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = Map<String, dynamic>.from(items[index]);
                return _buildCartItem(item);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItem(Map<String, dynamic> item) {
    final productId = (item['product_id'] ?? '').toString();
    final name = item['name'] ?? 'Unknown Product';
    final quantity = item['quantity'] ?? 1;
    final price = item['price'] ?? 0;
    final subtotal = item['subtotal'] ?? 0;
    final stockStatus = item['stock_status'] ?? 'instock';
    final regularPrice = item['regular_price'] ?? '';
    final salePrice = item['sale_price'] ?? '';

    // API returns 'image' as a direct string URL
    final imageUrl = item['image'] ?? '';

    final bool isOnSale = salePrice.toString().isNotEmpty;
    final bool isOutOfStock = stockStatus == 'outofstock';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Product Image ─────────────────────────────────────────────
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: imageUrl.isNotEmpty
                      ? Image.network(
                    imageUrl,
                    width: 90,
                    height: 90,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _placeholderImage(),
                  )
                      : _placeholderImage(),
                ),
                if (isOutOfStock)
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        color: Colors.black.withOpacity(0.45),
                        alignment: Alignment.center,
                        child: const Text(
                          'Out of\nStock',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(width: 12),

            // ── Product Info ──────────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name
                  Text(
                    name,
                    style: AppTextStyles.body1.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),

                  // Quantity Adjuster
                  Container(
                    height: 32,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32),
                          icon: const Icon(Icons.remove, size: 16, color: AppColors.textPrimary),
                          onPressed: () => _updateQuantity(productId, int.parse(quantity.toString()) - 1, item['variation_id']?.toString()),
                        ),
                        Container(
                          width: 32,
                          alignment: Alignment.center,
                          child: Text(
                            '$quantity',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                        ),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32),
                          icon: const Icon(Icons.add, size: 16, color: AppColors.textPrimary),
                          onPressed: () => _updateQuantity(productId, int.parse(quantity.toString()) + 1, item['variation_id']?.toString()),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Price row
                  Row(
                    children: [
                      if (isOnSale) ...[
                        Text(
                          '₹${double.tryParse(regularPrice.toString())?.toStringAsFixed(2) ?? regularPrice}',
                          style: AppTextStyles.body2.copyWith(
                            color: Colors.grey,
                            fontSize: 12,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '₹${double.tryParse(salePrice.toString())?.toStringAsFixed(2) ?? salePrice}',
                          style: AppTextStyles.body1.copyWith(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ] else ...[
                        Text(
                          '₹${double.tryParse(price.toString())?.toStringAsFixed(2) ?? price}',
                          style: AppTextStyles.body2.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Subtotal + Stock status
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Subtotal: ₹${double.tryParse(subtotal.toString())?.toStringAsFixed(2) ?? subtotal}',
                          style: AppTextStyles.body1.copyWith(
                            color: AppColors.yellow,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: isOutOfStock
                              ? Colors.red.shade50
                              : Colors.green.shade50,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isOutOfStock ? 'Out of Stock' : 'In Stock',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isOutOfStock ? Colors.red : Colors.green,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Delete Button ─────────────────────────────────────────────
            IconButton(
              onPressed: () => _showRemoveDialog(productId, name),
              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 22),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholderImage() {
    return Container(
      width: 90,
      height: 90,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(
        Icons.image_not_supported_outlined,
        color: Colors.grey,
        size: 32,
      ),
    );
  }

  void _showRemoveDialog(String productId, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Remove Item',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text('Remove "$name" from your cart?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _removeFromCart(productId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Remove',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget? _buildCheckoutBar() {
    final items = _getCartItems();
    if (_isLoading || items.isEmpty) return null;

    final total = _getCartTotal();
    final totalItems = _getTotalItems();
    final hasOutOfStockItems = _hasOutOfStockItems(items);

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
          // ── Order summary ───────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Items ($totalItems)',
                style: AppTextStyles.body2.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                '₹${total.toStringAsFixed(2)}',
                style: AppTextStyles.body2.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total',
                style: AppTextStyles.body1.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                '₹${total.toStringAsFixed(2)}',
                style: AppTextStyles.body1.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: AppColors.yellow,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Checkout Button ─────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                if (_cartData == null) return;
                if (hasOutOfStockItems) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Product is out of stock'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddressSelectionScreen(cartData: _cartData!),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.headerRed,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 2,
              ),
              child: const Text(
                'Proceed to Checkout',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    ));
  }
}
