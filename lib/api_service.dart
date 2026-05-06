import 'package:http/http.dart' as http;
import 'dart:convert';
import 'token_storage_service.dart';

class ApiService {
  static const String baseUrl = 'https://goodiesworld.techgigs.in/wp-json/wc/v3';

  static const String basicAuth =
      'Basic Y2tfYWZlY2FmZmFmNzhkMTE5ZGU2YmNhMzk0ZTk4YTA4N2E0NjM5YTJjMTpjc182OTVkNDA2OTc0YzE4ZTM1YWUzN2M3YjVhY2YxNGZkYTgwNGYwZmM3';

  // ─── Auth Headers (Firebase token if available, else Basic) ───────────────
  Future<Map<String, String>> _getAuthHeaders() async {
    final idToken = await TokenStorageService.getIdToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': (idToken != null && idToken.isNotEmpty)
          ? 'Bearer $idToken'
          : basicAuth,
    };
  }

  // ─── Basic Headers (always Basic Auth) ───────────────────────────────────
  Map<String, String> get _basicHeaders => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'Authorization': basicAuth,
  };

  // =========================================================================
  // AUTH
  // =========================================================================

  Future<Map<String, dynamic>> firebaseLogin({
    required String idToken,
    required String fcmToken,
    required String platform,
    required String osVersion,
    required String appVersion,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/firebased-login');
      print('🔐 Firebase Login API Call: POST $url');

      final body = {
        'idToken': idToken,
        'fcm_token': fcmToken,
        'platform': platform,
        'device_type': 'phone',
        'os_version': osVersion,
        'app_version': appVersion,
      };

      print('📤 Request Body: ${json.encode(body)}');

      final response = await http.post(
        url,
        headers: _basicHeaders,
        body: json.encode(body),
      );

      print('📡 Response Status: ${response.statusCode}');
      print('📦 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ Firebase login successful');
        return data is Map<String, dynamic> ? data : {'data': data};
      } else {
        print('❌ Error: ${response.statusCode} - ${response.body}');
        throw Exception('Firebase login failed: ${response.statusCode}');
      }
    } catch (e) {
      print('💥 Exception: $e');
      throw Exception('Error during Firebase login: $e');
    }
  }

  // =========================================================================
  // CATEGORIES
  // =========================================================================

  Future<List<Map<String, dynamic>>> getCategories({int perPage = 100}) async {
    try {
      final url = '$baseUrl/products/categories?per_page=$perPage';
      print('📂 Get Categories: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: _basicHeaders,
      );

      print('📡 Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        print('✅ Fetched ${data.length} categories');
        return data.map((e) => Map<String, dynamic>.from(e)).toList();
      } else {
        throw Exception('Failed to load categories: ${response.statusCode}');
      }
    } catch (e) {
      print('💥 Error in getCategories: $e');
      rethrow;
    }
  }

  // =========================================================================
  // PRODUCTS
  // =========================================================================

  Future<List<Map<String, dynamic>>> getProductsByCategory({
    required int categoryId,
    int perPage = 100,
  }) async {
    try {
      final url = '$baseUrl/products?category=$categoryId&per_page=$perPage';
      print('🛍️ Get Products by Category: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: _basicHeaders,
      );

      print('📡 Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        print('✅ Fetched ${data.length} products');
        return data.map((e) => Map<String, dynamic>.from(e)).toList();
      } else {
        throw Exception('Failed to load products: ${response.statusCode}');
      }
    } catch (e) {
      print('💥 Error in getProductsByCategory: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getProductDetails(int productId) async {
    try {
      final url = '$baseUrl/products/$productId';
      print('🔍 Get Product Details: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: _basicHeaders,
      );

      print('📡 Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        print('✅ Fetched product: $productId');
        return Map<String, dynamic>.from(json.decode(response.body));
      } else {
        throw Exception('Failed to load product details: ${response.statusCode}');
      }
    } catch (e) {
      print('💥 Error in getProductDetails: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getAllProducts({int perPage = 100}) async {
    try {
      final url = '$baseUrl/products?per_page=$perPage';
      print('🛍️ Get All Products: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: _basicHeaders,
      );

      print('📡 Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        print('✅ Fetched ${data.length} products');
        return data.map((e) => Map<String, dynamic>.from(e)).toList();
      } else {
        throw Exception('Failed to load products: ${response.statusCode}');
      }
    } catch (e) {
      print('💥 Error in getAllProducts: $e');
      rethrow;
    }
  }

  // =========================================================================
  // CART
  // =========================================================================

  Future<Map<String, dynamic>> getCart() async {
    try {
      final url = Uri.parse('$baseUrl/cart');
      print('🛒 Get Cart: GET $url');

      final headers = await _getAuthHeaders();
      print('🔑 Headers: $headers');

      final response = await http.get(url, headers: headers);

      print('📡 Response Status: ${response.statusCode}');
      print('📦 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ Cart fetched successfully');
        return data is Map<String, dynamic> ? data : {'data': data};
      } else {
        print('❌ Error: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to load cart: ${response.statusCode}');
      }
    } catch (e) {
      print('💥 Exception in getCart: $e');
      throw Exception('Error fetching cart: $e');
    }
  }

  Future<Map<String, dynamic>> addToCart({
    required String productId,
    required int quantity,
    String? variationId,
    Map<String, dynamic>? variation,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/cart/add');
      print('🛒 Add to Cart: POST $url');

      final body = {
        'product_id': productId,
        'quantity': quantity,
        if (variationId != null) 'variation_id': variationId,
        if (variation != null) 'variation': variation,
      };

      print('📤 Request Body: ${json.encode(body)}');

      final headers = await _getAuthHeaders();
      final response = await http.post(
        url,
        headers: headers,
        body: json.encode(body),
      );

      print('📡 Response Status: ${response.statusCode}');
      print('📦 Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        print('✅ Product added to cart');
        return data is Map<String, dynamic> ? data : {'data': data};
      } else {
        print('❌ Error: ${response.statusCode} - ${response.body}');
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to add product to cart');
      }
    } catch (e) {
      print('💥 Exception in addToCart: $e');
      throw Exception('Error adding product to cart: $e');
    }
  }

  Future<Map<String, dynamic>> removeFromCart({
    required String productId,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/cart/remove');
      print('🗑️ Remove from Cart: POST $url');

      final body = {'product_id': productId};
      print('📤 Request Body: ${json.encode(body)}');

      final headers = await _getAuthHeaders();
      print('🔑 Headers: $headers');

      final response = await http.post(
        url,
        headers: headers,
        body: json.encode(body),
      );

      print('📡 Response Status: ${response.statusCode}');
      print('📦 Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        print('✅ Product removed from cart');
        return data is Map<String, dynamic> ? data : {'data': data};
      } else {
        print('❌ Error: ${response.statusCode} - ${response.body}');
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to remove product from cart');
      }
    } catch (e) {
      print('💥 Exception in removeFromCart: $e');
      throw Exception('Error removing product from cart: $e');
    }
  }

  Future<Map<String, dynamic>> updateCartItem({
    required String productId,
    required int quantity,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/cart/update');
      print('✏️ Update Cart Item: POST $url');

      final body = {
        'product_id': productId,
        'quantity': quantity,
      };

      print('📤 Request Body: ${json.encode(body)}');

      final headers = await _getAuthHeaders();
      final response = await http.post(
        url,
        headers: headers,
        body: json.encode(body),
      );

      print('📡 Response Status: ${response.statusCode}');
      print('📦 Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        print('✅ Cart item updated');
        return data is Map<String, dynamic> ? data : {'data': data};
      } else {
        print('❌ Error: ${response.statusCode} - ${response.body}');
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to update cart item');
      }
    } catch (e) {
      print('💥 Exception in updateCartItem: $e');
      throw Exception('Error updating cart item: $e');
    }
  }

  Future<Map<String, dynamic>> clearCart() async {
    try {
      final url = Uri.parse('$baseUrl/cart/clear');
      print('🧹 Clear Cart: POST $url');

      final headers = await _getAuthHeaders();
      final response = await http.post(url, headers: headers);

      print('📡 Response Status: ${response.statusCode}');
      print('📦 Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        print('✅ Cart cleared');
        return data is Map<String, dynamic> ? data : {'data': data};
      } else {
        throw Exception('Failed to clear cart: ${response.statusCode}');
      }
    } catch (e) {
      print('💥 Exception in clearCart: $e');
      throw Exception('Error clearing cart: $e');
    }
  }

  // =========================================================================
  // ORDERS
  // =========================================================================

  Future<List<dynamic>> getOrders({int page = 1, int perPage = 10}) async {
    try {
      final userId = await TokenStorageService.getUserId();
      if (userId == null) throw Exception('User ID not found');

      final url = Uri.parse(
          '$baseUrl/orders?customer=$userId&page=$page&per_page=$perPage');
      print('📦 Get Orders: GET $url');

      final response = await http.get(url, headers: _basicHeaders);

      print('📡 Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ Fetched ${data.length} orders');
        return data;
      } else {
        throw Exception('Failed to load orders: ${response.statusCode}');
      }
    } catch (e) {
      print('💥 Exception in getOrders: $e');
      throw Exception('Error fetching orders: $e');
    }
  }

  Future<Map<String, dynamic>> getOrderById(int orderId) async {
    try {
      final userId = await TokenStorageService.getUserId();
      if (userId == null) throw Exception('User ID not found');

      final url = Uri.parse('$baseUrl/orders/$orderId?customer=$userId');
      print('📦 Get Order Detail: GET $url');

      final response = await http.get(url, headers: _basicHeaders);

      print('📡 Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        print('✅ Fetched order: $orderId');
        return Map<String, dynamic>.from(json.decode(response.body));
      } else {
        throw Exception('Failed to load order: ${response.statusCode}');
      }
    } catch (e) {
      print('💥 Exception in getOrderById: $e');
      throw Exception('Error fetching order: $e');
    }
  }


  // =========================================================================
// WISHLIST / FAVORITES
// =========================================================================

  Future<Map<String, dynamic>> getFavorites() async {
    try {
      final url = Uri.parse('$baseUrl/favorites');
      print('❤️ Get Favorites: GET $url');

      final headers = await _getAuthHeaders();
      print('🔑 Headers: $headers');

      final response = await http.get(url, headers: headers);

      print('📡 Response Status: ${response.statusCode}');
      print('📦 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ Favorites fetched successfully');
        return data is Map<String, dynamic> ? data : {'favorites': data};
      } else {
        print('❌ Error: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to load favorites: ${response.statusCode}');
      }
    } catch (e) {
      print('💥 Exception in getFavorites: $e');
      throw Exception('Error fetching favorites: $e');
    }
  }

  Future<Map<String, dynamic>> createOrder({
    required Map<String, dynamic> billing,
    required Map<String, dynamic> shipping,
    required List<Map<String, dynamic>> lineItems,
    String paymentMethod = 'razorpay',
    String paymentMethodTitle = 'Razorpay',
    bool setPaid = false,
    String? transactionId,
    List<dynamic>? metaData,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/orders');
      print('🛍️ Create Order: POST $url');

      final body = {
        'billing': billing,
        'shipping': shipping,
        'line_items': lineItems,
        'payment_method': paymentMethod,
        'payment_method_title': paymentMethodTitle,
        'set_paid': setPaid,
        if (transactionId != null) 'transaction_id': transactionId,
        if (metaData != null) 'meta_data': metaData,
      };

      print('📤 Request Body: ${json.encode(body)}');

      final headers = await _getAuthHeaders();
      final response = await http.post(
        url,
        headers: headers,
        body: json.encode(body),
      );

      print('📡 Response Status: ${response.statusCode}');
      print('📦 Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        print('✅ Order created: ${data['id']}');
        return data;
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to create order');
      }
    } catch (e) {
      print('💥 Exception in createOrder: $e');
      throw Exception('Error creating order: $e');
    }
  }

  // =========================================================================
  // CUSTOMER
  // =========================================================================

  Future<Map<String, dynamic>> getCustomerProfile() async {
    try {
      final userId = await TokenStorageService.getUserId();
      if (userId == null) throw Exception('User ID not found');

      final url = Uri.parse('$baseUrl/customers/$userId');
      print('👤 Get Customer Profile: GET $url');

      final response = await http.get(url, headers: _basicHeaders);

      print('📡 Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        print('✅ Customer profile fetched');
        return Map<String, dynamic>.from(json.decode(response.body));
      } else {
        throw Exception('Failed to load profile: ${response.statusCode}');
      }
    } catch (e) {
      print('💥 Exception in getCustomerProfile: $e');
      throw Exception('Error fetching customer profile: $e');
    }
  }

  Future<Map<String, dynamic>> updateCustomerProfile({
    required Map<String, dynamic> customerData,
  }) async {
    try {
      final userId = await TokenStorageService.getUserId();
      if (userId == null) throw Exception('User ID not found');

      final url = Uri.parse('$baseUrl/customers/$userId');
      print('✏️ Update Customer Profile: PUT $url');
      print('📤 Request Body: ${json.encode(customerData)}');

      final response = await http.put(
        url,
        headers: _basicHeaders,
        body: json.encode(customerData),
      );

      print('📡 Response Status: ${response.statusCode}');
      print('📦 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        print('✅ Customer profile updated');
        return Map<String, dynamic>.from(json.decode(response.body));
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to update profile');
      }
    } catch (e) {
      print('💥 Exception in updateCustomerProfile: $e');
      throw Exception('Error updating customer profile: $e');
    }
  }

  Future<Map<String, dynamic>> toggleFavorite({
    required String productId,
    String? variationId,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/toggle-favorite');
      final headers = await _getAuthHeaders();
      final body = <String, dynamic>{
        'product_id': productId,
        'variation_id': variationId ?? '',
      };

      final response = await http.post(
        url,
        headers: headers,
        body: json.encode(body),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        return data is Map<String, dynamic> ? data : {'data': data};
      }

      final errorData = json.decode(response.body);
      throw Exception(errorData['message'] ?? 'Failed to update wishlist');
    } catch (e) {
      throw Exception('Error toggling favorite: $e');
    }
  }

  // =========================================================================
  // PAGES
  // =========================================================================

  Future<Map<String, dynamic>> getPage(int id) async {
    try {
      final url = 'https://goodiesworld.techgigs.in/wp-json/wp/v2/pages/$id';
      print('📄 Get Page: GET $url');

      final response = await http.get(Uri.parse(url));

      print('📡 Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        print('✅ Page fetched: $id');
        return Map<String, dynamic>.from(json.decode(response.body));
      } else {
        throw Exception('Failed to load page: ${response.statusCode}');
      }
    } catch (e) {
      print('💥 Exception in getPage: $e');
      rethrow;
    }
  }
}