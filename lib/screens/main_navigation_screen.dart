import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:martfury/api_service.dart';
import 'package:martfury/screens/cart_screen.dart';
import 'package:martfury/screens/wishlist_screen.dart';
import 'package:martfury/widgets/tab_screen.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:upgrader/upgrader.dart';

import 'home_screen.dart';
import 'category_screen.dart';
import 'menu_screen.dart';

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
  final List<bool> _visitedTabs = [true, false, false, false, false];

  @override
  void initState() {
    super.initState();
    _refreshCartCount();
    _refreshWishlist();
    _checkForAndroidUpdate();
  }

  Future<void> _checkForAndroidUpdate() async {
    try {
      if (!kIsWeb && Platform.isAndroid) {
        final info = await InAppUpdate.checkForUpdate();
        if (info.updateAvailability == UpdateAvailability.updateAvailable) {
          await InAppUpdate.performImmediateUpdate();
        }
      }
    } catch (e) {
      debugPrint("InAppUpdate Error: $e");
    }
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

  Future<void> _refreshWishlist() async {
    try {
      // Just call it to populate the global ApiService.wishlistProductIds
      await _apiService.getFavorites();
    } catch (_) {}
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      _visitedTabs[index] = true;
    });

    // Auto refresh when switching tabs.
    if (index == 2) {
      _cartKey.currentState?.refresh();
      _refreshCartCount();
    }
    if (index == 3) {
      _wishlistKey.currentState?.refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget content = WillPopScope(
      onWillPop: () async {
        if (_selectedIndex != 0) {
          setState(() {
            _selectedIndex = 0;
          });
          return false; // Prevent pop, stay in app
        }
        // Exit the app completely
        SystemNavigator.pop();
        return false;
      },
      child: Scaffold(
        body: IndexedStack(
          index: _selectedIndex,
          children: [
            _visitedTabs[0] ? const HomeScreen() : const SizedBox(),
            _visitedTabs[1] ? const CategoryScreen() : const SizedBox(),
            _visitedTabs[2] ? CartScreen(
              key: _cartKey,
              onCartChanged: _refreshCartCount,
            ) : const SizedBox(),
            _visitedTabs[3] ? WishlistScreen(
              key: _wishlistKey,
              onCartChanged: _refreshCartCount,
            ) : const SizedBox(),
            _visitedTabs[4] ? const MenuScreen() : const SizedBox(),
          ],
        ),
        bottomNavigationBar: TabScreen(
          selectedIndex: _selectedIndex,
          onItemTapped: _onItemTapped,
          cartCount: _cartCount,
        ),
      ),
    );

    if (!kIsWeb && Platform.isIOS) {
      return UpgradeAlert(
        dialogStyle: UpgradeDialogStyle.cupertino,
        child: content,
      );
    }

    return content;
  }
}


