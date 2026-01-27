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
        
        int newCount = 0;
        double newTotal = 0.0;

        if (data is Map && data['status'] == true) {
          if (data['cart_totals'] != null && data['cart_totals'] is Map) {
            final totals = data['cart_totals'] as Map<String, dynamic>;
            newCount = int.tryParse(totals['total_items']?.toString() ?? '0') ?? 0;
            newTotal = double.tryParse(totals['total']?.toString() ?? '0') ?? 0.0;
          }
          
          if (newCount == 0 && data['cart_items'] != null && data['cart_items'] is List) {
            final items = data['cart_items'] as List;
            for (var item in items) {
              final qty = int.tryParse(item['quantity']?.toString() ?? '1') ?? 1;
              newCount += qty;
              final price = double.tryParse(item['price']?.toString() ?? '0') ?? 0.0;
              newTotal += price * qty;
            }
          }
        } else if (data is List) {
          // If the API returns a direct list of items without totals
          for (var item in data) {
            final qty = int.tryParse(item['quantity']?.toString() ?? '1') ?? 1;
            newCount += qty;
            final price = double.tryParse(item['price']?.toString() ?? '0') ?? 0.0;
            newTotal += price * qty;
          }
        }
        
        _cartCount = newCount;
        _cartTotal = newTotal;
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
    safePrint('🛒 Cart count updated manually: $_cartCount, Total: $_cartTotal');
  }

  /// Increment cart count
  static void increment({int by = 1}) {
    _cartCount += by;
    safePrint('🛒 Cart count incremented to: $_cartCount');
  }

  /// Decrement cart count
  static void decrement({int by = 1}) {
    _cartCount = (_cartCount - by).clamp(0, double.infinity).toInt();
    safePrint('🛒 Cart count decremented to: $_cartCount');
  }

  /// Reset cart count
  static void reset() {
    _cartCount = 0;
    _cartTotal = 0.0;
    safePrint('🛒 Cart count reset');
  }
}

