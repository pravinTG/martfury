import 'package:flutter/material.dart';
import '../api_service.dart';
import 'search_screen.dart';
import '../theme/app_colors.dart';
import '../widgets/app_snackbar.dart';

class ProductDetailScreen extends StatefulWidget {
  final int productId;

  const ProductDetailScreen({
    Key? key,
    required this.productId,
  }) : super(key: key);

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final ApiService _apiService = ApiService();
  Map<String, dynamic>? product;
  bool isLoading = true;
  int selectedImageIndex = 0;
  int quantity = 1;
  String selectedColor = 'Brown';
  late PageController _pageController;
  bool isDescriptionExpanded = false;
  bool isAddingToCart = false;
  bool isFavorite = false;
  bool isTogglingFavorite = false;
  String _priceMode = 'normal'; // normal | wallet

  double? _getWalletPrice() {
    final meta = product?['meta_data'];
    if (meta is! List) return null;
    for (final item in meta) {
      if (item is Map && item['key']?.toString() == '_wallet_price') {
        final raw = item['value']?.toString();
        final val = double.tryParse(raw ?? '');
        if (val != null && val > 0) return val;
      }
    }
    return null;
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0;
    return double.tryParse(value.toString()) ?? 0;
  }
  Future<void> _toggleFavorite() async {
    if (product == null || isTogglingFavorite) return;
    setState(() => isTogglingFavorite = true);
    try {
      final productId = (product!['id'] ?? '').toString();
      final response = await _apiService.toggleFavorite(productId: productId);
      final message = (response['message'] ?? 'Wishlist updated').toString();
      final removed = message.toLowerCase().contains('removed');
      if (mounted) {
        setState(() => isFavorite = !removed);
        AppSnackBar.show(context, message, type: AppSnackType.success);
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(context, '$e', type: AppSnackType.error);
      }
    } finally {
      if (mounted) setState(() => isTogglingFavorite = false);
    }
  }


  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    fetchProductDetails();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> fetchProductDetails() async {
    try {
      setState(() {
        isLoading = true;
      });
      final fetchedProduct = await _apiService.getProductDetails(widget.productId);
      setState(() {
        product = fetchedProduct;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      if (mounted) {
        AppSnackBar.show(
          context,
          'Failed to load product details: $e',
          type: AppSnackType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Back to Shop',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              isFavorite ? Icons.favorite : Icons.favorite_border,
              color: isFavorite ? Colors.red : AppColors.textPrimary,
            ),
            onPressed: isTogglingFavorite ? null : _toggleFavorite,
          ),
          IconButton(
            icon: const Icon(Icons.search, color: AppColors.textPrimary),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SearchScreen()),
              );
            },
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.yellow))
          : product == null
          ? const Center(child: Text('Product not found'))
          : SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildImageSection(),
            _buildProductInfo(),
            // _buildColorSelection(),
            _buildQuantitySelection(),
            _buildProductMeta(),
            _buildShareButtons(),
            _buildFrequentlyBought(),
            _buildDescription(),
            _buildReviews(),
            _buildTopReviews(),
            _buildRecentlyViewed(),
            const SizedBox(height: 100),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildImageSection() {
    final images = product!['images'] as List<dynamic>?;
    final imageUrls = images != null && images.isNotEmpty
        ? images.map((img) => img['src'] as String).toList()
        : <String>[];

    if (imageUrls.isEmpty) {
      return Container(
        height: 250,
        color: AppColors.card,
        child: const Center(
          child: Icon(Icons.image_outlined, size: 80, color: AppColors.textSecondary),
        ),
      );
    }

    return Column(
      children: [
        Container(
          height: 250,
          width: double.infinity,
          color: Colors.white,
          child: PageView.builder(
            controller: _pageController,
            itemCount: imageUrls.length,
            onPageChanged: (index) {
              setState(() {
                selectedImageIndex = index;
              });
            },
            itemBuilder: (context, index) {
              return Image.network(
                imageUrls[index],
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const Center(
                    child: Icon(Icons.image_outlined, size: 80, color: AppColors.textSecondary),
                  );
                },
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            imageUrls.length > 4 ? 4 : imageUrls.length,
                (index) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: selectedImageIndex == index ? AppColors.yellow : AppColors.border,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${selectedImageIndex + 1} / ${imageUrls.length}',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildProductInfo() {
    final name = product!['name'] ?? 'Unknown Product';
    final rating = product!['average_rating'] != null
        ? double.tryParse(product!['average_rating'].toString()) ?? 0.0
        : 0.0;
    final reviewCount = product!['rating_count'] ?? 0;
    final price = product!['price'] ?? '0';
    final regularPrice = product!['regular_price'] ?? '';
    final salePrice = product!['sale_price'] ?? '';
    final hasSalePrice = salePrice.isNotEmpty && salePrice != '0';
    final normalPrice = _toDouble(hasSalePrice ? salePrice : price);
    final walletPrice = _getWalletPrice();
    final hasWalletPrice = walletPrice != null && walletPrice > 0 && walletPrice < normalPrice;
    if (!hasWalletPrice && _priceMode == 'wallet') {
      _priceMode = 'normal';
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'Brand: ',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                'Marshall',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.blue,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  ...List.generate(
                    5,
                        (index) => Icon(
                      index < rating.floor() ? Icons.star : Icons.star_border,
                      size: 14,
                      color: AppColors.yellow,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    reviewCount.toString(),
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Icon(Icons.favorite_border, size: 20, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Icon(Icons.share_outlined, size: 20, color: AppColors.textSecondary),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹${normalPrice.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.red,
                ),
              ),
              const SizedBox(width: 8),
              if (hasSalePrice && regularPrice.isNotEmpty)
                Text(
                  '₹$regularPrice',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
            ],
          ),
          if (hasWalletPrice) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEFFAF0),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBFE8C5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Wallet Offer Price: ₹${walletPrice!.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1B7E2B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'You Save: ₹${(normalPrice - walletPrice).toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF2E7D32),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Choose Payment Option',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  RadioListTile<String>(
                    value: 'normal',
                    groupValue: _priceMode,
                    onChanged: (v) => setState(() => _priceMode = v ?? 'normal'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text('Normal Price: ₹${normalPrice.toStringAsFixed(2)}'),
                  ),
                  RadioListTile<String>(
                    value: 'wallet',
                    groupValue: _priceMode,
                    onChanged: (v) => setState(() => _priceMode = v ?? 'wallet'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text('Wallet Price: ₹${walletPrice.toStringAsFixed(2)}'),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                'Status: ',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                'In Stock',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.green,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildBulletPoints(),
        ],
      ),
    );
  }

  Widget _buildBulletPoints() {
    final List<String> features = [
      'Unrestrained and portable active stereo speaker',
      'Free from the confines of wires and chords',
      '20 hours of portable capabilities',
      'Double-ended Coil Cord with 3.5mm Stereo Plugs',
      '3/4" Dome Tweeters: 2X and 4" Woofer: 1X',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: features.map((feature) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 7),
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textSecondary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  feature,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildColorSelection() {
    final List<Map<String, dynamic>> colors = [
      {'name': 'Brown', 'price': '\₹235.35'},
      {'name': 'Black', 'price': '\₹215.99'},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1),
          const SizedBox(height: 16),
          Text(
            'Color: $selectedColor',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: colors.map((color) {
              final isSelected = selectedColor == color['name'];
              return GestureDetector(
                onTap: () {
                  setState(() {
                    selectedColor = color['name'];
                  });
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isSelected ? AppColors.yellow : AppColors.border,
                      width: isSelected ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Text(
                        color['name'],
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        color['price'],
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildQuantitySelection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Quantity:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    onPressed: () {
                      if (quantity > 1) {
                        setState(() {
                          quantity--;
                        });
                      }
                    },
                    icon: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(Icons.remove, size: 16),
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    quantity.toString().padLeft(2, '0'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        quantity++;
                      });
                    },
                    icon: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(Icons.add, size: 16),
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProductMeta() {
    final categories = product!['categories'] as List<dynamic>?;
    final categoryName = categories != null && categories.isNotEmpty
        ? categories[0]['name'] as String
        : 'Unknown';
    final sku = product!['sku']?.toString() ?? 'N/A';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                'Category: ',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                categoryName,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.blue,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'SKU: ',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                sku,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildShareButtons() {
    final List<Map<String, dynamic>> shareOptions = [
      {'icon': Icons.facebook, 'color': Colors.blue},
      {'icon': Icons.mail, 'gradient': true},
      {'icon': Icons.chat_bubble, 'gradient': true},
      {'icon': Icons.message, 'color': Colors.grey},
      {'icon': Icons.link, 'color': Colors.grey},
      {'icon': Icons.more_horiz, 'color': Colors.grey},
    ];

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: shareOptions.map((option) {
          return Container(
            margin: const EdgeInsets.only(right: 12),
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: option['gradient'] == true
                  ? const LinearGradient(
                colors: [Colors.red, Colors.orange, Colors.purple],
              )
                  : null,
              color: option['gradient'] != true ? option['color'].withOpacity(0.1) : null,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              option['icon'],
              color: option['gradient'] == true ? Colors.white : option['color'],
              size: 20,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFrequentlyBought() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1),
          const SizedBox(height: 16),
          const Text(
            'Frequently Bought Together',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Icon(Icons.add, size: 24, color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Marshall Acton III',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const Text(
                    'Compact Bluetooth',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const Text(
                    'Speaker',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '\₹235.35',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Xiaomi UHD Smart TV',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const Text(
                    '70inch',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '\₹1,679.85',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDescription() {
    final description = product!['description']?.toString() ?? '';
    final cleanDescription = description
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .trim();

    if (cleanDescription.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1),
          const SizedBox(height: 16),
          const Text(
            'Description',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Embodying the Raw, Wayward Spirit of Rock \'N\' Roll',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isDescriptionExpanded
                ? cleanDescription
                : cleanDescription.length > 200
                ? '${cleanDescription.substring(0, 200)}...'
                : cleanDescription,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () {
              setState(() {
                isDescriptionExpanded = !isDescriptionExpanded;
              });
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  isDescriptionExpanded ? 'Learn Less' : 'Learn More',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.yellow,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Icon(
                  isDescriptionExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: AppColors.yellow,
                  size: 20,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviews() {
    final rating = product!['average_rating'] != null
        ? double.tryParse(product!['average_rating'].toString()) ?? 0.0
        : 4.25;
    final reviewCount = product!['rating_count'] ?? 3;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1),
          const SizedBox(height: 16),
          Text(
            'Reviews ($reviewCount)',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                rating.toStringAsFixed(2),
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: List.generate(
                      5,
                          (index) => Icon(
                        index < rating.floor() ? Icons.star : Icons.star_border,
                        size: 16,
                        color: AppColors.yellow,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$reviewCount Reviews',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'SUBMIT YOUR REVIEW',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Your rating of this product:',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(
              5,
                  (index) => Icon(
                Icons.star_border,
                size: 24,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            decoration: InputDecoration(
              hintText: 'Your Name',
              hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppColors.border),
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            decoration: InputDecoration(
              hintText: 'Your Email Address',
              hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppColors.border),
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Write your review ...',
              hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppColors.border),
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.photo_camera_outlined, size: 18),
                  label: const Text('Add photo'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.videocam_outlined, size: 18),
                  label: const Text('Add video'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.yellow,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Submit Review',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
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
    final List<Map<String, dynamic>> reviews = [
      {
        'name': 'Ron Weasley',
        'rating': 4,
        'time': '15 hours ago',
        'title': 'Great sound and very love it!',
        'review': 'Whether you like this speaker or not will mainly exxtra hardware other than the 3.5mm',
      },
      {
        'name': 'Anna Rooly',
        'rating': 5,
        'time': 'Aug 23, 2024',
        'title': 'I heart this little unit',
        'review': 'Perfect for my small apartment. Sound quality is amazing!',
      },
    ];

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Top reviews',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              TextButton(
                onPressed: () {},
                child: const Text(
                  'View All',
                  style: TextStyle(
                    color: AppColors.yellow,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...reviews.map((review) => _buildReviewCard(review)).toList(),
        ],
      ),
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> review) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.grey.shade300,
                child: Text(
                  review['name'][0],
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review['name'],
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: List.generate(
                        5,
                            (index) => Icon(
                          index < review['rating'] ? Icons.star : Icons.star_border,
                          size: 14,
                          color: AppColors.yellow,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                review['time'],
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            review['title'],
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            review['review'],
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentlyViewed() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recently Viewed',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              TextButton(
                onPressed: () {},
                child: const Text(
                  'View All',
                  style: TextStyle(
                    color: AppColors.yellow,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 140,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 4,
              itemBuilder: (context, index) {
                return Container(
                  width: 110,
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
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              5,
                  (index) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: index == 0 ? AppColors.yellow : AppColors.border,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
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
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: isAddingToCart
                    ? null
                    : () async {
                        if (product == null) return;
                        setState(() {
                          isAddingToCart = true;
                        });
                        try {
                          final walletPrice = _getWalletPrice();
                          await _apiService.addToCart(
                            productId: product!['id'].toString(),
                            quantity: 1,
                            priceMode: _priceMode,
                            walletPrice: _priceMode == 'wallet' ? walletPrice : null,
                          );
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Added to cart successfully')),
                          );
                        } catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Add to cart failed: $e')),
                          );
                        } finally {
                          if (mounted) {
                            setState(() {
                              isAddingToCart = false;
                            });
                          }
                        }
                      },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: BorderSide(color: AppColors.border),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: isAddingToCart
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        'Add to Cart',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.yellow,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Buy Now',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }}