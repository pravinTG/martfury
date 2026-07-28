import 'package:flutter/material.dart';
import 'package:martfury/screens/search_screen.dart';
import '../api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class WishlistScreen extends StatefulWidget {
  const WishlistScreen({Key? key, this.onCartChanged}) : super(key: key);

  final VoidCallback? onCartChanged;

  @override
  State<WishlistScreen> createState() => WishlistScreenState();
}

class WishlistScreenState extends State<WishlistScreen> {
  final ApiService _apiService = ApiService();

  String selectedSort = 'Default';
  List<Map<String, dynamic>> wishlistItems = [];
  List<Map<String, dynamic>> filteredItems = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadWishlist();
  }

  Future<void> refresh() async {
    await _loadWishlist();
  }

  Future<void> _loadWishlist() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await _apiService.getFavorites();
      final List<dynamic> raw = data['favorites'] ?? [];
      if (!mounted) return;
      setState(() {
        wishlistItems = raw.map((e) => Map<String, dynamic>.from(e)).toList();
        filteredItems = List.from(wishlistItems);
        _isLoading = false;
      });
      _applySort(selectedSort);
    } catch (e) {
      if (!mounted) return;
      print('💥 Failed to load Wishlist API: $e');
      setState(() {
        _error = 'Failed to load data';
        _isLoading = false;
      });
    }
  }

  Future<void> _removeFromWishlist(String productId, String name) async {
    try {
      await _apiService.toggleFavorite(productId: productId);
      setState(() {
        wishlistItems.removeWhere(
              (item) => item['id'].toString() == productId,
        );
        filteredItems.removeWhere(
              (item) => item['id'].toString() == productId,
        );
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$name removed from wishlist'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _addToCart(Map<String, dynamic> item) async {
    try {
      await _apiService.addToCart(
        productId: item['id'].toString(),
        quantity: 1,
        variationId: item['variation_id']?.toString(),
      );
      widget.onCartChanged?.call();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${item['name']} added to cart'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add to cart: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _applySort(String sort) {
    setState(() {
      selectedSort = sort;
      filteredItems = List.from(wishlistItems);

      switch (sort) {
        case 'Price: Low to High':
          filteredItems.sort((a, b) {
            final aPrice =
                double.tryParse(a['price'].toString().replaceAll(',', '')) ?? 0;
            final bPrice =
                double.tryParse(b['price'].toString().replaceAll(',', '')) ?? 0;
            return aPrice.compareTo(bPrice);
          });
          break;
        case 'Price: High to Low':
          filteredItems.sort((a, b) {
            final aPrice =
                double.tryParse(a['price'].toString().replaceAll(',', '')) ?? 0;
            final bPrice =
                double.tryParse(b['price'].toString().replaceAll(',', '')) ?? 0;
            return bPrice.compareTo(aPrice);
          });
          break;
        case 'Newest':
          filteredItems = filteredItems.reversed.toList();
          break;
        default:
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.headerRed,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Wishlist',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          // if (!_isLoading)
          //   IconButton(
          //     icon: const Icon(Icons.refresh, color: Colors.white),
          //     onPressed: _loadWishlist,
          //   ),
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SearchScreen()),
              );
            },
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.yellow),
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
                'Failed to load wishlist',
                style: AppTextStyles.body1.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: AppTextStyles.body2
                    .copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadWishlist,
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

    if (wishlistItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.favorite_border,
              size: 100,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'Your wishlist is empty',
              style: AppTextStyles.body1.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add products you love to your wishlist!',
              style:
              AppTextStyles.body2.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        _buildFilterBar(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadWishlist,
            color: AppColors.yellow,
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.62,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: filteredItems.length,
              itemBuilder: (context, index) {
                return _buildWishlistCard(filteredItems[index]);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.white,
      child: Row(
        children: [
          // Item count
          Text(
            '${filteredItems.length} item(s)',
            style: AppTextStyles.body2.copyWith(
              color: AppColors.yellow,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          InkWell(
            onTap: _showSortBottomSheet,
            child: Row(
              children: [
                Text(
                  'Sort: ',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  selectedSort,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.keyboard_arrow_down,
                  size: 18,
                  color: AppColors.textPrimary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWishlistCard(Map<String, dynamic> item) {
    final productId = item['id'].toString();
    final name = item['name'] ?? 'Unknown Product';
    final price = item['price'] ?? '0.00';
    final imageUrl = item['image'] ?? '';
    final variation = item['variation'] as Map<String, dynamic>? ?? {};
    final variationText = variation.values.join(', ');

    // Format price display
    final priceDouble = double.tryParse(price.toString()) ?? 0.0;
    final priceFormatted = '₹${priceDouble.toStringAsFixed(2)}';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Product Image ───────────────────────────────────────────────
          ClipRRect(
            borderRadius:
            const BorderRadius.vertical(top: Radius.circular(12)),
            child: SizedBox(
              height: 140,
              width: double.infinity,
              child: imageUrl.isNotEmpty
                  ? Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _placeholderImage(),
              )
                  : _placeholderImage(),
            ),
          ),

          // ── Product Details ─────────────────────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name
                  Text(
                    name,
                    style: AppTextStyles.body1.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  // Variation (if any)
                  if (variationText.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      variationText,
                      style: AppTextStyles.body2.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  const Spacer(),

                  // Price
                  Text(
                    priceFormatted,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () =>
                              _showRemoveDialog(productId, name),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                              side: BorderSide(color: Colors.grey.shade300),
                            ),
                          ),
                          child: Text(
                            'Remove',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => _addToCart(item),
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: AppColors.yellow,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.shopping_bag_outlined,
                            size: 18,
                            color: Colors.white,
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

  Widget _placeholderImage() {
    return Container(
      color: Colors.grey.shade100,
      child: Center(
        child: Icon(
          Icons.image_not_supported_outlined,
          size: 40,
          color: Colors.grey.shade400,
        ),
      ),
    );
  }

  void _showRemoveDialog(String productId, String name) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Remove from Wishlist',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          content: Text(
            'Remove "$name" from your wishlist?',
            style: const TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _removeFromWishlist(productId, name);
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
        );
      },
    );
  }

  void _showSortBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Sort by',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              _buildSortOption('Default'),
              _buildSortOption('Price: Low to High'),
              _buildSortOption('Price: High to Low'),
              _buildSortOption('Newest'),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSortOption(String option) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        option,
        style: TextStyle(
          fontSize: 14,
          color: selectedSort == option
              ? AppColors.yellow
              : AppColors.textPrimary,
          fontWeight:
          selectedSort == option ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      trailing: selectedSort == option
          ? const Icon(Icons.check, color: AppColors.yellow)
          : null,
      onTap: () {
        Navigator.pop(context);
        _applySort(option);
      },
    );
  }
}
