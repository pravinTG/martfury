import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:html_unescape/html_unescape.dart'; // Add this if not already in pubspec.yaml
import '../api_service.dart';
import '../theme/app_colors.dart';
import '../widgets/custom_cached_image.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../theme/app_text_styles.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'menu_screen.dart';
import 'product_list.dart';
import 'product_detail_screen.dart'; // ADD THIS LINE
import 'search_screen.dart';
import 'wallet_screen.dart';
import 'shopping_selection_screen.dart';
import '../widgets/async_state_view.dart';
import '../widgets/app_loader.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/shimmer_loading.dart';
import '../widgets/coming_soon_popup.dart';
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
  bool _hasWalletNotification = false;

  int _currentBannerIndex = 0;
  List<Map<String, dynamic>> _bannerImages = [];

  final Map<String, String> _fallbackCategoryImages = {
    'clothing': 'https://images.unsplash.com/photo-1512436991641-6745cdb1723f?w=400&q=80',
    'toy': 'https://images.unsplash.com/photo-1596461404969-9ae70f2830c1?w=400&q=80',
    'electronic': 'https://images.unsplash.com/photo-1498049794561-7780e7231661?w=400&q=80',
    'cosmetic': 'https://images.unsplash.com/photo-1522335789203-aabd1fc54bc9?w=400&q=80',
    'saree': 'https://images.unsplash.com/photo-1583391733958-d25977af1017?w=400&q=80',
    'kurti': 'https://images.unsplash.com/photo-1617265888251-57c4a179619a?w=400&q=80',
    'shoe': 'https://images.unsplash.com/photo-1542291026-7eec264c27ff?w=400&q=80',
    'bag': 'https://images.unsplash.com/photo-1584916201218-f4242ceb4809?w=400&q=80',
  };

  Timer? _walletPollingTimer;

  void _openSearch() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SearchScreen()),
    );
  }

  Future<void> _openBecomeVendor() async {
    final url = Uri.parse('https://goodiesworld.in/my-account/');
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open the vendor page.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the vendor page.')),
        );
      }
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
    
    // Poll wallet status every 30 seconds to show the blinking dot without restarting
    _walletPollingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _loadWalletBalance();
    });
  }

  @override
  void dispose() {
    _walletPollingTimer?.cancel();
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

      await _fetchCategories();
      await _fetchBanners();
      await _fetchProducts(page: 1, append: false);

      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      await _loadWalletBalance();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to load data: $e';
        _isLoading = false;
      });
      print('Error fetching data: $e');
    }
  }

  Future<void> _fetchBanners() async {
    try {
      final banners = await _apiService.getMobileBanners();
      if (banners.isNotEmpty) {
        if (!mounted) return;
        setState(() {
          _bannerImages = banners;
        });
      }
    } catch (e) {
      print('Error fetching banners: $e');
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

      final results = await Future.wait([
        _apiService.getWalletBalance(uid),
        _apiService.checkWalletNotification(uid),
      ]);
      
      if (!mounted) return;
      setState(() {
        _walletBalance = results[0] as double;
        _hasWalletNotification = results[1] as bool;
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
          'https://goodiesworld.in/wp-json/wc/v3/products?per_page=$_productsPerPage&page=$page';
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

  Widget _buildShimmerHome() {
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            // Mock Quick Action Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: const [
                  Expanded(flex: 4, child: ShimmerContainer(width: double.infinity, height: 50, borderRadius: 18)),
                  SizedBox(width: 10),
                  Expanded(flex: 5, child: ShimmerContainer(width: double.infinity, height: 50, borderRadius: 18)),
                  SizedBox(width: 10),
                  Expanded(flex: 4, child: ShimmerContainer(width: double.infinity, height: 50, borderRadius: 18)),
                ],
              ),
            ),
            // Mock Search Bar
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: ShimmerContainer(width: double.infinity, height: 54, borderRadius: 18),
            ),
            // Mock Top Categories
            const ShimmerCategoryList(),
            // Mock Banners
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ShimmerContainer(width: double.infinity, height: 180, borderRadius: 16),
            ),
            // Mock Products Section
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ShimmerContainer(width: 150, height: 24),
                  const SizedBox(height: 16),
                  Row(
                    children: const [
                      Expanded(child: ShimmerProductCard()),
                      SizedBox(width: 12),
                      Expanded(child: ShimmerProductCard()),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: const [
                      Expanded(child: ShimmerProductCard()),
                      SizedBox(width: 12),
                      Expanded(child: ShimmerProductCard()),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: 110,
        backgroundColor: AppColors.headerRed,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white,size: 30,),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const MenuScreen()),
            );
          },
        ),
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Image.asset(
            'assets/logo5.png',
            height: 500, // Large height, allowing the image to be big
            alignment: Alignment.centerLeft,
          ),
        ),
        actions: [
          GestureDetector(
            onTap: () async {
              // Immediately hide the blinking dot.
              if (_hasWalletNotification) {
                setState(() => _hasWalletNotification = false);

                // Tell the backend to mark as read (fire-and-forget).
                final idStr = await TokenStorageService.getUserId();
                final uid = int.tryParse(idStr ?? '');
                if (uid != null) {
                  _apiService.markWalletNotificationRead(uid);
                }
              }

              if (!mounted) return;
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const WalletScreen()),
              );

              // Re-check notification status when returning from wallet screen.
              if (mounted) {
                _loadWalletBalance();
              }
            },
            child: Padding(
              padding: const EdgeInsets.only(right: 10,bottom: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Image.asset(
                        'assets/gennie.png',
                        height: 80
                      ),
                      if (_hasWalletNotification)
                        const Positioned(
                          top: 0,
                          right:5,
                          child: BlinkingDot(size: 20),
                        ),
                    ],
                  ),
                  SizedBox(height: 1,),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.orange,
                        width: 1.5,
                      ),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: const Text(
                      'Check Bonus',
                      style: TextStyle(
                        color: Colors.white, // changed for visibility
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                    ),
                  )
                ],
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? _buildShimmerHome()
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
                      SizedBox(height: 10,),
                      _buildQuickActionRow(),
                      _buildHomeSearchBar(),
                      _buildTopCategories(),
                      _buildTopBanners(),
                      _buildWinterBigSale(),
                      _buildMostTrending(),
                      _buildFlashSale(),
                      ..._buildDynamicCategorySections(),
                      // _buildRecentlyViewed(),
                      if (_isLoadingMoreProducts)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                          child: Row(
                            children: const [
                              Expanded(child: ShimmerProductCard()),
                              SizedBox(width: 12),
                              Expanded(child: ShimmerProductCard()),
                            ],
                          ),
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
            color: AppColors.yellow,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: AppColors.yellow, width: 1.3),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: AppColors.yellow, width: 1.3),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: AppColors.yellow, width: 1.4),
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
            flex: 4,
            child: _quickButton(
              label: 'Shopping',
              icon: Icons.shopping_bag_outlined,
              backgroundColor: AppColors.button,
              isSelected: true,
              foregroundColor: Colors.white,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ShoppingSelectionScreen(),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 5,
            child: _quickButton(
              label: 'Become a Vendor',
              icon: Icons.travel_explore_outlined,
              backgroundColor: AppColors.button,
              isSelected: false,
              foregroundColor: Colors.white,
              onTap: _openBecomeVendor,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 4,
            child: _quickButton(
              label: 'Wallet',
              icon: Icons.account_balance_wallet_outlined,
              backgroundColor: AppColors.button,
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
              color: isSelected ? const Color(0xFFD9DCE1) : const Color(0xFFD9DCE1),
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
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
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
          String? imageUrl = category['image']?['src']?.toString();
          final categoryId = category['id'] as int;

          if (imageUrl == null || imageUrl.isEmpty) {
            final lowerName = name.toLowerCase();
            for (var key in _fallbackCategoryImages.keys) {
              if (lowerName.contains(key)) {
                imageUrl = _fallbackCategoryImages[key];
                break;
              }
            }
            imageUrl ??= 'https://images.unsplash.com/photo-1472851294608-062f824d29cc?w=400&q=80';
          }

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
                        ? CachedNetworkImageProvider(imageUrl) as ImageProvider
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
    if (_bannerImages.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        children: [
          CarouselSlider(
            options: CarouselOptions(
              height: 180,
              viewportFraction: 1.0,
              autoPlay: true,
              autoPlayInterval: const Duration(seconds: 4),
              onPageChanged: (index, reason) {
                setState(() {
                  _currentBannerIndex = index;
                });
              },
            ),
            items: _bannerImages.map((banner) {
              return Builder(
                builder: (BuildContext context) {
                  final imageUrl = banner['image']?.toString() ?? banner['src']?.toString() ?? banner['url']?.toString() ?? '';
                  final title = banner['title']?.toString();
                  final subtitle = banner['subtitle']?.toString();

                  return Container(
                    width: MediaQuery.of(context).size.width,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      image: imageUrl.isNotEmpty
                          ? DecorationImage(
                              image: CachedNetworkImageProvider(imageUrl),
                              fit: BoxFit.cover,
                              colorFilter: (title != null || subtitle != null)
                                  ? ColorFilter.mode(Colors.black.withOpacity(0.35), BlendMode.darken)
                                  : null,
                            )
                          : null,
                      color: AppColors.purpleLight,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (title != null && title.isNotEmpty)
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          if (subtitle != null && subtitle.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              subtitle,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: _bannerImages.asMap().entries.map((entry) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: _currentBannerIndex == entry.key ? 20 : 7,
                height: 7,
                decoration: BoxDecoration(
                  color: _currentBannerIndex == entry.key
                      ? AppColors.yellow
                      : AppColors.textDisabled,
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }).toList(),
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
        color: const Color(0xFFFFF0E5),
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
              backgroundColor: AppColors.headerRed,
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

  @override
  void initState() {
    super.initState();
    final productId = (widget.product?['id'] ?? '').toString();
    _isFavorite = ApiService.wishlistProductIds.contains(productId);
  }

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
    String? imageUrl;
    final images = widget.product?['images'];
    if (images is List && images.isNotEmpty) {
      imageUrl = images[0]?['src'];
    }

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
                    child: CustomCachedImage(
                      imageUrl: imageUrl,
                      width: double.infinity,
                      height: 120,
                      fit: BoxFit.contain,
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

class BlinkingDot extends StatefulWidget {
  final double size;
  const BlinkingDot({Key? key, this.size = 20}) : super(key: key);

  @override
  _BlinkingDotState createState() => _BlinkingDotState();
}

class _BlinkingDotState extends State<BlinkingDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    
    _animation = Tween<double>(begin: 0.2, end: 1.0).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: Colors.green,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2.0),
          boxShadow: [
            BoxShadow(
              color: Colors.red.withOpacity(0.5),
              blurRadius: 6,
              spreadRadius: 1.5,
            ),
          ],
        ),
      ),
    );
  }
}
