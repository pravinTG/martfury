import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../api_service.dart';
import 'product_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  final ApiService _apiService = ApiService();
  bool _isLoading = false;
  List<Map<String, dynamic>> _searchResults = [];
  bool _hasSearched = false;
  final Set<int> _favoriteProductIds = <int>{};

  // Recent searches
  final List<String> recentSearches = [
    'speakers',
    'marshall',
    'camouflage backpack',
    'samsung hd 32inch',
  ];

  // Search suggestions (shown when typing)
  final List<String> searchSuggestions = [
    'speakers',
    'speakers bluetooth wireless',
    'speakers wire',
    'speakers for computer desktop',
    'speakers stands pair',
  ];

  // Trending categories
  final List<Map<String, String>> trendingCategories = [
    {'name': 'Home Audios & Theaters', 'icon': '🔊'},
    {'name': 'TV & Videos', 'icon': '📺'},
    {'name': 'Cameras, Photos & Videos', 'icon': '📷'},
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _performSearch(String query) async {
    if (query.trim().isEmpty) return;
    setState(() {
      _isLoading = true;
      _hasSearched = true;
      _isSearching = false;
    });
    
    if (!recentSearches.contains(query)) {
      recentSearches.insert(0, query);
      if (recentSearches.length > 5) recentSearches.removeLast();
    }

    try {
      final results = await _apiService.searchProducts(query);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to search: $e')),
        );
      }
    }
  }

  Future<void> _toggleFavorite(int productId) async {
    try {
      final response = await _apiService.toggleFavorite(productId: productId.toString());
      final message = (response['message'] ?? 'Wishlist updated').toString();
      final removed = message.toLowerCase().contains('removed');
      if (!mounted) return;
      setState(() {
        if (removed) {
          _favoriteProductIds.remove(productId);
        } else {
          _favoriteProductIds.add(productId);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  void _clearRecentSearches() {
    setState(() {
      recentSearches.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: AppColors.headerRed,
          elevation: 0,
          flexibleSpace: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              child: Row(
                children: [
                  // Back button
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    color: Colors.white,
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 12),
                  // Search Bar
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: TextField(
                        controller: _searchController,
                        autofocus: false,
                        onChanged: (value) {
                          setState(() {
                            _isSearching = value.isNotEmpty;
                            if (value.isEmpty) _hasSearched = false;
                          });
                        },
                        onSubmitted: (value) => _performSearch(value),
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          hintText: "I'm shopping for...",
                          hintStyle: AppTextStyles.hintText,
                          prefixIcon: null,
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_searchController.text.isNotEmpty)
                                IconButton(
                                  icon: const Icon(Icons.close, size: 20),
                                  color: Colors.grey,
                                  onPressed: () {
                                    setState(() {
                                      _searchController.clear();
                                      _isSearching = false;
                                      _hasSearched = false;
                                    });
                                  },
                                ),
                              Container(
                                margin: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.black,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.search,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  onPressed: () {
                                    _performSearch(_searchController.text);
                                  },
                                ),
                              ),
                            ],
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
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
      body: _isSearching
          ? _buildSearchSuggestions()
          : (_hasSearched ? _buildSearchResults() : _buildDefaultContent()),
    );
  }

  // Default content (Recent Search + Trending Categories)
  Widget _buildDefaultContent() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          // Recently Search section
          if (recentSearches.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Recently Search',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  GestureDetector(
                    onTap: _clearRecentSearches,
                    child: const Text(
                      'Clear All',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.yellow,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ...recentSearches.map((search) => _buildRecentSearchItem(search)),
            const SizedBox(height: 24),
          ],

          // Trending Categories section
          // const Padding(
          //   padding: EdgeInsets.symmetric(horizontal: 16),
          //   child: Text(
          //     'Trending Categories',
          //     style: TextStyle(
          //       fontSize: 16,
          //       fontWeight: FontWeight.w600,
          //       color: Colors.black87,
          //     ),
          //   ),
          // ),
          // const SizedBox(height: 16),
          // Padding(
          //   padding: const EdgeInsets.symmetric(horizontal: 16),
          //   child: Row(
          //     children: [
          //       Expanded(
          //         child: _buildCategoryCard(
          //           trendingCategories[0]['name']!,
          //           trendingCategories[0]['icon']!,
          //         ),
          //       ),
          //       const SizedBox(width: 12),
          //       Expanded(
          //         child: _buildCategoryCard(
          //           trendingCategories[1]['name']!,
          //           trendingCategories[1]['icon']!,
          //         ),
          //       ),
          //     ],
          //   ),
          // ),
          // const SizedBox(height: 12),
          // Padding(
          //   padding: const EdgeInsets.symmetric(horizontal: 16),
          //   child: Row(
          //     children: [
          //       Expanded(
          //         child: _buildCategoryCard(
          //           trendingCategories[2]['name']!,
          //           trendingCategories[2]['icon']!,
          //         ),
          //       ),
          //       const SizedBox(width: 12),
          //       const Expanded(child: SizedBox()),
          //     ],
          //   ),
          // ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // Search suggestions (when typing)
  Widget _buildSearchSuggestions() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: searchSuggestions.length,
      itemBuilder: (context, index) {
        final suggestion = searchSuggestions[index];
        final query = _searchController.text.toLowerCase();

        return InkWell(
          onTap: () {
            _searchController.text = suggestion;
            setState(() {
              _isSearching = false;
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Icon(
                  Icons.search,
                  size: 20,
                  color: Colors.grey,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                      children: _highlightSearchText(suggestion, query),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Helper to highlight matching text
  List<TextSpan> _highlightSearchText(String text, String query) {
    if (query.isEmpty) {
      return [TextSpan(text: text)];
    }

    final lowerText = text.toLowerCase();
    final index = lowerText.indexOf(query);

    if (index == -1) {
      return [TextSpan(text: text)];
    }

    return [
      if (index > 0) TextSpan(text: text.substring(0, index)),
      TextSpan(
        text: text.substring(index, index + query.length),
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      if (index + query.length < text.length)
        TextSpan(text: text.substring(index + query.length)),
    ];
  }

  Widget _buildRecentSearchItem(String search) {
    return InkWell(
      onTap: () {
        _searchController.text = search;
        setState(() {
          _isSearching = false;
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const Icon(
              Icons.access_time,
              size: 20,
              color: Colors.grey,
            ),
            const SizedBox(width: 16),
            Text(
              search,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCard(String name, String icon) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            icon,
            style: const TextStyle(fontSize: 32),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              name,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black87,
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

  Widget _buildSearchResults() {
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.headerRed));
    }

    if (_searchResults.isEmpty) {
      return const Center(
        child: Text(
          'No products found.',
          style: TextStyle(fontSize: 16, color: Colors.black54),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.65,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final product = _searchResults[index];
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ProductDetailScreen(
                  productId: product['id'],
                ),
              ),
            );
          },
          child: _buildProductCard(product),
        );
      },
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
            decoration: const BoxDecoration(
              color: Color(0xFFF5F5F5),
              borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Stack(
              children: [
                if (imageUrl != null)
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                    child: Image.network(
                      imageUrl,
                      width: double.infinity,
                      height: 130,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Center(
                          child: Icon(
                            Icons.image_outlined,
                            size: 50,
                            color: Colors.grey[400],
                          ),
                        );
                      },
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
                      _favoriteProductIds.contains(product['id'])
                          ? Icons.favorite
                          : Icons.favorite_border,
                      size: 20,
                      color: _favoriteProductIds.contains(product['id'])
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
}
