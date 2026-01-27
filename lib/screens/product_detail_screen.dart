import 'dart:convert';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/spacing.dart';
import '../services/api_service.dart';
import '../services/api_endpoints.dart';
import '../services/session_manager.dart';
import '../utils/safe_print.dart';
import '../utils/custom_snackbar.dart';
import 'main_tabs_screen.dart';
import 'package:google_fonts/google_fonts.dart';

class ProductDetailScreen extends StatefulWidget {
  static const String routeName = '/product-detail';
  final int productId;

  const ProductDetailScreen({
    super.key,
    required this.productId,
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  Map<String, dynamic>? _product;
  List<Map<String, dynamic>> _relatedProducts = [];
  List<Map<String, dynamic>> _variations = [];
  bool _isLoading = true;
  String? _errorMessage;
  int _currentImageIndex = 0;
  String? _selectedVariation;
  int _selectedVariationIndex = 0;
  int _quantity = 1;
  int _cartCount = 2;
  bool _isWishlisted = false;
  bool _isAddingToCart = false;
  bool _isTogglingFavorite = false;
  final PageController _imagePageController = PageController();

  @override
  void initState() {
    super.initState();
    _loadProductDetails();
  }

  @override
  void dispose() {
    _imagePageController.dispose();
    super.dispose();
  }

  Future<void> _loadProductDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await ApiService.gets(
        '${ApiEndpoints.products}/${widget.productId}',
      );

      if (response.statusCode == 200) {
        final productData = jsonDecode(response.body);
        setState(() {
          _product = Map<String, dynamic>.from(productData);
          _isWishlisted = productData['is_favorite'] ?? false;
          _isLoading = false;
        });
        
        // Load related products and variations
        _loadRelatedProducts();
        if (productData['type'] == 'variable' && 
            productData['variations'] != null && 
            (productData['variations'] as List).isNotEmpty) {
          _loadVariations(productData['variations'] as List);
        }
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load product: ${response.statusCode}';
        });
        safePrint('❌ Error loading product: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error loading product: $e';
      });
      safePrint('❌ Exception loading product: $e');
      safePrint('Stack trace: $stackTrace');
    }
  }

  Future<void> _loadRelatedProducts() async {
    if (_product == null) return;

    try {
      final relatedIds = _product!['related_ids'] as List?;
      if (relatedIds == null || relatedIds.isEmpty) return;

      // Fetch related products
      final List<Map<String, dynamic>> related = [];
      for (var id in relatedIds.take(4)) {
        try {
          final response = await ApiService.gets('${ApiEndpoints.products}/$id');
          if (response.statusCode == 200) {
            related.add(Map<String, dynamic>.from(jsonDecode(response.body)));
          }
        } catch (e) {
          safePrint('Error loading related product $id: $e');
        }
      }

      setState(() {
        _relatedProducts = related;
      });
    } catch (e) {
      safePrint('Error loading related products: $e');
    }
  }

  Future<void> _loadVariations(List variationIds) async {
    if (_product == null) return;

    try {
      final List<Map<String, dynamic>> fetchedVariations = [];
      
      for (var id in variationIds) {
        try {
          final response = await ApiService.gets(
            '${ApiEndpoints.products}/${widget.productId}/variations/$id'
          );
          if (response.statusCode == 200) {
            fetchedVariations.add(
              Map<String, dynamic>.from(jsonDecode(response.body))
            );
          }
        } catch (e) {
          safePrint('Error loading variation $id: $e');
        }
      }

      setState(() {
        _variations = fetchedVariations;
        if (_variations.isNotEmpty) {
          _selectedVariation = _variations[0]['id'].toString();
        }
      });
    } catch (e) {
      safePrint('Error loading variations: $e');
    }
  }

  Future<void> _toggleFavorite() async {
    if (_isTogglingFavorite || _product == null) return;
    
    setState(() => _isTogglingFavorite = true);

    try {
      final token = await SessionManager.getValidFirebaseToken();
      if (token == null) {
        CustomSnackBar.show(context, 'Please login to add favorites', isError: true);
        setState(() => _isTogglingFavorite = false);
        return;
      }

      final response = await ApiService.posts(
        '/toggle-favorite',
        {
          'product_id': widget.productId.toString(),
          'variation_id': _selectedVariation ?? widget.productId.toString(),
        },
        token: token,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _isWishlisted = !_isWishlisted;
        });
        CustomSnackBar.show(
          context,
          data['message'] ?? (_isWishlisted ? 'Added to favorites' : 'Removed from favorites'),
          isError: false,
        );
      } else {
        CustomSnackBar.show(context, 'Failed to update favorite', isError: true);
      }
    } catch (e) {
      safePrint('Error toggling favorite: $e');
      CustomSnackBar.show(context, 'Something went wrong', isError: true);
    } finally {
      setState(() => _isTogglingFavorite = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : _errorMessage != null
                ? _buildErrorState()
                : _product == null
                    ? _buildEmptyState()
                    : _buildProductDetail(),
      ),
    );
  }

  Widget _buildProductDetail() {
    final images = _product!['images'] as List? ?? [];
    final name = _product!['name'] ?? 'Product Name';
    final brands = _product!['brands'] as List?;
    final brandName = brands != null && brands.isNotEmpty 
        ? brands[0]['name'] as String? 
        : null;
    final rating = double.tryParse(_product!['average_rating']?.toString() ?? '0') ?? 0.0;
    final ratingCount = _product!['rating_count'] ?? 0;
    final price = _product!['price']?.toString() ?? '0';
    final regularPrice = _product!['regular_price']?.toString();
    final onSale = _product!['on_sale'] ?? false;
    final stockStatus = _product!['stock_status']?.toString() ?? 'instock';
    final shortDescription = _product!['short_description']?.toString() ?? '';
    final description = _product!['description']?.toString() ?? '';
    final categories = _product!['categories'] as List?;
    final categoryName = categories != null && categories.isNotEmpty
        ? categories[0]['name'] as String?
        : null;
    final sku = _product!['sku']?.toString() ?? '';
    final attributes = _product!['attributes'] as List? ?? [];
    final variations = _product!['variations'] as List? ?? [];

    final priceValue = double.tryParse(price) ?? 0.0;
    final regularPriceValue = regularPrice != null ? double.tryParse(regularPrice) : null;
    final discountPercent = onSale && regularPriceValue != null && regularPriceValue > priceValue
        ? ((regularPriceValue - priceValue) / regularPriceValue * 100).round()
        : null;
    final isInStock = stockStatus.toLowerCase() == 'instock';

    return Column(
      children: [
        // Header
        _buildHeader(),
        // Content
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image Gallery
                if (images.isNotEmpty) _buildImageGallery(images),
                Spacing.sizedBoxH16,
                // Product Info
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Product Name & Brand
                      Text(
                        name,
                        style: AppTextStyles.heading1,
                      ),
                      if (brandName != null) ...[
                        Spacing.sizedBoxH4,
                        Text(
                          brandName,
                          style: AppTextStyles.body1.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                      Spacing.sizedBoxH8,
                      // Rating and Wishlist
                      Row(
                        children: [
                          ...List.generate(5, (index) => Icon(
                            Icons.star,
                            size: 16,
                            color: index < rating.round()
                                ? AppColors.primary
                                : Colors.grey.shade300,
                          )),
                          Spacing.sizedBoxW8,
                          Flexible(
                            child: Text(
                              rating.toStringAsFixed(2),
                              style: AppTextStyles.body2.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Spacing.sizedBoxW4,
                          Flexible(
                            child: Text(
                              '($ratingCount reviews)',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: _isTogglingFavorite
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : Icon(
                                    _isWishlisted ? Icons.favorite : Icons.favorite_border,
                                    color: _isWishlisted ? Colors.red : Colors.grey,
                                    size: 24,
                                  ),
                            onPressed: _toggleFavorite,
                          ),
                        ],
                      ),
                      Spacing.sizedBoxH16,
                      // Price
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          Text(
                            '₹${priceValue.toStringAsFixed(2)}',
                            style: AppTextStyles.heading1.copyWith(
                              color: onSale ? Colors.red : AppColors.textPrimary,
                            ),
                          ),
                          if (onSale && regularPriceValue != null) ...[
                            Text(
                              '₹${regularPriceValue.toStringAsFixed(2)}',
                              style: AppTextStyles.body1.copyWith(
                                decoration: TextDecoration.lineThrough,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${discountPercent}% OFF',
                                style: AppTextStyles.caption.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Spacing.sizedBoxH8,
                      // Stock Status
                      Row(
                        children: [
                          Icon(
                            isInStock ? Icons.check_circle : Icons.cancel,
                            size: 16,
                            color: isInStock ? Colors.green : Colors.red,
                          ),
                          Spacing.sizedBoxW4,
                          Text(
                            'Status: ${isInStock ? 'In Stock' : 'Out of Stock'}',
                            style: AppTextStyles.body2.copyWith(
                              color: isInStock ? Colors.green : Colors.red,
                            ),
                          ),
                        ],
                      ),
                      Spacing.sizedBoxH16,
                      // Key Features
                      if (shortDescription.isNotEmpty) _buildKeyFeatures(shortDescription),
                      Spacing.sizedBoxH16,
                      // Color/Variation Options
                      if (attributes.isNotEmpty || _variations.isNotEmpty) 
                        _buildVariationOptions(attributes, variations),
                      Spacing.sizedBoxH16,
                      // Quantity Selector
                      _buildQuantitySelector(),
                      Spacing.sizedBoxH16,
                      // Category & SKU
                      _buildCategoryAndSku(categoryName, sku),
                      Spacing.sizedBoxH24,
                      // Frequently Bought Together
                      _buildFrequentlyBoughtTogether(),
                      Spacing.sizedBoxH24,
                      // Seller Information
                      _buildSellerInfo(),
                      Spacing.sizedBoxH24,
                      // Description
                      _buildDescription(description),
                      Spacing.sizedBoxH24,
                      // Reviews
                      _buildReviewsSection(rating, ratingCount),
                      Spacing.sizedBoxH24,
                      // Related Products
                      if (_relatedProducts.isNotEmpty) _buildRelatedProducts(),
                      Spacing.sizedBoxH24,
                      // Recently Viewed
                      _buildRecentlyViewed(),
                      Spacing.sizedBoxH80, // Space for bottom buttons
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        // Bottom Action Buttons
        _buildBottomActions(isInStock),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.of(context).pop(),
          ),
          Text(
            'Back to Shop',
            style: AppTextStyles.body1,
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.search, color: Colors.black),
            onPressed: () {},
          ),
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_bag_outlined, color: Colors.black),
                onPressed: () {},
              ),
              if (_cartCount > 0)
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
                      '$_cartCount',
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
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildImageGallery(List images) {
    return SizedBox(
      height: 300,
      child: Stack(
        children: [
          PageView.builder(
            controller: _imagePageController,
            itemCount: images.length,
            onPageChanged: (index) {
              setState(() => _currentImageIndex = index);
            },
            itemBuilder: (context, index) {
              final imageUrl = images[index]['src'] as String?;
              return imageUrl != null
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildPlaceholderImage(),
                    )
                  : _buildPlaceholderImage();
            },
          ),
          if (images.length > 1)
            Positioned(
              bottom: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_currentImageIndex + 1}/${images.length}',
                  style: const TextStyle(
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

  Widget _buildKeyFeatures(String shortDescription) {
    // Parse HTML and extract list items
    final items = shortDescription
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .take(5)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Key Features:',
          style: AppTextStyles.heading3,
        ),
        Spacing.sizedBoxH8,
        ...items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle, size: 16, color: Colors.green),
                  Spacing.sizedBoxW8,
                  Expanded(
                    child: Text(
                      item.trim(),
                      style: AppTextStyles.body2,
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }

  Widget _buildVariationOptions(List attributes, List variations) {
    // Find weight or size attribute (common for products)
    final weightAttr = attributes.firstWhere(
      (attr) {
        final name = (attr['name']?.toString().toLowerCase() ?? '');
        return name.contains('weight') || name.contains('size') || name.contains('color');
      },
      orElse: () => null,
    );

    if (weightAttr == null && _variations.isEmpty) return const SizedBox.shrink();

    final options = weightAttr != null 
        ? (weightAttr['options'] as List? ?? [])
        : _variations.map((v) => v['name'] ?? 'Option ${_variations.indexOf(v) + 1}').toList();
    
    if (options.isEmpty && _variations.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          weightAttr != null 
              ? '${weightAttr['name']} Options:'
              : 'Variations:',
          style: AppTextStyles.heading3,
        ),
        Spacing.sizedBoxH12,
        SizedBox(
          height: 50,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: options.length,
            itemBuilder: (context, index) {
              final optionName = options[index].toString();
              final isSelected = _selectedVariationIndex == index;
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _selectedVariationIndex = index;
                      if (_variations.isNotEmpty && index < _variations.length) {
                        _selectedVariation = _variations[index]['id'].toString();
                      }
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isSelected ? AppColors.primary : AppColors.border,
                        width: isSelected ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.transparent,
                    ),
                    child: Center(
                      child: Text(
                        optionName,
                        style: AppTextStyles.body2.copyWith(
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          color: isSelected ? AppColors.primary : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildQuantitySelector() {
    return Row(
      children: [
        Text(
          'Quantity:',
          style: AppTextStyles.heading3,
        ),
        Spacing.sizedBoxW16,
        Flexible(
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove, size: 20),
                  onPressed: _quantity > 1
                      ? () => setState(() => _quantity--)
                      : null,
                ),
                Container(
                  width: 50,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    '$_quantity',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.body1.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add, size: 20),
                  onPressed: () => setState(() => _quantity++),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryAndSku(String? categoryName, String sku) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (categoryName != null) ...[
          Text(
            'Category: ',
            style: AppTextStyles.body2.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          Flexible(
            child: Text(
              categoryName,
              style: AppTextStyles.body2,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
        Text(
          'SKU: ',
          style: AppTextStyles.body2.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        Flexible(
          child: Text(
            sku,
            style: AppTextStyles.body2,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildFrequentlyBoughtTogether() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Frequently Bought Together',
          style: AppTextStyles.heading2,
        ),
        Spacing.sizedBoxH16,
        Row(
          children: [
            Expanded(child: _buildPlaceholderBox()),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Icon(Icons.add, size: 24),
            ),
            Expanded(child: _buildPlaceholderBox()),
          ],
        ),
        Spacing.sizedBoxH16,
        Text(
          'Total Price: ₹1,905.20',
          style: AppTextStyles.heading3,
        ),
        Spacing.sizedBoxH12,
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: const BorderSide(color: AppColors.border),
                ),
                child: Text(
                  'Add All To Wishlist',
                  style: AppTextStyles.body1,
                ),
              ),
            ),
            Spacing.sizedBoxW12,
            Expanded(
              child: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text(
                  'Add All To Cart',
                  style: AppTextStyles.body1.copyWith(
                    color: Colors.black,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSellerInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'DIGIWORLD US',
                style: AppTextStyles.heading3,
              ),
              Spacing.sizedBoxH4,
              Text(
                '92% Positive customer\'s rating',
                style: AppTextStyles.body2.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              Spacing.sizedBoxH4,
              Text(
                '105 ratings',
                style: AppTextStyles.caption,
              ),
            ],
          ),
          const Spacer(),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.black,
            ),
            child: Text(
              'Visit',
              style: AppTextStyles.body1.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescription(String description) {
    // Remove HTML tags for display
    final cleanDescription = description
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Description',
          style: AppTextStyles.heading2,
        ),
        Spacing.sizedBoxH12,
        Text(
          cleanDescription,
          style: AppTextStyles.body2,
          maxLines: 10,
          overflow: TextOverflow.ellipsis,
        ),
        Spacing.sizedBoxH8,
        TextButton(
          onPressed: () {},
          child: Text(
            'Learn More',
            style: AppTextStyles.body2.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReviewsSection(double rating, int ratingCount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Reviews ($ratingCount)',
          style: AppTextStyles.heading2,
        ),
        Spacing.sizedBoxH12,
        Row(
          children: [
            Text(
              rating.toStringAsFixed(2),
              style: AppTextStyles.heading2,
            ),
            Spacing.sizedBoxW8,
            ...List.generate(5, (index) => Icon(
              Icons.star,
              size: 20,
              color: index < rating.round()
                  ? AppColors.primary
                  : Colors.grey.shade300,
            )),
          ],
        ),
        Spacing.sizedBoxH16,
        // Submit Review Form
        _buildReviewForm(),
        Spacing.sizedBoxH24,
        // Top Reviews
        _buildTopReviews(),
      ],
    );
  }

  Widget _buildReviewForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Submit Your Review',
            style: AppTextStyles.heading3,
          ),
          Spacing.sizedBoxH12,
          Text(
            'Your rating of this product',
            style: AppTextStyles.body2,
          ),
          Spacing.sizedBoxH8,
          Row(
            children: List.generate(5, (index) => IconButton(
              icon: const Icon(Icons.star_border, size: 24),
              onPressed: () {},
            )),
          ),
          Spacing.sizedBoxH12,
          TextField(
            decoration: InputDecoration(
              labelText: 'Your Name',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          Spacing.sizedBoxH12,
          TextField(
            decoration: InputDecoration(
              labelText: 'Your Email Address',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          Spacing.sizedBoxH12,
          TextField(
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Write your review...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          Spacing.sizedBoxH12,
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.camera_alt, size: 16),
                label: const Text('Add photo'),
              ),
              Spacing.sizedBoxW8,
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.videocam, size: 16),
                label: const Text('Add video'),
              ),
            ],
          ),
          Spacing.sizedBoxH12,
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Text(
                'Submit Review',
                style: AppTextStyles.body1.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopReviews() {
    // Mock reviews - replace with actual API data
    final reviews = [
      {'name': 'Ron Weasley', 'rating': 5, 'time': '15 hours ago', 'comment': 'Great sound and very love it!'},
      {'name': 'Anna Rooly', 'rating': 5, 'time': 'Aug 23, 2024', 'comment': 'I heart this little unit'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Top Reviews',
          style: AppTextStyles.heading3,
        ),
        Spacing.sizedBoxH12,
        ...reviews.map((review) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          review['name'] as String,
                          style: AppTextStyles.body1.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Spacing.sizedBoxW8,
                        ...List.generate(5, (index) => Icon(
                          Icons.star,
                          size: 14,
                          color: index < (review['rating'] as int)
                              ? AppColors.primary
                              : Colors.grey.shade300,
                        )),
                        const Spacer(),
                        Text(
                          review['time'] as String,
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    Spacing.sizedBoxH8,
                    Text(
                      review['comment'] as String,
                      style: AppTextStyles.body2,
                    ),
                  ],
                ),
              ),
            )),
      ],
    );
  }

  Widget _buildRelatedProducts() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Related Products',
          style: AppTextStyles.heading2,
        ),
        Spacing.sizedBoxH16,
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _relatedProducts.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: _buildRelatedProductCard(_relatedProducts[index]),
              );
            },
          ),
        ),
        Spacing.sizedBoxH8,
        _buildCarouselIndicator(_relatedProducts.length, 0),
      ],
    );
  }

  Widget _buildRelatedProductCard(Map<String, dynamic> product) {
    final name = product['name'] ?? 'Product';
    final price = product['price']?.toString() ?? '0';
    final images = product['images'] as List?;
    final imageUrl = images != null && images.isNotEmpty
        ? images[0]['src'] as String?
        : null;
    final rating = double.tryParse(product['average_rating']?.toString() ?? '0') ?? 0.0;
    final ratingCount = product['rating_count'] ?? 0;
    final priceValue = double.tryParse(price) ?? 0.0;

    return InkWell(
      onTap: () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetailScreen(
              productId: product['id'] as int,
            ),
          ),
        );
      },
      child: Container(
        width: 160,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
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
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: AppTextStyles.body2,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Spacing.sizedBoxH4,
                  Row(
                    children: [
                      ...List.generate(5, (index) => Icon(
                        Icons.star,
                        size: 12,
                        color: index < rating.round()
                            ? AppColors.primary
                            : Colors.grey.shade300,
                      )),
                      Spacing.sizedBoxW4,
                      Text(
                        ratingCount.toString(),
                        style: AppTextStyles.caption,
                      ),
                    ],
                  ),
                  Spacing.sizedBoxH4,
                  Text(
                    '₹${priceValue.toStringAsFixed(2)}',
                    style: AppTextStyles.body1.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
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
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: _buildPlaceholderBox(),
              );
            },
          ),
        ),
        Spacing.sizedBoxH8,
        _buildCarouselIndicator(3, 0),
      ],
    );
  }

  Widget _buildBottomActions(bool isInStock) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _isAddingToCart ? null : () => _addToCart(),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: const BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isAddingToCart
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      'Add to Cart',
                      style: AppTextStyles.body1.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
          Spacing.sizedBoxW12,
          Expanded(
            child: ElevatedButton(
              onPressed: (isInStock && !_isAddingToCart) ? () => _buyNow() : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isAddingToCart
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                      ),
                    )
                  : Text(
                      'Buy Now',
                      style: AppTextStyles.body1.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderBox() {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
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

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 80,
              color: AppColors.error,
            ),
            Spacing.sizedBoxH16,
            Text(
              _errorMessage ?? 'Error loading product',
              style: AppTextStyles.heading3.copyWith(
                color: AppColors.error,
              ),
              textAlign: TextAlign.center,
            ),
            Spacing.sizedBoxH16,
            ElevatedButton(
              onPressed: _loadProductDetails,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.black,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Text(
        'Product not found',
        style: AppTextStyles.heading3.copyWith(
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  Future<void> _addToCart({bool navigateToCart = false}) async {
    if (_isAddingToCart || _product == null) return;
    
    setState(() => _isAddingToCart = true);

    try {
      final token = await SessionManager.getValidFirebaseToken();
      if (token == null) {
        CustomSnackBar.show(context, 'Please login to add to cart', isError: true);
        setState(() => _isAddingToCart = false);
        return;
      }

      final payload = {
        'product_id': widget.productId.toString(),
        'quantity': _quantity,
      };

      // Add variation if selected
      if (_selectedVariation != null && _variations.isNotEmpty) {
        final selectedVar = _variations[_selectedVariationIndex];
        payload['variation_id'] = _selectedVariation!;
        
        // Add variation attributes if available
        if (selectedVar['attributes'] != null) {
          final attrs = selectedVar['attributes'] as List;
          final variationMap = <String, String>{};
          for (var attr in attrs) {
            if (attr['name'] != null && attr['option'] != null) {
              variationMap['attribute_${attr['name'].toString().toLowerCase().replaceAll(' ', '_')}'] = 
                  attr['option'].toString();
            }
          }
          if (variationMap.isNotEmpty) {
            payload['variation'] = variationMap;
          }
        }
      }

      safePrint('Adding to cart: $payload');
      final response = await ApiService.posts(
        ApiEndpoints.cartAdd,
        payload,
        token: token,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        CustomSnackBar.show(
          context,
          data['message'] ?? 'Added to cart successfully',
          isError: false,
        );
        
        // Update cart count (you can implement a cart counter provider here)
        setState(() {
          _cartCount++;
        });

        if (navigateToCart) {
          // Navigate to cart tab in main tabs
          Navigator.of(context).pushNamedAndRemoveUntil(
            MainTabsScreen.routeName,
            (route) => false,
          );
          // Switch to cart tab (index 2)
          Future.delayed(const Duration(milliseconds: 100), () {
            // You can use a callback or provider to switch tabs
            // For now, just navigate to main tabs
          });
        }
      } else {
        final errorData = jsonDecode(response.body);
        CustomSnackBar.show(
          context,
          errorData['message'] ?? 'Failed to add to cart',
          isError: true,
        );
      }
    } catch (e, stackTrace) {
      safePrint('Error adding to cart: $e');
      safePrint('Stack trace: $stackTrace');
      CustomSnackBar.show(context, 'Something went wrong', isError: true);
    } finally {
      setState(() => _isAddingToCart = false);
    }
  }

  Future<void> _buyNow() async {
    // Add to cart and navigate to checkout
    await _addToCart(navigateToCart: true);
  }
}

