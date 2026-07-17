import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sum_enterprises/core/constants/app_constants.dart';
import 'package:sum_enterprises/core/widgets/custom_button.dart';
import 'package:sum_enterprises/features/auth/presentation/providers/auth_provider.dart';

/// Clean, high-contrast Material 3 Corporate Login Screen for SUM Enterprises.
/// Features input validation, clean branding, responsive feedback, and secure transition signals.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  /// Interactive phone validation conforming to standard E.164 formats (+1234567890)
  String? _validatePhoneNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your registered phone number.';
    }
    final trimmed = value.trim();
    if (!trimmed.startsWith('+')) {
      return 'Include your country dial code (e.g., +1 or +91).';
    }
    if (trimmed.length < 8 || trimmed.length > 16) {
      return 'Enter a valid international phone number.';
    }
    // Check if the rest of characters are strictly numeric
    final digits = trimmed.substring(1);
    if (RegExp(r'^\d+$').hasMatch(digits) == false) {
      return 'Phone number must contain only numeric digits.';
    }
    return null;
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      // Form matches formatting requirements; request Firebase OTP
      FocusScope.of(context).unfocus();
      final phone = _phoneController.text.trim();
      ref.read(phoneAuthControllerProvider.notifier).sendOtp(phone);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = ref.watch(phoneAuthControllerProvider);

    // Responsive navigation listener triggers when step changes to OTP phase
    ref.listen<PhoneAuthState>(phoneAuthControllerProvider, (previous, next) {
      if (next.step == PhoneAuthStep.enteringOtp) {
        context.push('/otp');
      } else if (next.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            key: const ValueKey('login_error_snackbar'),
            content: Text(next.errorMessage!),
            backgroundColor: theme.colorScheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        ref.read(phoneAuthControllerProvider.notifier).clearError();
      }
    });

    return Scaffold(
      key: const ValueKey('login_scaffold'),
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 24.0),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 48,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 24),
                    // Corporate Geometric Brand Logo Card
                    Center(
                      child: Container(
                        key: const ValueKey('brand_logo_container'),
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: theme.colorScheme.primary.withOpacity(0.12),
                            width: 1.5,
                          ),
                        ),
                        child: Icon(
                          Icons.corporate_fare_rounded,
                          size: 48,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Welcome Text Block
                    Text(
                      'SUM ENTERPRISES',
                      key: const ValueKey('company_name_title'),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontFamily: 'Space Grotesk',
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2.0,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Corporate Staff Identity Authentication Portal',
                      key: const ValueKey('portal_subtitle'),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 48),

                    // Form Fields
                    Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFormField(
                            key: const ValueKey('phone_number_field'),
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _submit(),
                            validator: _validatePhoneNumber,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s\-]')),
                            ],
                            decoration: InputDecoration(
                              labelText: 'Registered Phone Number',
                              hintText: '+1 555 123 4567',
                              prefixIcon: Icon(
                                Icons.phone_android_rounded,
                                color: theme.colorScheme.primary,
                              ),
                              filled: true,
                              fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),

                          // Trigger Button
                          CustomButton(
                            key: const ValueKey('continue_button'),
                            text: 'CONTINUE',
                            icon: Icons.arrow_forward_rounded,
                            isLoading: authState.isLoading,
                            onPressed: _submit,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 48),

                    // Compliance disclaimer footer
                    Text(
                      'This device and network endpoint are protected by private sum corporate security rules. Authorized staff members only.',
                      key: const ValueKey('compliance_footer'),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
                        fontSize: 11,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
