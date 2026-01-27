import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/api_endpoints.dart';
import '../services/api_service.dart';
import '../services/session_manager.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/cart_counter.dart';
import '../utils/custom_snackbar.dart';
import '../utils/safe_print.dart';
import '../widgets/spacing.dart';
import 'checkout_screen.dart';

class CartScreen extends StatefulWidget {
  static const String routeName = '/cart';

  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => CartScreenState();
}

class CartScreenState extends State<CartScreen> with AutomaticKeepAliveClientMixin {
  List<Map<String, dynamic>> _cartItems = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _errorMessage;
  int _currentPage = 1;
  int _perPage = 10;
  bool _hasMore = true;
  final ScrollController _scrollController = ScrollController();
  double _totalAmount = 0.0;
  int _totalItems = 0;
  bool _hasLoadedOnce = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    safePrint('🛒 CartScreen initState called');
    _scrollController.addListener(_onScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Load cart items when screen becomes visible
    if (!_hasLoadedOnce) {
      safePrint('🛒 CartScreen didChangeDependencies - Loading cart items');
      _hasLoadedOnce = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _loadCartItems();
        }
      });
    }
  }

  // Public method to refresh cart from outside
  Future<void> refreshCart() async {
    safePrint('🛒 refreshCart() called from outside');
    if (mounted) {
      await _loadCartItems(refresh: true);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      if (!_isLoadingMore && _hasMore) {
        _loadMoreCartItems();
      }
    }
  }

  Future<void> _loadCartItems({bool refresh = false}) async {
    safePrint('🛒 _loadCartItems called - refresh: $refresh');
    
    if (refresh) {
      setState(() {
        _currentPage = 1;
        _hasMore = true;
        _cartItems = [];
      });
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final token = await SessionManager.getValidFirebaseToken();
      safePrint('🛒 Token available: ${token != null}');
      
      if (token == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Please login to view your cart';
        });
        return;
      }

      safePrint('🛒 Calling API: ${ApiEndpoints.cartList}');
      safePrint('🛒 Query params: page=${_currentPage}, per_page=${_perPage}');
      
      final response = await ApiService.gets(
        ApiEndpoints.cartList,
        token: token,
        queryParams: {
          'page': _currentPage.toString(),
          'per_page': _perPage.toString(),
        },
      );
      
      safePrint('🛒 API Response Status: ${response.statusCode}');
      safePrint('🛒 API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        safePrint('Cart API response: $data');

        // Handle different response formats
        List<Map<String, dynamic>> items = [];
        if (data is Map) {
          // New custom format: { status, cart_items: [...], cart_totals: {...} }
          if (data['cart_items'] != null && data['cart_items'] is List) {
            items = List<Map<String, dynamic>>.from(data['cart_items']);
          } else if (data['items'] != null && data['items'] is List) {
            items = List<Map<String, dynamic>>.from(data['items']);
          } else if (data['cart'] != null && data['cart'] is List) {
            items = List<Map<String, dynamic>>.from(data['cart']);
          } else if (data['data'] != null && data['data'] is List) {
            items = List<Map<String, dynamic>>.from(data['data']);
          }

          // Update totals if available
          if (data['cart_totals'] != null && data['cart_totals'] is Map) {
            final totals = data['cart_totals'] as Map<String, dynamic>;
            _totalAmount =
                double.tryParse(totals['total']?.toString() ?? '0') ?? 0.0;
            _totalItems =
                int.tryParse(totals['total_items']?.toString() ?? '0') ?? 0;
          } else {
            if (data['total'] != null) {
              _totalAmount = double.tryParse(data['total'].toString()) ?? 0.0;
            }
            if (data['total_items'] != null) {
              _totalItems = int.tryParse(data['total_items'].toString()) ?? 0;
            }
          }
        } else if (data is List) {
          items = List<Map<String, dynamic>>.from(data);
        }

        setState(() {
          if (refresh) {
            _cartItems = items;
          } else {
            _cartItems.addAll(items);
          }
          _hasMore = items.length >= _perPage;
          _isLoading = false;
        });

        // Calculate total if not provided by API
        if (_totalAmount == 0.0) {
          _calculateTotal();
        }

        // Sync global cart counter so badges update
        CartCounter.updateCartCount(_totalItems, total: _totalAmount);
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load cart: ${response.statusCode}';
        });
        safePrint('❌ Error loading cart: ${response.statusCode} - ${response.body}');
      }
    } catch (e, stackTrace) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error loading cart: $e';
      });
      safePrint('❌ Exception loading cart: $e');
      safePrint('Stack trace: $stackTrace');
    }
  }

  Future<void> _loadMoreCartItems() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() {
      _isLoadingMore = true;
      _currentPage++;
    });

    try {
      final token = await SessionManager.getValidFirebaseToken();
      if (token == null) return;

      final response = await ApiService.gets(
        ApiEndpoints.cartList,
        token: token,
        queryParams: {
          'page': _currentPage.toString(),
          'per_page': _perPage.toString(),
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        List<Map<String, dynamic>> items = [];
        
        if (data is Map) {
          if (data['cart_items'] != null && data['cart_items'] is List) {
            items = List<Map<String, dynamic>>.from(data['cart_items']);
          } else if (data['items'] != null && data['items'] is List) {
            items = List<Map<String, dynamic>>.from(data['items']);
          } else if (data['cart'] != null && data['cart'] is List) {
            items = List<Map<String, dynamic>>.from(data['cart']);
          } else if (data['data'] != null && data['data'] is List) {
            items = List<Map<String, dynamic>>.from(data['data']);
          }
        } else if (data is List) {
          items = List<Map<String, dynamic>>.from(data);
        }

        setState(() {
          _cartItems.addAll(items);
          _hasMore = items.length >= _perPage;
          _isLoadingMore = false;
        });

        _calculateTotal();
        CartCounter.updateCartCount(_totalItems, total: _totalAmount);
      } else {
        setState(() {
          _isLoadingMore = false;
          _currentPage--; // Revert page increment on error
        });
      }
    } catch (e) {
      setState(() {
        _isLoadingMore = false;
        _currentPage--; // Revert page increment on error
      });
      safePrint('Error loading more cart items: $e');
    }
  }

  void _calculateTotal() {
    double total = 0.0;
    int totalItems = 0;
    
    for (var item in _cartItems) {
      final quantity = int.tryParse(item['quantity']?.toString() ?? '1') ?? 1;
      final price = double.tryParse(item['price']?.toString() ?? '0') ?? 0.0;
      total += price * quantity;
      totalItems += quantity;
    }
    
    setState(() {
      _totalAmount = total;
      _totalItems = totalItems;
    });
  }

  /// Update quantity similar to old CartPage logic (using product & variation IDs)
  Future<void> _updateQuantity(int index, int newQuantity) async {
    if (newQuantity < 1) {
      await _removeItem(index);
      return;
    }

    try {
      final token = await SessionManager.getValidFirebaseToken();
      if (token == null) return;

      final item = _cartItems[index];
      final String productId =
          item['product_id']?.toString() ?? item['id']?.toString() ?? '';
      final String? variationId =
          item['variation_id'] != null ? item['variation_id'].toString() : null;

      final payload = <String, dynamic>{
        'product_id': productId,
        'quantity': newQuantity,
        if (variationId != null && variationId.isNotEmpty)
          'variation_id': variationId,
      };

      safePrint('🛒 Update cart payload: $payload');

      final response = await ApiService.posts(
        ApiEndpoints.cartUpdate,
        payload,
        token: token,
      );

      safePrint('🛒 Update cart status: ${response.statusCode}');
      safePrint('🛒 Update cart body: ${response.body}');

      if (response.statusCode == 200) {
        setState(() {
          _cartItems[index]['quantity'] = newQuantity;
        });
        _calculateTotal();
        CustomSnackBar.show(context, 'Quantity updated', isError: false);
      } else {
        CustomSnackBar.show(context, 'Failed to update cart', isError: true);
      }
    } catch (e, stackTrace) {
      CustomSnackBar.show(context, 'Something went wrong', isError: true);
      safePrint('Error updating quantity: $e');
      safePrint('Stack trace: $stackTrace');
    }
  }

  /// Remove item similar to old CartPage logic (using product & variation IDs)
  Future<void> _removeItem(int index) async {
    try {
      final token = await SessionManager.getValidFirebaseToken();
      if (token == null) return;

      final item = _cartItems[index];
      final String productId =
          item['product_id']?.toString() ?? item['id']?.toString() ?? '';
      final String? variationId =
          item['variation_id'] != null ? item['variation_id'].toString() : null;

      final payload = <String, dynamic>{
        'product_id': productId,
        if (variationId != null && variationId.isNotEmpty)
          'variation_id': variationId,
      };

      safePrint('🛒 Remove cart payload: $payload');

      // If your backend supports /cart/remove like in the old project,
      // use ApiEndpoints.cartRemove; otherwise keep using cartUpdate with quantity 0.
      final response = await ApiService.posts(
        ApiEndpoints.cartRemove,
        payload,
        token: token,
      );

      safePrint('🛒 Remove cart status: ${response.statusCode}');
      safePrint('🛒 Remove cart body: ${response.body}');

      if (response.statusCode == 200) {
        setState(() {
          _cartItems.removeAt(index);
        });
        _calculateTotal();
        CustomSnackBar.show(context, 'Item removed from cart', isError: false);
      } else {
        CustomSnackBar.show(context, 'Failed to remove item', isError: true);
      }
    } catch (e, stackTrace) {
      CustomSnackBar.show(context, 'Something went wrong', isError: true);
      safePrint('Error removing item: $e');
      safePrint('Stack trace: $stackTrace');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(),
            // Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : _errorMessage != null
                      ? _buildErrorState()
                      : _cartItems.isEmpty
                          ? _buildEmptyState()
                          : _buildCartList(),
            ),
            // Total and Checkout
            if (_cartItems.isNotEmpty) _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: AppColors.primary,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Text(
            'Cart',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartList() {
    return RefreshIndicator(
      onRefresh: () => _loadCartItems(refresh: true),
      color: AppColors.primary,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: _cartItems.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _cartItems.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            );
          }
          return _buildCartItem(_cartItems[index], index);
        },
      ),
    );
  }

  Widget _buildCartItem(Map<String, dynamic> item, int index) {
    final productName = item['name'] ?? item['product_name'] ?? 'Product';
    final quantity = int.tryParse(item['quantity']?.toString() ?? '1') ?? 1;
    final price = double.tryParse(item['price']?.toString() ?? '0') ?? 0.0;
    final lineTotal =
        double.tryParse(item['price']?.toString() ?? '0') ?? (price * quantity);
    final imageUrl = item['image'] ?? item['product_image'] ?? '';
    final variation = item['variation'] ?? {};

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product Image
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(8),
            ),
            child: imageUrl != null && imageUrl.toString().isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      imageUrl.toString(),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildPlaceholderImage(),
                    ),
                  )
                : _buildPlaceholderImage(),
          ),
          Spacing.sizedBoxW12,
          // Product Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  productName,
                  style: AppTextStyles.body1.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (variation.isNotEmpty) ...[
                  Spacing.sizedBoxH4,
                  Text(
                    variation.entries
                        .map((e) => '${e.key}: ${e.value}')
                        .join(', '),
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                Spacing.sizedBoxH8,
                // Quantity Controls
                Row(
                  children: [
                    // ================= QUANTITY CONTROLLER =================
                    Expanded(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 120),
                        // 🔥 hard limit
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.border),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.max, // 🔥 MUST be max
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove, size: 18),
                                onPressed: quantity > 1
                                    ? () => _updateQuantity(index, quantity - 1)
                                    : null,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 32,
                                  minHeight: 32,
                                ),
                              ),
                              Text(
                                quantity.toString(),
                                style: AppTextStyles.body2.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add, size: 18),
                                onPressed: () =>
                                    _updateQuantity(index, quantity + 1),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 32,
                                  minHeight: 32,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    // ================= PRICE =================
                    SizedBox(
                      width: 64, // 🔥 fixed price width = no overflow
                      child: Text(
                        '₹${lineTotal.toStringAsFixed(2)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: AppTextStyles.body2.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
          // Remove Button
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: () => _removeItem(index),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Items:',
                style: AppTextStyles.body1,
              ),
              Text(
                '$_totalItems',
                style: AppTextStyles.body1.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          Spacing.sizedBoxH8,
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Amount:',
                style: AppTextStyles.heading3,
              ),
              Text(
                '₹${_totalAmount.toStringAsFixed(2)}',
                style: AppTextStyles.heading2.copyWith(
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          Spacing.sizedBoxH16,
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                // Navigate to checkout with cart summary
                Navigator.of(context).pushNamed(
                  CheckoutScreen.routeName,
                  arguments: {
                    'totalAmount': _totalAmount,
                    'totalItems': _totalItems,
                  },
                );
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
                'Proceed to Checkout',
                style: AppTextStyles.body1.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderImage() {
    return Center(
      child: Icon(
        Icons.image,
        size: 40,
        color: AppColors.textSecondary,
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 80,
              color: AppColors.error,
            ),
            Spacing.sizedBoxH16,
            Text(
              _errorMessage ?? 'Error loading cart',
              style: AppTextStyles.heading3.copyWith(
                color: AppColors.error,
              ),
              textAlign: TextAlign.center,
            ),
            Spacing.sizedBoxH16,
            ElevatedButton(
              onPressed: () => _loadCartItems(refresh: true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.black,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: 100,
              color: AppColors.textSecondary,
            ),
            Spacing.sizedBoxH16,
            Text(
              'Your cart is empty',
              style: AppTextStyles.heading2.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            Spacing.sizedBoxH8,
            Text(
              'Add items to your cart to continue shopping',
              style: AppTextStyles.body2.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            Spacing.sizedBoxH24,
            ElevatedButton(
              onPressed: () {
                // Navigate to home
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
              child: Text(
                'Start Shopping',
                style: AppTextStyles.body1.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

