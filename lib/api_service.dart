import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'token_storage_service.dart';

class ApiService {
  static const String baseUrl = 'https://goodiesworld.techgigs.in/wp-json/wc/v3';
  static const String walletBaseUrl =
      'https://goodiesworld.techgigs.in/wp-json/techgigs-wallet/v1';

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

  // ─── Basic Headers (always Basic Auth) ───────────────────────────────────
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
          final decoded = json.decode(response.body);
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
      final url = Uri.parse('$baseUrl/cart/add');
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
    String? variationId,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/cart/update');
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
  // ADDRESS
  // =========================================================================

  Future<List<Map<String, dynamic>>> getAddressList() async {
    try {
      final url = Uri.parse('$baseUrl/address/list');
      final headers = await _getAuthHeaders();
      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final addresses = (data is Map<String, dynamic>)
            ? (data['addresses'] as List? ?? const [])
            : const [];
        return addresses
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      }
      throw Exception('Failed to load addresses: ${response.statusCode}');
    } catch (e) {
      throw Exception('Error fetching addresses: $e');
    }
  }

  Future<Map<String, dynamic>> addAddress({
    required Map<String, dynamic> address,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/address/add');
      final headers = await _getAuthHeaders();
      final response = await http.post(
        url,
        headers: headers,
        body: json.encode({'address': address}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        return data is Map<String, dynamic> ? data : {'data': data};
      }
      final errorData = json.decode(response.body);
      throw Exception(errorData['message'] ?? 'Failed to add address');
    } catch (e) {
      throw Exception('Error adding address: $e');
    }
  }

  Future<Map<String, dynamic>> updateAddress({
    required Map<String, dynamic> address,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/address/update');
      final headers = await _getAuthHeaders();
      final response = await http.post(
        url,
        headers: headers,
        body: json.encode({'address': address}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        return data is Map<String, dynamic> ? data : {'data': data};
      }
      final errorData = json.decode(response.body);
      throw Exception(errorData['message'] ?? 'Failed to update address');
    } catch (e) {
      throw Exception('Error updating address: $e');
    }
  }

  Future<Map<String, dynamic>> deleteAddress({required String id}) async {
    try {
      final url = Uri.parse('$baseUrl/address/delete');
      final headers = await _getAuthHeaders();
      final response = await http.post(
        url,
        headers: headers,
        body: json.encode({'id': id}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        return data is Map<String, dynamic> ? data : {'data': data};
      }
      final errorData = json.decode(response.body);
      throw Exception(errorData['message'] ?? 'Failed to delete address');
    } catch (e) {
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
      final url = Uri.parse('$baseUrl/checkout');
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
        final data = json.decode(response.body);
        return data is Map<String, dynamic> ? data : {'data': data};
      }
      final errorData = json.decode(response.body);
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
      final url = Uri.parse('$baseUrl/checkout');
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
        final data = json.decode(response.body);
        print('✅ Success: Order created with ID: ${data['id'] ?? data['order_id']}');
        return data is Map<String, dynamic> ? data : {'data': data};
      } else {
        print('❌ Error: ${response.statusCode} - ${response.body}');
        final errorData = json.decode(response.body);
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

  // =========================================================================
  // WALLET
  // =========================================================================

  Future<double> getWalletBalance(int userId) async {
    final url = Uri.parse('$walletBaseUrl/balance/$userId');
    final headers = await _getAuthHeaders();
    final response = await http.get(url, headers: headers);
    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return double.tryParse((data['wallet_balance'] ?? '0').toString()) ?? 0;
    }
    throw Exception('Unable to load wallet balance.');
  }

  Future<double> getUsableBalance(int userId) async {
    final url = Uri.parse('$walletBaseUrl/usable-balance/$userId');
    final headers = await _getAuthHeaders();
    final response = await http.get(url, headers: headers);
    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return double.tryParse((data['usable_balance'] ?? '0').toString()) ?? 0;
    }
    throw Exception('Unable to load usable balance.');
  }

  Future<double> getLockedBalance(int userId) async {
    final url = Uri.parse('$walletBaseUrl/locked-balance/$userId');
    final headers = await _getAuthHeaders();
    final response = await http.get(url, headers: headers);
    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return double.tryParse((data['locked_balance'] ?? '0').toString()) ?? 0;
    }
    throw Exception('Unable to load locked balance.');
  }

  Future<List<Map<String, dynamic>>> getWalletTransactions(int userId) async {
    final url = Uri.parse('$walletBaseUrl/transactions/$userId');
    final headers = await _getAuthHeaders();
    final response = await http.get(url, headers: headers);
    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      final items = (data['transactions'] as List?) ?? const [];
      return items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    throw Exception('Unable to load wallet transactions.');
  }

  Future<List<Map<String, dynamic>>> getWithdrawRequests(int userId) async {
    final url = Uri.parse('$walletBaseUrl/withdraw-requests/$userId');
    final headers = await _getAuthHeaders();
    final response = await http.get(url, headers: headers);
    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);
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

  Future<Map<String, dynamic>> createWithdrawRequest({
    required int userId,
    required double amount,
  }) async {
    final url = Uri.parse('$walletBaseUrl/withdraw');
    final headers = await _getAuthHeaders();
    final response = await http.post(
      url,
      headers: headers,
      body: json.encode({'user_id': userId, 'amount': amount}),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = json.decode(response.body);
      final parsed = data is Map<String, dynamic> ? data : {'data': data};
      final status = parsed['status'];
      if (status is bool && !status) {
        throw Exception((parsed['message'] ?? 'Withdraw failed').toString());
      }
      return parsed;
    }
    try {
      final data = json.decode(response.body);
      if (data is Map<String, dynamic>) {
        throw Exception((data['message'] ?? 'Withdraw failed').toString());
      }
    } catch (_) {}
    throw Exception('Withdraw failed.');
  }
}