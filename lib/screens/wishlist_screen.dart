import 'dart:convert';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/spacing.dart';
import '../utils/responsive.dart';
import '../services/api_service.dart';
import '../services/session_manager.dart';
import '../utils/safe_print.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_endpoints.dart';
import '../utils/custom_snackbar.dart';
import '../utils/cart_counter.dart';

class WishlistScreen extends StatefulWidget {
  static const String routeName = '/wishlist';

  const WishlistScreen({super.key});

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  List<Map<String, dynamic>> _wishlistProducts = [];
  bool _isLoading = true;
  String? _errorMessage;
  int _cartCount = 2;
  String _sortBy = 'Default';

  @override
  void initState() {
    super.initState();
    _fetchWishlistProducts();
  }

  Future<void> _fetchWishlistProducts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Get valid Firebase token from SessionManager
      final token = await SessionManager.getValidFirebaseToken();
      
      if (token == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Please login to view your wishlist';
        });
        safePrint('❌ No valid token available');
        return;
      }

      final response = await ApiService.gets(
        "/favorites",
        token: token,
      );

      safePrint('Wishlist API response: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Expected format:
        // {
        //   "status": true,
        //   "favorites": [
        //     {
        //       "id": 99,
        //       "name": "...",
        //       "price": "56",
        //       "regular_price": "",
        //       "sale_price": "",
        //       "image": "https://...",
        //       "is_favorite": true
        //     }
        //   ]
        // }
        if (data is Map &&
            data['status'] == true &&
            data['favorites'] is List) {
          final List<dynamic> favorites = data['favorites'];
          setState(() {
            _wishlistProducts =
                List<Map<String, dynamic>>.from(favorites);
            _isLoading = false;
          });
          safePrint(
              '✅ Wishlist products fetched: ${_wishlistProducts.length} items');
        } else {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Invalid wishlist data format';
          });
          safePrint('❌ Invalid wishlist data format: $data');
        }
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load wishlist: ${response.statusCode}';
        });
        safePrint('❌ GET Error: ${response.statusCode} - ${response.body}');
      }
    } catch (e, stackTrace) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error fetching wishlist: $e';
      });
      safePrint('❌ Fetch Wishlist Error: $e');
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
            // Filter and Sort
            // Products Grid
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : _errorMessage != null
                      ? _buildErrorState()
                      : _wishlistProducts.isEmpty
                          ? _buildEmptyState()
                          : RefreshIndicator(
                              onRefresh: _fetchWishlistProducts,
                              color: AppColors.primary,
                              child: _buildProductsGrid(),
                            ),
            ),
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
            'Wishlist',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }


  Widget _buildProductsGrid() {
    // Apply sorting (by price only for this simplified favorites format)
    List<Map<String, dynamic>> sortedProducts =
        List<Map<String, dynamic>>.from(_wishlistProducts);

    if (_sortBy == 'Price: Low to High') {
      sortedProducts.sort((a, b) {
        final priceA =
            double.tryParse(a['price']?.toString() ?? '0') ?? 0;
        final priceB =
            double.tryParse(b['price']?.toString() ?? '0') ?? 0;
        return priceA.compareTo(priceB);
      });
    } else if (_sortBy == 'Price: High to Low') {
      sortedProducts.sort((a, b) {
        final priceA =
            double.tryParse(a['price']?.toString() ?? '0') ?? 0;
        final priceB =
            double.tryParse(b['price']?.toString() ?? '0') ?? 0;
        return priceB.compareTo(priceA);
      });
    }

    final isTablet = Responsive.isTablet(context);
    final crossAxisCount = isTablet ? 3 : 2;

    // Make each grid item a bit taller (smaller aspect ratio) so
    // the image, text and two buttons fit without overflow.
    final double childAspectRatio = isTablet ? 0.7 : 0.6;

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: childAspectRatio,
      ),
      itemCount: sortedProducts.length,
      itemBuilder: (context, index) {
        return _buildProductCard(sortedProducts[index]);
      },
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    // Extract product data
    final String name = product['name'] ?? 'Product Name';
    final String price = product['price']?.toString() ?? '0';
    final String? regularPrice = product['regular_price']?.toString();
    final String? salePrice = product['sale_price']?.toString();
    final String? imageUrl = product['image']?.toString();
    final String productId = product['id']?.toString() ?? '';

    final double priceValue = double.tryParse(price) ?? 0.0;
    final double? regularPriceValue =
        regularPrice != null && regularPrice.isNotEmpty
            ? double.tryParse(regularPrice)
            : null;
    final bool hasDiscount =
        salePrice != null && salePrice.isNotEmpty && regularPriceValue != null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product Image
          Expanded(
            flex: 3,
            child: Stack(
              children: [
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: imageUrl != null
                      ? ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          _buildPlaceholderImage(),
                    ),
                  )
                      : _buildPlaceholderImage(),
                ),
              ],
            ),
          ),

          // Product Info
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                // ❌ REMOVE mainAxisSize.min to allow proper layout
                children: [
                  // Product Name
                  Text(
                    name,
                    style: AppTextStyles.body2.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 6),

                  // Price
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          '₹${priceValue.toStringAsFixed(2)}',
                          style: AppTextStyles.body1.copyWith(
                            color: hasDiscount
                                ? Colors.red
                                : AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (hasDiscount && regularPriceValue != null) ...[
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '₹${regularPriceValue.toStringAsFixed(2)}',
                            style: AppTextStyles.caption.copyWith(
                              decoration:
                              TextDecoration.lineThrough,
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),

                  const Spacer(), // ⭐ Push buttons to bottom safely

                  // Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () =>
                              _removeFromWishlist(productId),
                          style: OutlinedButton.styleFrom(
                            padding:
                            const EdgeInsets.symmetric(vertical: 6),
                            side: const BorderSide(
                                color: AppColors.border),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                              BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            'Remove',
                            style: AppTextStyles.body2.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),

                      const SizedBox(width: 6),

                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _addToCart(product),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(
                                vertical: 6),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                              BorderRadius.circular(8),
                            ),
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisAlignment:
                              MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.shopping_bag, size: 16),
                                SizedBox(width: 4),
                                Text('Add'),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
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
        size: 60,
        color: AppColors.textSecondary,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.favorite_border,
            size: 80,
            color: AppColors.textSecondary,
          ),
          Spacing.sizedBoxH16,
          Text(
            'Your wishlist is empty',
            style: AppTextStyles.heading3.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          Spacing.sizedBoxH8,
          TextButton(
            onPressed: _fetchWishlistProducts,
            child: Text(
              'Refresh',
              style: AppTextStyles.body2.copyWith(
                color: AppColors.primary,
              ),
            ),
          ),
        ],
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
              _errorMessage ?? 'Error loading wishlist',
              style: AppTextStyles.heading3.copyWith(
                color: AppColors.error,
              ),
              textAlign: TextAlign.center,
            ),
            Spacing.sizedBoxH16,
            ElevatedButton(
              onPressed: _fetchWishlistProducts,
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

  void _showSortDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Sort by',
              style: AppTextStyles.heading2,
            ),
            Spacing.sizedBoxH20,
            _buildSortOption('Default'),
            _buildSortOption('Price: Low to High'),
            _buildSortOption('Price: High to Low'),
            _buildSortOption('Newest'),
            _buildSortOption('Oldest'),
          ],
        ),
      ),
    );
  }

  Widget _buildSortOption(String option) {
    return ListTile(
      title: Text(option),
      trailing: _sortBy == option
          ? const Icon(Icons.check, color: AppColors.primary)
          : null,
      onTap: () {
        setState(() => _sortBy = option);
        Navigator.pop(context);
      },
    );
  }

  Future<void> _removeFromWishlist(String productId) async {
    try {
      final token = await SessionManager.getValidFirebaseToken();
      if (token == null) {
        CustomSnackBar.show(
          context,
          'Please login to remove items',
          isError: true,
        );
        return;
      }

      final response = await ApiService.posts(
        '/toggle-favorite',
        {
          'product_id': productId,
        },
        token: token,
      );

      if (response.statusCode == 200) {
        setState(() {
          _wishlistProducts
              .removeWhere((p) => p['id']?.toString() == productId);
        });

        final data = jsonDecode(response.body);
        CustomSnackBar.show(
          context,
          data['message'] ?? 'Removed from wishlist',
          isError: false,
        );
      } else {
        CustomSnackBar.show(
          context,
          'Failed to remove item',
          isError: true,
        );
      }
    } catch (e) {
      safePrint('Error removing from wishlist: $e');
      CustomSnackBar.show(
        context,
        'Failed to remove item',
        isError: true,
      );
    }
  }

  Future<void> _addToCart(Map<String, dynamic> product) async {
    try {
      final token = await SessionManager.getValidFirebaseToken();
      if (token == null) {
        CustomSnackBar.show(
          context,
          'Please login to add to cart',
          isError: true,
        );
        return;
      }

      final productId = product['id']?.toString() ?? '';
      if (productId.isEmpty) {
        CustomSnackBar.show(
          context,
          'Invalid product',
          isError: true,
        );
        return;
      }

      final payload = {
        'product_id': productId,
        'quantity': 1,
      };

      final response = await ApiService.posts(
        ApiEndpoints.cartAdd,
        payload,
        token: token,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        CustomSnackBar.show(
          context,
          data['message'] ?? 'Added to cart successfully',
          isError: false,
        );

        // Refresh global cart counter
        await CartCounter.loadCartCount();
        setState(() {
          _cartCount = CartCounter.cartCount;
        });
      } else {
        CustomSnackBar.show(
          context,
          'Failed to add to cart',
          isError: true,
        );
      }
    } catch (e) {
      safePrint('Error adding to cart from wishlist: $e');
      CustomSnackBar.show(
        context,
        'Something went wrong',
        isError: true,
      );
    }
  }
}
