import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../theme/app_colors.dart';

class ShimmerContainer extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;
  final EdgeInsetsGeometry margin;

  const ShimmerContainer({
    Key? key,
    required this.width,
    required this.height,
    this.borderRadius = 8.0,
    this.margin = EdgeInsets.zero,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        margin: margin,
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

class ShimmerProductCard extends StatelessWidget {
  const ShimmerProductCard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ShimmerContainer(
            width: double.infinity,
            height: 120,
            borderRadius: 8,
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ShimmerContainer(width: 100, height: 16),
                const SizedBox(height: 8),
                const ShimmerContainer(width: 60, height: 14),
                const SizedBox(height: 12),
                const ShimmerContainer(width: 80, height: 18),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ShimmerCategoryList extends StatelessWidget {
  const ShimmerCategoryList({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 112,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        scrollDirection: Axis.horizontal,
        itemCount: 6,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          return const SizedBox(
            width: 86,
            child: Column(
              children: [
                ShimmerContainer(width: 64, height: 64, borderRadius: 32),
                SizedBox(height: 8),
                ShimmerContainer(width: 60, height: 14),
              ],
            ),
          );
        },
      ),
    );
  }
}

class ShimmerCartItem extends StatelessWidget {
  const ShimmerCartItem({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ShimmerContainer(width: 80, height: 80, borderRadius: 8),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                ShimmerContainer(width: double.infinity, height: 16),
                SizedBox(height: 8),
                ShimmerContainer(width: 100, height: 14),
                SizedBox(height: 8),
                ShimmerContainer(width: 60, height: 18),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ShimmerProductDetail extends StatelessWidget {
  const ShimmerProductDetail({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ShimmerContainer(width: double.infinity, height: 250, borderRadius: 0),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ShimmerContainer(width: 250, height: 24),
                const SizedBox(height: 12),
                const ShimmerContainer(width: 120, height: 16),
                const SizedBox(height: 16),
                const ShimmerContainer(width: 100, height: 32),
                const SizedBox(height: 16),
                const ShimmerContainer(width: double.infinity, height: 80, borderRadius: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
