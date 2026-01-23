import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/spacing.dart';
import '../utils/responsive.dart';
import '../services/auth_service.dart';
import 'package:google_fonts/google_fonts.dart';

class MenuScreen extends StatelessWidget {
  static const String routeName = '/menu';

  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final user = authService.currentUser;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: Responsive.width(context, 0.04),
            vertical: Responsive.height(context, 0.02),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Spacing.sizedBoxH16,
              // Profile Section
              _buildProfileSection(user?.phoneNumber ?? 'User'),
              Spacing.sizedBoxH32,
              // Menu Items
              _buildMenuSection(context),
              Spacing.sizedBoxH80,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileSection(String phoneNumber) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.white,
            child: Icon(
              Icons.person,
              size: 30,
              color: AppColors.primary,
            ),
          ),
          Spacing.sizedBoxW16,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome!',
                  style: AppTextStyles.heading2.copyWith(
                    color: Colors.black,
                  ),
                ),
                Spacing.sizedBoxH4,
                Text(
                  phoneNumber,
                  style: AppTextStyles.body1.copyWith(
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuSection(BuildContext context) {
    final menuItems = [
      {'icon': Icons.person_outline, 'title': 'My Profile', 'onTap': () {}},
      {'icon': Icons.shopping_bag_outlined, 'title': 'My Orders', 'onTap': () {}},
      {'icon': Icons.location_on_outlined, 'title': 'Addresses', 'onTap': () {}},
      {'icon': Icons.payment_outlined, 'title': 'Payment Methods', 'onTap': () {}},
      {'icon': Icons.notifications_outlined, 'title': 'Notifications', 'onTap': () {}},
      {'icon': Icons.settings_outlined, 'title': 'Settings', 'onTap': () {}},
      {'icon': Icons.help_outline, 'title': 'Help & Support', 'onTap': () {}},
      {'icon': Icons.info_outline, 'title': 'About Us', 'onTap': () {}},
    ];

    return Column(
      children: menuItems.map((item) {
        return ListTile(
          leading: Icon(
            item['icon'] as IconData,
            color: AppColors.textPrimary,
          ),
          title: Text(
            item['title'] as String,
            style: AppTextStyles.body1,
          ),
          trailing: const Icon(
            Icons.chevron_right,
            color: AppColors.textSecondary,
          ),
          onTap: item['onTap'] as VoidCallback,
        );
      }).toList(),
    );
  }

}

