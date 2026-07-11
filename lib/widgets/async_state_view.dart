import 'package:flutter/material.dart';
import 'package:martfury/widgets/app_loader.dart';

class AsyncStateView extends StatelessWidget {
  const AsyncStateView({
    super.key,
    required this.isLoading,
    required this.child,
    this.errorMessage,
    this.onRetry,
    this.emptyMessage,
    this.isEmpty = false,
    this.shimmerChild,
  });

  final bool isLoading;
  final String? errorMessage;
  final VoidCallback? onRetry;
  final String? emptyMessage;
  final bool isEmpty;
  final Widget child;
  final Widget? shimmerChild;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      if (shimmerChild != null) {
        return shimmerChild!;
      }
      return const AppPageLoader();
    }

    if (errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(errorMessage!, textAlign: TextAlign.center),
              if (onRetry != null) ...[
                const SizedBox(height: 12),
                ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
              ],
            ],
          ),
        ),
      );
    }

    if (isEmpty) {
      return Center(child: Text(emptyMessage ?? 'No data available.'));
    }

    return child;
  }
}
