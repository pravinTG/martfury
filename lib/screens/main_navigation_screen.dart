import 'package:flutter/material.dart';
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

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: const [
          HomeScreen(),
          CategoryScreen(),
          WishlistScreen(),
          CartScreen(),
        ],
      ),
      bottomNavigationBar: TabScreen(
        selectedIndex: _selectedIndex,
        onItemTapped: _onItemTapped,
      ),
    );
  }
}


