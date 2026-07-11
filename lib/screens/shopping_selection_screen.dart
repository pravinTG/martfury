import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'category_screen.dart';

class ShoppingSelectionScreen extends StatelessWidget {
  const ShoppingSelectionScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColors.headerRed,
        elevation: 0,
        title: const Text(
          'Shopping',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.85,
          children: [
            _buildSelectionCard(
              context: context,
              title: 'EXPLORE',
              subtitle: 'EATABLE ITEMS',
              imageUrl: 'https://images.unsplash.com/photo-1542838132-92c53300491e?w=400&q=80',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CategoryScreen(
                      initialIsEatableTab: true,
                    ),
                  ),
                );
              },
            ),
            _buildSelectionCard(
              context: context,
              title: 'EXPLORE',
              subtitle: 'OTHER ITEMS',
              imageUrl: 'https://images.unsplash.com/photo-1505740420928-5e560c06d30e?w=400&q=80', // Headphones
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CategoryScreen(
                      initialIsEatableTab: false,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required String imageUrl,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.purpleLight, // Using theme light color
          borderRadius: BorderRadius.circular(20),
        ),
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            // Image in the upper portion
            Positioned.fill(
              bottom: 60, // Leave space for the pill
              child: Padding(
                padding: const EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.image_not_supported,
                      size: 40,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ),
            ),
            // Pill container at the bottom
            Container(
              width: double.infinity,
              height: 70,
              decoration: BoxDecoration(
                color: AppColors.button, // Using theme button color
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
