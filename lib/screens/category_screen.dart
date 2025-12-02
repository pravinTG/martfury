import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_appbar.dart';
import '../widgets/app_card.dart';
import '../widgets/app_textfield.dart';
import '../widgets/spacing.dart';
import '../utils/responsive.dart';

class CategoryScreen extends StatelessWidget {
  static const String routeName = '/categories';

  const CategoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = Responsive.isTablet(context);
        final crossAxisCount = isTablet ? 4 : 3;

        return Scaffold(
          appBar: const AppAppBar(title: 'Categories'),
          body: SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: Responsive.width(context, 0.04),
                vertical: Responsive.height(context, 0.01),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppTextField(
                    hintText: 'Search category',
                    prefixIcon: const Icon(Icons.search),
                  ),
                  Spacing.sizedBoxH16,
                  Text(
                    'All Categories',
                    style: AppTextStyles.heading3,
                  ),
                  Spacing.sizedBoxH12,
                  Expanded(
                    child: GridView.builder(
                      padding: EdgeInsets.only(
                        bottom: Responsive.height(context, 0.02),
                      ),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: isTablet ? 0.9 : 0.8,
                      ),
                      itemCount: _mockCategories.length,
                      itemBuilder: (context, index) {
                        final category = _mockCategories[index];
                        return _CategoryItem(
                          title: category.title,
                          imagePath: category.imagePath,
                          onTap: () {
                            // TODO: navigate to category products list when implemented
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CategoryData {
  final String title;
  final String imagePath;

  const _CategoryData({
    required this.title,
    required this.imagePath,
  });
}

const List<_CategoryData> _mockCategories = [
  _CategoryData(title: 'Electronics', imagePath: 'assets/images/cat_electronics.png'),
  _CategoryData(title: 'Fashion', imagePath: 'assets/images/cat_fashion.png'),
  _CategoryData(title: 'Home', imagePath: 'assets/images/cat_home.png'),
  _CategoryData(title: 'Beauty', imagePath: 'assets/images/cat_beauty.png'),
  _CategoryData(title: 'Sports', imagePath: 'assets/images/cat_sports.png'),
  _CategoryData(title: 'Toys', imagePath: 'assets/images/cat_toys.png'),
  _CategoryData(title: 'Groceries', imagePath: 'assets/images/cat_groceries.png'),
  _CategoryData(title: 'Automotive', imagePath: 'assets/images/cat_automotive.png'),
];

class _CategoryItem extends StatelessWidget {
  final String title;
  final String imagePath;
  final VoidCallback? onTap;

  const _CategoryItem({
    required this.title,
    required this.imagePath,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            flex: 6,
            child: Image.asset(
              imagePath,
              fit: BoxFit.contain,
            ),
          ),
          Spacing.sizedBoxH8,
          Expanded(
            flex: 4,
            child: Text(
              title,
              style: AppTextStyles.body2.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}


