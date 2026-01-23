import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/spacing.dart';
import '../utils/responsive.dart';
import '../services/api_service.dart';
import '../services/api_endpoints.dart';
import '../utils/safe_print.dart';
import 'package:google_fonts/google_fonts.dart';

class CategoryScreen extends StatefulWidget {
  static const String routeName = '/categories';

  const CategoryScreen({super.key});

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  
  List<Map<String, dynamic>> _allCategories = [];
  List<Map<String, dynamic>> _trendingCategories = [];
  List<String> _recentSearches = [];
  
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 1;
  final int _perPage = 10;
  
  static const String _recentSearchesKey = 'recent_searches';

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();
    _loadCategories();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent * 0.8) {
      if (!_isLoadingMore && _hasMore) {
        _loadMoreCategories();
      }
    }
  }

  Future<void> _loadRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final searches = prefs.getStringList(_recentSearchesKey) ?? [];
      setState(() {
        _recentSearches = searches;
      });
    } catch (e) {
      safePrint('Error loading recent searches: $e');
    }
  }

  Future<void> _saveRecentSearch(String search) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> searches = prefs.getStringList(_recentSearchesKey) ?? [];
      
      // Remove if already exists
      searches.remove(search);
      // Add to beginning
      searches.insert(0, search);
      // Keep only last 10
      if (searches.length > 10) {
        searches = searches.take(10).toList();
      }
      
      await prefs.setStringList(_recentSearchesKey, searches);
      setState(() {
        _recentSearches = searches;
      });
    } catch (e) {
      safePrint('Error saving recent search: $e');
    }
  }

  Future<void> _clearRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_recentSearchesKey);
      setState(() {
        _recentSearches = [];
      });
    } catch (e) {
      safePrint('Error clearing recent searches: $e');
    }
  }

  Future<void> _loadCategories({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _currentPage = 1;
        _allCategories = [];
        _hasMore = true;
        _isLoading = true;
      });
    }

    try {
      final response = await ApiService.gets(
        ApiEndpoints.productsCategories,
        queryParams: {
          'per_page': _perPage.toString(),
          'page': _currentPage.toString(),
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> categoriesData = jsonDecode(response.body);
        final List<Map<String, dynamic>> categories = 
            categoriesData.map((item) => Map<String, dynamic>.from(item)).toList();

        safePrint('✅ Loaded ${categories.length} categories (page $_currentPage)');

        setState(() {
          if (refresh) {
            _allCategories = categories;
          } else {
            _allCategories.addAll(categories);
          }
          
          // Filter trending categories (parent: 0 means top-level categories)
          _trendingCategories = _allCategories
              .where((cat) => cat['parent'] == 0)
              .take(3)
              .toList();
          
          _hasMore = categories.length == _perPage;
          _isLoading = false;
          _isLoadingMore = false;
        });
      } else {
        safePrint('❌ Error loading categories: ${response.statusCode}');
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    } catch (e, stackTrace) {
      safePrint('❌ Exception loading categories: $e');
      safePrint('Stack trace: $stackTrace');
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _loadMoreCategories() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() {
      _isLoadingMore = true;
      _currentPage++;
    });

    await _loadCategories();
  }

  void _handleSearch(String query) {
    if (query.trim().isEmpty) return;
    
    _saveRecentSearch(query.trim());
    // TODO: Navigate to search results
    safePrint('Searching for: $query');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Yellow Header with Search
            _buildHeader(),
            // Main Content
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => _loadCategories(refresh: true),
                color: AppColors.primary,
                child: CustomScrollView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding: EdgeInsets.symmetric(
                        horizontal: Responsive.width(context, 0.04),
                        vertical: Responsive.height(context, 0.02),
                      ),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          // Recently Search Section
                          _buildRecentlySearchSection(),
                          Spacing.sizedBoxH24,
                          // Trending Categories Section
                          _buildTrendingCategoriesSection(),
                          Spacing.sizedBoxH24,
                          // All Categories Section
                          _buildAllCategoriesSection(),
                        ]),
                      ),
                    ),
                    // Loading More Indicator
                    if (_isLoadingMore)
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                    // Bottom spacing
                    const SliverToBoxAdapter(
                      child: SizedBox(height: 80),
                    ),
                  ],
                ),
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
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: "I'm shopping for...",
                        hintStyle: AppTextStyles.body2.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      style: AppTextStyles.body2,
                      onSubmitted: _handleSearch,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.camera_alt_outlined, color: Colors.black),
                    onPressed: () {
                      // Camera search
                      safePrint('Camera search tapped');
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  Spacing.sizedBoxW8,
                  GestureDetector(
                    onTap: () => _handleSearch(_searchController.text),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.search,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentlySearchSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recently Search',
              style: AppTextStyles.heading2,
            ),
            if (_recentSearches.isNotEmpty)
              TextButton(
                onPressed: _clearRecentSearches,
                child: Text(
                  'Clear All',
                  style: AppTextStyles.body2.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        Spacing.sizedBoxH12,
        if (_recentSearches.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              'No recent searches',
              style: AppTextStyles.body2.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          )
        else
          ..._recentSearches.map((search) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  onTap: () {
                    _searchController.text = search;
                    _handleSearch(search);
                  },
                  child: Row(
                    children: [
                      const Icon(
                        Icons.access_time,
                        size: 20,
                        color: AppColors.textSecondary,
                      ),
                      Spacing.sizedBoxW12,
                      Expanded(
                        child: Text(
                          search,
                          style: AppTextStyles.body1,
                        ),
                      ),
                    ],
                  ),
                ),
              )),
      ],
    );
  }

  Widget _buildTrendingCategoriesSection() {
    if (_isLoading && _trendingCategories.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Trending Categories',
          style: AppTextStyles.heading2,
        ),
        Spacing.sizedBoxH16,
        if (_trendingCategories.isEmpty)
          Text(
            'No trending categories',
            style: AppTextStyles.body2.copyWith(
              color: AppColors.textSecondary,
            ),
          )
        else
          Row(
            children: _trendingCategories.asMap().entries.map((entry) {
              final index = entry.key;
              final category = entry.value;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: index < _trendingCategories.length - 1 ? 12 : 0,
                  ),
                  child: _buildCategoryCard(category),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildAllCategoriesSection() {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (_allCategories.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Text(
            'No categories found',
            style: AppTextStyles.body2.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'All Categories',
          style: AppTextStyles.heading2,
        ),
        Spacing.sizedBoxH16,
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.85,
          ),
          itemCount: _allCategories.length,
          itemBuilder: (context, index) {
            return _buildCategoryCard(_allCategories[index]);
          },
        ),
      ],
    );
  }

  Widget _buildCategoryCard(Map<String, dynamic> category) {
    final String name = category['name'] ?? 'Category';
    final String? imageUrl = category['image']?['src'] as String?;
    final int count = category['count'] ?? 0;
    
    // Decode HTML entities in name
    final String decodedName = name
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#039;', "'");

    return InkWell(
      onTap: () {
        // TODO: Navigate to category products
        safePrint('Category tapped: $decodedName');
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Category Image or Icon
            if (imageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  imageUrl,
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _buildCategoryIcon(decodedName),
                ),
              )
            else
              _buildCategoryIcon(decodedName),
            Spacing.sizedBoxH8,
            Flexible(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  decodedName,
                  style: AppTextStyles.body2.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            if (count > 0) ...[
              Spacing.sizedBoxH4,
              Text(
                '($count)',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryIcon(String categoryName) {
    // Map category names to emojis/icons
    String emoji = '📦';
    final lowerName = categoryName.toLowerCase();
    
    if (lowerName.contains('audio') || lowerName.contains('theater')) {
      emoji = '🎵';
    } else if (lowerName.contains('tv') || lowerName.contains('video')) {
      emoji = '📺';
    } else if (lowerName.contains('camera') || lowerName.contains('photo')) {
      emoji = '📷';
    } else if (lowerName.contains('bag')) {
      emoji = '👜';
    } else if (lowerName.contains('clothing') || lowerName.contains('apparel')) {
      emoji = '👕';
    } else if (lowerName.contains('computer') || lowerName.contains('tech')) {
      emoji = '💻';
    } else if (lowerName.contains('electric')) {
      emoji = '⚡';
    } else if (lowerName.contains('baby') || lowerName.contains('mom')) {
      emoji = '👶';
    } else if (lowerName.contains('book') || lowerName.contains('office')) {
      emoji = '📚';
    }

    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          emoji,
          style: const TextStyle(fontSize: 30),
        ),
      ),
    );
  }
}
