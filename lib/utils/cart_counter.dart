import '../services/api_service.dart';
import '../services/api_endpoints.dart';
import '../services/session_manager.dart';
import 'safe_print.dart';
import 'dart:convert';

/// Simple cart counter utility without state management
class CartCounter {
  static int _cartCount = 0;
  static double _cartTotal = 0.0;
  
  static int get cartCount => _cartCount;
  static double get cartTotal => _cartTotal;

  /// Load cart count from API
  static Future<void> loadCartCount() async {
    try {
      final token = await SessionManager.getValidFirebaseToken();
      if (token == null) {
        _cartCount = 0;
        _cartTotal = 0.0;
        return;
      }

      final response = await ApiService.gets(
        ApiEndpoints.cartList,
        token: token,
        queryParams: {
          'page': '1',
          'per_page': '1', // Just need count, not full data
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data is Map && data['status'] == true) {
          // Parse cart_totals
          if (data['cart_totals'] != null && data['cart_totals'] is Map) {
            final totals = data['cart_totals'] as Map<String, dynamic>;
            _cartCount = int.tryParse(totals['total_items']?.toString() ?? '0') ?? 0;
            _cartTotal = double.tryParse(totals['total']?.toString() ?? '0') ?? 0.0;
          }
          
          // Also check cart_items length as fallback
          if (_cartCount == 0 && data['cart_items'] != null && data['cart_items'] is List) {
            final items = data['cart_items'] as List;
            int totalItems = 0;
            double total = 0.0;
            for (var item in items) {
              final qty = int.tryParse(item['quantity']?.toString() ?? '1') ?? 1;
              totalItems += qty;
              final price = double.tryParse(item['price']?.toString() ?? '0') ?? 0.0;
              total += price * qty;
            }
            _cartCount = totalItems;
            _cartTotal = total;
          }
        }
        
        safePrint('🛒 Cart count loaded: $_cartCount, Total: $_cartTotal');
      }
    } catch (e) {
      safePrint('Error loading cart count: $e');
    }
  }

  /// Update cart count manually
  static void updateCartCount(int count, {double? total}) {
    _cartCount = count;
    if (total != null) {
      _cartTotal = total;
    }
  }

  /// Increment cart count
  static void increment({int by = 1}) {
    _cartCount += by;
  }

  /// Decrement cart count
  static void decrement({int by = 1}) {
    _cartCount = (_cartCount - by).clamp(0, double.infinity).toInt();
  }

  /// Reset cart count
  static void reset() {
    _cartCount = 0;
    _cartTotal = 0.0;
  }
}

