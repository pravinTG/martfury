import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:html_unescape/html_unescape.dart'; // Add this if not already in pubspec.yaml
import '../api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'menu_screen.dart';
import 'product_list.dart';
import 'product_detail_screen.dart'; // ADD THIS LINE
import 'search_screen.dart';
import 'wallet_screen.dart';
import '../widgets/async_state_view.dart';
import '../widgets/app_loader.dart';
import '../widgets/app_snackbar.dart';
import '../token_storage_service.dart';

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
  double? _walletBalance;
  bool _isWalletLoading = false;

  void _openSearch() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SearchScreen()),
    );
  }

  Future<void> _openBecomeVendor() async {
    try {
      final uri = Uri.parse('https://goodiesworld.techgigs.in/become-a-vendor/');
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        AppSnackBar.show(
          context,
          'Unable to open vendor page',
          type: AppSnackType.error,
        );
      }
    } catch (_) {
      if (!mounted) return;
      AppSnackBar.show(
        context,
        'Unavailable',
        type: AppSnackType.error,
      );
    }
  }

  void _goToHomeTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _fetchData();
    _loadWalletBalance();
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
      await _loadWalletBalance();
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load data: $e';
        _isLoading = false;
      });
      print('Error fetching data: $e');
    }
  }

  Future<void> _loadWalletBalance() async {
    if (_isWalletLoading) return;
    setState(() => _isWalletLoading = true);
    try {
      final idStr = await TokenStorageService.getUserId();
      final uid = int.tryParse(idStr ?? '');
      if (uid == null) {
        if (mounted) {
          setState(() {
            _walletBalance = null;
            _isWalletLoading = false;
          });
        }
        return;
      }

      final balance = await _apiService.getWalletBalance(uid);
      if (!mounted) return;
      setState(() {
        _walletBalance = balance;
        _isWalletLoading = false;
      });
    } catch (e) {
      // Silent on UI; keep console for debugging.
      debugPrint('WALLET_BALANCE: failed $e');
      if (!mounted) return;
      setState(() => _isWalletLoading = false);
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
          'Goodies World',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const WalletScreen()),
              );
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/chirag.png',height: 40,width: 40
                ),
                const Text(
                  'Check Bonus',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
        ],
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
                      _buildQuickActionRow(),
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
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: TextField(
        readOnly: true,
        onTap: _openSearch,
        decoration: InputDecoration(
          hintText: 'Search for Sarees, Kurtis, Cosmetics, etc.',
          hintStyle: AppTextStyles.hintText,
          prefixIcon: const Icon(
            Icons.search,
            color: AppColors.textSecondary,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: Color(0xFF9A9AA0), width: 1.3),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: Color(0xFF9A9AA0), width: 1.3),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: Color(0xFF8A8A90), width: 1.4),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
      child: Row(
        children: [
          Expanded(
            child: _quickButton(
              label: 'Shopping',
              icon: Icons.shopping_bag_outlined,
              backgroundColor: AppColors.yellow,
              isSelected: true,
              foregroundColor: Colors.white,
              onTap: _goToHomeTop,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _quickButton(
              label: 'Become a Vendor',
              icon: Icons.travel_explore_outlined,
              backgroundColor: const Color(0xFFF1F2F4),
              isSelected: false,
              foregroundColor: AppColors.textPrimary,
              onTap: _openBecomeVendor,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _quickButton(
              label: 'Wallet',
              icon: Icons.account_balance_wallet_outlined,
              backgroundColor: AppColors.yellow,
              isSelected: true,
              foregroundColor: Colors.white,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const WalletScreen()),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickButton({
    required String label,
    required IconData icon,
    required Color backgroundColor,
    required bool isSelected,
    required Color foregroundColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        splashColor: Colors.black.withOpacity(0.06),
        highlightColor: Colors.black.withOpacity(0.04),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected ? const Color(0xFFE0B400) : const Color(0xFFD9DCE1),
              width: isSelected ? 1.2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 4,
                offset: const Offset(0, 1.5),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 19, color: foregroundColor),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: label == 'Become a Vendor' ? 10.5 : 11.5,
                  fontStyle: FontStyle.italic,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                  color: foregroundColor,
                  height: 1.0,
                ),
              ),
            ],
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
            onPressed: _openSearch,
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
                color: Colors.white,
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