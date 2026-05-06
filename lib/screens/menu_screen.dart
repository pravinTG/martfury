import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:martfury/screens/about_us.dart';
import 'package:martfury/screens/faq.dart';
import 'package:martfury/screens/orders_screen.dart';
import 'package:martfury/screens/our_policy.dart';
import 'package:martfury/term_condition.dart';
import 'package:martfury/theme/app_colors.dart';
import 'package:martfury/theme/app_text_styles.dart';
import '../api_service.dart';
import '../widgets/app_snackbar.dart';

import '../edit_profile.dart';
import '../token_storage_service.dart';
import 'sign_in_screen.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({Key? key}) : super(key: key);

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  final ApiService _apiService = ApiService();
  String _userName = 'User';
  String _avatarUrl = '';

  @override
  void initState() {
    super.initState();
    _loadCustomerProfile();
  }

  Future<void> _loadCustomerProfile() async {
    try {
      final profile = await _apiService.getCustomerProfile();
      if (!mounted) return;
      final firstName = (profile['first_name'] ?? '').toString().trim();
      final lastName = (profile['last_name'] ?? '').toString().trim();
      final fallback = (profile['username'] ?? '').toString().trim();

      final fullName = '$firstName $lastName'.trim();
      setState(() {
        _userName = fullName.isNotEmpty
            ? fullName
            : (fallback.isNotEmpty ? fallback : 'User');
        _avatarUrl = (profile['avatar_url'] ?? '').toString();
      });
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.show(context, 'Failed to load profile: $e', type: AppSnackType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColors.yellow,
        elevation: 0,
        automaticallyImplyLeading: false,
        toolbarHeight: 80,
        title: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white,
                  backgroundImage:
                      _avatarUrl.isNotEmpty ? NetworkImage(_avatarUrl) : null,
                  child: _avatarUrl.isEmpty
                      ? Text(
                          _userName.isNotEmpty
                              ? _userName[0].toUpperCase()
                              : 'U',
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const EditProfileScreen(),
                        ),
                      );
                      if (result == true) {
                        await _loadCustomerProfile();
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppColors.yellow,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.edit,
                        size: 12,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _userName,
                  style: AppTextStyles.body1.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(
                        Icons.storefront,
                        size: 14,
                        color: Color(0xFFFDB825),
                      ),
                      SizedBox(width: 4),
                      Text(
                        'My Shop',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: const [
          Icon(Icons.chat_bubble_outline, color: Colors.white),
          SizedBox(width: 16),
          Icon(Icons.notifications_none, color: Colors.white),
          SizedBox(width: 16),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),

            // My Orders Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'My Orders',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const OrdersScreen()),
                      );
                    },
                    child: const Text(
                      'View All',
                      style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFFFDB825),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Order Status Icons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildOrderStatus(Icons.shopping_bag_outlined, 'Ongoing'),
                  _buildOrderStatus(Icons.local_shipping_outlined, 'Completed'),
                  _buildOrderStatus(Icons.rate_review_outlined, 'Reviews'),
                  _buildOrderStatus(Icons.keyboard_return, 'Returns'),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Menu Items
            _buildMenuItem(
              icon: Icons.shopping_bag_outlined,
              title: 'My Orders',
              color: AppColors.yellow,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const OrdersScreen()),
                );
              },
            ),
            _buildMenuItem(
              icon: Icons.location_on_outlined,
              title: 'Manage Address',
              color: AppColors.yellow,
              onTap: () {

              },
            ),
            _buildMenuItem(
              icon: Icons.account_balance_wallet_outlined,
              title: 'My Wallet',
              color: AppColors.yellow,
              onTap: () {

              },

            ),
            _buildMenuItem(
              icon: Icons.local_offer_outlined,
              title: 'My Coupons',
              color: AppColors.yellow,
              onTap: () {

              },
            ),
            _buildMenuItem(
              icon: Icons.history,
              title: 'Recently Viewed',
              color: AppColors.yellow,
              onTap: () {

              },
            ),

            const SizedBox(height: 24),

            // Support Section
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Support',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 8),

            _buildMenuItem(
              icon: Icons.help_outline,
              title: 'FAQ',
              color: const Color(0xFFFDB825),
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => FaqScreen(),));
              },
            ),
            _buildMenuItem(
              icon: Icons.headset_mic_outlined,
              title: 'Our Policy',
              color: const Color(0xFFFDB825),
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => OurPolicy(),));

              },
            ),
            _buildMenuItem(
              icon: Icons.article_outlined,
              title: 'Terms and Condition',
              color: const Color(0xFFFDB825),
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => TermCondition(),));
              },
            ),
            _buildMenuItem(
              icon: Icons.article_outlined,
              title: "About Us",
              color: const Color(0xFFFDB825),
              onTap: () {Navigator.push(context, MaterialPageRoute(builder: (context) => AboutUS(),));
              },
            ),

            const SizedBox(height: 24),

            // Setting Section
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Setting',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 8),

            _buildMenuItem(
              icon: Icons.attach_money,
              title: 'Currency',
              color: const Color(0xFFFDB825),
              onTap: () {

              },
            ),
            _buildMenuItemWithFlag(
              title: 'Language',
            ),
            _buildMenuItem(
              icon: Icons.logout_outlined,
              title: 'Logout',
              color: AppColors.yellow,
              onTap: () async {
                await FirebaseAuth.instance.signOut();
                await TokenStorageService.clearSession();
                if (!mounted) return;
                Navigator.of(context).pushReplacementNamed(SignInScreen.routeName);
              },
            ),

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderStatus(IconData icon, String label) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFDB825).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: const Color(0xFFFDB825),
            size: 24,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required VoidCallback onTap,
    required String title,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: Icon(
          icon,
          color: color,
          size: 24,
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right,
          color: Colors.grey,
        ),
        onTap: onTap,     // ✅ Works correctly now
        contentPadding: EdgeInsets.zero,
      ),
    );
  }


  Widget _buildMenuItemWithFlag({
    required String title,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Image.network(
              'https://flagcdn.com/w40/us.png',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: Colors.blue,
                  child: const Center(
                    child: Text(
                      '🇺🇸',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right,
          color: Colors.grey,
        ),
        contentPadding: EdgeInsets.zero,
      ),
    );
  }
}