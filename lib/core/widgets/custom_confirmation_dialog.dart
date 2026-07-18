import 'package:flutter/material.dart';

class CustomConfirmationDialog extends StatelessWidget {
  final String title;
  final String? message;
  final List<String>? bulletPoints;
  final String cancelText;
  final String confirmText;
  final VoidCallback onConfirm;
  final Color? confirmButtonColor;
  final Color? confirmTextColor;
  final IconData? icon;
  final Color? iconColor;

  const CustomConfirmationDialog({
    super.key,
    required this.title,
    this.message,
    this.bulletPoints,
    this.cancelText = 'Cancel',
    this.confirmText = 'Confirm',
    required this.onConfirm,
    this.confirmButtonColor,
    this.confirmTextColor,
    this.icon,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              color: iconColor ?? theme.colorScheme.primary,
              size: 28,
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message != null) ...[
              Text(
                message!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  height: 1.4,
                ),
              ),
              if (bulletPoints != null && bulletPoints!.isNotEmpty)
                const SizedBox(height: 12),
            ],
            if (bulletPoints != null && bulletPoints!.isNotEmpty) ...[
              ...bulletPoints!.map((point) => Padding(
                    padding: const EdgeInsets.only(bottom: 6.0, left: 4.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '• ',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            point,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            cancelText.toUpperCase(),
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: confirmButtonColor ?? theme.colorScheme.primary,
            foregroundColor: confirmTextColor ?? theme.colorScheme.onPrimary,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: () {
            Navigator.pop(context);
            onConfirm();
          },
          child: Text(
            confirmText.toUpperCase(),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
