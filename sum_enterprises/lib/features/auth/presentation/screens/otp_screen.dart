import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sum_enterprises/core/constants/app_constants.dart';
import 'package:sum_enterprises/core/widgets/custom_button.dart';
import 'package:sum_enterprises/features/auth/presentation/providers/auth_provider.dart';

/// Production-ready OTP Verification Screen with full feedback loop.
/// Integrates a 60-second reactive countdown timer, automated pin-field formatters, and unified Riverpod status watchers.
class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _otpController = TextEditingController();
  
  // Timer States
  Timer? _timer;
  int _secondsRemaining = 60;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  void _startCountdown() {
    setState(() {
      _secondsRemaining = 60;
      _canResend = false;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        setState(() {
          _canResend = true;
        });
        _timer?.cancel();
      }
    });
  }

  void _verifyCode() {
    if (_formKey.currentState?.validate() ?? false) {
      FocusScope.of(context).unfocus();
      final code = _otpController.text.trim();
      ref.read(phoneAuthControllerProvider.notifier).verifyOtp(code);
    }
  }

  void _resendCode() {
    if (_canResend) {
      final phone = ref.read(phoneAuthControllerProvider).phoneNumber;
      if (phone.isNotEmpty) {
        ref.read(phoneAuthControllerProvider.notifier).sendOtp(phone);
        _startCountdown();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            id: const ValueKey('resend_success_snackbar'),
            content: const Text('A fresh 6-digit OTP code has been dispatched.'),
            backgroundColor: Theme.of(context).colorScheme.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = ref.watch(phoneAuthControllerProvider);

    // Watcher to capture errors thrown during verification
    ref.listen<PhoneAuthState>(phoneAuthControllerProvider, (previous, next) {
      if (next.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            id: const ValueKey('otp_error_snackbar'),
            content: Text(next.errorMessage!),
            backgroundColor: theme.colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
        ref.read(phoneAuthControllerProvider.notifier).clearError();
      }
    });

    return Scaffold(
      id: const ValueKey('otp_scaffold'),
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        id: const ValueKey('otp_app_bar'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          id: const ValueKey('otp_back_button'),
          icon: Icon(Icons.arrow_back_rounded, color: theme.colorScheme.onSurface),
          onPressed: () {
            ref.read(phoneAuthControllerProvider.notifier).resetToPhoneEntry();
            context.pop();
          },
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 12.0),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 24,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Brand Indicator Icon
                    Center(
                      child: Container(
                        id: const ValueKey('otp_icon_container'),
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withOpacity(0.08),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.security_rounded,
                          size: 36,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Headings
                    Text(
                      'Security Verification',
                      id: const ValueKey('otp_screen_title'),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    RichText(
                      id: const ValueKey('otp_subtitle_rich_text'),
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        children: [
                          const TextSpan(text: 'We sent a 6-digit confirmation code to '),
                          TextSpan(
                            text: authState.phoneNumber,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const TextSpan(text: '. Please input it below to sign in.'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Form Input Card
                    Form(
                      key: _formKey,
                      id: const ValueKey('otp_form'),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFormField(
                            id: const ValueKey('otp_input_field'),
                            controller: _otpController,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.done,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.headlineMedium?.copyWith(
                              letterSpacing: 8.0,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLength: 6,
                            onFieldSubmitted: (_) => _verifyCode(),
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Please enter the 6-digit code.';
                              }
                              if (val.trim().length != 6) {
                                return 'Code must be exactly 6 digits.';
                              }
                              return null;
                            },
                            decoration: InputDecoration(
                              counterText: '',
                              hintText: '000000',
                              hintStyle: TextStyle(
                                color: theme.colorScheme.onSurface.withOpacity(0.15),
                              ),
                              filled: true,
                              fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
                              ),
                              contentPadding: const EdgeInsets.symmetric(vertical: 20),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Countdown Text Label
                          Center(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: _canResend
                                  ? TextButton.icon(
                                      id: const ValueKey('resend_otp_button'),
                                      onPressed: authState.isLoading ? null : _resendCode,
                                      icon: const Icon(Icons.refresh_rounded, size: 18),
                                      label: const Text('Resend OTP Code'),
                                      style: TextButton.styleFrom(
                                        foregroundColor: theme.colorScheme.primary,
                                      ),
                                    )
                                  : Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      key: const ValueKey('timer_row'),
                                      children: [
                                        Icon(
                                          Icons.timer_outlined,
                                          size: 16,
                                          color: theme.colorScheme.onSurfaceVariant,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Resend code in ${_secondsRemaining}s',
                                          style: theme.textTheme.bodyMedium?.copyWith(
                                            color: theme.colorScheme.onSurfaceVariant,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                          const SizedBox(height: 32),

                          // Verification Trigger Button
                          CustomButton(
                            id: const ValueKey('verify_otp_button'),
                            text: 'VERIFY & PROCEED',
                            icon: Icons.verified_user_rounded,
                            isLoading: authState.isLoading,
                            onPressed: _verifyCode,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Change phone helper link
                    Center(
                      child: TextButton(
                        id: const ValueKey('change_phone_number_link'),
                        onPressed: authState.isLoading
                            ? null
                            : () {
                                ref.read(phoneAuthControllerProvider.notifier).resetToPhoneEntry();
                                context.pop();
                              },
                        child: Text(
                          'Incorrect number? Change Phone Number',
                          style: TextStyle(
                            color: theme.colorScheme.primary.withOpacity(0.8),
                            decoration: TextDecoration.underline,
                          ),
                        ),
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
