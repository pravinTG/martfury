class Product {
  final String id;
  final String name;
  final String? description;
  final double price;
  final double? originalPrice;
  final String? imageUrl;
  final String? category;
  final double? rating;
  final int? reviewCount;
  final int? sold;
  final String? seller;
  final bool? inStock;

  Product({
    required this.id,
    required this.name,
    this.description,
    required this.price,
    this.originalPrice,
    this.imageUrl,
    this.category,
    this.rating,
    this.reviewCount,
    this.sold,
    this.seller,
    this.inStock,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    // Parse price - WooCommerce returns price as string
    final priceStr = json['price']?.toString() ?? '0';
    final regularPriceStr = json['regular_price']?.toString();
    final salePriceStr = json['sale_price']?.toString();
    
    // Determine actual price and original price
    double price = _parsePrice(priceStr);
    double? originalPrice;
    
    if (json['on_sale'] == true && regularPriceStr != null && regularPriceStr.isNotEmpty) {
      // Product is on sale, use sale_price as price and regular_price as original
      if (salePriceStr != null && salePriceStr.isNotEmpty) {
        price = _parsePrice(salePriceStr);
      }
      originalPrice = _parsePrice(regularPriceStr);
    } else if (regularPriceStr != null && regularPriceStr.isNotEmpty) {
      originalPrice = _parsePrice(regularPriceStr);
      if (price == 0) price = originalPrice;
    }
    
    // Parse images - WooCommerce has images array with src
    String? imageUrl;
    if (json['images'] != null && json['images'] is List && (json['images'] as List).isNotEmpty) {
      final firstImage = json['images'][0];
      if (firstImage is Map && firstImage['src'] != null) {
        imageUrl = firstImage['src'].toString();
      }
    }
    
    // Parse categories - WooCommerce has categories array
    String? categoryName;
    if (json['categories'] != null && json['categories'] is List && (json['categories'] as List).isNotEmpty) {
      final firstCategory = json['categories'][0];
      if (firstCategory is Map && firstCategory['name'] != null) {
        categoryName = firstCategory['name'].toString();
      }
    }
    
    // Parse rating - WooCommerce returns average_rating as string
    double? rating;
    if (json['average_rating'] != null) {
      rating = _parsePrice(json['average_rating'].toString());
    }
    
    // Parse seller/brand - WooCommerce has brands array
    String? sellerName;
    if (json['brands'] != null && json['brands'] is List && (json['brands'] as List).isNotEmpty) {
      final firstBrand = json['brands'][0];
      if (firstBrand is Map && firstBrand['name'] != null) {
        sellerName = firstBrand['name'].toString();
      }
    }
    
    return Product(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      name: json['name'] ?? json['title'] ?? 'Unknown Product',
      description: json['description']?.toString(),
      price: price,
      originalPrice: originalPrice,
      imageUrl: imageUrl,
      category: categoryName,
      rating: rating,
      reviewCount: json['rating_count'] ?? json['reviews_count'] ?? 0,
      sold: json['total_sales'] ?? json['sold'] ?? 0,
      seller: sellerName,
      inStock: json['stock_status']?.toString().toLowerCase() == 'instock',
    );
  }

  static double _parsePrice(dynamic price) {
    if (price is double) return price;
    if (price is int) return price.toDouble();
    if (price is String) {
      return double.tryParse(price.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0.0;
    }
    return 0.0;
  }

  bool get hasDiscount => originalPrice != null && originalPrice! > price;
  double? get discountPercentage {
    if (!hasDiscount) return null;
    return ((originalPrice! - price) / originalPrice!) * 100;
  }
}

