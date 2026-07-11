import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'token_storage_service.dart';

class ApiService {
  static const String baseUrl = 'https://goodiesworld.in/wp-json/wc/v3';
  // static const String baseUrl = 'https://goodiesworld.in/wp-json/wc/v3';

  // static const String walletBaseUrl =
  //     'https://goodiesworld.in/wp-json/techgigs-wallet/v1';
  static const String walletBaseUrl =
      'https://goodiesworld.in/wp-json/techgigs-wallet/v1';

  static const String basicAuth =
      'Basic Y2tfYWZlY2FmZmFmNzhkMTE5ZGU2YmNhMzk0ZTk4YTA4N2E0NjM5YTJjMTpjc182OTVkNDA2OTc0YzE4ZTM1YWUzN2M3YjVhY2YxNGZkYTgwNGYwZmM3';

  // ─── Auth Headers (Firebase token if available, else Basic) ───────────────
  Future<Map<String, String>> _getAuthHeaders() async {
    String? idToken;
    final firebaseUser = FirebaseAuth.instance.currentUser;

    if (firebaseUser != null) {
      try {
        // Prefer the latest Firebase token to avoid stale-session 401 issues.
        idToken = await firebaseUser.getIdToken();
        if (idToken != null && idToken.isNotEmpty) {
          await TokenStorageService.saveIdToken(idToken);
        }
      } catch (e) {
        print('⚠️ Unable to refresh Firebase token: $e');
      }
    }

    idToken ??= await TokenStorageService.getIdToken();

    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': (idToken != null && idToken.isNotEmpty)
          ? 'Bearer $idToken'
          : basicAuth,
    };
  }

//  ─── Basic Headers (always Basic Auth) ───────────────────────────────────
  Map<String, String> get _basicHeaders => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'Authorization': basicAuth,
  };

  double _parseAmount(dynamic value) {
    if (value == null) return 0;
    final sanitized = value.toString().replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(sanitized) ?? 0;
  }

  double _extractMetaPrice(dynamic metaData, String keyName) {
    if (metaData is! List) return 0;
    for (final entry in metaData) {
      if (entry is Map && (entry['key'] ?? '').toString() == keyName) {
        final amount = _parseAmount(entry['value']);
        if (amount > 0) return amount;
      }
    }
    return 0;
  }

  Map<String, dynamic> _applySelectedCartPrice(Map<String, dynamic> item) {
    final mode = (item['price_mode'] ?? '').toString().toLowerCase();
    final walletPrice = _parseAmount(item['wallet_price']);
    final selectedPrice = _parseAmount(item['selected_price']);
    final customPrice = _parseAmount(item['custom_price']);
    final metaWalletA = _extractMetaPrice(item['meta_data'], '_wallet_price');
    final metaWalletB = _extractMetaPrice(item['meta_data'], 'wallet_price');

    final chosenWalletPrice = [
      walletPrice,
      selectedPrice,
      customPrice,
      metaWalletA,
      metaWalletB,
    ].firstWhere((v) => v > 0, orElse: () => 0);

    if (mode != 'wallet' || chosenWalletPrice <= 0) {
      return item;
    }

    final quantity = int.tryParse((item['quantity'] ?? 1).toString()) ?? 1;
    final subtotal = chosenWalletPrice * (quantity <= 0 ? 1 : quantity);

    return <String, dynamic>{
      ...item,
      'price': chosenWalletPrice.toStringAsFixed(2),
      'subtotal': subtotal.toStringAsFixed(2),
      'line_total': subtotal.toStringAsFixed(2),
      'total': subtotal.toStringAsFixed(2),
    };
  }

  // ─── Retry Helper ────────────────────────────────────────────────────────
  dynamic _decodeJson(String body) {
    String cleaned = body
        .replaceAll('&amp;', '&')
        .replaceAll('&#038;', '&')
        .replaceAll('&#039;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&quot;', '\\"')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>');
    return json.decode(cleaned);
  }

  Future<http.Response> _retryRequest(Future<http.Response> Function() requestFunc, {int maxRetries = 2}) async {
    for (int attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        final response = await requestFunc();
        if (response.statusCode >= 500 && attempt < maxRetries) {
          print('⚠️ 500 Server Error, retrying request (attempt ${attempt + 1})...');
          await Future.delayed(Duration(milliseconds: 1000 * (attempt + 1)));
          continue;
        }
        return response;
      } catch (e) {
        if (attempt >= maxRetries) rethrow;
        print('⚠️ Request Exception, retrying (attempt ${attempt + 1})...: $e');
        await Future.delayed(Duration(milliseconds: 1000 * (attempt + 1)));
      }
    }
    throw Exception('Request failed after $maxRetries retries');
  }

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
        final data = _decodeJson(response.body);
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
  // GLOBAL STATE
  // =========================================================================
  static Set<String> wishlistProductIds = {};

  // =========================================================================
  // CATEGORIES
  // =========================================================================

  Future<List<Map<String, dynamic>>> getCategories({int perPage = 100}) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final url = '$baseUrl/products/categories?per_page=$perPage&_t=$timestamp';
      print('📂 Get Categories: $url');

      final response = await _retryRequest(() => http.get(
        Uri.parse(url),
        headers: _basicHeaders,
      ));

      print('📡 Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final List<dynamic> data = _decodeJson(response.body);
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
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final url = '$baseUrl/products?category=$categoryId&per_page=$perPage&_t=$timestamp';
      print('🛍️ Get Products by Category: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: _basicHeaders,
      );

      print('📡 Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final List<dynamic> data = _decodeJson(response.body);
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
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final url = '$baseUrl/products/$productId?_t=$timestamp';
      print('🔍 Get Product Details: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: _basicHeaders,
      );

      print('📡 Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        print('✅ Fetched product: $productId');
        return Map<String, dynamic>.from(_decodeJson(response.body));
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
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final url = '$baseUrl/products?per_page=$perPage&_t=$timestamp';
      print('🛍️ Get All Products: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: _basicHeaders,
      );

      print('📡 Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final List<dynamic> data = _decodeJson(response.body);
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

  Future<List<Map<String, dynamic>>> searchProducts(String query) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final url = '$baseUrl/products?search=$query&_t=$timestamp';
      print('🔍 Search Products: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: _basicHeaders,
      );

      print('📡 Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final List<dynamic> data = _decodeJson(response.body);
        print('✅ Fetched ${data.length} products');
        return data.map((e) => Map<String, dynamic>.from(e)).toList();
      } else {
        throw Exception('Failed to search products: ${response.statusCode}');
      }
    } catch (e) {
      print('💥 Error in searchProducts: $e');
      rethrow;
    }
  }


  // =========================================================================
  // CART
  // =========================================================================

  Future<Map<String, dynamic>> getCart() async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final url = Uri.parse('$baseUrl/cart?_t=$timestamp');
      print('🛒 Get Cart: GET $url');

      final headers = await _getAuthHeaders();
      print('🔑 Headers: $headers');

      final response = await _retryRequest(() => http.get(url, headers: headers));

      print('📡 Response Status: ${response.statusCode}');
      print('📦 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = _decodeJson(response.body);
        print('✅ Cart fetched successfully');
        final parsed = data is Map<String, dynamic> ? data : {'data': data};
        final cartItemsRaw = parsed['cart_items'];
        if (cartItemsRaw is List) {
          final normalizedItems = cartItemsRaw
              .map((e) => _applySelectedCartPrice(Map<String, dynamic>.from(e as Map)))
              .toList();
          parsed['cart_items'] = normalizedItems;
        }
        return parsed;
      } else {
        print('❌ Error: ${response.statusCode} - ${response.body}');
        Map<String, dynamic> errorData = {};
        try {
          final decoded = _decodeJson(response.body);
          if (decoded is Map<String, dynamic>) errorData = decoded;
        } catch (_) {}

        final backendMessage = (errorData['message'] ?? '').toString();
        if (response.statusCode == 401 &&
            backendMessage.contains('User not found for Firebase UID')) {
          throw Exception(
            'We could not verify your cart session right now. Please sign in again.',
          );
        }

        throw Exception('Unable to load cart right now. Please try again.');
      }
    } catch (e) {
      print('💥 Exception in getCart: $e');
      throw Exception('$e');
    }
  }

  Future<Map<String, dynamic>> addToCart({
    required String productId,
    required int quantity,
    String? variationId,
    Map<String, dynamic>? variation,
    String? priceMode,
    double? walletPrice,
  }) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final url = Uri.parse('$baseUrl/cart/add?_t=$timestamp');
      print('🛒 Add to Cart: POST $url');

      final body = {
        'product_id': productId,
        'quantity': quantity,
        if (variationId != null) 'variation_id': variationId,
        if (variation != null) 'variation': variation,
        if (priceMode != null && priceMode.isNotEmpty) 'price_mode': priceMode,
        if (walletPrice != null && walletPrice > 0) 'wallet_price': walletPrice,
        if (priceMode == 'wallet' && walletPrice != null && walletPrice > 0) ...{
          // Send multiple compatible keys because different backends parse different fields.
          'price': walletPrice,
          'custom_price': walletPrice,
          'selected_price': walletPrice,
          'meta_data': [
            {'key': 'price_mode', 'value': 'wallet'},
            {'key': '_wallet_price', 'value': walletPrice},
          ],
        },
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
        final data = _decodeJson(response.body);
        print('✅ Product added to cart');
        return data is Map<String, dynamic> ? data : {'data': data};
      } else {
        print('❌ Error: ${response.statusCode} - ${response.body}');
        final errorData = _decodeJson(response.body);
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
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final url = Uri.parse('$baseUrl/cart/remove?_t=$timestamp');
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
        final data = _decodeJson(response.body);
        print('✅ Product removed from cart');
        return data is Map<String, dynamic> ? data : {'data': data};
      } else {
        print('❌ Error: ${response.statusCode} - ${response.body}');
        final errorData = _decodeJson(response.body);
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
    String? variationId,
  }) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final url = Uri.parse('$baseUrl/cart/update?_t=$timestamp');
      print('✏️ Update Cart Item: POST $url');

      final body = {
        'product_id': productId,
        'quantity': quantity,
        if (variationId != null) 'variation_id': variationId,
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
        final data = _decodeJson(response.body);
        print('✅ Cart item updated');
        return data is Map<String, dynamic> ? data : {'data': data};
      } else {
        print('❌ Error: ${response.statusCode} - ${response.body}');
        final errorData = _decodeJson(response.body);
        throw Exception(errorData['message'] ?? 'Failed to update cart item');
      }
    } catch (e) {
      print('💥 Exception in updateCartItem: $e');
      throw Exception('Error updating cart item: $e');
    }
  }

  Future<Map<String, dynamic>> clearCart() async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final url = Uri.parse('$baseUrl/cart/clear?_t=$timestamp');
      print('🧹 Clear Cart: POST $url');

      final headers = await _getAuthHeaders();
      final response = await http.post(url, headers: headers);

      print('📡 Response Status: ${response.statusCode}');
      print('📦 Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = _decodeJson(response.body);
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
  // ADDRESS
  // =========================================================================

  Future<List<Map<String, dynamic>>> getAddressList() async {
    try {
      final userId = await TokenStorageService.getUserId();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final urlStr = userId != null 
          ? '$baseUrl/address/list?customer_id=$userId&user_id=$userId&_t=$timestamp' 
          : '$baseUrl/address/list?_t=$timestamp';
      final url = Uri.parse(urlStr);
      print('📍 Get Address List: GET $url');
      final headers = await _getAuthHeaders();
      final response = await http.get(url, headers: headers);
      
      print('📡 Get Address List Response Status: ${response.statusCode}');
      print('📦 Get Address List Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = _decodeJson(response.body);
        final addresses = (data is Map<String, dynamic>)
            ? (data['addresses'] as List? ?? const [])
            : const [];
        print('✅ Fetched ${addresses.length} addresses');
        return addresses
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      }
      throw Exception('Failed to load addresses: ${response.statusCode}');
    } catch (e) {
      print('💥 Exception in getAddressList: $e');
      throw Exception('Error fetching addresses: $e');
    }
  }

  // =========================================================================
  // BANNERS
  // =========================================================================

  Future<List<Map<String, dynamic>>> getMobileBanners() async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final url = 'https://goodiesworld.in/wp-json/wc/v3/mobilebanners?_t=$timestamp';
      print('🖼️ Get Mobile Banners: $url');

      final response = await _retryRequest(() => http.get(Uri.parse(url)));

      print('📡 Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = _decodeJson(response.body);
        print('✅ Fetched mobile banners');
        
        if (data is List) {
          return data.map((e) => Map<String, dynamic>.from(e)).toList();
        } else if (data is Map && data.containsKey('banners')) {
          return (data['banners'] as List).map((e) => Map<String, dynamic>.from(e)).toList();
        } else if (data is Map) {
           return [Map<String, dynamic>.from(data)];
        }
        return [];
      } else {
        print('❌ Failed to load banners: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('💥 Error in getMobileBanners: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> addAddress({
    required Map<String, dynamic> address,
  }) async {
    try {
      final userId = await TokenStorageService.getUserId();
      if (userId != null) {
        address['customer_id'] = userId;
        address['user_id'] = userId;
      }
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final url = Uri.parse('$baseUrl/address/add?_t=$timestamp');
      print('➕ Add Address: POST $url');
      print('📤 Request Body (Address): ${json.encode(address)}');
      final headers = await _getAuthHeaders();
      final response = await http.post(
        url,
        headers: headers,
        body: json.encode({'address': address}),
      );

      print('📡 Add Address Response Status: ${response.statusCode}');
      print('📦 Add Address Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = _decodeJson(response.body);
        print('✅ Address added successfully');
        return data is Map<String, dynamic> ? data : {'data': data};
      }
      print('❌ Add Address Error: ${response.statusCode} - ${response.body}');
      final errorData = _decodeJson(response.body);
      throw Exception(errorData['message'] ?? 'Failed to add address');
    } catch (e) {
      print('💥 Exception in addAddress: $e');
      throw Exception('Error adding address: $e');
    }
  }

  Future<Map<String, dynamic>> updateAddress({
    required Map<String, dynamic> address,
  }) async {
    try {
      final userId = await TokenStorageService.getUserId();
      if (userId != null) {
        address['customer_id'] = userId;
        address['user_id'] = userId;
      }
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final url = Uri.parse('$baseUrl/address/update?_t=$timestamp');
      print('✏️ Update Address: POST $url');
      print('📤 Request Body (Address): ${json.encode(address)}');
      final headers = await _getAuthHeaders();
      final response = await http.post(
        url,
        headers: headers,
        body: json.encode({'address': address}),
      );

      print('📡 Update Address Response Status: ${response.statusCode}');
      print('📦 Update Address Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = _decodeJson(response.body);
        print('✅ Address updated successfully');
        return data is Map<String, dynamic> ? data : {'data': data};
      }
      print('❌ Update Address Error: ${response.statusCode} - ${response.body}');
      final errorData = _decodeJson(response.body);
      throw Exception(errorData['message'] ?? 'Failed to update address');
    } catch (e) {
      print('💥 Exception in updateAddress: $e');
      throw Exception('Error updating address: $e');
    }
  }

  Future<Map<String, dynamic>> deleteAddress({required String id}) async {
    try {
      final userId = await TokenStorageService.getUserId();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final urlStr = userId != null ? '$baseUrl/address/delete?customer_id=$userId&user_id=$userId&_t=$timestamp' : '$baseUrl/address/delete?_t=$timestamp';
      final url = Uri.parse(urlStr);
      print('🗑️ Delete Address: POST $url, id: $id');
      final headers = await _getAuthHeaders();
      final response = await http.post(
        url,
        headers: headers,
        body: json.encode({'id': id, 'customer_id': userId, 'user_id': userId}),
      );

      print('📡 Delete Address Response Status: ${response.statusCode}');
      print('📦 Delete Address Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = _decodeJson(response.body);
        print('✅ Address deleted successfully');
        return data is Map<String, dynamic> ? data : {'data': data};
      }
      print('❌ Delete Address Error: ${response.statusCode} - ${response.body}');
      final errorData = _decodeJson(response.body);
      throw Exception(errorData['message'] ?? 'Failed to delete address');
    } catch (e) {
      print('💥 Exception in deleteAddress: $e');
      throw Exception('Error deleting address: $e');
    }
  }

  // =========================================================================
  // CHECKOUT
  // =========================================================================

  Future<Map<String, dynamic>> checkout({
    required Map<String, dynamic> billing,
    required Map<String, dynamic> shipping,
    required List<Map<String, dynamic>> lineItems,
    String? couponCode,
    String? deliveryDate,
    String? customerNote,
    String paymentMethod = 'razorpay',
    String? paymentId,
    double deliveryCharge = 0,
  }) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final url = Uri.parse('$baseUrl/checkout?_t=$timestamp');
      final headers = await _getAuthHeaders();
      final body = <String, dynamic>{
        'billing': billing,
        'shipping': shipping,
        'line_items': lineItems,
        if (couponCode != null && couponCode.isNotEmpty) 'coupon_code': couponCode,
        if (deliveryDate != null && deliveryDate.isNotEmpty)
          'delivery_date': deliveryDate,
        if (customerNote != null && customerNote.isNotEmpty)
          'customer_note': customerNote,
        'payment_method': paymentMethod,
        if (paymentId != null && paymentId.isNotEmpty) 'payment_id': paymentId,
        'delivery_charge': deliveryCharge,
      };

      final response = await http.post(
        url,
        headers: headers,
        body: json.encode(body),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = _decodeJson(response.body);
        return data is Map<String, dynamic> ? data : {'data': data};
      }
      final errorData = _decodeJson(response.body);
      throw Exception(errorData['message'] ?? 'Failed to place order');
    } catch (e) {
      throw Exception('Error placing order: $e');
    }
  }

  // =========================================================================
  // ORDERS
  // =========================================================================

  Future<List<dynamic>> getOrders({int page = 1, int perPage = 10}) async {
    try {
      final userId = await TokenStorageService.getUserId();
      if (userId == null) throw Exception('User ID not found');

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final url = Uri.parse(
          '$baseUrl/orders?customer=$userId&page=$page&per_page=$perPage&_t=$timestamp');
      print('📦 Get Orders: GET $url');

      final response = await http.get(url, headers: _basicHeaders);

      print('📡 Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = _decodeJson(response.body);
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

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final url = Uri.parse('$baseUrl/orders/$orderId?customer=$userId&_t=$timestamp');
      print('📦 Get Order Detail: GET $url');

      final response = await http.get(url, headers: _basicHeaders);

      print('📡 Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        print('✅ Fetched order: $orderId');
        return Map<String, dynamic>.from(_decodeJson(response.body));
      } else {
        throw Exception('Failed to load order: ${response.statusCode}');
      }
    } catch (e) {
      print('💥 Exception in getOrderById: $e');
      throw Exception('Error fetching order: $e');
    }
  }

  Future<Map<String, dynamic>> refundOrder({
    required int orderId,
    required String reason,
  }) async {
    try {
      final userId = await TokenStorageService.getUserId();
      if (userId == null) throw Exception('User ID not found');

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final url = Uri.parse('$walletBaseUrl/refund-order?_t=$timestamp');
      print('💸 Refund Order: POST $url');

      final body = {
        'user_id': int.tryParse(userId.toString()) ?? 0,
        'order_id': orderId,
        'reason': reason,
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
        final data = _decodeJson(response.body);
        if (data['status'] == true || data['status'] == 'true') {
          print('✅ Refund request submitted successfully');
          return data is Map<String, dynamic> ? data : {'data': data};
        } else {
          throw Exception(data['message'] ?? 'Failed to submit refund request');
        }
      } else {
        throw Exception('Failed to submit refund request');
      }
    } catch (e) {
      print('💥 Exception in refundOrder: $e');
      throw Exception('Error submitting refund: $e');
    }
  }


  // =========================================================================
// WISHLIST / FAVORITES
// =========================================================================

  Future<Map<String, dynamic>> getFavorites() async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final url = Uri.parse('$baseUrl/favorites?_t=$timestamp');
      print('❤️ Get Favorites: GET $url');

      final headers = await _getAuthHeaders();
      print('🔑 Headers: $headers');

      final response = await _retryRequest(() => http.get(url, headers: headers));

      print('📡 Response Status: ${response.statusCode}');
      print('📦 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = _decodeJson(response.body);
        print('✅ Favorites fetched successfully');
        final parsed = data is Map<String, dynamic> ? data : {'favorites': data};
        
        // Update global wishlist cache
        if (parsed['favorites'] is List) {
          wishlistProductIds.clear();
          for (var item in parsed['favorites']) {
            if (item['id'] != null) {
              wishlistProductIds.add(item['id'].toString());
            } else if (item['product_id'] != null) {
              wishlistProductIds.add(item['product_id'].toString());
            }
          }
        }
        
        return parsed;
      } else {
        print('❌ Error: ${response.statusCode} - ${response.body}');
        throw Exception('Unable to load wishlist right now. Please try again.');
      }
    } catch (e) {
      print('💥 Exception in getFavorites: $e');
      throw Exception('$e');
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
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final url = Uri.parse('$baseUrl/checkout?_t=$timestamp');
      print('🛍️ Create Order API Call: POST $url');

      final body = {
        'billing': billing,
        'shipping': shipping,
        'line_items': lineItems,
        'payment_method': paymentMethod,
        'payment_method_title': paymentMethodTitle,
        'set_paid': setPaid,
        if (transactionId != null) ...{
          // Different backends use different keys; send both for compatibility.
          'transaction_id': transactionId,
          'payment_id': transactionId,
        },
        if (metaData != null) 'meta_data': metaData,
      };

      print('📤 Request Body: ${json.encode(body)}');

      final headers = await _getAuthHeaders();
      print('🔑 Headers: $headers');
      final response =
          await http.post(url, headers: headers, body: json.encode(body));

      print('📡 Response Status Code: ${response.statusCode}');
      print('📦 Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = _decodeJson(response.body);
        print('✅ Success: Order created with ID: ${data['id'] ?? data['order_id']}');
        return data is Map<String, dynamic> ? data : {'data': data};
      } else {
        print('❌ Error: ${response.statusCode} - ${response.body}');
        final errorData = _decodeJson(response.body);
        throw Exception(errorData['message'] ?? 'Failed to create order');
      }
    } catch (e) {
      print('💥 Exception caught: $e');
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

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final url = Uri.parse('$baseUrl/customers/$userId?_t=$timestamp');
      print('👤 Get Customer Profile: GET $url');

      final response = await _retryRequest(() => http.get(url, headers: _basicHeaders));

      print('📡 Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        print('✅ Customer profile fetched');
        return Map<String, dynamic>.from(_decodeJson(response.body));
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

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final url = Uri.parse('$baseUrl/customers/$userId?_t=$timestamp');
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
        return Map<String, dynamic>.from(_decodeJson(response.body));
      } else {
        final errorData = _decodeJson(response.body);
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
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final url = Uri.parse('$baseUrl/toggle-favorite?_t=$timestamp');
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
        final data = _decodeJson(response.body);
        final message = (data['message'] ?? '').toString().toLowerCase();
        
        // Update global wishlist cache
        if (message.contains('removed')) {
          wishlistProductIds.remove(productId.toString());
        } else {
          wishlistProductIds.add(productId.toString());
        }

        return data is Map<String, dynamic> ? data : {'data': data};
      }

      final errorData = _decodeJson(response.body);
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
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final url = 'https://goodiesworld.in/wp-json/wp/v2/pages/$id?_t=$timestamp';
      print('📄 Get Page: GET $url');

      final response = await http.get(Uri.parse(url));

      print('📡 Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        print('✅ Page fetched: $id');
        return Map<String, dynamic>.from(_decodeJson(response.body));
      } else {
        throw Exception('Failed to load page: ${response.statusCode}');
      }
    } catch (e) {
      print('💥 Exception in getPage: $e');
      rethrow;
    }
  }

  // =========================================================================
  // WALLET
  // =========================================================================

  Future<double> getWalletBalance(int userId) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final url = Uri.parse('$walletBaseUrl/balance/$userId?_t=$timestamp');
    final headers = await _getAuthHeaders();
    final response = await http.get(url, headers: headers);
    if (response.statusCode == 200) {
      final data = _decodeJson(response.body) as Map<String, dynamic>;
      return double.tryParse((data['wallet_balance'] ?? '0').toString()) ?? 0;
    }
    throw Exception('Unable to load wallet balance.');
  }

  Future<double> getUsableBalance(int userId) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final url = Uri.parse('$walletBaseUrl/usable-balance/$userId?_t=$timestamp');
    final headers = await _getAuthHeaders();
    final response = await http.get(url, headers: headers);
    if (response.statusCode == 200) {
      final data = _decodeJson(response.body) as Map<String, dynamic>;
      return double.tryParse((data['usable_balance'] ?? '0').toString()) ?? 0;
    }
    throw Exception('Unable to load usable balance.');
  }

  Future<double> getLockedBalance(int userId) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final url = Uri.parse('$walletBaseUrl/locked-balance/$userId?_t=$timestamp');
    final headers = await _getAuthHeaders();
    final response = await http.get(url, headers: headers);
    if (response.statusCode == 200) {
      final data = _decodeJson(response.body) as Map<String, dynamic>;
      return double.tryParse((data['locked_balance'] ?? '0').toString()) ?? 0;
    }
    throw Exception('Unable to load locked balance.');
  }

  Future<List<Map<String, dynamic>>> getWalletTransactions(int userId, {int page = 1, int limit = 20}) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final url = Uri.parse('https://goodiesworld.in/wp-json/techgigs-wallet/v1/transactions/$userId?page=$page&limit=$limit&_t=$timestamp');
    print('💸 Get Wallet Transactions: GET $url');
    final headers = await _getAuthHeaders();
    try {
      final response = await http.get(url, headers: headers);
      print('📡 Response Status: ${response.statusCode}');
      print('📦 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = _decodeJson(response.body);
        if (data is Map<String, dynamic>) {
          var items = data['transactions'] ?? data['data'];
          if (items is! List) items = [];
          return (items as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        } else if (data is List) {
          return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
        return <Map<String, dynamic>>[];
      }
      throw Exception('Failed with status: ${response.statusCode}, body: ${response.body}');
    } catch (e) {
      print('💥 Error in getWalletTransactions: $e');
      throw Exception('Unable to load wallet transactions: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getWithdrawRequests(int userId) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final url = Uri.parse('$walletBaseUrl/withdraw-requests/$userId?_t=$timestamp');
    final headers = await _getAuthHeaders();
    final response = await http.get(url, headers: headers);
    if (response.statusCode == 200) {
      final decoded = _decodeJson(response.body);
      if (decoded is List) {
        return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      if (decoded is Map<String, dynamic>) {
        final items = (decoded['requests'] ?? decoded['data'] ?? const []) as List;
        return items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      return <Map<String, dynamic>>[];
    }
    throw Exception('Unable to load withdraw history.');
  }

  Future<bool> checkWalletNotification(int userId) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final url = Uri.parse('$walletBaseUrl/check-wallet-notification?user_id=$userId&_t=$timestamp');
    try {
      final headers = await _getAuthHeaders();
      final response = await http.get(url, headers: headers);
      
      print('🔔 Wallet Notification Check URL: $url');
      print('🔔 Wallet Notification Response: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = _decodeJson(response.body);
        if (data is Map<String, dynamic>) {
          return data['show_red_dot'] == true;
        }
      }
      return false;
    } catch (e) {
      print('💥 Error checking wallet notification: $e');
      return false;
    }
  }

  Future<void> markWalletNotificationRead(int userId) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final url = Uri.parse('$walletBaseUrl/mark-wallet-notification-read?_t=$timestamp');
    try {
      final headers = await _getAuthHeaders();
      final response = await http.post(
        url,
        headers: headers,
        body: json.encode({'user_id': userId}),
      );

      print('🔔 Mark Notification Read URL: $url');
      print('🔔 Mark Notification Read Response: ${response.statusCode} ${response.body}');
    } catch (e) {
      print('💥 Error marking wallet notification read: $e');
    }
  }

  Future<Map<String, dynamic>> createWithdrawRequest({
    required int userId,
    required double amount,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final url = Uri.parse('$walletBaseUrl/withdraw?_t=$timestamp');
    print('💸 Create Withdraw Request: POST $url');
    
    final payload = {'user_id': userId, 'amount': amount};
    print('📤 Request Body: ${json.encode(payload)}');
    
    final headers = await _getAuthHeaders();
    final response = await http.post(
      url,
      headers: headers,
      body: json.encode(payload),
    );
    
    print('📡 Response Status: ${response.statusCode}');
    print('📦 Response Body: ${response.body}');
    
    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = _decodeJson(response.body);
      final parsed = data is Map<String, dynamic> ? data : {'data': data};
      final status = parsed['status'];
      if (status is bool && !status) {
        throw Exception((parsed['message'] ?? 'Withdraw failed').toString());
      }
      return parsed;
    }
    try {
      final data = _decodeJson(response.body);
      if (data is Map<String, dynamic>) {
        throw Exception((data['message'] ?? 'Withdraw failed').toString());
      }
    } catch (_) {}
    throw Exception('Withdraw failed.');
  }
  Future<Map<String, dynamic>> addWalletBalance({
    required int userId,
    required double amount,
    required String note,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final url = Uri.parse('$walletBaseUrl/add-balance?_t=$timestamp');
    print('💸 Add Wallet Balance: POST $url');
    
    final payload = {'user_id': userId, 'amount': amount, 'note': note};
    print('📤 Request Body: ${json.encode(payload)}');
    
    final headers = await _getAuthHeaders();
    final response = await http.post(
      url,
      headers: headers,
      body: json.encode(payload),
    );
    
    print('📡 Response Status: ${response.statusCode}');
    print('📦 Response Body: ${response.body}');
    
    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = _decodeJson(response.body);
      final parsed = data is Map<String, dynamic> ? data : {'data': data};
      final status = parsed['status'];
      if (status is bool && !status) {
        throw Exception((parsed['message'] ?? 'Failed to add balance').toString());
      }
      return parsed;
    }
    try {
      final data = _decodeJson(response.body);
      if (data is Map<String, dynamic>) {
        throw Exception((data['message'] ?? 'Failed to add balance').toString());
      }
    } catch (_) {}
    throw Exception('Failed to add balance.');
  }

  Future<Map<String, dynamic>> payFromWallet({
    required int userId,
    required dynamic orderId,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final url = Uri.parse('$walletBaseUrl/pay-from-wallet?_t=$timestamp');
    final headers = await _getAuthHeaders();
    final response = await http.post(
      url,
      headers: headers,
      body: json.encode({'user_id': userId, 'order_id': orderId}),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = _decodeJson(response.body);
      final parsed = data is Map<String, dynamic> ? data : {'data': data};
      final status = parsed['status'];
      if (status is bool && !status) {
        throw Exception((parsed['message'] ?? 'Wallet payment failed').toString());
      }
      return parsed;
    }
    try {
      final data = _decodeJson(response.body);
      if (data is Map<String, dynamic>) {
        throw Exception((data['message'] ?? 'Wallet payment failed').toString());
      }
    } catch (_) {}
    throw Exception('Wallet payment failed. Server returned ${response.statusCode}');
  }

  // =========================================================================
  // CONTACT US
  // =========================================================================

  Future<Map<String, dynamic>> submitContactForm({
    required String name,
    required String email,
    required String mobile,
    required String message,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final url = Uri.parse('$walletBaseUrl/callback-request?_t=$timestamp');
    print("contact url: $url");
    
    final body = {
      'name': name,
      'email': email,
      'mobile': mobile,
      'message': message,
    };
    
    final headers = await _getAuthHeaders();
    final response = await http.post(
      url,
      headers: headers,
      body: json.encode(body),
    );

    print('📡 Contact Response Status: ${response.statusCode}');
    print('📦 Contact Response Body: ${response.body}');
    
    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = _decodeJson(response.body);
      final result = data is Map<String, dynamic> ? data : {'data': data};
      if (result['status'] == false) {
        throw Exception(result['message'] ?? 'Unable to send email.');
      }
      return result;
    }
    
    throw Exception('Failed to submit form. Server returned ${response.statusCode}');
  }
}
