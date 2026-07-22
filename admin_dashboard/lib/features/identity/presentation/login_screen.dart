import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_error.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_error_banner.dart';
import '../../../core/widgets/app_text_field.dart';
import '../application/auth_controller.dart';

/// The only entry point into this app - there is no register screen,
/// deliberately: a system_administrator account is never self-served,
/// it's created directly against the backend by whoever already holds
/// that role. Centered card on a plain background rather than mobile/'s
/// full-bleed form, since this is desktop-only and never needs to
/// adapt to a narrow phone width.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isSubmitting = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await ref.read(authControllerProvider.notifier).login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (mounted) context.go('/');
    } on NotSystemAdministratorException {
      if (mounted) {
        setState(
          () => _errorMessage = 'Cet espace est réservé aux administrateurs système.',
        );
      }
    } catch (error) {
      if (mounted) setState(() => _errorMessage = extractApiErrorMessage(error));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: const Icon(Icons.shield_outlined, color: AppColors.textOnPrimary),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Text('Guinea Go Admin', style: textTheme.headlineMedium),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Console d\'administration système.',
                    style: textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  if (_errorMessage != null) ...[
                    AppErrorBanner(message: _errorMessage!),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  AppTextField(
                    controller: _emailController,
                    label: 'Email',
                    hint: 'admin@guineago.com',
                    keyboardType: TextInputType.emailAddress,
                    prefixIcon: Icons.mail_outline_rounded,
                    validator: AppValidators.email,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: _passwordController,
                    label: 'Mot de passe',
                    obscureText: _obscurePassword,
                    prefixIcon: Icons.lock_outline_rounded,
                    validator: AppValidators.password,
                    textInputAction: TextInputAction.done,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      ),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  AppButton(
                    label: 'Se connecter',
                    isLoading: _isSubmitting,
                    onPressed: _submit,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
