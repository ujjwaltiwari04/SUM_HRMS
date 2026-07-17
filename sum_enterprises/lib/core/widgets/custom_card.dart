import 'package:flutter/material.dart';
import 'package:sum_enterprises/core/constants/app_constants.dart';

/// Reusable clean Card widget for displaying records, field logs, or details.
/// Features soft shadows, a 14px border radius, and strict compliance with the Material 3 aesthetic.
class CustomCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Color? color;
  final double? elevation;
  final BorderSide? borderSide;

  const CustomCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.color,
    this.elevation,
    this.borderSide,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderRadius = BorderRadius.circular(AppConstants.defaultBorderRadius);

    Widget currentWidget = Container(
      decoration: BoxDecoration(
        color: color ?? theme.cardTheme.color,
        borderRadius: borderRadius,
        border: borderSide != null 
            ? Border.fromBorderSide(borderSide!) 
            : Border.all(color: theme.colorScheme.outline.withOpacity(0.08), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2), // Very soft, clean corporate shadow
          ),
        ],
      ),
      padding: padding ?? const EdgeInsets.all(AppConstants.defaultPadding),
      child: child,
    );

    if (onTap != null) {
      currentWidget = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius,
          splashColor: theme.colorScheme.primary.withOpacity(0.06),
          highlightColor: theme.colorScheme.primary.withOpacity(0.03),
          child: currentWidget,
        ),
      );
    }

    return currentWidget;
  }
}
