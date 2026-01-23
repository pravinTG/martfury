import 'dart:convert';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/cart_counter.dart';
import '../widgets/spacing.dart';
import '../utils/responsive.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../services/api_endpoints.dart';
import '../utils/safe_print.dart';
import 'product_detail_screen.dart';
import 'package:google_fonts/google_fonts.dart';

class HomepageScreen extends StatefulWidget {
  static const String routeName = '/homepage';

  const HomepageScreen({super.key});

  @override
  State<HomepageScreen> createState() => _HomepageScreenState();
}

class _HomepageScreenState extends State<HomepageScreen> {
  final AuthService _authService = AuthService();
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _flashSaleProducts = [];
  List<Map<String, dynamic>> _clothingProducts = [];
  List<Map<String, dynamic>> _techProducts = [];
  List<Map<String, dynamic>> _electronicsProducts = [];
  bool _isLoading = true;
  int _currentFlashSaleIndex = 0;
  int _currentCategoryIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadProducts();
    // Load cart count when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      CartCounter.loadCartCount();
    });
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    
    try {
      final response = await ApiService.gets(ApiEndpoints.products);
      
      if (response.statusCode == 200) {
        final List<dynamic> productsData = jsonDecode(response.body);
        final List<Map<String, dynamic>> products = 
            productsData.map((item) => Map<String, dynamic>.from(item)).toList();

        safePrint('✅ Loaded ${products.length} products');

        // Filter products by categories
        final flashSale = products.where((p) => p['on_sale'] == true || p['featured'] == true).take(2).toList();
        final clothing = products.where((p) {
          final categories = p['categories'] as List?;
          if (categories == null) return false;
          return categories.any((cat) => 
            (cat['name'] as String? ?? '').toLowerCase().contains('clothing') ||
            (cat['name'] as String? ?? '').toLowerCase().contains('apparel')
          );
        }).take(4).toList();
        
        final tech = products.where((p) {
          final categories = p['categories'] as List?;
          if (categories == null) return false;
          return categories.any((cat) => 
            (cat['name'] as String? ?? '').toLowerCase().contains('computer') ||
            (cat['name'] as String? ?? '').toLowerCase().contains('technology') ||
            (cat['name'] as String? ?? '').toLowerCase().contains('tech')
          );
        }).take(4).toList();
        
        final electronics = products.where((p) {
          final categories = p['categories'] as List?;
          if (categories == null) return false;
          return categories.any((cat) => 
            (cat['name'] as String? ?? '').toLowerCase().contains('electric') ||
            (cat['name'] as String? ?? '').toLowerCase().contains('electronic')
          );
        }).take(4).toList();

        setState(() {
          _products = products;
          _flashSaleProducts = flashSale.isNotEmpty ? flashSale : products.take(2).toList();
          _clothingProducts = clothing.isNotEmpty ? clothing : products.take(4).toList();
          _techProducts = tech.isNotEmpty ? tech : products.skip(4).take(4).toList();
          _electronicsProducts = electronics.isNotEmpty ? electronics : products.skip(8).take(4).toList();
          _isLoading = false;
        });
      } else {
        safePrint('❌ Error loading products: ${response.statusCode}');
        setState(() => _isLoading = false);
      }
    } catch (e, stackTrace) {
      safePrint('❌ Exception loading products: $e');
      safePrint('Stack trace: $stackTrace');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header with logo, cart, and notification
            _buildHeader(),
            // Search Bar
            _buildSearchBar(),
            // Main Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : RefreshIndicator(
                      onRefresh: _loadProducts,
                      color: AppColors.primary,
                      child: SingleChildScrollView(
                        padding: EdgeInsets.symmetric(
                          horizontal: Responsive.width(context, 0.04),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Spacing.sizedBoxH16,
                            // Promotional Banner
                            _buildPromoBanner(),
                            Spacing.sizedBoxH20,
                            // Feature Cards
                            _buildFeatureCards(),
                            Spacing.sizedBoxH24,
                            // Flash Sale Section
                            _buildFlashSaleSection(),
                            Spacing.sizedBoxH24,
                            // Category Sections
                            _buildCategorySection('Clothing & Apparel', _clothingProducts),
                            Spacing.sizedBoxH24,
                            _buildCategorySection('Computer & Technology', _techProducts),
                            Spacing.sizedBoxH24,
                            _buildCategorySection('Consumer Electric', _electronicsProducts),
                            Spacing.sizedBoxH24,
                            // Recently Viewed
                            _buildRecentlyViewed(),
                            Spacing.sizedBoxH24,
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return StatefulBuilder(
      builder: (context, setState) {
        // Load cart count and rebuild when needed
        CartCounter.loadCartCount().then((_) {
          if (mounted) {
            setState(() {});
          }
        });
        
        return Container(
          color: AppColors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Text(
                'goodiesworld',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
              const Spacer(),
              Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.shopping_bag_outlined, color: Colors.black),
                    onPressed: () {
                      // Navigate to cart tab
                      Navigator.of(context).pushNamed('/main');
                    },
                  ),
                  if (CartCounter.cartCount > 0)
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
                          '${CartCounter.cartCount}',
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
              IconButton(
                icon: const Icon(Icons.notifications_outlined, color: Colors.black),
                onPressed: () {
                  // Navigate to notifications
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Text(
            "I'm shopping for...",
            style: AppTextStyles.body2.copyWith(color: AppColors.textSecondary),
          ),
          const Spacer(),
          const Icon(Icons.search, color: Colors.black),
        ],
      ),
    );
  }

  Widget _buildPromoBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange.shade300, Colors.orange.shade500],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Winter Big Sale!',
            style: AppTextStyles.heading2.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          Spacing.sizedBoxH8,
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: 'Up to ',
                  style: AppTextStyles.heading2.copyWith(color: Colors.white),
                ),
                TextSpan(
                  text: '70% OFF',
                  style: AppTextStyles.heading1.copyWith(
                    color: Colors.orange.shade900,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                TextSpan(
                  text: ' ArmChair Brands',
                  style: AppTextStyles.heading2.copyWith(color: Colors.white),
                ),
              ],
            ),
          ),
          Spacing.sizedBoxH16,
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Shop Now',
              style: AppTextStyles.button.copyWith(color: Colors.black),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCards() {
    return Row(
      children: [
        Expanded(
          child: _buildFeatureCard(
            'Most Trending\nAccessories',
            '70% OFF',
            Colors.orange,
          ),
        ),
        Spacing.sizedBoxW12,
        Expanded(
          child: _buildFeatureCard(
            'Iphone 14 Pro\nDiscount 20% OFF',
            '20% OFF',
            AppColors.accent,
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureCard(String title, String badge, Color badgeColor) {
    return Container(
      height: 120,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                style: AppTextStyles.body1.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
              ),
            ],
          ),
          Positioned(
            bottom: 0,
            left: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: badgeColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                badge,
                style: AppTextStyles.caption.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlashSaleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Flash Sale',
              style: AppTextStyles.heading2,
            ),
            _buildCountdownTimer(),
          ],
        ),
        Spacing.sizedBoxH16,
        SizedBox(
          height: 280,
          child: _flashSaleProducts.isEmpty
              ? _buildEmptyState('No flash sale products')
              : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _flashSaleProducts.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: _buildProductCard(_flashSaleProducts[index], showProgress: true),
                    );
                  },
                ),
        ),
        Spacing.sizedBoxH8,
        _buildCarouselIndicator(_flashSaleProducts.length, _currentFlashSaleIndex),
      ],
    );
  }

  Widget _buildCountdownTimer() {
    return Row(
      children: [
        Text(
          'Ends in: ',
          style: AppTextStyles.body2,
        ),
        _buildTimerBox('12'),
        const Text(' : ', style: TextStyle(fontWeight: FontWeight.bold)),
        _buildTimerBox('30'),
        const Text(' : ', style: TextStyle(fontWeight: FontWeight.bold)),
        _buildTimerBox('47'),
      ],
    );
  }

  Widget _buildTimerBox(String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        value,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildCategorySection(String title, List<Map<String, dynamic>> products) {
    if (products.isEmpty) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: AppTextStyles.heading2,
            ),
            TextButton(
              onPressed: () {},
              child: Text(
                'View All',
                style: AppTextStyles.body2.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        Spacing.sizedBoxH12,
        SizedBox(
          height: title == 'Computer & Technology' || title == 'Consumer Electric' ? 320 : 240,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: products.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: _buildProductCard(products[index], isGrid: title == 'Computer & Technology' || title == 'Consumer Electric'),
              );
            },
          ),
        ),
        Spacing.sizedBoxH8,
        _buildCarouselIndicator(products.length, _currentCategoryIndex),
      ],
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product, {bool showProgress = false, bool isGrid = false}) {
    // Extract product data
    final String name = product['name'] ?? 'Product Name';
    final String price = product['price'] ?? '0';
    final String? regularPrice = product['regular_price']?.toString();
    final bool onSale = product['on_sale'] ?? false;
    final List<dynamic>? images = product['images'] as List?;
    final String? imageUrl = images != null && images.isNotEmpty 
        ? images[0]['src'] as String? 
        : null;
    final double? rating = product['average_rating'] != null 
        ? double.tryParse(product['average_rating'].toString()) 
        : null;
    final int ratingCount = product['rating_count'] ?? 0;
    final int totalSales = product['total_sales'] ?? 0;
    final List<dynamic>? brands = product['brands'] as List?;
    final String? brandName = brands != null && brands.isNotEmpty 
        ? brands[0]['name'] as String? 
        : null;
    final int productId = product['id'] as int? ?? 0;

    final double priceValue = double.tryParse(price) ?? 0.0;
    final double? regularPriceValue = regularPrice != null ? double.tryParse(regularPrice) : null;
    final bool hasDiscount = onSale && regularPriceValue != null && regularPriceValue > priceValue;
    final int ratingInt = rating != null ? rating.round() : 0;

    return InkWell(
      onTap: () {
        Navigator.pushNamed(
          context,
          ProductDetailScreen.routeName,
          arguments: {'productId': productId},
        );
      },
      child: Container(
      width: isGrid ? 160 : 160,
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
            flex: 2,
            child: Container(
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
          ),
          // Product Info
          Expanded(
            flex: 3,
            child: ClipRect(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                  // Price
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          '₹${priceValue.toStringAsFixed(2)}',
                          style: AppTextStyles.body1.copyWith(
                            color: hasDiscount ? Colors.red : AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
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
                              decoration: TextDecoration.lineThrough,
                              color: AppColors.textSecondary,
                              fontSize: 10,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  // Product Name
                  Text(
                    name,
                    style: AppTextStyles.body2.copyWith(
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (brandName != null) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          'Sold by: ',
                          style: AppTextStyles.caption.copyWith(fontSize: 9),
                        ),
                        Expanded(
                          child: Text(
                            brandName,
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.accent,
                              fontSize: 9,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  // Rating
                  if (rating != null && rating > 0) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        ...List.generate(5, (index) => Icon(
                          Icons.star,
                          size: 10,
                          color: index < ratingInt 
                              ? AppColors.primary 
                              : Colors.grey.shade300,
                        )),
                        const SizedBox(width: 2),
                        Text(
                          ratingCount.toString().padLeft(2, '0'),
                          style: AppTextStyles.caption.copyWith(fontSize: 9),
                        ),
                      ],
                    ),
                  ],
                  // Progress bar and sold count
                  if (showProgress && totalSales > 0) ...[
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: 0.6,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                      minHeight: 3,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Sold: $totalSales',
                      style: AppTextStyles.caption.copyWith(fontSize: 9),
                    ),
                  ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
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

  Widget _buildCarouselIndicator(int count, int currentIndex) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        count > 5 ? 5 : count,
        (index) => Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: index == currentIndex 
                ? AppColors.primary 
                : Colors.grey.shade300,
          ),
        ),
      ),
    );
  }

  Widget _buildRecentlyViewed() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recently Viewed',
              style: AppTextStyles.heading2,
            ),
            TextButton(
              onPressed: () {},
              child: Text(
                'View All',
                style: AppTextStyles.body2.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        Spacing.sizedBoxH12,
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: 3,
            itemBuilder: (context, index) {
              return Container(
                width: 100,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: _buildPlaceholderImage(),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Text(
        message,
        style: AppTextStyles.body2.copyWith(color: AppColors.textSecondary),
      ),
    );
  }

  // Bottom navigation is provided by `MainTabsScreen`.
}
