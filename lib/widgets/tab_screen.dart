import 'package:flutter/material.dart';
import 'package:martfury/theme/app_colors.dart';
import 'package:martfury/widgets/coming_soon_popup.dart';

class TabScreen extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemTapped;
  final int cartCount;

  const TabScreen({
    Key? key,
    required this.selectedIndex,
    required this.onItemTapped,
    required this.cartCount,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: Colors.grey[300]!,
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                icon: Icons.home_outlined,
                label: 'Home',
                index: 0,
              ),
              _buildNavItem(
                icon: Icons.grid_view_rounded,
                label: 'Category',
                index: 1,
              ),
              _buildNavItem(
                icon: Icons.shopping_cart_outlined,
                label: 'Cart',
                index: 2,
                badgeCount: cartCount,
              ),
              _buildNavItem(
                icon: Icons.favorite_border,
                label: 'Wishlist',
                index: 3,
              ),
              _buildNavItem(
                icon: Icons.local_offer_outlined,
                label: 'Offers',
                index: 4,
                context: context,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
    int badgeCount = 0,
    BuildContext? context,
  }) {
    final isSelected = selectedIndex == index;

    return GestureDetector(
      onTap: () {
        if (index == 4 && context != null) {
          ComingSoonPopup.show(context);
        } else {
          onItemTapped(index);
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon with selection indicator
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              // Selection indicator line
              if (isSelected)
                Positioned(
                  top: -12,
                  child: Container(
                    width: 60,
                    height: 6,
                    decoration: BoxDecoration(
                      color: AppColors.yellow,
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(33),
                        bottomRight: Radius.circular(33),
                      ),
                    ),
                  ),
                ),
              // Icon
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    icon,
                    size: 28,
                    color: isSelected ? AppColors.yellow : Colors.black87,
                  ),
                  if (badgeCount > 0)
                    Positioned(
                      right: -6,
                      top: -6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: Text(
                          badgeCount > 99 ? '99+' : badgeCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.normal,
              color: isSelected ? AppColors.yellow : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
