import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

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
          backgroundColor: AppColors.yellow,
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
                          });
                        },
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
                                    // Perform search
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
      body: _isSearching ? _buildSearchSuggestions() : _buildDefaultContent(),
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
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Trending Categories',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: _buildCategoryCard(
                    trendingCategories[0]['name']!,
                    trendingCategories[0]['icon']!,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildCategoryCard(
                    trendingCategories[1]['name']!,
                    trendingCategories[1]['icon']!,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: _buildCategoryCard(
                    trendingCategories[2]['name']!,
                    trendingCategories[2]['icon']!,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(child: SizedBox()),
              ],
            ),
          ),
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
}