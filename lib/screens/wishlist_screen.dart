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
        if (data['status'] == true && data['favorites'] is List) {
          setState(() {
            _wishlistProducts = List<Map<String, dynamic>>.from(data['favorites']);
            _isLoading = false;
          });
          safePrint('✅ Wishlist products fetched: ${_wishlistProducts.length} items');
        } else {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Invalid wishlist data format';
          });
          safePrint('❌ Invalid wishlist data format');
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
            _buildFilterSortBar(),
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
          IconButton(
            icon: const Icon(Icons.search, color: Colors.black),
            onPressed: () {
              // Search
            },
          ),
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_bag_outlined, color: Colors.black),
                onPressed: () {
                  // Cart
                },
              ),
              if (_cartCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$_cartCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSortBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () {
                // Filter
              },
              icon: const Icon(Icons.tune, size: 20),
              label: Text('Filter', style: AppTextStyles.body1),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                side: const BorderSide(color: AppColors.border),
              ),
            ),
          ),
          Spacing.sizedBoxW12,
          Expanded(
            child: OutlinedButton(
              onPressed: () {
                _showSortDialog();
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                side: const BorderSide(color: AppColors.border),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Sort by: $_sortBy',
                    style: AppTextStyles.body1,
                  ),
                  Spacing.sizedBoxW4,
                  const Icon(Icons.keyboard_arrow_down, size: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductsGrid() {
    // Apply sorting
    List<Map<String, dynamic>> sortedProducts = List.from(_wishlistProducts);
    
    switch (_sortBy) {
      case 'Price: Low to High':
        sortedProducts.sort((a, b) {
          final priceA = double.tryParse(a['price']?.toString() ?? '0') ?? 0;
          final priceB = double.tryParse(b['price']?.toString() ?? '0') ?? 0;
          return priceA.compareTo(priceB);
        });
        break;
      case 'Price: High to Low':
        sortedProducts.sort((a, b) {
          final priceA = double.tryParse(a['price']?.toString() ?? '0') ?? 0;
          final priceB = double.tryParse(b['price']?.toString() ?? '0') ?? 0;
          return priceB.compareTo(priceA);
        });
        break;
      case 'Newest':
        sortedProducts.sort((a, b) {
          final dateA = a['date_created']?.toString() ?? '';
          final dateB = b['date_created']?.toString() ?? '';
          return dateB.compareTo(dateA);
        });
        break;
      case 'Oldest':
        sortedProducts.sort((a, b) {
          final dateA = a['date_created']?.toString() ?? '';
          final dateB = b['date_created']?.toString() ?? '';
          return dateA.compareTo(dateB);
        });
        break;
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.7,
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
    final bool onSale = product['on_sale'] ?? false;
    final List<dynamic>? images = product['images'] as List?;
    final String? imageUrl = images != null && images.isNotEmpty 
        ? images[0]['src'] as String? 
        : null;
    final String stockStatus = product['stock_status']?.toString() ?? 'instock';
    final String productId = product['id']?.toString() ?? '';

    final double priceValue = double.tryParse(price) ?? 0.0;
    final double? regularPriceValue = regularPrice != null ? double.tryParse(regularPrice) : null;
    final bool hasDiscount = onSale && regularPriceValue != null && regularPriceValue > priceValue;
    final bool isSoldOut = stockStatus.toLowerCase() == 'outofstock';

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
                            errorBuilder: (_, __, ___) => _buildPlaceholderImage(),
                          ),
                        )
                      : _buildPlaceholderImage(),
                ),
                if (isSoldOut)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                    ),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade800,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Sold Out',
                          style: AppTextStyles.body2.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Product Info
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
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
                  Spacing.sizedBoxH8,
                  // Price
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          '₹${priceValue.toStringAsFixed(2)}',
                          style: AppTextStyles.body1.copyWith(
                            color: hasDiscount ? Colors.red : AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (hasDiscount && regularPriceValue != null) ...[
                        Spacing.sizedBoxW4,
                        Flexible(
                          child: Text(
                            '₹${regularPriceValue.toStringAsFixed(2)}',
                            style: AppTextStyles.caption.copyWith(
                              decoration: TextDecoration.lineThrough,
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const Spacer(),
                  // Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _removeFromWishlist(productId),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            side: const BorderSide(color: AppColors.border),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            'Remove',
                            style: AppTextStyles.body2.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      Spacing.sizedBoxW8,
                      Expanded(
                        child: ElevatedButton(
                          onPressed: isSoldOut ? null : () => _addToCart(product),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.shopping_bag, size: 16),
                              Spacing.sizedBoxW4,
                              Text(
                                'Add to cart',
                                style: AppTextStyles.body2.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black,
                                ),
                              ),
                            ],
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please login to remove items')),
        );
        return;
      }

      // TODO: Call API to remove from wishlist
      // For now, just remove from local list
      setState(() {
        _wishlistProducts.removeWhere((p) => p['id']?.toString() == productId);
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Removed from wishlist')),
      );
    } catch (e) {
      safePrint('Error removing from wishlist: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to remove item')),
      );
    }
  }

  Future<void> _addToCart(Map<String, dynamic> product) async {
    // TODO: Call API to add to cart
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${product['name']} added to cart')),
    );
  }
}
