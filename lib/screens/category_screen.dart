import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:martfury/screens/product_list.dart';
import 'package:martfury/screens/search_screen.dart';
import '../api_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_snackbar.dart';

class CategoryScreen extends StatefulWidget {
  const CategoryScreen({Key? key}) : super(key: key);

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  final TextEditingController _searchController = TextEditingController();

  final ApiService _apiService = ApiService();

  List<Map<String, dynamic>> mainCategories = [];
  Map<int, List<Map<String, dynamic>>> subcategoriesMap = {};
  List<Map<String, dynamic>> categoryProducts = [];
  bool isLoading = true;
  bool isLoadingProducts = false;
  String? selectedCategory;
  int? selectedCategoryId;

  @override
  void initState() {
    super.initState();
    fetchCategories();
  }

  Future<void> fetchCategories() async {
    try {
      List<Map<String, dynamic>> allCategories =
      await _apiService.getCategories(perPage: 100);

      print('Total categories fetched: ${allCategories.length}');

      // Separate main categories (parent = 0) and subcategories
      List<Map<String, dynamic>> main = [];
      Map<int, List<Map<String, dynamic>>> subMap = {};

      for (var category in allCategories) {
        // ✔ Decode HTML entities in category name
        category['name'] = _decodeHtmlEntities(category['name']);

        if (category['parent'] == 0) {
          main.add(category);
          print('Main category: ${category['name']} (ID: ${category['id']})');
        } else {
          int parentId = category['parent'];
          if (!subMap.containsKey(parentId)) {
            subMap[parentId] = [];
          }
          subMap[parentId]!.add(category);
          print('Sub category: ${category['name']} (Parent ID: $parentId)');
        }
      }

      setState(() {
        mainCategories = main;
        subcategoriesMap = subMap;
        isLoading = false;

        if (mainCategories.isNotEmpty) {
          selectedCategory = mainCategories[0]['name'];
          selectedCategoryId = mainCategories[0]['id'];
          // Fetch products for the first category
          _fetchCategoryProducts(mainCategories[0]['id']);
        }
      });
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) {
        AppSnackBar.show(context, 'Error fetching categories: $e', type: AppSnackType.error);
      }
    }
  }

  Future<void> _fetchCategoryProducts(int categoryId) async {
    setState(() {
      isLoadingProducts = true;
    });

    try {
      final url = 'https://goodiesworld.techgigs.in/wp-json/wc/v3/products?category=$categoryId&per_page=100';
      final response = await http.get(
        Uri.parse(url),
        headers: {
          "Authorization": ApiService.basicAuth,
        },
      );

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        setState(() {
          categoryProducts = data.map((e) => Map<String, dynamic>.from(e)).toList();
          isLoadingProducts = false;
        });
      } else {
        throw Exception('Failed to load products: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        isLoadingProducts = false;
        categoryProducts = [];
      });
      if (mounted) {
        AppSnackBar.show(context, 'Error fetching category products: $e', type: AppSnackType.error);
      }
    }
  }

  // Helper method to decode HTML entities
  String _decodeHtmlEntities(String text) {
    return text
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#039;', "'")
        .replaceAll('&apos;', "'");
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(110),
        child: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: AppColors.yellow,
          elevation: 0,
          flexibleSpace: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              child: Column(
                children: [
                  const SizedBox(height: 30),
                  // Search Bar
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: "I'm shopping for...",
                        hintStyle: TextStyle(
                          color: AppColors.hintText,
                          fontSize: 16,
                        ),
                        prefixIcon: null,
                        suffixIcon: Container(
                          margin: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppColors.purpleDark,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: IconButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => SearchScreen(),
                                ),
                              );
                            },
                            icon: const Icon(
                              Icons.search,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : mainCategories.isEmpty
          ? const Center(child: Text('No categories available'))
          : Column(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Side - Categories List
                Expanded(
                  flex: 4,
                  child: Container(
                    color: Colors.white,
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: mainCategories.length,
                      itemBuilder: (context, index) {
                        final category = mainCategories[index];
                        final isSelected = category['name'] == selectedCategory;
                        final categoryName = category['name'];

                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              selectedCategory = category['name'];
                              selectedCategoryId = category['id'];
                            });
                            // Fetch products for selected category
                            _fetchCategoryProducts(category['id']);
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.purpleLight : Colors.white,
                              border: Border(
                                left: BorderSide(
                                  color: isSelected
                                      ? AppColors.yellow
                                      : Colors.transparent,
                                  width: 3,
                                ),
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 14,
                            ),
                            child: Text(
                              categoryName,
                              style: TextStyle(
                                fontSize: 14,
                                color: isSelected
                                    ? AppColors.textPrimary
                                    : AppColors.textSecondary,
                                fontWeight: isSelected
                                    ? FontWeight.w500
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // Right Side - Subcategories
                Expanded(
                  flex: 5,
                  child: Container(
                    color: AppColors.purpleLight,
                    child: isLoadingProducts
                        ? const Center(child: CircularProgressIndicator())
                        : SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header with arrow
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: GestureDetector(
                              onTap: () {
                                if (selectedCategoryId != null) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ProductListScreen(
                                        categoryId: selectedCategoryId!,
                                        categoryName: selectedCategory ?? '',
                                      ),
                                    ),
                                  );
                                }
                              },
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      selectedCategory ?? '',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  const Icon(
                                    Icons.arrow_forward_ios,
                                    size: 14,
                                    color: AppColors.textPrimary,
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Check if subcategories exist
                          if (selectedCategoryId != null &&
                              subcategoriesMap[selectedCategoryId] != null &&
                              subcategoriesMap[selectedCategoryId]!.isNotEmpty)
                          // Show Subcategories Grid
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0),
                              child: GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  childAspectRatio: 0.85,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                ),
                                itemCount: subcategoriesMap[selectedCategoryId]!.length,
                                itemBuilder: (context, index) {
                                  final subcategory =
                                  subcategoriesMap[selectedCategoryId]![index];
                                  return GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => ProductListScreen(
                                            categoryId: subcategory['id'],
                                            categoryName: subcategory['name'],
                                          ),
                                        ),
                                      );
                                    },
                                    child: SubcategoryCard(
                                      name: subcategory['name'],
                                      imageUrl: subcategory['image']?['src'],
                                    ),
                                  );
                                },
                              ),
                            )
                          else
                          // Show Products Grid if no subcategories
                            categoryProducts.isEmpty
                                ? const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Center(
                                child: Text(
                                  'No products available',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            )
                                : Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0),
                              child: GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  childAspectRatio: 0.52,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                ),
                                itemCount: categoryProducts.length,
                                itemBuilder: (context, index) {
                                  final product = categoryProducts[index];
                                  return ProductCard(product: product);
                                },
                              ),
                            ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SubcategoryCard extends StatelessWidget {
  final String name;
  final String? imageUrl;

  const SubcategoryCard({
    Key? key,
    required this.name,
    this.imageUrl,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Image or placeholder
          if (imageUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                imageUrl!,
                height: 60,
                width: 60,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 60,
                    width: 60,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.image_outlined,
                      size: 40,
                      color: Colors.grey[400],
                    ),
                  );
                },
              ),
            )
          else
            Container(
              height: 60,
              width: 60,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.image_outlined,
                size: 40,
                color: Colors.grey[400],
              ),
            ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Text(
              name,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// Product Card Widget for Category Screen
class ProductCard extends StatefulWidget {
  final Map<String, dynamic> product;

  const ProductCard({
    Key? key,
    required this.product,
  }) : super(key: key);

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  final ApiService _apiService = ApiService();
  bool _isFavorite = false;
  bool _isToggling = false;

  Future<void> _toggleFavorite() async {
    if (_isToggling) return;
    setState(() => _isToggling = true);
    try {
      final response = await _apiService.toggleFavorite(
        productId: (widget.product['id'] ?? '').toString(),
      );
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
    String displayName = widget.product['name'] ?? 'Product Name';
    String displayPrice = '₹${widget.product['price']}';
    String? displayOldPrice = widget.product['on_sale'] == true && widget.product['regular_price'] != null
        ? '₹${widget.product['regular_price']}'
        : null;
    double? displayRating = widget.product['average_rating'] != null
        ? double.tryParse(widget.product['average_rating'].toString())
        : null;
    int? displayReviews = widget.product['rating_count'];
    String? imageUrl = widget.product['images']?[0]?['src'];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product Image Container
          Container(
            height: 120,
            decoration: BoxDecoration(
              color: Colors.grey[100],
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
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    displayName,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  if (displayRating != null && displayReviews != null) ...[
                    Row(
                      children: [
                        ...List.generate(
                          5,
                          (index) => Icon(
                            index < displayRating.floor() ? Icons.star : Icons.star_border,
                            size: 11,
                            color: const Color(0xFFFDB825),
                          ),
                        ),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            '($displayReviews)',
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.textSecondary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                  ],
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          displayPrice,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: displayOldPrice != null ? Colors.red : AppColors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (displayOldPrice != null) ...[
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            displayOldPrice,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                              decoration: TextDecoration.lineThrough,
                            ),
                            overflow: TextOverflow.ellipsis,
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
}