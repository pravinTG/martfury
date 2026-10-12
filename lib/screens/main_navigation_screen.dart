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
import 'package:firebase_auth/firebase_auth.dart';
import '../token_storage_service.dart';

import 'home_screen.dart';
import 'category_screen.dart';
import 'offers_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  static const String routeName = '/main';

  const MainNavigationScreen({Key? key}) : super(key: key);

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen>
    with WidgetsBindingObserver {
  int _selectedIndex = 0;
  final ApiService _apiService = ApiService();
  final GlobalKey<CartScreenState> _cartKey = GlobalKey<CartScreenState>();
  final GlobalKey<WishlistScreenState> _wishlistKey =
      GlobalKey<WishlistScreenState>();
  int _cartCount = 0;
  final List<bool> _visitedTabs = [true, false, false, false, false];

  /// Timestamp of last token refresh — used to avoid redundant force-refreshes.
  DateTime? _lastTokenRefresh;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initSession();
    _checkForAndroidUpdate();
  }

  /// Full session init: sync user → refresh token → load cart count.
  /// Called once on startup and again every time app resumes.
  Future<void> _initSession() async {
    await _syncUserIfNeeded();
    await _refreshCartCount();
    await _refreshWishlist();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Called automatically whenever the app lifecycle state changes.
  /// On [AppLifecycleState.resumed] we force-refresh the Firebase token so
  /// that stale/expired tokens (>1 hour old) never reach the backend.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _onAppResumed();
    }
  }

  Future<void> _onAppResumed() async {
    final now = DateTime.now();
    // Only force-refresh token if we haven't done so in the last 50 minutes.
    final shouldRefresh = _lastTokenRefresh == null ||
        now.difference(_lastTokenRefresh!).inMinutes >= 50;

    if (shouldRefresh) {
      debugPrint('🔄 App resumed — force-refreshing Firebase token...');
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final newToken = await user.getIdToken(true);
          if (newToken != null && newToken.isNotEmpty) {
            await TokenStorageService.saveIdToken(newToken);
            _lastTokenRefresh = now;
            debugPrint('✅ Firebase token refreshed on app resume.');
          }
        }
      } catch (e) {
        debugPrint('⚠️ Token refresh on resume failed: $e');
      }
    }

    // Re-sync user mapping on EVERY resume — the backend mapping can expire
    // or be invalidated between sessions (especially on aggressive-battery
    // devices like Realme/OPPO where the process is fully killed).
    await _syncUserIfNeeded();

    if (mounted) {
      _refreshCartCount();
      if (_selectedIndex == 2) {
        _cartKey.currentState?.refresh();
      }
    }
  }

  /// Silently re-syncs the Firebase UID → WordPress user mapping.
  /// This is cheap (one POST request) and ensures the backend always
  /// recognises the current Firebase user, preventing 401 "User not found"
  /// errors on getCart() after the app was killed and reopened.
  Future<void> _syncUserIfNeeded() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final savedUserId = await TokenStorageService.getUserId();
      if (user == null || savedUserId == null || savedUserId.isEmpty) return;

      await _apiService.syncFirebaseUser(
        userId: int.parse(savedUserId),
        firebaseUid: user.uid,
        phoneNumber: user.phoneNumber ?? '',
      );
      debugPrint('✅ Firebase user re-synced on app open.');
    } catch (e) {
      // Non-fatal — cart retries will handle any resulting 401.
      debugPrint('⚠️ syncFirebaseUser on resume failed (non-fatal): $e');
    }
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
            _visitedTabs[4] ? const OffersScreen() : const SizedBox(),
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


