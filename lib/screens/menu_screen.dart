import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/cart_counter.dart';
import '../widgets/spacing.dart';
import 'update_profile_screen.dart';
import 'order_history_screen.dart';

class MenuScreen extends StatelessWidget {
  static const String routeName = '/menu';

  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Ensure badge is up-to-date when menu is opened
    CartCounter.loadCartCount();
    final authService = AuthService();
    final user = authService.currentUser;
    final userLabel = user?.phoneNumber ?? 'johnsmith_23';

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildHeader(context, userLabel),
              Container(
                color: AppColors.background,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionHeader(
                        title: 'My Orders',
                        actionText: 'View All',
                        onActionTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const OrderHistoryScreen()),
                        ),
                      ),
                      Spacing.sizedBoxH12,
                      _buildOrderRow(context),
                      Spacing.sizedBoxH20,
                      _buildListCard([
                        _MenuTileData(icon: Icons.person_outline, title: 'My Profile', onTap: () async => Navigator.pushNamed(context, UpdateProfileScreen.routeName)),
                        _MenuTileData(icon: Icons.location_on_outlined, title: 'Manage Address', onTap: () {}),
                        _MenuTileData(icon: Icons.account_balance_wallet_outlined, title: 'My Wallet', onTap: () {}),
                        _MenuTileData(icon: Icons.card_giftcard, title: 'My Coupons', onTap: () {}),
                        _MenuTileData(icon: Icons.visibility_outlined, title: 'Recently Viewed', onTap: () {}),
                      ]),
                      Spacing.sizedBoxH24,
                      _sectionHeader(title: 'Support'),
                      Spacing.sizedBoxH12,
                      _buildListCard([
                        _MenuTileData(icon: Icons.help_outline, title: 'Help Center', onTap: () {}),
                        _MenuTileData(icon: Icons.support_agent, title: 'Customer Service', onTap: () {}),
                        _MenuTileData(icon: Icons.article_outlined, title: 'Martfury Blog', onTap: () {}),
                      ]),
                      Spacing.sizedBoxH24,
                      _sectionHeader(title: 'Setting'),
                      Spacing.sizedBoxH12,
                      _buildListCard([
                        _MenuTileData(icon: Icons.attach_money, title: 'Currency', onTap: () {}),
                        _MenuTileData(icon: Icons.language, title: 'Language', onTap: () {}),
                      ]),
                      Spacing.sizedBoxH24,
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String userLabel) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 20),
      decoration: const BoxDecoration(color: Color(0xFFFCC72C)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.pushNamed(context, UpdateProfileScreen.routeName),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    _profileAvatar(),
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        child: const Icon(Icons.edit, size: 12, color: Colors.black87),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userLabel,
                      style: AppTextStyles.heading3.copyWith(color: Colors.black),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.storefront, size: 16),
                          SizedBox(width: 6),
                          Text('My Shop'),
                          SizedBox(width: 6),
                          Icon(Icons.chevron_right, size: 16),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              _iconWithBadge(
                icon: Icons.shopping_bag_outlined,
                countListenable: CartCounter.cartCountNotifier,
                onTap: () {},
              ),
              _iconWithBadge(
                icon: Icons.notifications_outlined,
                onTap: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader({required String title, String? actionText, VoidCallback? onActionTap}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: AppTextStyles.heading3.copyWith(fontSize: 16),
        ),
        if (actionText != null)
          GestureDetector(
            onTap: onActionTap,
            child: Text(
              actionText,
              style: AppTextStyles.body2.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
            ),
          ),
      ],
    );
  }

  Widget _buildOrderRow(BuildContext context) {
    final orders = [
      {'icon': Icons.inventory_2_outlined, 'label': 'Ongoing'},
      {'icon': Icons.checklist_rtl, 'label': 'Completed'},
      {'icon': Icons.rate_review_outlined, 'label': 'Reviews'},
      {'icon': Icons.assignment_return, 'label': 'Returns'},
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: orders.map((item) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Column(
              children: [
                Container(
                  height: 56,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3CC),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () {
                      final label = item['label'] as String;
                      if (label == 'Reviews') return;
                      final initialTab = label == 'Ongoing'
                          ? 'In Progress'
                          : label == 'Completed'
                              ? 'Delivered'
                              : 'Returns';
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => OrderHistoryScreen(initialTab: initialTab),
                        ),
                      );
                    },
                    child: Icon(item['icon'] as IconData, color: Colors.orange.shade700),
                  ),
                ),
                Spacing.sizedBoxH8,
                Text(
                  item['label'] as String,
                  style: AppTextStyles.caption.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildListCard(List<_MenuTileData> items) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            ListTile(
              leading: Icon(items[i].icon, color: AppColors.textPrimary),
              title: Text(items[i].title, style: AppTextStyles.body1),
              trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
              onTap: items[i].onTap,
            ),
            if (i != items.length - 1)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Divider(height: 1),
              ),
          ],
        ],
      ),
    );
  }

  Widget _iconWithBadge({
    required IconData icon,
    ValueListenable<int>? countListenable,
    int count = 0,
    VoidCallback? onTap,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          onPressed: onTap,
          icon: Icon(icon, color: Colors.black87),
        ),
        if (countListenable != null)
          ValueListenableBuilder<int>(
            valueListenable: countListenable,
            builder: (context, value, _) {
              if (value <= 0) return const SizedBox.shrink();
              return Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: Colors.black87, shape: BoxShape.circle),
                  child: Text(
                    value > 99 ? '99+' : '$value',
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              );
            },
          )
        else if (count > 0)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(color: Colors.black87, shape: BoxShape.circle),
              child: Text(
                count > 99 ? '99+' : '$count',
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ),
      ],
    );
  }

  Widget _profileAvatar() {
    final authService = AuthService();
    final user = authService.currentUser;
    final photoUrl = user?.photoURL ?? '';

    if (photoUrl.trim().isNotEmpty) {
      return CircleAvatar(
        radius: 26,
        backgroundColor: Colors.white,
        backgroundImage: NetworkImage(photoUrl),
      );
    }
    return const CircleAvatar(
      radius: 26,
      backgroundColor: Colors.white,
      child: Icon(Icons.person_outline, color: Colors.grey, size: 28),
    );
  }
}

class _MenuTileData {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _MenuTileData({
    required this.icon,
    required this.title,
    required this.onTap,
  });
}