import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../api_service.dart';
import '../theme/app_text_styles.dart';
import '../widgets/custom_cached_image.dart';
import 'cart_screen.dart';
import 'product_detail_screen.dart';
import 'search_screen.dart';
import '../widgets/app_snackbar.dart';

class ProductListScreen extends StatefulWidget {
  final int categoryId;
  final String categoryName;

  const ProductListScreen({
    Key? key,
    required this.categoryId,
    this.categoryName = 'Consumer Electric',
  }) : super(key: key);

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  String selectedSort = 'Best Match';
  final ApiService _apiService = ApiService();
  final Set<int> _favoriteProductIds = <int>{};
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> products = [];
  bool isLoading = true;
  int _cartCount = 0;

  @override
  void initState() {
    super.initState();
    fetchProducts();
    _loadCartCount();
  }

  Future<void> fetchProducts() async {
    try {
      setState(() {
        isLoading = true;
      });
      final fetchedProducts = await _apiService.getProductsByCategory(
        categoryId: widget.categoryId,
      );
      setState(() {
        products = fetchedProducts;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      print('Error fetching products: $e');
      if (mounted) {
        AppSnackBar.show(context, 'Failed to load products: $e', type: AppSnackType.error);
      }
    }
  }

  Future<void> _loadCartCount() async {
    try {
      final cart = await _apiService.getCart();
      final totals = cart['cart_totals'];
      int count = 0;
      if (totals != null && totals['total_items'] != null) {
        count = int.tryParse(totals['total_items'].toString()) ?? 0;
      } else if (cart['cart_items'] is List) {
        count = (cart['cart_items'] as List).length;
      }
      if (!mounted) return;
      setState(() => _cartCount = count);
    } catch (_) {
      if (!mounted) return;
      setState(() => _cartCount = 0);
    }
  }

  List<Map<String, dynamic>> get _visibleProducts {
    final query = _searchController.text.trim().toLowerCase();
    final filtered = query.isEmpty
        ? List<Map<String, dynamic>>.from(products)
        : products.where((p) {
            final name = (p['name'] ?? '').toString().toLowerCase();
            return name.contains(query);
          }).toList();

    double parsePrice(Map<String, dynamic> p) {
      final v = p['price'] ?? p['sale_price'] ?? p['regular_price'] ?? '0';
      return double.tryParse(v.toString()) ?? 0;
    }

    switch (selectedSort) {
      case 'Price: Low to High':
        filtered.sort((a, b) => parsePrice(a).compareTo(parsePrice(b)));
        break;
      case 'Price: High to Low':
        filtered.sort((a, b) => parsePrice(b).compareTo(parsePrice(a)));
        break;
      case 'Newest':
        filtered.sort((a, b) => (b['id'] ?? 0).compareTo(a['id'] ?? 0));
        break;
      case 'Top Rated':
        filtered.sort((a, b) {
          final ar = double.tryParse((a['average_rating'] ?? '0').toString()) ?? 0;
          final br = double.tryParse((b['average_rating'] ?? '0').toString()) ?? 0;
          return br.compareTo(ar);
        });
        break;
      default:
        break;
    }
    return filtered;
  }

  Future<void> _toggleFavorite(int productId) async {
    try {
      final response = await _apiService.toggleFavorite(productId: productId.toString());
      final message = (response['message'] ?? 'Wishlist updated').toString();
      final removed = message.toLowerCase().contains('removed');
      if (!mounted) return;
      setState(() {
        if (removed) {
          ApiService.wishlistProductIds.remove(productId.toString());
        } else {
          ApiService.wishlistProductIds.add(productId.toString());
        }
      });
      AppSnackBar.show(context, message, type: AppSnackType.success);
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.show(context, '$e', type: AppSnackType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColors.headerRed,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.categoryName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SearchScreen()),
              );
            },
          ),
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_bag_outlined),
                color: Colors.white,
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CartScreen()),
                  );
                  _loadCartCount();
                },
              ),
              if (_cartCount > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      _cartCount > 99 ? '99+' : '$_cartCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Search + Sort Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Search products...',
                      isDense: true,
                      prefixIcon: const Icon(Icons.search, size: 20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _buildFilterButton(selectedSort, Icons.swap_vert, () {
                  _showSortBottomSheet(context);
                }),
              ],
            ),
          ),

          // Products Grid
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : _visibleProducts.isEmpty
                    ? const Center(
                        child: Text(
                          'No products available',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.65,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: _visibleProducts.length,
                        itemBuilder: (context, index) {
                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ProductDetailScreen(
                                    productId: _visibleProducts[index]['id'],
                                  ),
                                ),
                              );
                            },
                            child: _buildProductCard(_visibleProducts[index]),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButton(String label, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: Colors.black87),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    // Extract product data from API response
    final productName = product['name'] ?? 'Unknown Product';
    final images = product['images'] as List<dynamic>?;
    final imageUrl = images != null && images.isNotEmpty
        ? images[0]['src'] as String?
        : null;
    
    // Extract price information
    final price = product['price'] ?? '0';
    final regularPrice = product['regular_price'] ?? '';
    final salePrice = product['sale_price'] ?? '';
    final hasSalePrice = salePrice.isNotEmpty && salePrice != '0';
    
    // Extract rating
    final rating = product['average_rating'] != null
        ? double.tryParse(product['average_rating'].toString()) ?? 0.0
        : 0.0;
    final reviewCount = product['rating_count'] ?? 0;
    final productId = (product['id'] ?? '').toString();
    final isFavorite = ApiService.wishlistProductIds.contains(productId);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product Image
          Container(
            height: 130,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Stack(
              children: [
                if (imageUrl != null)
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                    child: CustomCachedImage(
                      imageUrl: imageUrl,
                      width: double.infinity,
                      height: 130,
                      fit: BoxFit.cover,
                    ),
                  )
                else
                  Center(
                    child: Icon(
                      Icons.image_outlined,
                      size: 50,
                      color: Colors.grey[400],
                    ),
                  ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () => _toggleFavorite(product['id']),
                    child: Icon(
                      isFavorite
                          ? Icons.favorite
                          : Icons.favorite_border,
                      size: 20,
                      color: isFavorite
                          ? Colors.red
                          : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Product Details
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    productName,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black87,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      ...List.generate(
                        5,
                        (index) => Icon(
                          index < rating.floor()
                              ? Icons.star
                              : Icons.star_border,
                          size: 11,
                          color: const Color(0xFFFDB913),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '($reviewCount)',
                        style: const TextStyle(fontSize: 9, color: Colors.grey),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Text(
                        '₹${hasSalePrice ? salePrice : price}',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: hasSalePrice
                              ? const Color(0xFFE63946)
                              : Colors.black,
                        ),
                      ),
                      if (hasSalePrice && regularPrice.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Text(
                          '₹$regularPrice',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      ],
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

  void _showSortBottomSheet(BuildContext context) {
    final sortOptions = [
      'Best Match',
      'Price: Low to High',
      'Price: High to Low',
      'Newest',
      'Top Rated',
    ];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Sort By',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 24),
            ...sortOptions.map((option) => ListTile(
              title: Text(
                option,
                style: TextStyle(
                  color: selectedSort == option
                      ? const Color(0xFFFDB913)
                      : Colors.black87,
                  fontWeight: selectedSort == option
                      ? FontWeight.w600
                      : FontWeight.normal,
                ),
              ),
              trailing: selectedSort == option
                  ? const Icon(Icons.check, color: Color(0xFFFDB913))
                  : null,
              onTap: () {
                setState(() {
                  selectedSort = option;
                });
                Navigator.pop(context);
              },
            )),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
