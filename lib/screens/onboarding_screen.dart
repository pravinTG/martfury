import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/responsive.dart';
import '../widgets/app_button.dart';
import '../widgets/spacing.dart';

class OnboardingScreen extends StatefulWidget {
  static const String routeName = '/onboarding';

  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  final List<_OnboardingPageData> _pages = const [
    _OnboardingPageData(
      image: 'assets/images/onboarding_1.png',
      title: 'Discover Best Deals',
      description:
          'Browse thousands of products with exclusive offers tailored just for you.',
    ),
    _OnboardingPageData(
      image: 'assets/images/onboarding_2.png',
      title: 'Fast & Secure Delivery',
      description:
          'Get your orders delivered quickly with reliable and secure shipping.',
    ),
    _OnboardingPageData(
      image: 'assets/images/onboarding_3.png',
      title: 'Shop Anywhere, Anytime',
      description:
          'Enjoy a seamless shopping experience from the comfort of your home.',
    ),
  ];

  void _onNext() {
    if (_currentIndex < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else {
      Navigator.of(context).pushNamed('/signin');
    }
  }

  void _onSkip() {
    Navigator.of(context).pushNamed('/signin');
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmall = constraints.maxHeight < 700;
        return Scaffold(
          backgroundColor: AppColors.scaffoldBackground,
          body: SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: Responsive.width(context, 0.06),
              ),
              child: Column(
                children: [
                  // Skip
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _onSkip,
                      child: Text(
                        'Skip',
                        style: AppTextStyles.body2.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: isSmall ? 6 : 7,
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: _pages.length,
                      onPageChanged: (index) {
                        setState(() {
                          _currentIndex = index;
                        });
                      },
                      itemBuilder: (context, index) {
                        final page = _pages[index];
                        return _OnboardingPage(
                          data: page,
                        );
                      },
                    ),
                  ),
                  Spacing.sizedBoxH16,
                  // Indicators
                  _OnboardingIndicators(
                    length: _pages.length,
                    currentIndex: _currentIndex,
                  ),
                  Spacing.sizedBoxH24,
                  // Button
                  AppButton(
                    label:
                        _currentIndex == _pages.length - 1 ? 'Get Started' : 'Next',
                    onPressed: _onNext,
                  ),
                  Spacing.sizedBoxH24,
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _OnboardingPageData {
  final String image;
  final String title;
  final String description;

  const _OnboardingPageData({
    required this.image,
    required this.title,
    required this.description,
  });
}

class _OnboardingPage extends StatelessWidget {
  final _OnboardingPageData data;

  const _OnboardingPage({required this.data});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          flex: 6,
          child: Padding(
            padding: EdgeInsets.only(
              top: Responsive.height(context, 0.02),
            ),
            child: Image.asset(
              data.image,
              fit: BoxFit.contain,
            ),
          ),
        ),
        Spacing.sizedBoxH24,
        Expanded(
          flex: 4,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Text(
                data.title,
                style: AppTextStyles.heading2,
                textAlign: TextAlign.center,
              ),
              Spacing.sizedBoxH12,
              Text(
                data.description,
                style: AppTextStyles.body2,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OnboardingIndicators extends StatelessWidget {
  final int length;
  final int currentIndex;

  const _OnboardingIndicators({
    required this.length,
    required this.currentIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(length, (index) {
        final isActive = index == currentIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          height: 6,
          width: isActive ? 20 : 8,
          decoration: BoxDecoration(
            color: isActive ? AppColors.primary : AppColors.border,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}


