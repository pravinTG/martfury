import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart' show GoogleFonts;
import '../services/api_endpoints.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/safe_print.dart';
import 'category_products_screen.dart';

class CategoryScreen extends StatefulWidget {
  static const String routeName = '/categories';

  const CategoryScreen({super.key});

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;

  List<Map<String, dynamic>> _allCategories = [];
  List<Map<String, dynamic>> _parentCategories = [];
  List<Map<String, dynamic>> _childCategories = [];
  int? _selectedParentId;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoading = true);

    try {
      // Fetch a large page; WooCommerce default max is often 100.
      final response = await ApiService.gets(
        ApiEndpoints.productsCategories,
        queryParams: const {
          'per_page': '100',
          'page': '1',
          'hide_empty': 'false',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final list = data.map((e) => Map<String, dynamic>.from(e)).toList();

        // Decode HTML entities in category names.
        for (final c in list) {
          final raw = (c['name'] ?? '').toString();
          c['name'] = _decodeHtml(raw);
        }

        final parents = list.where((c) => (c['parent'] ?? 0) == 0).toList();

        setState(() {
          _allCategories = list;
          _parentCategories = parents;
          _selectedParentId = parents.isNotEmpty ? parents.first['id'] as int : null;
          _filterChildren();
          _isLoading = false;
        });
      } else {
        safePrint('❌ Error loading categories: ${response.statusCode}');
        setState(() => _isLoading = false);
      }
    } catch (e) {
      safePrint('❌ Exception loading categories: $e');
      setState(() => _isLoading = false);
    }
  }

  void _filterChildren() {
    if (_selectedParentId == null) {
      _childCategories = [];
      return;
    }

    _childCategories =
        _allCategories.where((c) => (c['parent'] ?? 0) == _selectedParentId).toList();
  }

  void _onSelectParent(int parentId) {
    setState(() {
      _selectedParentId = parentId;
      _filterChildren();
    });
  }

  void _openProducts(Map<String, dynamic> category) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CategoryProductsScreen(
          categoryId: category['id'].toString(),
          categoryName: (category['name'] ?? '').toString(),
        ),
      ),
    );
  }

  String _decodeHtml(String value) {
    return value
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#039;', "'");
  }

  @override
  Widget build(BuildContext context) {
    final selectedParent = _parentCategories
        .where((c) => c['id'] == _selectedParentId)
        .cast<Map<String, dynamic>>()
        .toList();
    final selectedParentName =
        selectedParent.isNotEmpty ? (selectedParent.first['name'] ?? '').toString() : '';

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    )
                  : Row(
                      children: [
                        _buildLeftCategoryRail(),
                        _buildRightSubCategoryPanel(selectedParentName),
                      ],
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
          Text(
            'Category',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildLeftCategoryRail() {
    return Container(
      width: 120,
      color: const Color(0xFFF7F7F7),
      child: ListView(
        children: [
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Text(
              'Promotions',
              style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
            ),
          ),
          ..._parentCategories.map((cat) {
            final id = cat['id'] as int? ?? 0;
            final name = (cat['name'] ?? '').toString();
            final selected = id == _selectedParentId;

            return InkWell(
              onTap: () => _onSelectParent(id),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                decoration: BoxDecoration(
                  color: selected ? Colors.white : Colors.transparent,
                  border: selected
                      ? const Border(
                          left: BorderSide(color: AppColors.primary, width: 4),
                        )
                      : null,
                ),
                child: Text(
                  name,
                  style: AppTextStyles.body2.copyWith(
                    color: selected ? AppColors.textPrimary : AppColors.textSecondary,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildRightSubCategoryPanel(String selectedParentName) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    selectedParentName,
                    style: AppTextStyles.heading3.copyWith(fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.black),
              ],
            ),
          ),
          Expanded(
            child: _childCategories.isEmpty
                ? Center(
                    child: Text(
                      'No subcategories',
                      style: AppTextStyles.body2.copyWith(color: AppColors.textSecondary),
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      childAspectRatio: 0.86,
                    ),
                    itemCount: _childCategories.length,
                    itemBuilder: (context, index) {
                      final cat = _childCategories[index];
                      final name = (cat['name'] ?? '').toString();
                      final imageUrl = cat['image']?['src']?.toString();

                      return InkWell(
                        onTap: () => _openProducts(cat),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              height: 86,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3F3F3),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: (imageUrl != null && imageUrl.isNotEmpty)
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: Image.network(
                                        imageUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              name,
                              style: AppTextStyles.body2.copyWith(fontSize: 12),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
