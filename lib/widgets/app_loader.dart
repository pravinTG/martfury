import 'package:flutter/material.dart';
import 'package:martfury/theme/app_colors.dart';

class AppLoader extends StatelessWidget {
  const AppLoader({super.key, this.size = 26});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: const CircularProgressIndicator(
        strokeWidth: 2.5,
        color: AppColors.primary,
      ),
    );
  }
}

class AppPageLoader extends StatelessWidget {
  const AppPageLoader({super.key});

  @override
  Widget build(BuildContext context) => const Center(child: AppLoader(size: 30));
}

class AppBlockingLoader extends StatelessWidget {
  const AppBlockingLoader({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black45,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppLoader(size: 30),
            if (message != null) ...[
              const SizedBox(height: 10),
              Text(message!, style: const TextStyle(color: Colors.white)),
            ],
          ],
        ),
      ),
    );
  }
}
