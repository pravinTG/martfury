import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/api_endpoints.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/cart_counter.dart';
import '../utils/safe_print.dart';
import 'cart_screen.dart';
import 'product_detail_screen.dart';

class CategoryProductsScreen extends StatefulWidget {
  final String categoryId;
  final String categoryName;

  const CategoryProductsScreen({
    super.key,
    required this.categoryId,
    required this.categoryName,
  });

  @override
  State<CategoryProductsScreen> createState() => _CategoryProductsScreenState();
}

class _CategoryProductsScreenState extends State<CategoryProductsScreen> {
  final ScrollController _scrollController = ScrollController();

  bool _isLoading = true;
  bool _isPaginating = false;
  bool _hasMore = true;
  int _page = 1;
  final int _perPage = 20;

  bool _gridView = true;
  String _sort =
      'default'; // default, popularity, price_asc, price_desc, latest, max_discount

  List<Map<String, dynamic>> _original = [];
  List<Map<String, dynamic>> _products = [];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _fetchProducts(initial: true);
    _syncCartBadge();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _syncCartBadge() async {
    await CartCounter.loadCartCount();
    if (mounted) setState(() {});
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.9) {
      if (!_isPaginating && !_isLoading && _hasMore) {
        _fetchProducts(initial: false);
      }
    }
  }

  String _sortLabel() {
    switch (_sort) {
      case 'default':
        return 'Default';
      case 'popularity':
        return 'Popular';
      case 'price_asc':
        return 'Price: Low to High';
      case 'price_desc':
        return 'Price: High to Low';
      case 'latest':
        return 'Latest';
      case 'max_discount':
        return 'Maximum Discount';
      default:
        return 'Default';
    }
  }

  Map<String, String> _apiSortParams() {
    switch (_sort) {
      case 'popularity':
        return {'orderby': 'popularity', 'order': 'desc'};
      case 'price_asc':
        return {'orderby': 'price', 'order': 'asc'};
      case 'price_desc':
        return {'orderby': 'price', 'order': 'desc'};
      case 'latest':
        return {'orderby': 'date', 'order': 'desc'};
      case 'default':
      case 'max_discount':
      default:
        return {};
    }
  }

  Future<void> _fetchProducts({required bool initial}) async {
    if (initial) {
      setState(() {
        _isLoading = true;
        _isPaginating = false;
        _hasMore = true;
        _page = 1;
        _original = [];
        _products = [];
      });
    } else {
      setState(() => _isPaginating = true);
    }

    try {
      final query = <String, String>{
        'category': widget.categoryId,
        'page': _page.toString(),
        'per_page': _perPage.toString(),
      };
      query.addAll(_apiSortParams());

      final response = await ApiService.gets(
        ApiEndpoints.products,
        queryParams: query,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final fetched = data.map((e) => Map<String, dynamic>.from(e)).toList();

        setState(() {
          _original.addAll(fetched);
          _page++;
          _hasMore = fetched.length == _perPage;
          _isLoading = false;
          _isPaginating = false;
        });

        _applyClientSideSort();
      } else {
        safePrint('❌ Products error: ${response.statusCode}');
        setState(() {
          _isLoading = false;
          _isPaginating = false;
        });
      }
    } catch (e) {
      safePrint('❌ Products exception: $e');
      setState(() {
        _isLoading = false;
        _isPaginating = false;
      });
    }
  }

  void _applyClientSideSort() {
    final temp = List<Map<String, dynamic>>.from(_original);

    if (_sort == 'max_discount') {
      temp.sort((a, b) => _discountPercent(b).compareTo(_discountPercent(a)));
    }

    setState(() => _products = temp);
  }

  double _price(Map<String, dynamic> p) {
    final sale = double.tryParse((p['sale_price'] ?? '').toString()) ?? 0.0;
    final price = double.tryParse((p['price'] ?? '').toString()) ?? 0.0;
    return (sale > 0) ? sale : price;
  }

  double _regular(Map<String, dynamic> p) {
    return double.tryParse((p['regular_price'] ?? '').toString()) ?? 0.0;
  }

  double _discountPercent(Map<String, dynamic> p) {
    final reg = _regular(p);
    final pr = _price(p);
    if (reg <= 0 || pr <= 0 || pr >= reg) return 0.0;
    return ((reg - pr) / reg) * 100;
  }

  void _showSortSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) {
        Widget item(String label, String value) {
          final selected = _sort == value;
          return ListTile(
            title: Text(label, style: AppTextStyles.body1),
            trailing: Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? AppColors.primary : Colors.grey,
            ),
            onTap: () {
              Navigator.pop(context);
              setState(() => _sort = value);
              _fetchProducts(initial: true);
            },
          );
        }

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Row(
                  children: [
                    Text('Sort By', style: AppTextStyles.heading3),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              item('Default', 'default'),
              item('Popular', 'popularity'),
              item('Price: Low to High', 'price_asc'),
              item('Price: High to Low', 'price_desc'),
              item('Latest', 'latest'),
              item('Maximum Discount', 'max_discount'),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new,
              color: Colors.black, size: 20),
        ),
        title: Text(
          widget.categoryName,
          style: AppTextStyles.heading3
              .copyWith(color: Colors.black, fontWeight: FontWeight.w700),
        ),
        actions: [
          Stack(
            children: [
              IconButton(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CartScreen()),
                  );
                  await _syncCartBadge();
                },
                icon: const Icon(Icons.shopping_bag_outlined,
                    color: Colors.black),
              ),
              if (CartCounter.cartCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      CartCounter.cartCount > 99
                          ? '99+'
                          : '${CartCounter.cartCount}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Column(
        children: [
          // Controls row (Filter / Sort / View toggle) like screenshot
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            child: Row(
              children: [
                const SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    onTap: _showSortSheet,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Text(
                            'Sort by: ${_sortLabel()}',
                            style: AppTextStyles.body2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const Spacer(),
                          const Icon(Icons.keyboard_arrow_down,
                              color: Colors.black),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                _iconSquare(
                  icon: Icons.grid_view_rounded,
                  active: _gridView,
                  onTap: () => setState(() => _gridView = true),
                ),
                const SizedBox(width: 8),
                _iconSquare(
                  icon: Icons.view_list_rounded,
                  active: !_gridView,
                  onTap: () => setState(() => _gridView = false),
                ),
              ],
            ),
          ),

          Expanded(
            child: _isLoading
                ? _buildLoadingGrid()
                : _products.isEmpty
                    ? Center(
                        child: Text(
                          'No products available',
                          style: AppTextStyles.body2
                              .copyWith(color: AppColors.textSecondary),
                        ),
                      )
                    : GridView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: _gridView ? 2 : 1,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: _gridView ? 0.72 : 3.4,
                        ),
                        itemCount: _products.length + (_isPaginating ? 2 : 0),
                        itemBuilder: (context, index) {
                          if (index >= _products.length) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(8),
                                child: CircularProgressIndicator(
                                    color: AppColors.primary),
                              ),
                            );
                          }
                          final p = _products[index];
                          return _gridView
                              ? _ProductGridTile(product: p)
                              : _ProductListTile(product: p);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _controlButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: Colors.black),
            const SizedBox(width: 8),
            Text(label, style: AppTextStyles.body2),
          ],
        ),
      ),
    );
  }

  Widget _iconSquare({
    required IconData icon,
    required bool active,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: active ? Colors.grey.shade100 : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Icon(icon, color: Colors.black),
      ),
    );
  }

  Widget _buildLoadingGrid() {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.72,
      ),
      itemCount: 6,
      itemBuilder: (_, __) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 120,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F3F3),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Container(
                    height: 10, width: 90, color: const Color(0xFFF3F3F3)),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Container(
                    height: 10, width: 130, color: const Color(0xFFF3F3F3)),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Container(
                    height: 10, width: 80, color: const Color(0xFFF3F3F3)),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ProductGridTile extends StatelessWidget {
  final Map<String, dynamic> product;

  const _ProductGridTile({required this.product});

  String _brand() {
    final brands = product['brands'] as List?;
    if (brands != null && brands.isNotEmpty) {
      return (brands.first['name'] ?? '').toString();
    }
    return '';
  }

  String _image() {
    final images = product['images'] as List?;
    if (images != null && images.isNotEmpty) {
      return (images.first['src'] ?? '').toString();
    }
    return '';
  }

  double _price() {
    final sale =
        double.tryParse((product['sale_price'] ?? '').toString()) ?? 0.0;
    final price = double.tryParse((product['price'] ?? '').toString()) ?? 0.0;
    return (sale > 0) ? sale : price;
  }

  double _regular() {
    return double.tryParse((product['regular_price'] ?? '').toString()) ?? 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final img = _image();
    final name = (product['name'] ?? 'Product').toString();
    final brand = _brand().toUpperCase();
    final rating =
        double.tryParse((product['average_rating'] ?? '0').toString()) ?? 0.0;
    final ratingCount = (product['rating_count'] ?? 0) as int;

    final pr = _price();
    final reg = _regular();
    final hasDiscount = reg > pr && pr > 0;

    return InkWell(
      onTap: () {
        final id = product['id'] as int? ?? 0;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ProductDetailScreen(productId: id)),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image section takes flexible space to prevent overflow
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Color(0xFFF3F3F3),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: img.isEmpty
                    ? null
                    : ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          topRight: Radius.circular(12),
                        ),
                        child: Image.network(
                          img,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                brand,
                style: AppTextStyles.caption.copyWith(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                name,
                style: AppTextStyles.body2
                    .copyWith(fontWeight: FontWeight.w600, fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  Text(
                    '₹${pr.toStringAsFixed(2)}',
                    style: AppTextStyles.body1.copyWith(
                      color: hasDiscount ? Colors.red : AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 6),
                  if (hasDiscount)
                    Text(
                      '₹${reg.toStringAsFixed(2)}',
                      style: AppTextStyles.caption.copyWith(
                        decoration: TextDecoration.lineThrough,
                        color: AppColors.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: Row(
                children: [
                  ...List.generate(
                    5,
                    (i) => Icon(
                      Icons.star,
                      size: 11,
                      color: i < rating.round()
                          ? AppColors.primaryDark
                          : Colors.grey.shade300,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    ratingCount.toString().padLeft(2, '0'),
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}

class _ProductListTile extends StatelessWidget {
  final Map<String, dynamic> product;

  const _ProductListTile({required this.product});

  String _image() {
    final images = product['images'] as List?;
    if (images != null && images.isNotEmpty)
      return (images.first['src'] ?? '').toString();
    return '';
  }

  double _price() {
    final sale =
        double.tryParse((product['sale_price'] ?? '').toString()) ?? 0.0;
    final price = double.tryParse((product['price'] ?? '').toString()) ?? 0.0;
    return (sale > 0) ? sale : price;
  }

  double _regular() {
    return double.tryParse((product['regular_price'] ?? '').toString()) ?? 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final img = _image();
    final name = (product['name'] ?? 'Product').toString();
    final pr = _price();
    final reg = _regular();
    final hasDiscount = reg > pr && pr > 0;

    return InkWell(
      onTap: () {
        final id = product['id'] as int? ?? 0;
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => ProductDetailScreen(productId: id)));
      },
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: const Color(0xFFF3F3F3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: img.isEmpty
                  ? null
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(img,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const SizedBox.shrink()),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: AppTextStyles.body1
                        .copyWith(fontWeight: FontWeight.w600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text(
                        '₹${pr.toStringAsFixed(2)}',
                        style: AppTextStyles.body1.copyWith(
                          color:
                              hasDiscount ? Colors.red : AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 10),
                      if (hasDiscount)
                        Text(
                          '₹${reg.toStringAsFixed(2)}',
                          style: AppTextStyles.caption.copyWith(
                            decoration: TextDecoration.lineThrough,
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
