import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/spacing.dart';
import '../utils/cart_counter.dart';
import 'homepage_screen.dart';
import 'category_screen.dart';
import 'wishlist_screen.dart';
import 'cart_screen.dart';
import 'menu_screen.dart';

class MainTabsScreen extends StatefulWidget {
  static const String routeName = '/main';

  const MainTabsScreen({super.key});

  @override
  State<MainTabsScreen> createState() => _MainTabsScreenState();
}

class _MainTabsScreenState extends State<MainTabsScreen> {
  int _index = 0;
  final GlobalKey<CartScreenState> _cartKey = GlobalKey<CartScreenState>();

  List<Widget> get _pages => [
    const HomepageScreen(),
    const CategoryScreen(),
    CartScreen(key: _cartKey),
    const WishlistScreen(),
    const MenuScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Load cart count on init
    CartCounter.loadCartCount();
  }

  void _onTabChanged(int index) {
    setState(() {
      _index = index;
    });
    
    // Refresh cart when cart tab is selected
    if (index == 2) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final cartState = _cartKey.currentState;
        if (cartState != null && cartState.mounted) {
          cartState.refreshCart();
        }
      });
    }
    
    // Reload cart count when switching tabs to update badge
    CartCounter.loadCartCount().then((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: IndexedStack(
        index: _index,
        children: _pages,
      ),
      bottomNavigationBar: _BottomNav(
        currentIndex: _index,
        onChanged: _onTabChanged,
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onChanged;

  const _BottomNav({
    required this.currentIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    Widget item({
      required int index,
      required IconData icon,
      required String label,
    }) {
      final isActive = index == currentIndex;
      return InkWell(
        onTap: () => onChanged(index),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 2,
                width: 40,
                color: isActive ? AppColors.primary : Colors.transparent,
              ),
              Spacing.sizedBoxH4,
              Icon(
                icon,
                color: isActive ? AppColors.primary : AppColors.textSecondary,
              ),
              Spacing.sizedBoxH4,
              Text(
                label,
                style: AppTextStyles.caption.copyWith(
                  color: isActive ? AppColors.primary : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    Widget _buildCartItem() {
      final isActive = 2 == currentIndex;
      return InkWell(
        onTap: () => onChanged(2),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 2,
                width: 40,
                color: isActive ? AppColors.primary : Colors.transparent,
              ),
              Spacing.sizedBoxH4,
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    Icons.shopping_cart_outlined,
                    color: isActive ? AppColors.primary : AppColors.textSecondary,
                  ),
                  if (CartCounter.cartCount > 0)
                    Positioned(
                      right: -8,
                      top: -8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Center(
                          child: Text(
                            CartCounter.cartCount > 99 ? '99+' : '${CartCounter.cartCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              Spacing.sizedBoxH4,
              Text(
                'Cart',
                style: AppTextStyles.caption.copyWith(
                  color: isActive ? AppColors.primary : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            item(index: 0, icon: Icons.home_outlined, label: 'Home'),
            item(index: 1, icon: Icons.grid_view_outlined, label: 'Category'),
            _buildCartItem(),
            item(index: 3, icon: Icons.favorite_border, label: 'Wishlist'),
            item(index: 4, icon: Icons.menu, label: 'Menu'),
          ],
        ),
      ),
    );
  }
}



