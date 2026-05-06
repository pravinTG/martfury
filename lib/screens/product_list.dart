import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../api_service.dart';
import 'product_detail_screen.dart';
import '../widgets/app_snackbar.dart';

class ProductListScreen extends StatefulWidget {
  final int categoryId;
  final String categoryName;

  const ProductListScreen({
    Key? key,
    required this.categoryId,
    this.categoryName = 'Consumer Electric',
  }) : super(key: key);

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  String selectedSort = 'Best Match';
  final ApiService _apiService = ApiService();
  final Set<int> _favoriteProductIds = <int>{};
  List<Map<String, dynamic>> products = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchProducts();
  }

  Future<void> fetchProducts() async {
    try {
      setState(() {
        isLoading = true;
      });
      final fetchedProducts = await _apiService.getProductsByCategory(
        categoryId: widget.categoryId,
      );
      setState(() {
        products = fetchedProducts;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      print('Error fetching products: $e');
      if (mounted) {
        AppSnackBar.show(context, 'Failed to load products: $e', type: AppSnackType.error);
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
      AppSnackBar.show(context, message, type: AppSnackType.success);
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.show(context, '$e', type: AppSnackType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColors.yellow,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.categoryName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: () {},
          ),
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_bag_outlined),
                color: Colors.white,
                onPressed: () {},
              ),
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: const Text(
                    '2',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Filter Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                _buildFilterButton('Filter', Icons.tune, () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const FilterScreen(),
                    ),
                  );
                }),
                const SizedBox(width: 8),
                _buildFilterButton(selectedSort, Icons.swap_vert, () {
                  _showSortBottomSheet(context);
                }),
              ],
            ),
          ),

          // Products Grid
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : products.isEmpty
                    ? const Center(
                        child: Text(
                          'No products available',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.65,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: products.length,
                        itemBuilder: (context, index) {
                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ProductDetailScreen(
                                    productId: products[index]['id'],
                                  ),
                                ),
                              );
                            },
                            child: _buildProductCard(products[index]),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButton(String label, IconData icon, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: Colors.black87),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
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
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
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
                        '\$${hasSalePrice ? salePrice : price}',
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
                          '\$$regularPrice',
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

  void _showSortBottomSheet(BuildContext context) {
    final sortOptions = [
      'Best Match',
      'Price: Low to High',
      'Price: High to Low',
      'Newest',
      'Top Rated',
    ];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Sort By',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 24),
            ...sortOptions.map((option) => ListTile(
              title: Text(
                option,
                style: TextStyle(
                  color: selectedSort == option
                      ? const Color(0xFFFDB913)
                      : Colors.black87,
                  fontWeight: selectedSort == option
                      ? FontWeight.w600
                      : FontWeight.normal,
                ),
              ),
              trailing: selectedSort == option
                  ? const Icon(Icons.check, color: Color(0xFFFDB913))
                  : null,
              onTap: () {
                setState(() {
                  selectedSort = option;
                });
                Navigator.pop(context);
              },
            )),
          ],
        ),
      ),
    );
  }

  void _showFilterBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Filters',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed: () {},
                    child: const Text(
                      'Reset',
                      style: TextStyle(
                        color: Color(0xFFFDB913),
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    const Text(
                      'Price Range',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    RangeSlider(
                      values: const RangeValues(20, 200),
                      min: 0,
                      max: 500,
                      activeColor: const Color(0xFFFDB913),
                      onChanged: (values) {},
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Brand',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...['Bosch', 'Samsung', 'LG', 'Sony'].map(
                          (brand) => CheckboxListTile(
                        title: Text(brand),
                        value: false,
                        activeColor: const Color(0xFFFDB913),
                        onChanged: (value) {},
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFDB913),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Apply Filters',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}



class FilterScreen extends StatefulWidget {
  const FilterScreen({Key? key}) : super(key: key);

  @override
  State<FilterScreen> createState() => _FilterScreenState();
}

class _FilterScreenState extends State<FilterScreen> {
  final TextEditingController _brandSearchController = TextEditingController();
  final TextEditingController _manufacturerSearchController = TextEditingController();

  RangeValues _priceRange = const RangeValues(500, 5000);

  // Category options
  Map<String, bool> categories = {
    'Type Hanging On Wall': false,
    'Type Erect': true,
    'Type Hanging On Ceiling': false,
    'Accessories': false,
  };

  // Highlight selection
  String? selectedHighlight = 'New Arrivals';

  // Brand selection
  Set<String> selectedBrands = {'Electrolux'};
  final List<String> brandList = [
    'Electrolux',
    'Sony',
    'Daikin',
    'Hitachi',
    'LG',
    'Samsung',
    'Panasonic',
    'Blue Stone',
  ];
  bool showAllBrands = false;

  // Manufacturer selection
  Set<String> selectedManufacturers = {};
  final List<String> manufacturerList = [
    'Amazon',
    'ABB SmartWorld',
    'Digiworld',
    'Techland USA',
    'Meidamart UK',
  ];
  bool showAllManufacturers = false;

  // Delivery & Payment options
  Set<String> selectedDeliveryOptions = {};
  final List<String> deliveryOptions = [
    'Freeship By MartFury',
    'Payment On Delivery',
    'Verify By MartFury',
    'Ship To Vietnam',
  ];

  // Review rating
  int? selectedReview;

  // Color selection
  Set<Color> selectedColors = {};
  final List<Color> availableColors = [
    const Color(0xFFFF69B4), // Pink
    const Color(0xFFE91E63), // Magenta
    const Color(0xFF9C27B0), // Purple
    const Color(0xFF2196F3), // Blue
    const Color(0xFF00BCD4), // Cyan
    const Color(0xFF009688), // Teal
    const Color(0xFF8BC34A), // Light Green
    const Color(0xFFFF9800), // Orange
    const Color(0xFFFF5722), // Deep Orange
    const Color(0xFFF44336), // Red
    Colors.black,
  ];

  // Size selection
  Set<String> selectedSizes = {'M'};
  final List<String> sizeList = [
    'XXS',
    'XS',
    'S',
    'M',
    'L',
    'XL',
    'XXL',
    '3XL',
    '4XL',
    '5XL',
    '6XL',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFFFDB825),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Consumer Electric',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_bag_outlined),
                color: AppColors.textPrimary,
                onPressed: () {},
              ),
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: const Text(
                    '2',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: AppColors.textPrimary),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Filter header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.tune, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Filter',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    '7',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          // Scrollable filter content
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Category Section
                _buildExpandableSection(
                  'Category',
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left side categories
                      SizedBox(
                        height: 200,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Category list
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildCategoryItem('TV Televisions', false),
                                  _buildCategoryItem('Air Conditioners', true),
                                  _buildCategoryItem('Washing Machines', false),
                                  _buildCategoryItem('Microwaves', false),
                                  _buildCategoryItem('Refrigerators', false),
                                  _buildCategoryItem('Office Electronics', false),
                                ],
                              ),
                            ),
                            // Checkboxes
                            Expanded(
                              flex: 4,
                              child: Column(
                                children: categories.keys.map((category) {
                                  return CheckboxListTile(
                                    title: Text(
                                      category,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    value: categories[category],
                                    activeColor: const Color(0xFFFDB913),
                                    onChanged: (value) {
                                      setState(() {
                                        categories[category] = value!;
                                      });
                                    },
                                    controlAffinity: ListTileControlAffinity.trailing,
                                    contentPadding: EdgeInsets.zero,
                                    dense: true,
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(height: 32),

                // Highlight Section
                _buildExpandableSection(
                  'Highlight',
                  Wrap(
                    spacing: 8,
                    children: ['Promotions', 'New Arrivals'].map((highlight) {
                      final isSelected = selectedHighlight == highlight;
                      return InkWell(
                        onTap: () {
                          setState(() {
                            selectedHighlight = isSelected ? null : highlight;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.yellow[100] : Colors.transparent,
                            border: Border.all(
                              color: isSelected ? const Color(0xFFFDB913) : Colors.grey.shade300,
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            highlight,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: isSelected ? Colors.black87 : Colors.black54,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                const Divider(height: 32),

                // By Brand Section
                _buildExpandableSection(
                  'By Brand',
                  Column(
                    children: [
                      // Search field
                      TextField(
                        controller: _brandSearchController,
                        decoration: InputDecoration(
                          hintText: 'Search brand',
                          hintStyle: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 14,
                          ),
                          suffixIcon: const Icon(Icons.search, size: 20),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: (showAllBrands ? brandList : brandList.take(8).toList())
                            .map((brand) {
                          final isSelected = selectedBrands.contains(brand);
                          return InkWell(
                            onTap: () {
                              setState(() {
                                if (isSelected) {
                                  selectedBrands.remove(brand);
                                } else {
                                  selectedBrands.add(brand);
                                }
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.yellow[100] : Colors.transparent,
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFFFDB913)
                                      : Colors.grey.shade300,
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                brand,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: isSelected ? Colors.black87 : Colors.black54,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      if (brandList.length > 8)
                        TextButton(
                          onPressed: () {
                            setState(() {
                              showAllBrands = !showAllBrands;
                            });
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                showAllBrands ? 'Show Less' : 'Show More',
                                style: const TextStyle(
                                  color: Color(0xFFFDB913),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Icon(
                                showAllBrands ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                                color: const Color(0xFFFDB913),
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),

                const Divider(height: 32),

                // By Price Section
                _buildExpandableSection(
                  'By Price',
                  Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '\$${_priceRange.start.round()}.00',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '\$${_priceRange.end.round()}.00',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: const Color(0xFFFDB913),
                          inactiveTrackColor: Colors.grey[300],
                          thumbColor: const Color(0xFFFDB913),
                          overlayColor: const Color(0xFFFDB913).withOpacity(0.2),
                          trackHeight: 4,
                        ),
                        child: RangeSlider(
                          values: _priceRange,
                          min: 0,
                          max: 10000,
                          divisions: 100,
                          onChanged: (values) {
                            setState(() {
                              _priceRange = values;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(height: 32),

                // By Manufacturer Section
                _buildExpandableSection(
                  'By Manufacturer',
                  Column(
                    children: [
                      // Search field
                      TextField(
                        controller: _manufacturerSearchController,
                        decoration: InputDecoration(
                          hintText: 'Search Manufacturer',
                          hintStyle: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 14,
                          ),
                          suffixIcon: const Icon(Icons.search, size: 20),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: (showAllManufacturers
                            ? manufacturerList
                            : manufacturerList.take(5).toList())
                            .map((manufacturer) {
                          final isSelected = selectedManufacturers.contains(manufacturer);
                          return InkWell(
                            onTap: () {
                              setState(() {
                                if (isSelected) {
                                  selectedManufacturers.remove(manufacturer);
                                } else {
                                  selectedManufacturers.add(manufacturer);
                                }
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.yellow[100] : Colors.transparent,
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFFFDB913)
                                      : Colors.grey.shade300,
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                manufacturer,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: isSelected ? Colors.black87 : Colors.black54,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      if (manufacturerList.length > 5)
                        TextButton(
                          onPressed: () {
                            setState(() {
                              showAllManufacturers = !showAllManufacturers;
                            });
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                showAllManufacturers ? 'Show Less' : 'Show More',
                                style: const TextStyle(
                                  color: Color(0xFFFDB913),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Icon(
                                showAllManufacturers
                                    ? Icons.keyboard_arrow_up
                                    : Icons.keyboard_arrow_down,
                                color: const Color(0xFFFDB913),
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),

                const Divider(height: 32),

                // Delivery & Payment Section
                _buildExpandableSection(
                  'Delivery & Payment',
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: deliveryOptions.map((option) {
                      final isSelected = selectedDeliveryOptions.contains(option);
                      return InkWell(
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              selectedDeliveryOptions.remove(option);
                            } else {
                              selectedDeliveryOptions.add(option);
                            }
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.yellow[100] : Colors.transparent,
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFFFDB913)
                                  : Colors.grey.shade300,
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            option,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: isSelected ? Colors.black87 : Colors.black54,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                const Divider(height: 32),

                // By Review Section
                _buildExpandableSection(
                  'By Review',
                  Row(
                    children: [5, 4, 3, 2, 1].map((rating) {
                      final isSelected = selectedReview == rating;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              selectedReview = isSelected ? null : rating;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.yellow[100] : Colors.transparent,
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFFFDB913)
                                    : Colors.grey.shade300,
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.star,
                                  size: 14,
                                  color: isSelected
                                      ? const Color(0xFFFDB913)
                                      : Colors.grey[400],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  rating.toString(),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: isSelected ? Colors.black87 : Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                const Divider(height: 32),

                // By Color Section
                _buildExpandableSection(
                  'By Color',
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: availableColors.map((color) {
                      final isSelected = selectedColors.contains(color);
                      return InkWell(
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              selectedColors.remove(color);
                            } else {
                              selectedColors.add(color);
                            }
                          });
                        },
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFFFDB913)
                                  : Colors.grey.shade300,
                              width: isSelected ? 3 : 2,
                            ),
                          ),
                          child: isSelected
                              ? Icon(
                            Icons.check,
                            color: color == Colors.black || color.computeLuminance() < 0.5
                                ? Colors.white
                                : Colors.black,
                            size: 18,
                          )
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                ),

                const Divider(height: 32),

                // By Size Section
                _buildExpandableSection(
                  'By Size',
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: sizeList.map((size) {
                      final isSelected = selectedSizes.contains(size);
                      return InkWell(
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              selectedSizes.remove(size);
                            } else {
                              selectedSizes.add(size);
                            }
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.yellow[100] : Colors.transparent,
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFFFDB913)
                                  : Colors.grey.shade300,
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            size,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: isSelected ? Colors.black87 : Colors.black54,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(height: 80),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _priceRange = const RangeValues(0, 10000);
                      categories.updateAll((key, value) => false);
                      selectedHighlight = null;
                      selectedBrands.clear();
                      selectedManufacturers.clear();
                      selectedDeliveryOptions.clear();
                      selectedReview = null;
                      selectedColors.clear();
                      selectedSizes.clear();
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Clear All',
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFDB913),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'View Results',
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpandableSection(String title, Widget content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const Icon(Icons.keyboard_arrow_up, size: 20),
          ],
        ),
        const SizedBox(height: 16),
        content,
      ],
    );
  }

  Widget _buildCategoryItem(String title, bool isActive) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          color: isActive ? Colors.black87 : Colors.grey[400],
          fontWeight: isActive ? FontWeight.w500 : FontWeight.normal,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _brandSearchController.dispose();
    _manufacturerSearchController.dispose();
    super.dispose();
  }
}