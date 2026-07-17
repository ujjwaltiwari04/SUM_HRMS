import 'package:flutter/material.dart';

/// Customized, lightweight brand-themed progress indicator.
class LoadingIndicator extends StatelessWidget {
  final double size;
  final double strokeWidth;
  final String? message;

  const LoadingIndicator({
    super.key,
    this.size = 28.0,
    this.strokeWidth = 3.0,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    Widget indicator = SizedBox(
      height: size,
      width: size,
      child: CircularProgressIndicator(
        strokeWidth: strokeWidth,
        valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
        backgroundColor: theme.colorScheme.primary.withOpacity(0.12),
      ),
    );

    if (message != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            indicator,
            const SizedBox(height: 12.0),
            Text(
              message!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onBackground.withOpacity(0.7),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return Center(child: indicator);
  }
}
