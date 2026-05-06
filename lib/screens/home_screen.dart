import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:html_unescape/html_unescape.dart'; // Add this if not already in pubspec.yaml
import '../api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'package:http/http.dart' as http;
import 'menu_screen.dart';
import 'product_list.dart';
import 'product_detail_screen.dart'; // ADD THIS LINE
import '../widgets/async_state_view.dart';
import '../widgets/app_loader.dart';
import '../widgets/app_snackbar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = ApiService();
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _categories = [];
  bool _isLoading = true;
  bool _isLoadingMoreProducts = false;
  bool _hasMoreProducts = true;
  int _currentProductsPage = 1;
  static const int _productsPerPage = 20;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _fetchData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _products = [];
        _currentProductsPage = 1;
        _hasMoreProducts = true;
      });

      await Future.wait([
        _fetchProducts(page: 1, append: false),
        _fetchCategories(),
      ]);

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load data: $e';
        _isLoading = false;
      });
      print('Error fetching data: $e');
    }
  }

  Future<void> _fetchProducts({required int page, required bool append}) async {
    try {
      final url =
          'https://goodiesworld.techgigs.in/wp-json/wc/v3/products?per_page=$_productsPerPage&page=$page';
      final response = await http.get(
        Uri.parse(url),
        headers: {
          "Authorization": ApiService.basicAuth,
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final fetched = data.map((e) => Map<String, dynamic>.from(e)).toList();
        _hasMoreProducts = fetched.length == _productsPerPage;
        if (append) {
          _products.addAll(fetched);
        } else {
          _products = fetched;
        }
      } else {
        throw Exception('Failed to load products: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching products: $e');
    }
  }

  Future<void> _fetchCategories() async {
    try {
      _categories = await _apiService.getCategories(perPage: 100);
      final unescape = HtmlUnescape();

      _categories = _categories.where((cat) => cat['parent'] == 0).toList();

      for (var category in _categories) {
        if (category['name'] != null) {
          category['name'] = unescape.convert(category['name']);
        }
      }
    } catch (e) {
      throw Exception('Error fetching categories: $e');
    }
  }

  List<Map<String, dynamic>> _getProductsByCategoryId(int categoryId) {
    return _products.where((product) {
      List<dynamic> categories = product['categories'] ?? [];
      return categories.any((cat) => cat['id'] == categoryId);
    }).toList();
  }

  List<Map<String, dynamic>> _getFlashSaleProducts() {
    return _products.where((product) {
      return product['on_sale'] == true;
    }).take(2).toList();
  }

  Future<void> _loadMoreProducts() async {
    if (_isLoading || _isLoadingMoreProducts || !_hasMoreProducts) return;

    setState(() {
      _isLoadingMoreProducts = true;
    });

    try {
      _currentProductsPage += 1;
      await _fetchProducts(page: _currentProductsPage, append: true);
      if (mounted) setState(() {});
    } catch (_) {
      _currentProductsPage -= 1;
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMoreProducts = false;
        });
      }
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 280) {
      _loadMoreProducts();
    }
  }

  Widget _buildFancyLoader() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppLoader(size: 36),
          SizedBox(height: 12),
          Text(
            'Loading latest products...',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: AppColors.yellow,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const MenuScreen(),
              ),
            );
          },
        ),
        title: const Text(
          'Goodiesworld',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: _isLoading
          ? _buildFancyLoader()
          : AsyncStateView(
              isLoading: false,
              errorMessage: _errorMessage,
              onRetry: _fetchData,
              child: SafeArea(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHomeSearchBar(),
                      _buildTopCategories(),
                      _buildTopBanners(),
                      _buildWinterBigSale(),
                      _buildMostTrending(),
                      _buildFlashSale(),
                      ..._buildDynamicCategorySections(),
                      _buildRecentlyViewed(),
                      if (_isLoadingMoreProducts)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 20),
                          child: Center(child: AppLoader(size: 24)),
                        ),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildHomeSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Search for Sarees, Kurtis, Cosmetics, etc.',
          hintStyle: AppTextStyles.hintText,
          prefixIcon: const Icon(
            Icons.search,
            color: AppColors.textSecondary,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.border),
          ),
        ),
      ),
    );
  }

  Widget _buildTopCategories() {
    final categories = _categories.take(10).toList();
    if (categories.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 112,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final category = categories[index];
          final name = (category['name'] ?? '').toString();
          final imageUrl = category['image']?['src']?.toString();
          final categoryId = category['id'] as int;

          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProductListScreen(
                    categoryId: categoryId,
                    categoryName: name,
                  ),
                ),
              );
            },
            child: SizedBox(
              width: 86,
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: AppColors.purpleLight,
                    backgroundImage: imageUrl != null && imageUrl.isNotEmpty
                        ? NetworkImage(imageUrl)
                        : null,
                    child: imageUrl == null || imageUrl.isEmpty
                        ? const Icon(Icons.category, color: AppColors.yellow)
                        : null,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTopBanners() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        children: [
          Container(
            height: 180,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                colors: [Color(0xFF8CD8F5), Color(0xFF7CE1D2)],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Text(
                    'Kurta sets, sarees...',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'From Rs 229',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Loved styles, limited stock!',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              5,
              (index) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: index == 0 ? 20 : 7,
                height: 7,
                decoration: BoxDecoration(
                  color: index == 0 ? AppColors.yellow : AppColors.textDisabled,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildDynamicCategorySections() {
    List<Widget> sections = [];

    for (var category in _categories) {
      final categoryId = category['id'];
      final categoryName = category['name'];
      final categoryProducts = _getProductsByCategoryId(categoryId).take(4).toList();

      if (categoryProducts.isNotEmpty) {
        sections.add(_buildCategorySection(
          categoryId: categoryId,
          categoryName: categoryName,
          products: categoryProducts,
        ));
      }
    }

    return sections;
  }

  Widget _buildCategorySection({
    required int categoryId,
    required String categoryName,
    required List<Map<String, dynamic>> products,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  categoryName,
                  style: AppTextStyles.heading2,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProductListScreen(
                        categoryId: categoryId,
                        categoryName: categoryName,
                      ),
                    ),
                  );
                },
                child: Text(
                  'View All',
                  style: AppTextStyles.body2.copyWith(
                    color: AppColors.yellow,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...List.generate((products.length / 2).ceil(), (rowIndex) {
            int startIndex = rowIndex * 2;
            return Padding(
              padding: EdgeInsets.only(
                  bottom: rowIndex < (products.length / 2).ceil() - 1 ? 12 : 0),
              child: Row(
                children: [
                  Expanded(
                    child: products.length > startIndex
                        ? GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ProductDetailScreen(
                              productId: products[startIndex]['id'] as int,
                            ),
                          ),
                        );
                      },
                      child: ProductCard(product: products[startIndex]),
                    )
                        : const SizedBox(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: products.length > startIndex + 1
                        ? GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ProductDetailScreen(
                              productId: products[startIndex + 1]['id'] as int,
                            ),
                          ),
                        );
                      },
                      child: ProductCard(product: products[startIndex + 1]),
                    )
                        : const SizedBox(),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildWinterBigSale() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Winter Big Sale!',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          RichText(
            text: const TextSpan(
              children: [
                TextSpan(
                  text: 'Up to ',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                TextSpan(
                  text: '70% OFF',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: AppColors.orange,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'ArmChair Brands',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.yellow,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Shop Now',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMostTrending() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 170,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: AppColors.card,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Most Trending',
                    style: AppTextStyles.body1,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Accessories',
                    style: AppTextStyles.body1.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 55,
                        height: 55,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.yellow,
                        ),
                      ),
                      Container(
                        width: 45,
                        height: 45,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.orange,
                        ),
                        child: const Center(
                          child: Text(
                            '70%\nOFF',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
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
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 170,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: AppColors.card,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'iPhone 14 Pro',
                    style: AppTextStyles.body1,
                  ),
                  const SizedBox(height: 4),
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: 'Discount ',
                          style: AppTextStyles.body1.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        TextSpan(
                          text: '20% OFF',
                          style: AppTextStyles.body1.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.orange,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlashSale() {
    final flashSaleProducts = _getFlashSaleProducts();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Flash Sale',
                style: AppTextStyles.heading2,
              ),
              Row(
                children: [
                  Text(
                    'Ends in: ',
                    style: AppTextStyles.body2.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  _buildTimeBox('02'),
                  Text(
                    ' : ',
                    style: AppTextStyles.body2.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  _buildTimeBox('09'),
                  Text(
                    ' : ',
                    style: AppTextStyles.body2.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  _buildTimeBox('42'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (flashSaleProducts.isNotEmpty) ...[
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ProductDetailScreen(
                            productId: flashSaleProducts[0]['id'] as int,
                          ),
                        ),
                      );
                    },
                    child: ProductCard(product: flashSaleProducts[0]),
                  ),
                ),
                const SizedBox(width: 12),
                if (flashSaleProducts.length > 1)
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ProductDetailScreen(
                              productId: flashSaleProducts[1]['id'] as int,
                            ),
                          ),
                        );
                      },
                      child: ProductCard(product: flashSaleProducts[1]),
                    ),
                  )
                else
                  const Expanded(child: SizedBox()),
              ] else ...[
                const Expanded(child: SizedBox()),
                const Expanded(child: SizedBox()),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeBox(String time) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.red,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        time,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildRecentlyViewed() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recently Viewed',
            style: AppTextStyles.heading2,
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 140,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 4,
              itemBuilder: (context, index) {
                return Container(
                  width: 120,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(8),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                5,
                    (index) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: index == 0 ? 20 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: index == 0 ? AppColors.yellow : Colors.grey,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Your ProductCard remains exactly the same
class ProductCard extends StatefulWidget {
  final Map<String, dynamic>? product;
  final String? name;
  final String? price;
  final String? oldPrice;
  final double? rating;
  final int? reviews;
  final Color bgColor;
  final bool isPriceRange;

  const ProductCard({
    Key? key,
    this.product,
    this.name,
    this.price,
    this.oldPrice,
    this.rating,
    this.reviews,
    this.bgColor = AppColors.card,
    this.isPriceRange = false,
  }) : super(key: key);

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  final ApiService _apiService = ApiService();
  bool _isFavorite = false;
  bool _isToggling = false;

  Future<void> _toggleFavorite() async {
    if (_isToggling || widget.product == null) return;
    final productId = (widget.product!['id'] ?? '').toString();
    if (productId.isEmpty) return;

    setState(() => _isToggling = true);
    try {
      final response = await _apiService.toggleFavorite(productId: productId);
      final message = (response['message'] ?? 'Wishlist updated').toString();
      final removed = message.toLowerCase().contains('removed');
      if (!mounted) return;
      setState(() => _isFavorite = !removed);
      AppSnackBar.show(context, message, type: AppSnackType.success);
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.show(context, '$e', type: AppSnackType.error);
    } finally {
      if (mounted) setState(() => _isToggling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    String displayName = widget.name ?? widget.product?['name'] ?? 'Product Name';
    String displayPrice = widget.price ?? (widget.product != null ? '₹${widget.product!['price']}' : '₹0.00');
    String? displayOldPrice = widget.oldPrice ??
        (widget.product?['on_sale'] == true && widget.product?['regular_price'] != null
            ? '₹${widget.product!['regular_price']}'
            : null);
    double? displayRating = widget.rating ??
        (widget.product?['average_rating'] != null
            ? double.tryParse(widget.product!['average_rating'].toString())
            : null);
    int? displayReviews = widget.reviews ?? widget.product?['rating_count'];
    String? imageUrl = widget.product?['images']?[0]?['src'];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 120,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(8),
              ),
            ),
            child: Stack(
              children: [
                if (imageUrl != null)
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(8),
                    ),
                    child: Image.network(
                      imageUrl,
                      width: double.infinity,
                      height: 120,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Center(
                          child: Icon(Icons.image_not_supported),
                        );
                      },
                    ),
                  ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: _toggleFavorite,
                    child: Icon(
                    _isFavorite ? Icons.favorite : Icons.favorite_border,
                    size: 20,
                    color: _isFavorite ? Colors.red : AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: AppTextStyles.heading3,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                if (displayRating != null && displayReviews != null) ...[
                  Row(
                    children: [
                      ...List.generate(
                        5,
                            (index) => Icon(
                          index < displayRating!.floor()
                              ? Icons.star
                              : Icons.star_border,
                          size: 12,
                          color: AppColors.yellow,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '($displayReviews)',
                        style: AppTextStyles.body2.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                if (widget.isPriceRange)
                  Text(
                    displayPrice,
                    style: AppTextStyles.heading3.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  )
                else
                  Row(
                    children: [
                      Text(
                        displayPrice,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: displayOldPrice != null
                              ? AppColors.red
                              : AppColors.textPrimary,
                        ),
                      ),
                      if (displayOldPrice != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          displayOldPrice,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      ],
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}