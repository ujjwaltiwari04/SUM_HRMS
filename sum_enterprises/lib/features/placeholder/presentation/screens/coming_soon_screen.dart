import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// A generic, clean, reusable production-ready placeholder screen.
/// Displays the title of a future module, a "Coming Soon" visual signature, and a Material 3 back button.
class ComingSoonScreen extends StatelessWidget {
  final String title;

  const ComingSoonScreen({
    super.key,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      id: ValueKey('coming_soon_scaffold_${title.replaceAll(' ', '_').toLowerCase()}'),
      appBar: AppBar(
        id: ValueKey('coming_soon_app_bar_${title.replaceAll(' ', '_').toLowerCase()}'),
        title: Text(title),
        centerTitle: true,
        leading: IconButton(
          id: ValueKey('coming_soon_back_${title.replaceAll(' ', '_').toLowerCase()}'),
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Minimalist visual clock/cog indicator
                Container(
                  id: ValueKey('coming_soon_icon_container_${title.replaceAll(' ', '_').toLowerCase()}'),
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.hourglass_empty_rounded,
                    size: 44,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 32),

                // Coming Soon Typography
                Text(
                  title.toUpperCase(),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2.0,
                    color: theme.colorScheme.primary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Coming Soon',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'We are actively preparing this module for SUM Enterprises. Automated validation and sync features will be fully functional in the next secure release.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),

                // Simple action to return home
                OutlinedButton.icon(
                  id: ValueKey('coming_soon_back_button_${title.replaceAll(' ', '_').toLowerCase()}'),
                  onPressed: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/');
                    }
                  },
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: const Text('GO BACK'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
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
