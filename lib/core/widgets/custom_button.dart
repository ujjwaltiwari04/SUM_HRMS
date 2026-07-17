import 'package:flutter/material.dart';
import 'package:sum_enterprises/core/constants/app_constants.dart';

/// Reusable Copper Brown branded Material 3 Button.
/// Handles active loading states, disabled modes, icons, and aligns to the 14px rounded design rule.
class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final bool isFullWidth;
  final Color? backgroundColor;
  final Color? textColor;

  const CustomButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.isFullWidth = true,
    this.backgroundColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isButtonEnabled = onPressed != null && !isLoading;

    final Widget buttonChild = isLoading
        ? SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.0,
              valueColor: AlwaysStoppedAnimation<Color>(
                textColor ?? theme.colorScheme.onPrimary,
              ),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18),
                const SizedBox(width: 8),
              ],
              Text(
                text,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: isButtonEnabled
                      ? (textColor ?? theme.colorScheme.onPrimary)
                      : theme.colorScheme.onSurface.withOpacity(0.38),
                ),
              ),
            ],
          );

    final buttonStyle = ElevatedButton.styleFrom(
      backgroundColor: backgroundColor ?? theme.colorScheme.primary,
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 24.0),
      elevation: isButtonEnabled ? AppConstants.defaultElevation : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
      ),
    );

    return SizedBox(
      width: isFullWidth ? double.infinity : null,
      child: ElevatedButton(
        style: buttonStyle,
        onPressed: isButtonEnabled ? onPressed : null,
        child: buttonChild,
      ),
    );
  }
}
