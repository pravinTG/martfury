import 'package:flutter/material.dart';
import 'package:martfury/api_service.dart';
import 'package:martfury/screens/cart_screen.dart';
import 'package:martfury/screens/wishlist_screen.dart';
import 'package:martfury/widgets/tab_screen.dart';
import 'home_screen.dart';
import 'category_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  static const String routeName = '/main';

  const MainNavigationScreen({Key? key}) : super(key: key);

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;
  final ApiService _apiService = ApiService();
  final GlobalKey<CartScreenState> _cartKey = GlobalKey<CartScreenState>();
  final GlobalKey<WishlistScreenState> _wishlistKey =
      GlobalKey<WishlistScreenState>();
  int _cartCount = 0;

  @override
  void initState() {
    super.initState();
    _refreshCartCount();
  }

  Future<void> _refreshCartCount() async {
    try {
      final data = await _apiService.getCart();
      final totals = data['cart_totals'];
      int count = 0;
      if (totals != null && totals['total_items'] != null) {
        count = int.tryParse(totals['total_items'].toString()) ?? 0;
      } else if (data['cart_items'] is List) {
        count = (data['cart_items'] as List).length;
      }
      if (!mounted) return;
      setState(() => _cartCount = count);
    } catch (_) {
      // Keep badge hidden on errors.
      if (mounted) setState(() => _cartCount = 0);
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    // Auto refresh when switching tabs.
    if (index == 2) {
      _wishlistKey.currentState?.refresh();
    }
    if (index == 3) {
      _cartKey.currentState?.refresh();
      _refreshCartCount();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          const HomeScreen(),
          const CategoryScreen(),
          WishlistScreen(
            key: _wishlistKey,
            onCartChanged: _refreshCartCount,
          ),
          CartScreen(
            key: _cartKey,
            onCartChanged: _refreshCartCount,
          ),
        ],
      ),
      bottomNavigationBar: TabScreen(
        selectedIndex: _selectedIndex,
        onItemTapped: _onItemTapped,
        cartCount: _cartCount,
      ),
    );
  }
}


