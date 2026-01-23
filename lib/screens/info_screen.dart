import 'dart:async';

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/responsive.dart';
import '../widgets/app_button.dart';
import '../widgets/spacing.dart';
import 'sign_in_screen.dart';

class InfoScreen extends StatefulWidget {
  static const String routeName = '/info';

  const InfoScreen({super.key});

  @override
  State<InfoScreen> createState() => _InfoScreenState();
}

class _InfoScreenState extends State<InfoScreen> {
  static const int _initialPage = 1000;

  final PageController _pageController = PageController(
    viewportFraction: 0.78,
    initialPage: _initialPage,
  );

  int _currentIndex = 0; // logical index (0.._cards.length-1)
  int _pageIndex = _initialPage; // raw page index for infinite-style scrolling
  Timer? _autoSlideTimer;

  final List<_IntroCardData> _cards = const [
    _IntroCardData(
      title: 'Unlock Amazing',
      highlighted: 'Deals & Discounts',
      body: 'Discover the best deals from top brands.',
    ),
    _IntroCardData(
      title: 'Discover the',
      highlighted: 'Best Deals',
      body: 'Exclusive offers curated just for you.',
    ),
    _IntroCardData(
      title: 'Curated Deals',
      highlighted: 'You\'ll Love',
      body: 'Handpicked products at the best prices.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _startAutoSlide();
  }

  void _startAutoSlide() {
    _autoSlideTimer?.cancel();
    _autoSlideTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted || _cards.isEmpty) return;
      final nextIndex = _pageIndex + 1;
      _pageController.animateToPage(
        nextIndex,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _autoSlideTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: Responsive.width(context, 0.06),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Top close button (X)
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        Navigator.of(context)
                            .pushReplacementNamed(SignInScreen.routeName);
                      },
                    ),
                  ),
                  Spacing.sizedBoxH32,
                  // Title
                  RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: 'Unlock Amazing\n',
                          style: AppTextStyles.heading2
                              .copyWith(fontSize: 24, color: Colors.black),
                        ),
                        TextSpan(
                          text: 'Deals & Discounts',
                          style: AppTextStyles.heading2.copyWith(
                            fontSize: 24,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Spacing.sizedBoxH32,
                  // Cards carousel
                  SizedBox(
                    height: constraints.maxHeight * 0.38,
                    child: PageView.builder(
                      controller: _pageController,
                      onPageChanged: (index) {
                        setState(() {
                          _pageIndex = index;
                          _currentIndex = index % _cards.length;
                        });
                      },
                      itemBuilder: (context, index) {
                        final card = _cards[index % _cards.length];
                        final bool isActive =
                            (index % _cards.length) == _currentIndex;

                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOut,
                          margin: EdgeInsets.only(
                            top: isActive ? 0 : 12,
                            bottom: isActive ? 0 : 12,
                          ),
                          child: AnimatedScale(
                            duration: const Duration(milliseconds: 250),
                            scale: isActive ? 1.0 : 0.95,
                            curve: Curves.easeOut,
                            child: _IntroCard(data: card),
                          ),
                        );
                      },
                    ),
                  ),
                  Spacing.sizedBoxH16,
                  _IntroIndicators(
                    length: _cards.length,
                    currentIndex: _currentIndex,
                  ),
                  const Spacer(),
                  AppButton(
                    label: 'Let’s Get Started',
                    onPressed: () {
                      Navigator.of(context)
                          .pushReplacementNamed(SignInScreen.routeName);
                    },
                  ),
                  Spacing.sizedBoxH16,
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Already have an account? ',
                        style: AppTextStyles.body2,
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context)
                              .pushReplacementNamed(SignInScreen.routeName);
                        },
                        child: Text(
                          'Sign In',
                          style: AppTextStyles.body2.copyWith(
                            color: AppColors.primary,
                            decoration: TextDecoration.underline,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
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

class _IntroCardData {
  final String title;
  final String highlighted;
  final String body;

  const _IntroCardData({
    required this.title,
    required this.highlighted,
    required this.body,
  });
}

class _IntroCard extends StatelessWidget {
  final _IntroCardData data;

  const _IntroCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Align(
            alignment: Alignment.bottomLeft,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.title,
                  style: AppTextStyles.body1.copyWith(
                    fontWeight: FontWeight.w500,
                    color: Colors.black,
                  ),
                ),
                Spacing.sizedBoxH4,
                Text(
                  data.highlighted,
                  style: AppTextStyles.heading3.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IntroIndicators extends StatelessWidget {
  final int length;
  final int currentIndex;

  const _IntroIndicators({
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
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive ? AppColors.primary : const Color(0xFFE0E0E0),
            shape: BoxShape.circle,
          ),
        );
      }),
    );
  }
}

